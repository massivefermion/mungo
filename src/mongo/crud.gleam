import gleam/list
import bson/types
import mongo/utils
import mongo/client
import bson/object_id

pub type UpdateResult {
  UpdateResult(n: Int, modified: Int)
  UpsertResult(n: Int, upserted: object_id.ObjectId)
}

pub fn insert_one(collection, doc) {
  collection
  |> insert_many([doc])
}

pub fn find_by_id(collection, id) {
  case object_id.from_string(id) {
    Ok(id) ->
      collection
      |> find_one(
        types.Document([#("_id", types.ObjectId(id))]),
        types.Document([]),
      )
    Error(Nil) -> Error(utils.default_error)
  }
}

pub fn find_one(collection, filter, projection) {
  case filter {
    types.Document(_) ->
      case projection {
        types.Document(doc) -> {
          let options = case doc {
            [] -> [utils.Limit(1)]
            _ -> [utils.Limit(1), utils.Projection(projection)]
          }
          case collection
          |> find_many(filter, options) {
            Ok([]) -> Ok(types.Null)
            Ok([doc]) -> Ok(doc)
            Error(error) -> Error(error)
          }
        }
        _ -> Error(utils.default_error)
      }
    _ -> Error(utils.default_error)
  }
}

pub fn insert_many(
  collection: client.Collection,
  docs: List(types.Value),
) -> Result(Int, utils.MongoError) {
  case docs
  |> list.all(fn(doc) {
    case doc {
      types.Document(_) -> True
      _ -> False
    }
  }) {
    True ->
      case collection
      |> client.execute(types.Document([
        #("insert", types.Str(collection.name)),
        #("documents", types.Array(docs)),
      ])) {
        Ok([#("n", types.Integer(n)), #("ok", ok)]) ->
          case ok {
            types.Double(1.0) -> Ok(n)
            _ -> Error(utils.default_error)
          }
        Ok([#("n", _), #("writeErrors", types.Array(errors)), #("ok", ok)]) ->
          case ok {
            types.Double(1.0) -> {
              assert Ok(error) = list.first(errors)
              case error {
                types.Document([
                  #("index", _),
                  #("code", types.Integer(code)),
                  #("keyPattern", _),
                  #("keyValue", source),
                  #("errmsg", types.Str(msg)),
                ]) -> Error(utils.MongoError(code, msg, source))
                _ -> Error(utils.default_error)
              }
            }
            _ -> Error(utils.default_error)
          }
        Error(#(code, msg)) ->
          Error(utils.MongoError(code, msg, source: types.Null))
      }
    False -> Error(utils.default_error)
  }
}

pub fn find_all(
  collection: client.Collection,
  options: List(utils.FindOption),
) -> Result(List(types.Value), utils.MongoError) {
  let body = [#("find", types.Str(collection.name))]
  let options =
    options
    |> list.fold(
      [],
      fn(acc, opt) {
        case opt {
          utils.Sort(types.Document(sort)) -> [
            #("sort", types.Document(sort)),
            ..acc
          ]
          utils.Projection(types.Document(projection)) -> [
            #("projection", types.Document(projection)),
            ..acc
          ]
          utils.Skip(skip) -> [#("skip", types.Integer(skip)), ..acc]
          utils.Limit(limit) -> [#("limit", types.Integer(limit)), ..acc]
        }
      },
    )
  let body = list.append(options, body)
  case collection
  |> client.execute(types.Document(body)) {
    Ok(result) -> {
      let [#("cursor", types.Document(result)), #("ok", ok)] = result
      let [#("firstBatch", types.Array(docs)), #("id", _), #("ns", _)] = result
      case ok {
        types.Double(1.0) -> Ok(docs)
        _ -> Error(utils.default_error)
      }
    }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: types.Null))
  }
}

pub fn find_many(
  collection: client.Collection,
  filter: types.Value,
  options: List(utils.FindOption),
) -> Result(List(types.Value), utils.MongoError) {
  case filter {
    types.Document(_) -> {
      let body = [
        #("find", types.Str(collection.name)),
        #("filter", filter),
        #("batchSize", types.Integer(2)),
      ]
      let options =
        options
        |> list.fold(
          [],
          fn(acc, opt) {
            case opt {
              utils.Sort(types.Document(sort)) -> [
                #("sort", types.Document(sort)),
                ..acc
              ]
              utils.Projection(types.Document(projection)) -> [
                #("projection", types.Document(projection)),
                ..acc
              ]
              utils.Skip(skip) -> [#("skip", types.Integer(skip)), ..acc]
              utils.Limit(limit) -> [#("limit", types.Integer(limit)), ..acc]
            }
          },
        )
      let body = list.append(body, options)
      case collection
      |> client.execute(types.Document(body)) {
        Ok(result) -> {
          let [#("cursor", types.Document(result)), #("ok", ok)] = result
          let [#("firstBatch", types.Array(docs)), #("id", _), #("ns", _)] =
            result
          case ok {
            types.Double(1.0) -> Ok(docs)
            _ -> Error(utils.default_error)
          }
        }
        Error(#(code, msg)) ->
          Error(utils.MongoError(code, msg, source: types.Null))
      }
    }

    _ -> Error(utils.default_error)
  }
}

pub fn update_one(
  collection: client.Collection,
  filter: types.Value,
  change: types.Value,
  options: List(utils.UpdateOption),
) {
  case filter {
    types.Document(_) ->
      case change {
        types.Document(_) -> {
          let update = [
            #("q", filter),
            #("u", change),
            #("multi", types.Boolean(False)),
          ]
          let options =
            options
            |> list.fold(
              [],
              fn(acc, opt) {
                case opt {
                  utils.Upsert -> [#("upsert", types.Boolean(True)), ..acc]
                  utils.ArrayFilters(filters) -> [
                    #("arrayFilters", types.Array(filters)),
                    ..acc
                  ]
                }
              },
            )
          let update = types.Document(list.append(update, options))
          case collection
          |> client.execute(types.Document([
            #("update", types.Str(collection.name)),
            #("updates", types.Array([update])),
          ])) {
            Ok([
              #("n", types.Integer(n)),
              #("nModified", types.Integer(modified)),
              #("ok", ok),
            ]) ->
              case ok {
                types.Double(1.0) -> Ok(UpdateResult(n, modified))
                _ -> Error(utils.default_error)
              }
            Ok([
              #("n", types.Integer(n)),
              #(
                "upserted",
                types.Array([
                  types.Document([
                    #("_id", types.ObjectId(upserted)),
                    #("index", _),
                  ]),
                ]),
              ),
              #("nModified", _),
              #("ok", ok),
            ]) ->
              case ok {
                types.Double(1.0) -> Ok(UpsertResult(n, upserted))
                _ -> Error(utils.default_error)
              }
            Ok([
              #("n", _),
              #("writeErrors", types.Array(errors)),
              #("nModified", _),
              #("ok", ok),
            ]) ->
              case ok {
                types.Double(1.0) -> {
                  assert Ok(error) = list.first(errors)
                  case error {
                    types.Document([
                      #("index", _),
                      #("code", types.Integer(code)),
                      #("keyPattern", _),
                      #("keyValue", source),
                      #("errmsg", types.Str(msg)),
                    ]) -> Error(utils.MongoError(code, msg, source))
                    _ -> Error(utils.default_error)
                  }
                }
                _ -> Error(utils.default_error)
              }
            Error(#(code, msg)) ->
              Error(utils.MongoError(code, msg, source: types.Null))
          }
        }
        _ -> Error(utils.default_error)
      }
    _ -> Error(utils.default_error)
  }
}

pub fn update_many(
  collection: client.Collection,
  filter: types.Value,
  change: types.Value,
  options: List(utils.UpdateOption),
) {
  case filter {
    types.Document(_) ->
      case change {
        types.Document(_) -> {
          let update = [
            #("q", filter),
            #("u", change),
            #("multi", types.Boolean(True)),
          ]
          let options =
            options
            |> list.fold(
              [],
              fn(acc, opt) {
                case opt {
                  utils.Upsert -> [#("upsert", types.Boolean(True)), ..acc]
                  utils.ArrayFilters(filters) -> [
                    #("arrayFilters", types.Array(filters)),
                    ..acc
                  ]
                }
              },
            )
          let update = types.Document(list.append(update, options))
          case collection
          |> client.execute(types.Document([
            #("update", types.Str(collection.name)),
            #("updates", types.Array([update])),
          ])) {
            Ok([
              #("n", types.Integer(n)),
              #("nModified", types.Integer(modified)),
              #("ok", ok),
            ]) ->
              case ok {
                types.Double(1.0) -> Ok(UpdateResult(n, modified))
                _ -> Error(utils.default_error)
              }
            Ok([
              #("n", types.Integer(n)),
              #(
                "upserted",
                types.Array([
                  types.Document([
                    #("_id", types.ObjectId(upserted)),
                    #("index", _),
                  ]),
                ]),
              ),
              #("nModified", _),
              #("ok", ok),
            ]) ->
              case ok {
                types.Double(1.0) -> Ok(UpsertResult(n, upserted))
                _ -> Error(utils.default_error)
              }
            Ok([
              #("n", _),
              #("writeErrors", types.Array(errors)),
              #("nModified", _),
              #("ok", ok),
            ]) ->
              case ok {
                types.Double(1.0) -> {
                  assert Ok(error) = list.first(errors)
                  case error {
                    types.Document([
                      #("index", _),
                      #("code", types.Integer(code)),
                      #("keyPattern", _),
                      #("keyValue", source),
                      #("errmsg", types.Str(msg)),
                    ]) -> Error(utils.MongoError(code, msg, source))
                    _ -> Error(utils.default_error)
                  }
                }
                _ -> Error(utils.default_error)
              }
            Error(#(code, msg)) ->
              Error(utils.MongoError(code, msg, source: types.Null))
          }
        }
        _ -> Error(utils.default_error)
      }
    _ -> Error(utils.default_error)
  }
}

pub fn delete_one(collection: client.Collection, filter: types.Value) {
  case filter {
    types.Document(_) ->
      case collection
      |> client.execute(types.Document([
        #("delete", types.Str(collection.name)),
        #(
          "deletes",
          types.Array([
            types.Document([#("q", filter), #("limit", types.Integer(1))]),
          ]),
        ),
      ])) {
        Ok([#("n", types.Integer(n)), #("ok", ok)]) ->
          case ok {
            types.Double(1.0) -> Ok(n)
            _ -> Error(utils.default_error)
          }
        Ok([#("n", _), #("writeErrors", types.Array(errors)), #("ok", ok)]) ->
          case ok {
            types.Double(1.0) -> {
              assert Ok(error) = list.first(errors)
              case error {
                types.Document([
                  #("index", _),
                  #("code", types.Integer(code)),
                  #("keyPattern", _),
                  #("keyValue", source),
                  #("errmsg", types.Str(msg)),
                ]) -> Error(utils.MongoError(code, msg, source))
                _ -> Error(utils.default_error)
              }
            }
            _ -> Error(utils.default_error)
          }
        Error(#(code, msg)) ->
          Error(utils.MongoError(code, msg, source: types.Null))
      }
    _ -> Error(utils.default_error)
  }
}

pub fn delete_many(collection: client.Collection, filter: types.Value) {
  case filter {
    types.Document(_) ->
      case collection
      |> client.execute(types.Document([
        #("delete", types.Str(collection.name)),
        #(
          "deletes",
          types.Array([
            types.Document([#("q", filter), #("limit", types.Integer(0))]),
          ]),
        ),
      ])) {
        Ok([#("n", types.Integer(n)), #("ok", ok)]) ->
          case ok {
            types.Double(1.0) -> Ok(n)
            _ -> Error(utils.default_error)
          }
        Ok([#("n", _), #("writeErrors", types.Array(errors)), #("ok", ok)]) ->
          case ok {
            types.Double(1.0) -> {
              assert Ok(error) = list.first(errors)
              case error {
                types.Document([
                  #("index", _),
                  #("code", types.Integer(code)),
                  #("keyPattern", _),
                  #("keyValue", source),
                  #("errmsg", types.Str(msg)),
                ]) -> Error(utils.MongoError(code, msg, source))
                _ -> Error(utils.default_error)
              }
            }
            _ -> Error(utils.default_error)
          }
        Error(#(code, msg)) ->
          Error(utils.MongoError(code, msg, source: types.Null))
      }
    _ -> Error(utils.default_error)
  }
}

pub fn count_all(collection: client.Collection) {
  case collection
  |> client.execute(types.Document([#("count", types.Str(collection.name))])) {
    Ok([#("n", types.Integer(n)), #("ok", ok)]) ->
      case ok {
        types.Double(1.0) -> Ok(n)
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: types.Null))
  }
}

pub fn count(collection: client.Collection, filter: types.Value) {
  case filter {
    types.Document(_) ->
      case collection
      |> client.execute(types.Document([
        #("count", types.Str(collection.name)),
        #("query", filter),
      ])) {
        Ok([#("n", types.Integer(n)), #("ok", ok)]) ->
          case ok {
            types.Double(1.0) -> Ok(n)
            _ -> Error(utils.default_error)
          }
        Error(#(code, msg)) ->
          Error(utils.MongoError(code, msg, source: types.Null))
      }
    _ -> Error(utils.default_error)
  }
}

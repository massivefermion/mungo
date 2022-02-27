import gleam/list
import bson/types
import mongo/utils
import mongo/client
import bson/object_id

pub type MongoError {
  MongoError(code: Int, msg: String, source: types.Value)
}

pub type UpdateResult {
  UpdateResult(n: Int, modified: Int)
  UpsertResult(n: Int, upserted: object_id.ObjectId)
}

const default_error = MongoError(code: 0, msg: "", source: types.Null)

pub fn insert_many(
  collection: client.Collection,
  docs: List(types.Value),
) -> Result(Int, MongoError) {
  case docs
  |> list.all(fn(doc) {
    case doc {
      types.Document(_) -> True
      _ -> False
    }
  }) {
    True ->
      case client.execute(
        collection,
        types.Document([
          #("documents", types.Array(docs)),
          #("insert", types.Str(collection.name)),
        ]),
      ) {
        Ok([#("ok", ok), #("n", types.Integer(n))]) ->
          case ok {
            types.Double(1.0) -> Ok(n)
            _ -> Error(default_error)
          }
        Ok([#("ok", ok), #("writeErrors", types.Array(errors)), #("n", _)]) ->
          case ok {
            types.Double(1.0) -> {
              assert Ok(error) = list.first(errors)
              case error {
                types.Document([
                  #("errmsg", types.Str(msg)),
                  #("keyValue", source),
                  #("keyPattern", _),
                  #("code", types.Integer(code)),
                  #("index", _),
                ]) -> Error(MongoError(code, msg, source))
                _ -> Error(default_error)
              }
            }
            _ -> Error(default_error)
          }
        Error(Nil) -> Error(default_error)
      }
    False -> Error(default_error)
  }
}

pub fn insert_one(collection, doc) {
  insert_many(collection, [doc])
}

pub fn find(
  collection: client.Collection,
  filter: types.Value,
  options: List(utils.FindOption),
) -> Result(List(types.Value), MongoError) {
  case filter {
    types.Document(_) -> {
      let body = [#("filter", filter), #("find", types.Str(collection.name))]
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
      case client.execute(collection, types.Document(body)) {
        Ok(result) -> {
          let [#("ok", ok), #("cursor", types.Document(result))] = result
          let [#("ns", _), #("id", _), #("firstBatch", types.Array(docs))] =
            result
          case ok {
            types.Double(1.0) -> Ok(docs)
            _ -> Error(default_error)
          }
        }
        Error(Nil) -> Error(default_error)
      }
    }

    _ -> Error(default_error)
  }
}

pub fn find_all(
  collection: client.Collection,
  options: List(utils.FindOption),
) -> Result(List(types.Value), MongoError) {
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
  case client.execute(collection, types.Document(body)) {
    Ok(result) -> {
      let [#("ok", ok), #("cursor", types.Document(result))] = result
      let [#("ns", _), #("id", _), #("firstBatch", types.Array(docs))] = result
      case ok {
        types.Double(1.0) -> Ok(docs)
        _ -> Error(default_error)
      }
    }
    Error(Nil) -> Error(default_error)
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
                  utils.Upsert(upsert) -> [
                    #("upsert", types.Boolean(upsert)),
                    ..acc
                  ]
                  utils.ArrayFilters(filters) -> [
                    #("arrayFilters", types.Array(filters)),
                    ..acc
                  ]
                }
              },
            )
          let update = types.Document(list.append(update, options))
          case client.execute(
            collection,
            types.Document([
              #("updates", types.Array([update])),
              #("update", types.Str(collection.name)),
            ]),
          ) {
            Ok([
              #("ok", ok),
              #("nModified", types.Integer(modified)),
              #("n", types.Integer(n)),
            ]) ->
              case ok {
                types.Double(1.0) -> Ok(UpdateResult(n, modified))
                _ -> Error(default_error)
              }
            Ok([
              #("ok", ok),
              #("nModified", _),
              #(
                "upserted",
                types.Array([
                  types.Document([
                    #("_id", types.ObjectId(upserted)),
                    #("index", _),
                  ]),
                ]),
              ),
              #("n", types.Integer(n)),
            ]) ->
              case ok {
                types.Double(1.0) -> Ok(UpsertResult(n, upserted))
                _ -> Error(default_error)
              }
            Ok([
              #("ok", ok),
              #("nModified", _),
              #("writeErrors", types.Array(errors)),
              #("n", _),
            ]) ->
              case ok {
                types.Double(1.0) -> {
                  assert Ok(error) = list.first(errors)
                  case error {
                    types.Document([
                      #("errmsg", types.Str(msg)),
                      #("keyValue", source),
                      #("keyPattern", _),
                      #("code", types.Integer(code)),
                      #("index", _),
                    ]) -> Error(MongoError(code, msg, source))
                    _ -> Error(default_error)
                  }
                }
                _ -> Error(default_error)
              }
            Error(Nil) -> Error(default_error)
          }
        }
        _ -> Error(default_error)
      }
    _ -> Error(default_error)
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
                  utils.Upsert(upsert) -> [
                    #("upsert", types.Boolean(upsert)),
                    ..acc
                  ]
                  utils.ArrayFilters(filters) -> [
                    #("arrayFilters", types.Array(filters)),
                    ..acc
                  ]
                }
              },
            )
          let update = types.Document(list.append(update, options))
          case client.execute(
            collection,
            types.Document([
              #("updates", types.Array([update])),
              #("update", types.Str(collection.name)),
            ]),
          ) {
            Ok([
              #("ok", ok),
              #("nModified", types.Integer(modified)),
              #("n", types.Integer(n)),
            ]) ->
              case ok {
                types.Double(1.0) -> Ok(UpdateResult(n, modified))
                _ -> Error(default_error)
              }
            Ok([
              #("ok", ok),
              #("nModified", _),
              #(
                "upserted",
                types.Array([
                  types.Document([
                    #("_id", types.ObjectId(upserted)),
                    #("index", _),
                  ]),
                ]),
              ),
              #("n", types.Integer(n)),
            ]) ->
              case ok {
                types.Double(1.0) -> Ok(UpsertResult(n, upserted))
                _ -> Error(default_error)
              }
            Ok([
              #("ok", ok),
              #("nModified", _),
              #("writeErrors", types.Array(errors)),
              #("n", _),
            ]) ->
              case ok {
                types.Double(1.0) -> {
                  assert Ok(error) = list.first(errors)
                  case error {
                    types.Document([
                      #("errmsg", types.Str(msg)),
                      #("keyValue", source),
                      #("keyPattern", _),
                      #("code", types.Integer(code)),
                      #("index", _),
                    ]) -> Error(MongoError(code, msg, source))
                    _ -> Error(default_error)
                  }
                }
                _ -> Error(default_error)
              }
            Error(Nil) -> Error(default_error)
          }
        }
        _ -> Error(default_error)
      }
    _ -> Error(default_error)
  }
}

pub fn delete_many(collection: client.Collection, filter: types.Value) {
  case filter {
    types.Document(_) ->
      case client.execute(
        collection,
        types.Document([
          #(
            "deletes",
            types.Array([
              types.Document([#("q", filter), #("limit", types.Integer(0))]),
            ]),
          ),
          #("delete", types.Str(collection.name)),
        ]),
      ) {
        Ok([#("ok", ok), #("n", types.Integer(n))]) ->
          case ok {
            types.Double(1.0) -> Ok(n)
            _ -> Error(default_error)
          }
        Ok([#("ok", ok), #("writeErrors", types.Array(errors)), #("n", _)]) ->
          case ok {
            types.Double(1.0) -> {
              assert Ok(error) = list.first(errors)
              case error {
                types.Document([
                  #("errmsg", types.Str(msg)),
                  #("keyValue", source),
                  #("keyPattern", _),
                  #("code", types.Integer(code)),
                  #("index", _),
                ]) -> Error(MongoError(code, msg, source))
                _ -> Error(default_error)
              }
            }
            _ -> Error(default_error)
          }
        Error(Nil) -> Error(default_error)
      }
    _ -> Error(default_error)
  }
}

pub fn delete_one(collection: client.Collection, filter: types.Value) {
  case filter {
    types.Document(_) ->
      case client.execute(
        collection,
        types.Document([
          #(
            "deletes",
            types.Array([
              types.Document([#("q", filter), #("limit", types.Integer(1))]),
            ]),
          ),
          #("delete", types.Str(collection.name)),
        ]),
      ) {
        Ok([#("ok", ok), #("n", types.Integer(n))]) ->
          case ok {
            types.Double(1.0) -> Ok(n)
            _ -> Error(default_error)
          }
        Ok([#("ok", ok), #("writeErrors", types.Array(errors)), #("n", _)]) ->
          case ok {
            types.Double(1.0) -> {
              assert Ok(error) = list.first(errors)
              case error {
                types.Document([
                  #("errmsg", types.Str(msg)),
                  #("keyValue", source),
                  #("keyPattern", _),
                  #("code", types.Integer(code)),
                  #("index", _),
                ]) -> Error(MongoError(code, msg, source))
                _ -> Error(default_error)
              }
            }
            _ -> Error(default_error)
          }
        Error(Nil) -> Error(default_error)
      }
    _ -> Error(default_error)
  }
}

pub fn count(collection: client.Collection, filter: types.Value) {
  case filter {
    types.Document(_) ->
      case client.execute(
        collection,
        types.Document([
          #("query", filter),
          #("count", types.Str(collection.name)),
        ]),
      ) {
        Ok([#("ok", ok), #("n", types.Integer(n))]) ->
          case ok {
            types.Double(1.0) -> Ok(n)
            _ -> Error(default_error)
          }
        Error(Nil) -> Error(default_error)
      }
    _ -> Error(default_error)
  }
}

pub fn count_all(collection: client.Collection) {
  case client.execute(
    collection,
    types.Document([#("count", types.Str(collection.name))]),
  ) {
    Ok([#("ok", ok), #("n", types.Integer(n))]) ->
      case ok {
        types.Double(1.0) -> Ok(n)
        _ -> Error(default_error)
      }
    Error(Nil) -> Error(default_error)
  }
}

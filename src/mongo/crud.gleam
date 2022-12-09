import gleam/list
import gleam/pair
import bson/types
import mongo/utils
import mongo/client
import bson/object_id

pub type InsertResult {
  InsertResult(inserted: Int, inserted_ids: List(types.Value))
}

pub type UpdateResult {
  UpdateResult(matched: Int, modified: Int)
  UpsertResult(matched: Int, upserted_id: types.Value)
}

pub fn insert_one(collection, doc) {
  case
    collection
    |> insert_many([doc])
  {
    Ok(InsertResult(inserted: _, inserted_ids: [id])) -> Ok(id)
    Error(error) -> Error(error)
  }
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
          case
            collection
            |> find_many(filter, options)
          {
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

pub fn find_many(
  collection: client.Collection,
  filter: types.Value,
  options: List(utils.FindOption),
) -> Result(List(types.Value), utils.MongoError) {
  collection
  |> find(filter, options)
}

pub fn find_all(
  collection: client.Collection,
  options: List(utils.FindOption),
) -> Result(List(types.Value), utils.MongoError) {
  collection
  |> find(types.Document([]), options)
}

pub fn update_one(
  collection: client.Collection,
  filter: types.Value,
  change: types.Value,
  options: List(utils.UpdateOption),
) {
  collection
  |> update(filter, change, options, False)
}

pub fn update_many(
  collection: client.Collection,
  filter: types.Value,
  change: types.Value,
  options: List(utils.UpdateOption),
) {
  collection
  |> update(filter, change, options, True)
}

pub fn delete_one(collection: client.Collection, filter: types.Value) {
  collection
  |> delete(filter, False)
}

pub fn delete_many(collection: client.Collection, filter: types.Value) {
  collection
  |> delete(filter, True)
}

pub fn count_all(collection: client.Collection) {
  case
    collection
    |> client.execute(types.Document([#("count", types.Str(collection.name))]))
  {
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
      case
        collection
        |> client.execute(types.Document([
          #("count", types.Str(collection.name)),
          #("query", filter),
        ]))
      {
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

pub fn insert_many(
  collection: client.Collection,
  docs: List(types.Value),
) -> Result(InsertResult, utils.MongoError) {
  case
    list.all(
      docs,
      fn(doc) {
        case doc {
          types.Document(_) -> True
          _ -> False
        }
      },
    )
  {
    True -> {
      let docs =
        list.map(
          docs,
          fn(d) {
            case d {
              types.Document(fields) ->
                case list.find(fields, fn(kv) { pair.first(kv) == "_id" }) {
                  Ok(_) -> d
                  Error(Nil) -> {
                    let id = object_id.new()
                    let fields =
                      list.prepend(fields, #("_id", types.ObjectId(id)))
                    types.Document(fields)
                  }
                }
              _ -> d
            }
          },
        )
      let inserted_ids =
        list.map(
          docs,
          fn(d) {
            case d {
              types.Document(fields) ->
                case list.find(fields, fn(kv) { pair.first(kv) == "_id" }) {
                  Ok(#(_, id)) -> id
                  _ -> types.Str("")
                }
              _ -> types.Str("")
            }
          },
        )
      case
        collection
        |> client.execute(types.Document([
          #("insert", types.Str(collection.name)),
          #("documents", types.Array(docs)),
        ]))
      {
        Ok([#("n", types.Integer(n)), #("ok", ok)]) ->
          case ok {
            types.Double(1.0) -> Ok(InsertResult(n, inserted_ids))
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
    }
    False -> Error(utils.default_error)
  }
}

fn find(
  collection: client.Collection,
  filter: types.Value,
  options: List(utils.FindOption),
) -> Result(List(types.Value), utils.MongoError) {
  case filter {
    types.Document(doc) -> {
      let body = case doc {
        [] -> [#("find", types.Str(collection.name))]
        _ -> [#("find", types.Str(collection.name)), #("filter", filter)]
      }
      let body =
        list.fold(
          options,
          body,
          fn(acc, opt) {
            case opt {
              utils.Sort(types.Document(sort)) ->
                list.key_set(acc, "sort", types.Document(sort))
              utils.Projection(types.Document(projection)) ->
                list.key_set(acc, "projection", types.Document(projection))
              utils.Skip(skip) -> list.key_set(acc, "skip", types.Integer(skip))
              utils.Limit(limit) ->
                list.key_set(acc, "limit", types.Integer(limit))
            }
          },
        )
      case
        collection
        |> client.execute(types.Document(body))
      {
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

fn update(
  collection: client.Collection,
  filter: types.Value,
  change: types.Value,
  options: List(utils.UpdateOption),
  multi: Bool,
) {
  case filter {
    types.Document(_) ->
      case change {
        types.Document(_) -> {
          let update = [
            #("q", filter),
            #("u", change),
            #("multi", types.Boolean(multi)),
          ]
          let update =
            list.fold(
              options,
              update,
              fn(acc, opt) {
                case opt {
                  utils.Upsert ->
                    list.key_set(acc, "upsert", types.Boolean(True))
                  utils.ArrayFilters(filters) ->
                    list.key_set(acc, "arrayFilters", types.Array(filters))
                }
              },
            )
            |> types.Document
          case
            collection
            |> client.execute(types.Document([
              #("update", types.Str(collection.name)),
              #("updates", types.Array([update])),
            ]))
          {
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
                  types.Document([#("index", _), #("_id", upserted)]),
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

fn delete(collection: client.Collection, filter: types.Value, multi: Bool) {
  case filter {
    types.Document(_) ->
      case
        collection
        |> client.execute(types.Document([
          #("delete", types.Str(collection.name)),
          #(
            "deletes",
            types.Array([
              types.Document([
                #("q", filter),
                #(
                  "limit",
                  types.Integer(case multi {
                    True -> 0
                    False -> 1
                  }),
                ),
              ]),
            ]),
          ),
        ]))
      {
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

import gleam/list
import gleam/pair
import mongo/utils
import mongo/client
import bson/value
import bson/object_id

pub type InsertResult {
  InsertResult(inserted: Int, inserted_ids: List(value.Value))
}

pub type UpdateResult {
  UpdateResult(matched: Int, modified: Int)
  UpsertResult(matched: Int, upserted_id: value.Value)
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
        value.Document([#("_id", value.ObjectId(id))]),
        value.Document([]),
      )
    Error(Nil) -> Error(utils.default_error)
  }
}

pub fn find_one(collection, filter, projection) {
  use _ <- unwrap_doc(filter)
  use doc <- unwrap_doc(projection)

  let options = case doc {
    [] -> [utils.Limit(1)]
    _ -> [utils.Limit(1), utils.Projection(projection)]
  }
  case
    collection
    |> find_many(filter, options)
  {
    Ok([]) -> Ok(value.Null)
    Ok([doc]) -> Ok(doc)
    Error(error) -> Error(error)
  }
}

pub fn find_many(
  collection: client.Collection,
  filter: value.Value,
  options: List(utils.FindOption),
) -> Result(List(value.Value), utils.MongoError) {
  collection
  |> find(filter, options)
}

pub fn find_all(
  collection: client.Collection,
  options: List(utils.FindOption),
) -> Result(List(value.Value), utils.MongoError) {
  collection
  |> find(value.Document([]), options)
}

pub fn update_one(
  collection: client.Collection,
  filter: value.Value,
  change: value.Value,
  options: List(utils.UpdateOption),
) {
  collection
  |> update(filter, change, options, False)
}

pub fn update_many(
  collection: client.Collection,
  filter: value.Value,
  change: value.Value,
  options: List(utils.UpdateOption),
) {
  collection
  |> update(filter, change, options, True)
}

pub fn delete_one(collection: client.Collection, filter: value.Value) {
  collection
  |> delete(filter, False)
}

pub fn delete_many(collection: client.Collection, filter: value.Value) {
  collection
  |> delete(filter, True)
}

pub fn count_all(collection: client.Collection) {
  case
    collection
    |> client.execute(value.Document([#("count", value.Str(collection.name))]))
  {
    Ok([#("n", value.Integer(n)), #("ok", ok)]) ->
      case ok {
        value.Double(1.0) -> Ok(n)
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: value.Null))
  }
}

pub fn count(collection: client.Collection, filter: value.Value) {
  use _ <- unwrap_doc(filter)

  case
    collection
    |> client.execute(value.Document([
      #("count", value.Str(collection.name)),
      #("query", filter),
    ]))
  {
    Ok([#("n", value.Integer(n)), #("ok", ok)]) ->
      case ok {
        value.Double(1.0) -> Ok(n)
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: value.Null))
  }
}

pub fn insert_many(
  collection: client.Collection,
  docs: List(value.Value),
) -> Result(InsertResult, utils.MongoError) {
  use _ <- unwrap_all_docs(docs)

  let docs =
    list.map(
      docs,
      fn(d) {
        case d {
          value.Document(fields) ->
            case list.find(fields, fn(kv) { pair.first(kv) == "_id" }) {
              Ok(_) -> d
              Error(Nil) -> {
                let id = object_id.new()
                let fields = list.prepend(fields, #("_id", value.ObjectId(id)))
                value.Document(fields)
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
          value.Document(fields) ->
            case list.find(fields, fn(kv) { pair.first(kv) == "_id" }) {
              Ok(#(_, id)) -> id
              _ -> value.Str("")
            }
          _ -> value.Str("")
        }
      },
    )

  case
    collection
    |> client.execute(value.Document([
      #("insert", value.Str(collection.name)),
      #("documents", value.Array(docs)),
    ]))
  {
    Ok([#("n", value.Integer(n)), #("ok", ok)]) ->
      case ok {
        value.Double(1.0) -> Ok(InsertResult(n, inserted_ids))
        _ -> Error(utils.default_error)
      }

    Ok([#("n", _), #("writeErrors", value.Array(errors)), #("ok", ok)]) ->
      case ok {
        value.Double(1.0) -> {
          let assert Ok(error) = list.first(errors)
          case error {
            value.Document([
              #("index", _),
              #("code", value.Integer(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", value.Str(msg)),
            ]) -> Error(utils.MongoError(code, msg, source))
            _ -> Error(utils.default_error)
          }
        }

        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: value.Null))
  }
}

fn find(
  collection: client.Collection,
  filter: value.Value,
  options: List(utils.FindOption),
) -> Result(List(value.Value), utils.MongoError) {
  use doc <- unwrap_doc(filter)

  let body = case doc {
    [] -> [#("find", value.Str(collection.name))]
    _ -> [#("find", value.Str(collection.name)), #("filter", filter)]
  }
  let body =
    list.fold(
      options,
      body,
      fn(acc, opt) {
        case opt {
          utils.Sort(value.Document(sort)) ->
            list.key_set(acc, "sort", value.Document(sort))
          utils.Projection(value.Document(projection)) ->
            list.key_set(acc, "projection", value.Document(projection))
          utils.Skip(skip) -> list.key_set(acc, "skip", value.Integer(skip))
          utils.Limit(limit) -> list.key_set(acc, "limit", value.Integer(limit))
        }
      },
    )
  case
    collection
    |> client.execute(value.Document(body))
  {
    Ok(result) -> {
      let [#("cursor", value.Document(result)), #("ok", ok)] = result
      let assert Ok(value.Array(docs)) = list.key_find(result, "firstBatch")
      case ok {
        value.Double(1.0) -> Ok(docs)
        _ -> Error(utils.default_error)
      }
    }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: value.Null))
  }
}

fn update(
  collection: client.Collection,
  filter: value.Value,
  change: value.Value,
  options: List(utils.UpdateOption),
  multi: Bool,
) {
  use _ <- unwrap_doc(filter)
  use _ <- unwrap_doc(change)

  let update = [
    #("q", filter),
    #("u", change),
    #("multi", value.Boolean(multi)),
  ]
  let update =
    list.fold(
      options,
      update,
      fn(acc, opt) {
        case opt {
          utils.Upsert -> list.key_set(acc, "upsert", value.Boolean(True))
          utils.ArrayFilters(filters) ->
            list.key_set(acc, "arrayFilters", value.Array(filters))
        }
      },
    )
    |> value.Document
  case
    collection
    |> client.execute(value.Document([
      #("update", value.Str(collection.name)),
      #("updates", value.Array([update])),
    ]))
  {
    Ok([
      #("n", value.Integer(n)),
      #("nModified", value.Integer(modified)),
      #("ok", ok),
    ]) ->
      case ok {
        value.Double(1.0) -> Ok(UpdateResult(n, modified))
        _ -> Error(utils.default_error)
      }
    Ok([
      #("n", value.Integer(n)),
      #(
        "upserted",
        value.Array([value.Document([#("index", _), #("_id", upserted)])]),
      ),
      #("nModified", _),
      #("ok", ok),
    ]) ->
      case ok {
        value.Double(1.0) -> Ok(UpsertResult(n, upserted))
        _ -> Error(utils.default_error)
      }
    Ok([
      #("n", _),
      #("writeErrors", value.Array(errors)),
      #("nModified", _),
      #("ok", ok),
    ]) ->
      case ok {
        value.Double(1.0) -> {
          let assert Ok(error) = list.first(errors)
          case error {
            value.Document([
              #("index", _),
              #("code", value.Integer(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", value.Str(msg)),
            ]) -> Error(utils.MongoError(code, msg, source))
            _ -> Error(utils.default_error)
          }
        }
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: value.Null))
  }
}

fn delete(collection: client.Collection, filter: value.Value, multi: Bool) {
  use _ <- unwrap_doc(filter)

  case
    collection
    |> client.execute(value.Document([
      #("delete", value.Str(collection.name)),
      #(
        "deletes",
        value.Array([
          value.Document([
            #("q", filter),
            #(
              "limit",
              value.Integer(case multi {
                True -> 0
                False -> 1
              }),
            ),
          ]),
        ]),
      ),
    ]))
  {
    Ok([#("n", value.Integer(n)), #("ok", ok)]) ->
      case ok {
        value.Double(1.0) -> Ok(n)
        _ -> Error(utils.default_error)
      }
    Ok([#("n", _), #("writeErrors", value.Array(errors)), #("ok", ok)]) ->
      case ok {
        value.Double(1.0) -> {
          let assert Ok(error) = list.first(errors)
          case error {
            value.Document([
              #("index", _),
              #("code", value.Integer(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", value.Str(msg)),
            ]) -> Error(utils.MongoError(code, msg, source))
            _ -> Error(utils.default_error)
          }
        }
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: value.Null))
  }
}

fn unwrap_doc(candidate: value.Value, rest) {
  case candidate {
    value.Document(doc) -> rest(doc)
    _ -> Error(utils.default_error)
  }
}

fn unwrap_all_docs(candidates: List(value.Value), rest) {
  case
    list.try_fold(
      candidates,
      [],
      fn(acc, candidate) {
        use doc <- unwrap_doc(candidate)
        Ok(list.append(acc, [doc]))
      },
    )
  {
    Ok(docs) -> rest(docs)
    _ -> Error(utils.default_error)
  }
}

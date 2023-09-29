import gleam/list
import gleam/bool
import gleam/pair
import gleam/option
import mongo/utils
import mongo/cursor
import mongo/client
import bson/value
import bson/object_id

pub type FindOption {
  Skip(Int)
  Limit(Int)
  BatchSize(Int)
  Sort(value.Value)
  Projection(value.Value)
}

pub type UpdateOption {
  Upsert
  ArrayFilters(List(value.Value))
}

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
  use <- bool.guard(!validate_doc(filter), Error(utils.default_error))
  use <- bool.guard(!validate_doc(projection), Error(utils.default_error))

  case
    collection
    |> find_many(filter, [Limit(1), Projection(projection)])
  {
    Ok(cursor) ->
      case cursor.next(cursor) {
        #(option.Some(doc), _) ->
          doc
          |> option.Some
          |> Ok
        #(option.None, _) ->
          option.None
          |> Ok
      }
    Error(error) -> Error(error)
  }
}

pub fn find_many(
  collection: client.Collection,
  filter: value.Value,
  options: List(FindOption),
) {
  collection
  |> find(filter, options)
}

pub fn find_all(collection: client.Collection, options: List(FindOption)) {
  collection
  |> find(value.Document([]), options)
}

pub fn update_one(
  collection: client.Collection,
  filter: value.Value,
  change: value.Value,
  options: List(UpdateOption),
) {
  collection
  |> update(filter, change, options, False)
}

pub fn update_many(
  collection: client.Collection,
  filter: value.Value,
  change: value.Value,
  options: List(UpdateOption),
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
    Ok([#("n", value.Int32(n)), #("ok", ok)]) ->
      case ok {
        value.Double(1.0) -> Ok(n)
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: value.Null))
  }
}

pub fn count(collection: client.Collection, filter: value.Value) {
  use <- bool.guard(!validate_doc(filter), Error(utils.default_error))

  case
    collection
    |> client.execute(value.Document([
      #("count", value.Str(collection.name)),
      #("query", filter),
    ]))
  {
    Ok([#("n", value.Int32(n)), #("ok", ok)]) ->
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
  use <- bool.guard(!validate_all_docs(docs), Error(utils.default_error))

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
    Ok([#("n", value.Int32(n)), #("ok", ok)]) ->
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
              #("code", value.Int32(code)),
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
  options: List(FindOption),
) {
  use <- bool.guard(!validate_doc(filter), Error(utils.default_error))

  let body =
    list.fold(
      options,
      [#("find", value.Str(collection.name)), #("filter", filter)],
      fn(acc, opt) {
        case opt {
          Sort(value.Document(sort)) ->
            list.key_set(acc, "sort", value.Document(sort))
          Projection(value.Document(projection)) ->
            list.key_set(acc, "projection", value.Document(projection))
          Skip(skip) -> list.key_set(acc, "skip", value.Int32(skip))
          Limit(limit) -> list.key_set(acc, "limit", value.Int32(limit))
          BatchSize(size) -> list.key_set(acc, "batchSize", value.Int32(size))
        }
      },
    )
  case
    collection
    |> client.execute(value.Document(body))
  {
    Ok(result) -> {
      let [#("cursor", value.Document(result)), #("ok", ok)] = result
      let assert Ok(value.Int64(id)) = list.key_find(result, "id")
      let assert Ok(value.Array(batch)) = list.key_find(result, "firstBatch")
      case ok {
        value.Double(1.0) ->
          cursor.new(collection, id, batch)
          |> Ok
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
  options: List(UpdateOption),
  multi: Bool,
) {
  use <- bool.guard(!validate_doc(filter), Error(utils.default_error))
  use <- bool.guard(!validate_doc(change), Error(utils.default_error))

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
          Upsert -> list.key_set(acc, "upsert", value.Boolean(True))
          ArrayFilters(filters) ->
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
      #("n", value.Int32(n)),
      #("nModified", value.Int32(modified)),
      #("ok", ok),
    ]) ->
      case ok {
        value.Double(1.0) -> Ok(UpdateResult(n, modified))
        _ -> Error(utils.default_error)
      }
    Ok([
      #("n", value.Int32(n)),
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
              #("code", value.Int32(code)),
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
  use <- bool.guard(!validate_doc(filter), Error(utils.default_error))

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
              value.Int32(case multi {
                True -> 0
                False -> 1
              }),
            ),
          ]),
        ]),
      ),
    ]))
  {
    Ok([#("n", value.Int32(n)), #("ok", ok)]) ->
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
              #("code", value.Int32(code)),
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

fn validate_doc(candidate: value.Value) {
  case candidate {
    value.Document(_) -> True
    _ -> False
  }
}

fn validate_all_docs(candidates: List(value.Value)) {
  list.all(candidates, validate_doc)
}

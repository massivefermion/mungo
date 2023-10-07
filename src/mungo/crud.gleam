import gleam/list
import gleam/pair
import gleam/option
import mungo/utils
import mungo/cursor
import mungo/client
import bison/bson
import bison/object_id

pub type FindOption {
  Skip(Int)
  Limit(Int)
  BatchSize(Int)
  Sort(List(#(String, bson.Value)))
  Projection(List(#(String, bson.Value)))
}

pub type UpdateOption {
  Upsert
  ArrayFilters(List(List(#(String, bson.Value))))
}

pub type InsertResult {
  InsertResult(inserted: Int, inserted_ids: List(bson.Value))
}

pub type UpdateResult {
  UpdateResult(matched: Int, modified: Int)
  UpsertResult(matched: Int, upserted_id: bson.Value)
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
      |> find_one([#("_id", bson.ObjectId(id))], [])
    Error(Nil) -> Error(utils.default_error)
  }
}

pub fn find_one(collection, filter, projection) {
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
  filter: List(#(String, bson.Value)),
  options: List(FindOption),
) {
  collection
  |> find(filter, options)
}

pub fn find_all(collection: client.Collection, options: List(FindOption)) {
  collection
  |> find([], options)
}

/// for more information, see [here](https://www.mongodb.com/docs/manual/reference/operator/update)
pub fn update_one(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  change: List(#(String, bson.Value)),
  options: List(UpdateOption),
) {
  collection
  |> update(filter, change, options, False)
}

/// for more information, see [here](https://www.mongodb.com/docs/manual/reference/operator/update)
pub fn update_many(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  change: List(#(String, bson.Value)),
  options: List(UpdateOption),
) {
  collection
  |> update(filter, change, options, True)
}

pub fn delete_one(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
) {
  collection
  |> delete(filter, False)
}

pub fn delete_many(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
) {
  collection
  |> delete(filter, True)
}

pub fn count_all(collection: client.Collection) {
  case
    collection
    |> client.execute(bson.Document([#("count", bson.Str(collection.name))]))
  {
    Ok([#("n", bson.Int32(n)), #("ok", ok)]) ->
      case ok {
        bson.Double(1.0) -> Ok(n)
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) -> Error(utils.MongoError(code, msg, source: bson.Null))
  }
}

pub fn count(collection: client.Collection, filter: List(#(String, bson.Value))) {
  case
    collection
    |> client.execute(bson.Document([
      #("count", bson.Str(collection.name)),
      #("query", bson.Document(filter)),
    ]))
  {
    Ok([#("n", bson.Int32(n)), #("ok", ok)]) ->
      case ok {
        bson.Double(1.0) -> Ok(n)
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) -> Error(utils.MongoError(code, msg, source: bson.Null))
  }
}

pub fn insert_many(
  collection: client.Collection,
  docs: List(List(#(String, bson.Value))),
) -> Result(InsertResult, utils.MongoError) {
  let docs =
    list.map(
      docs,
      fn(fields) {
        case list.find(fields, fn(kv) { pair.first(kv) == "_id" }) {
          Ok(_) -> fields
          Error(Nil) -> {
            let id = object_id.new()
            let fields = list.prepend(fields, #("_id", bson.ObjectId(id)))
            fields
          }
        }
        |> bson.Document
      },
    )

  let inserted_ids =
    list.map(
      docs,
      fn(d) {
        case d {
          bson.Document(fields) ->
            case list.find(fields, fn(kv) { pair.first(kv) == "_id" }) {
              Ok(#(_, id)) -> id
              _ -> bson.Str("")
            }
          _ -> bson.Str("")
        }
      },
    )

  case
    collection
    |> client.execute(bson.Document([
      #("insert", bson.Str(collection.name)),
      #("documents", bson.Array(docs)),
    ]))
  {
    Ok([#("n", bson.Int32(n)), #("ok", ok)]) ->
      case ok {
        bson.Double(1.0) -> Ok(InsertResult(n, inserted_ids))
        _ -> Error(utils.default_error)
      }

    Ok([#("n", _), #("writeErrors", bson.Array(errors)), #("ok", ok)]) ->
      case ok {
        bson.Double(1.0) -> {
          let assert Ok(error) = list.first(errors)
          case error {
            bson.Document([
              #("index", _),
              #("code", bson.Int32(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", bson.Str(msg)),
            ]) -> Error(utils.MongoError(code, msg, source))
            _ -> Error(utils.default_error)
          }
        }

        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) -> Error(utils.MongoError(code, msg, source: bson.Null))
  }
}

fn find(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  options: List(FindOption),
) {
  let body =
    list.fold(
      options,
      [#("find", bson.Str(collection.name)), #("filter", bson.Document(filter))],
      fn(acc, opt) {
        case opt {
          Sort(sort) -> list.key_set(acc, "sort", bson.Document(sort))
          Projection(projection) ->
            list.key_set(acc, "projection", bson.Document(projection))
          Skip(skip) -> list.key_set(acc, "skip", bson.Int32(skip))
          Limit(limit) -> list.key_set(acc, "limit", bson.Int32(limit))
          BatchSize(size) -> list.key_set(acc, "batchSize", bson.Int32(size))
        }
      },
    )
  case
    collection
    |> client.execute(bson.Document(body))
  {
    Ok(result) -> {
      let [#("cursor", bson.Document(result)), #("ok", ok)] = result
      let assert Ok(bson.Int64(id)) = list.key_find(result, "id")
      let assert Ok(bson.Array(batch)) = list.key_find(result, "firstBatch")
      case ok {
        bson.Double(1.0) ->
          cursor.new(collection, id, batch)
          |> Ok
        _ -> Error(utils.default_error)
      }
    }
    Error(#(code, msg)) -> Error(utils.MongoError(code, msg, source: bson.Null))
  }
}

fn update(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  change: List(#(String, bson.Value)),
  options: List(UpdateOption),
  multi: Bool,
) {
  let update =
    list.fold(
      options,
      [
        #("q", bson.Document(filter)),
        #("u", bson.Document(change)),
        #("multi", bson.Boolean(multi)),
      ],
      fn(acc, opt) {
        case opt {
          Upsert -> list.key_set(acc, "upsert", bson.Boolean(True))
          ArrayFilters(filters) ->
            list.key_set(
              acc,
              "arrayFilters",
              bson.Array(list.map(filters, bson.Document)),
            )
        }
      },
    )
    |> bson.Document
  case
    collection
    |> client.execute(bson.Document([
      #("update", bson.Str(collection.name)),
      #("updates", bson.Array([update])),
    ]))
  {
    Ok([
      #("n", bson.Int32(n)),
      #("nModified", bson.Int32(modified)),
      #("ok", ok),
    ]) ->
      case ok {
        bson.Double(1.0) -> Ok(UpdateResult(n, modified))
        _ -> Error(utils.default_error)
      }
    Ok([
      #("n", bson.Int32(n)),
      #(
        "upserted",
        bson.Array([bson.Document([#("index", _), #("_id", upserted)])]),
      ),
      #("nModified", _),
      #("ok", ok),
    ]) ->
      case ok {
        bson.Double(1.0) -> Ok(UpsertResult(n, upserted))
        _ -> Error(utils.default_error)
      }
    Ok([
      #("n", _),
      #("writeErrors", bson.Array(errors)),
      #("nModified", _),
      #("ok", ok),
    ]) ->
      case ok {
        bson.Double(1.0) -> {
          let assert Ok(error) = list.first(errors)
          case error {
            bson.Document([
              #("index", _),
              #("code", bson.Int32(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", bson.Str(msg)),
            ]) -> Error(utils.MongoError(code, msg, source))
            _ -> Error(utils.default_error)
          }
        }
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) -> Error(utils.MongoError(code, msg, source: bson.Null))
  }
}

fn delete(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  multi: Bool,
) {
  case
    collection
    |> client.execute(bson.Document([
      #("delete", bson.Str(collection.name)),
      #(
        "deletes",
        bson.Array([
          bson.Document([
            #("q", bson.Document(filter)),
            #(
              "limit",
              bson.Int32(case multi {
                True -> 0
                False -> 1
              }),
            ),
          ]),
        ]),
      ),
    ]))
  {
    Ok([#("n", bson.Int32(n)), #("ok", ok)]) ->
      case ok {
        bson.Double(1.0) -> Ok(n)
        _ -> Error(utils.default_error)
      }
    Ok([#("n", _), #("writeErrors", bson.Array(errors)), #("ok", ok)]) ->
      case ok {
        bson.Double(1.0) -> {
          let assert Ok(error) = list.first(errors)
          case error {
            bson.Document([
              #("index", _),
              #("code", bson.Int32(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", bson.Str(msg)),
            ]) -> Error(utils.MongoError(code, msg, source))
            _ -> Error(utils.default_error)
          }
        }
        _ -> Error(utils.default_error)
      }
    Error(#(code, msg)) -> Error(utils.MongoError(code, msg, source: bson.Null))
  }
}

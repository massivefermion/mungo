import gleam/list
import gleam/pair
import gleam/option
import gleam/result
import mungo/error
import mungo/cursor
import mungo/client
import bison/bson
import bison/object_id
import gleam/erlang/process

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
  UpdateResult(matched: Int, modified: Int, upserted: List(bson.Value))
}

pub fn insert_one(collection, doc, timeout) {
  case
    collection
    |> insert_many([doc], timeout)
  {
    Ok(InsertResult(inserted: _, inserted_ids: [id])) -> Ok(id)
    Error(error) -> Error(error)
  }
}

pub fn find_by_id(collection, id, timeout) {
  object_id.from_string(id)
  |> result.map(fn(id) {
    collection
    |> find_one([#("_id", bson.ObjectId(id))], [], timeout)
  })
  |> result.replace_error(error.StructureError)
  |> result.flatten
}

pub fn find_one(collection, filter, projection, timeout: Int) {
  collection
  |> find_many(filter, [Limit(1), Projection(projection)], timeout)
  |> result.map(fn(cursor) {
    case cursor.next(cursor, timeout) {
      #(option.Some(doc), _) ->
        doc
        |> option.Some
        |> Ok
      #(option.None, _) ->
        option.None
        |> Ok
    }
  })
  |> result.flatten
}

pub fn find_many(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  options: List(FindOption),
  timeout: Int,
) {
  collection
  |> find(filter, options, timeout)
}

pub fn find_all(
  collection: client.Collection,
  options: List(FindOption),
  timeout: Int,
) {
  collection
  |> find([], options, timeout)
}

/// for more information, see [here](https://www.mongodb.com/docs/manual/reference/operator/update)
pub fn update_one(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  change: List(#(String, bson.Value)),
  options: List(UpdateOption),
  timeout: Int,
) {
  collection
  |> update(filter, change, options, False, timeout)
}

/// for more information, see [here](https://www.mongodb.com/docs/manual/reference/operator/update)
pub fn update_many(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  change: List(#(String, bson.Value)),
  options: List(UpdateOption),
  timeout: Int,
) {
  collection
  |> update(filter, change, options, True, timeout)
}

pub fn delete_one(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  timeout: Int,
) {
  collection
  |> delete(filter, False, timeout)
}

pub fn delete_many(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  timeout: Int,
) {
  collection
  |> delete(filter, True, timeout)
}

pub fn count_all(collection: client.Collection, timeout: Int) {
  let cmd = [#("count", bson.String(collection.name))]
  process.try_call(collection.client, client.Command(cmd, _), timeout)
  |> result.replace_error(error.ActorError)
  |> result.flatten
  |> result.map(fn(reply) {
    case list.key_find(reply, "n") {
      Ok(bson.Int32(n)) -> Ok(n)
      _ -> Error(error.StructureError)
    }
  })
  |> result.flatten
}

pub fn count(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  timeout: Int,
) {
  let cmd = [
    #("count", bson.String(collection.name)),
    #("query", bson.Document(filter)),
  ]

  process.try_call(collection.client, client.Command(cmd, _), timeout)
  |> result.replace_error(error.ActorError)
  |> result.flatten
  |> result.map(fn(reply) {
    case list.key_find(reply, "n") {
      Ok(bson.Int32(n)) -> Ok(n)
      Error(Nil) -> Error(error.StructureError)
    }
  })
  |> result.flatten
}

pub fn insert_many(
  collection: client.Collection,
  docs: List(List(#(String, bson.Value))),
  timeout: Int,
) -> Result(InsertResult, error.Error) {
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
              _ -> bson.String("")
            }
          _ -> bson.String("")
        }
      },
    )

  let cmd = [
    #("insert", bson.String(collection.name)),
    #("documents", bson.Array(docs)),
  ]

  process.try_call(collection.client, client.Command(cmd, _), timeout)
  |> result.replace_error(error.ActorError)
  |> result.flatten
  |> result.map(fn(reply) {
    case [list.key_find(reply, "n"), list.key_find(reply, "writeErrors")] {
      [_, Ok(bson.Array(errors))] ->
        Error(error.WriteErrors(
          errors
          |> list.map(fn(error) {
            let assert bson.Document([
              #("index", _),
              #("code", bson.Int32(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", bson.String(msg)),
            ]) = error
            error.WriteError(code, msg, source)
          }),
        ))
      [Ok(bson.Int32(n)), _] -> Ok(InsertResult(n, inserted_ids))
    }
  })
  |> result.flatten
}

fn find(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  options: List(FindOption),
  timeout: Int,
) {
  let body =
    list.fold(
      options,
      [
        #("find", bson.String(collection.name)),
        #("filter", bson.Document(filter)),
      ],
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

  process.try_call(collection.client, client.Command(body, _), timeout)
  |> result.replace_error(error.ActorError)
  |> result.flatten
  |> result.map(fn(reply) {
    case list.key_find(reply, "cursor") {
      Ok(bson.Document(cursor)) ->
        case
          [list.key_find(cursor, "id"), list.key_find(cursor, "firstBatch")]
        {
          [Ok(bson.Int64(id)), Ok(bson.Array(batch))] ->
            cursor.new(collection, id, batch)
            |> Ok

          _ -> Error(error.StructureError)
        }
      _ -> Error(error.StructureError)
    }
  })
  |> result.flatten
}

fn update(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  change: List(#(String, bson.Value)),
  options: List(UpdateOption),
  multi: Bool,
  timeout: Int,
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
  let cmd = [
    #("update", bson.String(collection.name)),
    #("updates", bson.Array([update])),
  ]

  process.try_call(collection.client, client.Command(cmd, _), timeout)
  |> result.replace_error(error.ActorError)
  |> result.flatten
  |> result.map(fn(reply) {
    case
      [
        list.key_find(reply, "n"),
        list.key_find(reply, "nModified"),
        list.key_find(reply, "upserted"),
        list.key_find(reply, "writeErrors"),
      ]
    {
      [Ok(bson.Int32(n)), Ok(bson.Int32(modified)), Ok(bson.Array(upserted)), _] ->
        Ok(UpdateResult(n, modified, upserted))

      [Ok(bson.Int32(n)), Ok(bson.Int32(modified))] ->
        Ok(UpdateResult(n, modified, []))

      [_, _, _, Ok(bson.Array(errors))] ->
        Error(error.WriteErrors(
          errors
          |> list.map(fn(error) {
            let assert bson.Document([
              #("index", _),
              #("code", bson.Int32(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", bson.String(msg)),
            ]) = error
            error.WriteError(code, msg, source)
          }),
        ))

      _ -> Error(error.StructureError)
    }
  })
  |> result.flatten
}

fn delete(
  collection: client.Collection,
  filter: List(#(String, bson.Value)),
  multi: Bool,
  timeout: Int,
) {
  let cmd = [
    #("delete", bson.String(collection.name)),
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
  ]

  process.try_call(collection.client, client.Command(cmd, _), timeout)
  |> result.replace_error(error.ActorError)
  |> result.flatten
  |> result.map(fn(reply) {
    case [list.key_find(reply, "n"), list.key_find(reply, "writeErrors")] {
      [Ok(bson.Int32(n)), _] -> Ok(n)
      [_, Ok(bson.Array(errors))] ->
        Error(error.WriteErrors(
          errors
          |> list.map(fn(error) {
            let assert bson.Document([
              #("index", _),
              #("code", bson.Int32(code)),
              #("keyPattern", _),
              #("keyValue", source),
              #("errmsg", bson.String(msg)),
            ]) = error
            error.WriteError(code, msg, source)
          }),
        ))
      _ -> Error(error.StructureError)
    }
  })
  |> result.flatten
}

import gleam/list
import gleam/option
import gleam/result
import gleam/iterator
import mungo/error
import mungo/client
import bison/bson
import gleam/erlang/process

pub opaque type Cursor {
  Cursor(
    collection: client.Collection,
    id: Int,
    batch_size: Int,
    iterator: iterator.Iterator(bson.Value),
  )
}

pub fn to_list(cursor: Cursor) {
  to_list_internal(cursor, [])
}

pub fn next(cursor: Cursor) {
  case iterator.step(cursor.iterator) {
    iterator.Next(doc, rest) -> #(
      option.Some(doc),
      Cursor(cursor.collection, cursor.id, cursor.batch_size, rest),
    )
    iterator.Done ->
      case cursor.id {
        0 -> #(
          option.None,
          Cursor(cursor.collection, 0, cursor.batch_size, iterator.empty()),
        )
        _ -> {
          let assert Ok(new_cursor) = get_more(cursor)
          case iterator.step(new_cursor.iterator) {
            iterator.Next(doc, rest) -> #(
              option.Some(doc),
              Cursor(
                cursor.collection,
                new_cursor.id,
                new_cursor.batch_size,
                rest,
              ),
            )
            iterator.Done -> #(
              option.None,
              Cursor(
                cursor.collection,
                new_cursor.id,
                new_cursor.batch_size,
                iterator.empty(),
              ),
            )
          }
        }
      }
  }
}

pub fn new(collection: client.Collection, id: Int, batch: List(bson.Value)) {
  Cursor(collection, id, list.length(batch), iterator.from_list(batch))
}

fn to_list_internal(cursor, storage) {
  case next(cursor) {
    #(option.Some(next), new_cursor) ->
      to_list_internal(new_cursor, list.append(storage, [next]))
    #(option.None, _) -> storage
  }
}

fn get_more(cursor: Cursor) -> Result(Cursor, error.Error) {
  let cmd = [
    #("getMore", bson.Int64(cursor.id)),
    #("collection", bson.Str(cursor.collection.name)),
    #("batchSize", bson.Int32(cursor.batch_size)),
  ]

  process.try_call(
    cursor.collection.client,
    client.Command(cmd, _),
    cursor.collection.timeout,
  )
  |> result.replace_error(error.ActorError)
  |> result.flatten
  |> result.map(fn(reply) {
    case list.key_find(reply, "cursor") {
      Ok(bson.Document(reply_cursor)) ->
        case
          [
            list.key_find(reply_cursor, "id"),
            list.key_find(reply_cursor, "nextBatch"),
          ]
        {
          [Ok(bson.Int64(id)), Ok(bson.Array(batch))] ->
            new(cursor.collection, id, batch)
            |> Ok

          _ -> Error(error.StructureError)
        }
      _ -> Error(error.StructureError)
    }
  })
  |> result.flatten
}

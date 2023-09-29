import gleam/list
import gleam/option
import gleam/iterator
import mongo/utils
import mongo/client
import bson/value

pub opaque type Cursor {
  Cursor(
    collection: client.Collection,
    id: Int,
    batch_size: Int,
    iterator: iterator.Iterator(value.Value),
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

pub fn new(collection: client.Collection, id: Int, batch: List(value.Value)) {
  Cursor(collection, id, list.length(batch), iterator.from_list(batch))
}

fn to_list_internal(cursor, storage) {
  case next(cursor) {
    #(option.Some(next), new_cursor) ->
      to_list_internal(new_cursor, list.append(storage, [next]))
    #(option.None, _) -> storage
  }
}

fn get_more(cursor: Cursor) -> Result(Cursor, utils.MongoError) {
  case client.get_more(cursor.collection, cursor.id, cursor.batch_size) {
    Ok(result) -> {
      let [#("cursor", value.Document(result)), #("ok", ok)] = result
      let assert Ok(value.Int64(id)) = list.key_find(result, "id")
      let assert Ok(value.Array(batch)) = list.key_find(result, "nextBatch")
      case ok {
        value.Double(1.0) ->
          new(cursor.collection, id, batch)
          |> Ok
        _ -> Error(utils.default_error)
      }
    }
    Error(#(code, msg)) ->
      Error(utils.MongoError(code, msg, source: value.Null))
  }
}

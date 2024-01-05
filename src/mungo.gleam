import mungo/crud
import mungo/cursor
import mungo/client

/// The connection uri must specify the database
pub fn start(uri, timeout) {
  client.start(uri, timeout)
}

pub fn next(cursor, timeout) {
  cursor.next(cursor, timeout)
}

pub fn to_list(cursor, timeout) {
  cursor.to_list(cursor, timeout)
}

pub fn collection(db, name) {
  db
  |> client.collection(name)
}

pub fn count_all(collection, timeout) {
  collection
  |> crud.count_all(timeout)
}

pub fn count(collection, filter, timeout) {
  collection
  |> crud.count(filter, timeout)
}

pub fn find_by_id(collection, id, timeout) {
  collection
  |> crud.find_by_id(id, timeout)
}

pub fn insert_one(collection, doc, timeout) {
  collection
  |> crud.insert_one(doc, timeout)
}

pub fn insert_many(collection, docs, timeout) {
  collection
  |> crud.insert_many(docs, timeout)
}

pub fn find_all(collection, options, timeout) {
  collection
  |> crud.find_all(options, timeout)
}

pub fn delete_one(collection, filter, timeout) {
  collection
  |> crud.delete_one(filter, timeout)
}

pub fn delete_many(collection, filter, timeout) {
  collection
  |> crud.delete_many(filter, timeout)
}

pub fn find_many(collection, filter, options, timeout) {
  collection
  |> crud.find_many(filter, options, timeout)
}

pub fn find_one(collection, filter, projection, timeout) {
  collection
  |> crud.find_one(filter, projection, timeout)
}

pub fn update_one(collection, filter, change, options, timeout) {
  collection
  |> crud.update_one(filter, change, options, timeout)
}

pub fn update_many(collection, filter, change, options, timeout) {
  collection
  |> crud.update_many(filter, change, options, timeout)
}

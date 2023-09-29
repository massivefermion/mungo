import mongo/crud
import mongo/client
import mongo/cursor

pub fn connect(uri) {
  client.connect(uri)
}

pub fn next(cursor) {
  cursor.next(cursor)
}

pub fn to_list(cursor) {
  cursor.to_list(cursor)
}

pub fn collection(db, name) {
  db
  |> client.collection(name)
}

pub fn count_all(collection) {
  collection
  |> crud.count_all
}

pub fn count(collection, filter) {
  collection
  |> crud.count(filter)
}

pub fn find_by_id(collection, id) {
  collection
  |> crud.find_by_id(id)
}

pub fn insert_one(collection, doc) {
  collection
  |> crud.insert_one(doc)
}

pub fn insert_many(collection, docs) {
  collection
  |> crud.insert_many(docs)
}

pub fn find_all(collection, options) {
  collection
  |> crud.find_all(options)
}

pub fn delete_one(collection, filter) {
  collection
  |> crud.delete_one(filter)
}

pub fn delete_many(collection, filter) {
  collection
  |> crud.delete_many(filter)
}

pub fn find_many(collection, filter, options) {
  collection
  |> crud.find_many(filter, options)
}

pub fn find_one(collection, filter, projection) {
  collection
  |> crud.find_one(filter, projection)
}

pub fn update_one(collection, filter, change, options) {
  collection
  |> crud.update_one(filter, change, options)
}

pub fn update_many(collection, filter, change, options) {
  collection
  |> crud.update_many(filter, change, options)
}

import mongo/crud
import mongo/client

pub fn connect(ip, port) {
  client.connect(ip, port)
}

pub fn db(connection, name) {
  client.db(connection, name)
}

pub fn collection(db, name) {
  client.collection(db, name)
}

pub fn count_all(collection) {
  crud.count_all(collection)
}

pub fn count(collection, filter) {
  crud.count(collection, filter)
}

pub fn insert_one(collection, doc) {
  crud.insert_one(collection, doc)
}

pub fn insert_many(collection, docs) {
  crud.insert_many(collection, docs)
}

pub fn delete_one(collection, filter) {
  crud.delete_one(collection, filter)
}

pub fn delete_many(collection, filter) {
  crud.delete_many(collection, filter)
}

pub fn find_all(collection, options) {
  crud.find_all(collection, options)
}

pub fn find(collection, filter, options) {
  crud.find(collection, filter, options)
}

pub fn update_one(collection, filter, change, options) {
  crud.update_one(collection, filter, change, options)
}

pub fn update_many(collection, filter, change, options) {
  crud.update_many(collection, filter, change, options)
}

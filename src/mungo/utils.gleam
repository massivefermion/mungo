import bison/bson

pub type MongoError {
  MongoError(code: Int, msg: String, source: bson.Value)
}

pub const default_error = MongoError(code: -16, msg: "", source: bson.Null)

import bson/value

pub type MongoError {
  MongoError(code: Int, msg: String, source: value.Value)
}

pub const default_error = MongoError(code: -16, msg: "", source: value.Null)

pub type FindOption {
  Skip(Int)
  Limit(Int)
  Sort(value.Value)
  Projection(value.Value)
}

pub type UpdateOption {
  Upsert
  ArrayFilters(List(value.Value))
}

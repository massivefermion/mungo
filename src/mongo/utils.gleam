import bson/types

pub type MongoError {
  MongoError(code: Int, msg: String, source: types.Value)
}

pub const default_error = MongoError(code: -16, msg: "", source: types.Null)

pub type FindOption {
  Sort(types.Value)
  Projection(types.Value)
  Skip(Int)
  Limit(Int)
}

pub type UpdateOption {
  Upsert
  ArrayFilters(List(types.Value))
}

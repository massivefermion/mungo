import bson/types

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

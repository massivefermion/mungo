import bson/types
import gleam/list
import mongo/client
import mongo/utils.{MongoError, default_error}

pub opaque type Pipeline {
  Pipeline(collection: client.Collection, stages: List(types.Value))
}

pub fn aggregate(collection: client.Collection) -> Pipeline {
  Pipeline(collection, stages: [])
}

pub fn match(pipeline: Pipeline, doc: types.Value) {
  Pipeline(
    collection: pipeline.collection,
    stages: list.append(pipeline.stages, [types.Document([#("$match", doc)])]),
  )
}

pub fn lookup(
  pipeline: Pipeline,
  from from: String,
  local_field local_field: String,
  foreign_field foreign_field: String,
  alias alias: String,
) {
  Pipeline(
    collection: pipeline.collection,
    stages: list.append(
      pipeline.stages,
      [
        types.Document([
          #(
            "$lookup",
            types.Document([
              #("from", types.Str(from)),
              #("localField", types.Str(local_field)),
              #("foreignField", types.Str(foreign_field)),
              #("as", types.Str(alias)),
            ]),
          ),
        ]),
      ],
    ),
  )
}

pub fn project(pipeline: Pipeline, doc: types.Value) {
  Pipeline(
    collection: pipeline.collection,
    stages: list.append(pipeline.stages, [types.Document([#("$project", doc)])]),
  )
}

pub fn add_fields(pipeline: Pipeline, doc: types.Value) {
  Pipeline(
    collection: pipeline.collection,
    stages: list.append(
      pipeline.stages,
      [types.Document([#("$addFields", doc)])],
    ),
  )
}

pub fn sort(pipeline: Pipeline, doc: types.Value) {
  Pipeline(
    collection: pipeline.collection,
    stages: list.append(pipeline.stages, [types.Document([#("$sort", doc)])]),
  )
}

pub fn group(pipeline: Pipeline, doc: types.Value) {
  Pipeline(
    collection: pipeline.collection,
    stages: list.append(pipeline.stages, [types.Document([#("$group", doc)])]),
  )
}

pub fn skip(pipeline: Pipeline, count: Int) {
  Pipeline(
    collection: pipeline.collection,
    stages: list.append(
      pipeline.stages,
      [types.Document([#("$skip", types.Integer(count))])],
    ),
  )
}

pub fn limit(pipeline: Pipeline, count: Int) {
  Pipeline(
    collection: pipeline.collection,
    stages: list.append(
      pipeline.stages,
      [types.Document([#("$limit", types.Integer(count))])],
    ),
  )
}

pub fn exec(pipeline: Pipeline) {
  case client.execute(
    pipeline.collection,
    types.Document([
      #("aggregate", types.Str(pipeline.collection.name)),
      #("cursor", types.Document([])),
      #("pipeline", types.Array(pipeline.stages)),
    ]),
  ) {
    Ok(result) -> {
      let [#("cursor", types.Document(result)), #("ok", ok)] = result
      let [#("firstBatch", types.Array(docs)), #("id", _), #("ns", _)] = result
      case ok {
        types.Double(1.0) -> Ok(docs)
        _ -> Error(default_error)
      }
    }
    Error(#(code, msg)) -> Error(MongoError(code, msg, source: types.Null))
  }
}

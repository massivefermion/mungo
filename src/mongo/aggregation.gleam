import bson/types
import gleam/list
import mongo/client

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
      #("cursor", types.Document([])),
      #("pipeline", types.Array(pipeline.stages)),
      #("aggregate", types.Str(pipeline.collection.name)),
    ]),
  ) {
    Ok(result) -> {
      let [#("ok", ok), #("cursor", types.Document(result))] = result
      let [#("ns", _), #("id", _), #("firstBatch", types.Array(docs))] = result
      case ok {
        types.Double(1.0) -> Ok(docs)
        _ -> Error(Nil)
      }
    }
    Error(Nil) -> Error(Nil)
  }
}

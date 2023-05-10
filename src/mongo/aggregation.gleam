import gleam/list
import gleam/queue
import mongo/client
import mongo/utils.{MongoError, default_error}
import bson/value

pub opaque type Pipeline {
  Pipeline(collection: client.Collection, stages: queue.Queue(value.Value))
}

pub fn aggregate(collection: client.Collection) -> Pipeline {
  Pipeline(collection, stages: queue.new())
}

pub fn stages(pipeline: Pipeline, docs: List(value.Value)) {
  list.fold(
    docs,
    pipeline,
    fn(new_pipeline, current) { append_stage(new_pipeline, current) },
  )
}

pub fn match(pipeline: Pipeline, doc: value.Value) {
  append_stage(pipeline, value.Document([#("$match", doc)]))
}

pub fn lookup(
  pipeline: Pipeline,
  from from: String,
  local_field local_field: String,
  foreign_field foreign_field: String,
  alias alias: String,
) {
  append_stage(
    pipeline,
    value.Document([
      #(
        "$lookup",
        value.Document([
          #("from", value.Str(from)),
          #("localField", value.Str(local_field)),
          #("foreignField", value.Str(foreign_field)),
          #("as", value.Str(alias)),
        ]),
      ),
    ]),
  )
}

pub fn project(pipeline: Pipeline, doc: value.Value) {
  append_stage(pipeline, value.Document([#("$project", doc)]))
}

pub fn add_fields(pipeline: Pipeline, doc: value.Value) {
  append_stage(pipeline, value.Document([#("$addFields", doc)]))
}

pub fn sort(pipeline: Pipeline, doc: value.Value) {
  append_stage(pipeline, value.Document([#("$sort", doc)]))
}

pub fn group(pipeline: Pipeline, doc: value.Value) {
  append_stage(pipeline, value.Document([#("$group", doc)]))
}

pub fn skip(pipeline: Pipeline, count: Int) {
  append_stage(pipeline, value.Document([#("$skip", value.Integer(count))]))
}

pub fn limit(pipeline: Pipeline, count: Int) {
  append_stage(pipeline, value.Document([#("$limit", value.Integer(count))]))
}

pub fn exec(pipeline: Pipeline) {
  case
    client.execute(
      pipeline.collection,
      value.Document([
        #("aggregate", value.Str(pipeline.collection.name)),
        #("cursor", value.Document([])),
        #(
          "pipeline",
          pipeline.stages
          |> queue.to_list
          |> value.Array,
        ),
      ]),
    )
  {
    Ok(result) -> {
      let [#("cursor", value.Document(result)), #("ok", ok)] = result
      let [#("firstBatch", value.Array(docs)), #("id", _), #("ns", _)] = result
      case ok {
        value.Double(1.0) -> Ok(docs)
        _ -> Error(default_error)
      }
    }
    Error(#(code, msg)) -> Error(MongoError(code, msg, source: value.Null))
  }
}

fn append_stage(pipeline: Pipeline, stage: value.Value) {
  Pipeline(
    collection: pipeline.collection,
    stages: pipeline.stages
    |> queue.push_back(stage),
  )
}

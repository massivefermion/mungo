import gleam/list
import gleam/queue
import mongo/client
import mongo/cursor
import mongo/utils.{MongoError, default_error}
import bson/value

pub opaque type Pipeline {
  Pipeline(
    collection: client.Collection,
    options: List(AggregateOption),
    stages: queue.Queue(value.Value),
  )
}

pub type AggregateOption {
  BatchSize(Int)
  Let(value.Value)
}

pub fn aggregate(
  collection: client.Collection,
  options: List(AggregateOption),
) -> Pipeline {
  Pipeline(collection, options, stages: queue.new())
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
  append_stage(pipeline, value.Document([#("$skip", value.Int32(count))]))
}

pub fn limit(pipeline: Pipeline, count: Int) {
  append_stage(pipeline, value.Document([#("$limit", value.Int32(count))]))
}

pub fn exec(pipeline: Pipeline) {
  let body =
    list.fold(
      pipeline.options,
      [
        #("aggregate", value.Str(pipeline.collection.name)),
        #(
          "pipeline",
          pipeline.stages
          |> queue.to_list
          |> value.Array,
        ),
        #("cursor", value.Document([])),
      ],
      fn(acc, opt) {
        case opt {
          BatchSize(size) ->
            list.key_set(
              acc,
              "cursor",
              value.Document([#("batchSize", value.Int32(size))]),
            )
          Let(value.Document(let_doc)) ->
            list.key_set(acc, "let", value.Document(let_doc))
        }
      },
    )

  case client.execute(pipeline.collection, value.Document(body)) {
    Ok(result) -> {
      let [#("cursor", value.Document(result)), #("ok", ok)] = result
      let [
        #("firstBatch", value.Array(batch)),
        #("id", value.Int64(id)),
        #("ns", _),
      ] = result
      case ok {
        value.Double(1.0) ->
          cursor.new(pipeline.collection, id, batch)
          |> Ok
        _ -> Error(default_error)
      }
    }
    Error(#(code, msg)) -> Error(MongoError(code, msg, source: value.Null))
  }
}

fn append_stage(pipeline: Pipeline, stage: value.Value) {
  Pipeline(
    collection: pipeline.collection,
    options: pipeline.options,
    stages: pipeline.stages
    |> queue.push_back(stage),
  )
}

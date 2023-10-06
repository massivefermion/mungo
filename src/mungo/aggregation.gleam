//// for more information, see [here](https://www.mongodb.com/docs/manual/reference/operator/aggregation-pipeline)

import gleam/list
import gleam/queue
import mungo/client
import mungo/cursor
import mungo/utils.{MongoError, default_error}
import bison/bson

pub opaque type Pipeline {
  Pipeline(
    collection: client.Collection,
    options: List(AggregateOption),
    stages: queue.Queue(bson.Value),
  )
}

pub type AggregateOption {
  BatchSize(Int)
  Let(bson.Value)
}

pub fn aggregate(
  collection: client.Collection,
  options: List(AggregateOption),
) -> Pipeline {
  Pipeline(collection, options, stages: queue.new())
}

pub fn append_stage(pipeline: Pipeline, stage: #(String, bson.Value)) {
  Pipeline(
    collection: pipeline.collection,
    options: pipeline.options,
    stages: pipeline.stages
    |> queue.push_back(bson.Document([stage])),
  )
}

pub fn match(pipeline: Pipeline, doc: List(#(String, bson.Value))) {
  append_stage(pipeline, #("$match", bson.Document(doc)))
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
    #(
      "$lookup",
      bson.Document([
        #("from", bson.Str(from)),
        #("localField", bson.Str(local_field)),
        #("foreignField", bson.Str(foreign_field)),
        #("as", bson.Str(alias)),
      ]),
    ),
  )
}

pub fn pipelined_lookup(
  pipeline: Pipeline,
  from from: String,
  define definitions: List(#(String, bson.Value)),
  pipeline lookup_pipeline: List(bson.Value),
  alias alias: String,
) {
  append_stage(
    pipeline,
    #(
      "$lookup",
      bson.Document([
        #("from", bson.Str(from)),
        #("let", bson.Document(definitions)),
        #("pipeline", bson.Array(lookup_pipeline)),
        #("as", bson.Str(alias)),
      ]),
    ),
  )
}

pub fn unwind(
  pipeline: Pipeline,
  path: String,
  preserve_null_and_empty_arrays: Bool,
) {
  append_stage(
    pipeline,
    #(
      "$unwind",
      bson.Document([
        #("path", bson.Str(path)),
        #(
          "preserveNullAndEmptyArrays",
          bson.Boolean(preserve_null_and_empty_arrays),
        ),
      ]),
    ),
  )
}

pub fn unwind_with_index(
  pipeline: Pipeline,
  path: String,
  index_field: String,
  preserve_null_and_empty_arrays: Bool,
) {
  append_stage(
    pipeline,
    #(
      "$unwind",
      bson.Document([
        #("path", bson.Str(path)),
        #("includeArrayIndex", bson.Str(index_field)),
        #(
          "preserveNullAndEmptyArrays",
          bson.Boolean(preserve_null_and_empty_arrays),
        ),
      ]),
    ),
  )
}

pub fn project(pipeline: Pipeline, doc: List(#(String, bson.Value))) {
  append_stage(pipeline, #("$project", bson.Document(doc)))
}

pub fn add_fields(pipeline: Pipeline, doc: List(#(String, bson.Value))) {
  append_stage(pipeline, #("$addFields", bson.Document(doc)))
}

pub fn sort(pipeline: Pipeline, doc: List(#(String, bson.Value))) {
  append_stage(pipeline, #("$sort", bson.Document(doc)))
}

pub fn group(pipeline: Pipeline, doc: List(#(String, bson.Value))) {
  append_stage(pipeline, #("$group", bson.Document(doc)))
}

pub fn skip(pipeline: Pipeline, count: Int) {
  append_stage(pipeline, #("$skip", bson.Int32(count)))
}

pub fn limit(pipeline: Pipeline, count: Int) {
  append_stage(pipeline, #("$limit", bson.Int32(count)))
}

pub fn to_cursor(pipeline: Pipeline) {
  let body =
    list.fold(
      pipeline.options,
      [
        #("aggregate", bson.Str(pipeline.collection.name)),
        #(
          "pipeline",
          pipeline.stages
          |> queue.to_list
          |> bson.Array,
        ),
        #("cursor", bson.Document([])),
      ],
      fn(acc, opt) {
        case opt {
          BatchSize(size) ->
            list.key_set(
              acc,
              "cursor",
              bson.Document([#("batchSize", bson.Int32(size))]),
            )
          Let(bson.Document(let_doc)) ->
            list.key_set(acc, "let", bson.Document(let_doc))
        }
      },
    )

  case client.execute(pipeline.collection, bson.Document(body)) {
    Ok(result) -> {
      let [#("cursor", bson.Document(result)), #("ok", ok)] = result
      let [
        #("firstBatch", bson.Array(batch)),
        #("id", bson.Int64(id)),
        #("ns", _),
      ] = result
      case ok {
        bson.Double(1.0) ->
          cursor.new(pipeline.collection, id, batch)
          |> Ok
        _ -> Error(default_error)
      }
    }
    Error(#(code, msg)) -> Error(MongoError(code, msg, source: bson.Null))
  }
}

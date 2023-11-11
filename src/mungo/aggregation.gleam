//// for more information, see [here](https://www.mongodb.com/docs/manual/reference/operator/aggregation-pipeline)

import gleam/list
import gleam/queue
import gleam/result
import mungo/client
import mungo/cursor
import mungo/error
import bison/bson
import gleam/erlang/process

pub opaque type Pipeline {
  Pipeline(
    collection: client.Collection,
    options: List(AggregateOption),
    timeout: Int,
    stages: queue.Queue(bson.Value),
  )
}

pub type AggregateOption {
  BatchSize(Int)
  Let(List(#(String, bson.Value)))
}

pub fn aggregate(
  collection: client.Collection,
  options: List(AggregateOption),
  timeout: Int,
) -> Pipeline {
  Pipeline(collection, options, timeout, stages: queue.new())
}

pub fn append_stage(pipeline: Pipeline, stage: #(String, bson.Value)) {
  Pipeline(
    collection: pipeline.collection,
    options: pipeline.options,
    timeout: pipeline.timeout,
    stages: pipeline.stages
    |> queue.push_back(bson.Document([stage])),
  )
}

pub fn match(pipeline: Pipeline, doc: List(#(String, bson.Value))) {
  append_stage(pipeline, #("$match", bson.Document(doc)))
}

/// for more information, see [here](https://www.mongodb.com/docs/manual/reference/operator/aggregation/lookup)
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
        #("from", bson.String(from)),
        #("localField", bson.String(local_field)),
        #("foreignField", bson.String(foreign_field)),
        #("as", bson.String(alias)),
      ]),
    ),
  )
}

/// for more information, see [here](https://www.mongodb.com/docs/manual/reference/operator/aggregation/lookup)
pub fn pipelined_lookup(
  pipeline: Pipeline,
  from from: String,
  define definitions: List(#(String, bson.Value)),
  pipeline lookup_pipeline: List(List(#(String, bson.Value))),
  alias alias: String,
) {
  append_stage(
    pipeline,
    #(
      "$lookup",
      bson.Document([
        #("from", bson.String(from)),
        #("let", bson.Document(definitions)),
        #("pipeline", bson.Array(list.map(lookup_pipeline, bson.Document))),
        #("as", bson.String(alias)),
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
        #("path", bson.String(path)),
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
        #("path", bson.String(path)),
        #("includeArrayIndex", bson.String(index_field)),
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
        #("aggregate", bson.String(pipeline.collection.name)),
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
          Let(let_doc) -> list.key_set(acc, "let", bson.Document(let_doc))
          _ -> acc
        }
      },
    )

  process.try_call(
    pipeline.collection.client,
    client.Command(body, _),
    pipeline.timeout,
  )
  |> result.replace_error(error.ActorError)
  |> result.flatten
  |> result.map(fn(reply) {
    case list.key_find(reply, "cursor") {
      Ok(bson.Document(cursor)) ->
        case
          [list.key_find(cursor, "id"), list.key_find(cursor, "firstBatch")]
        {
          [Ok(bson.Int64(id)), Ok(bson.Array(batch))] ->
            cursor.new(pipeline.collection, id, batch)
            |> Ok

          _ -> Error(error.StructureError)
        }
      _ -> Error(error.StructureError)
    }
  })
  |> result.flatten
}

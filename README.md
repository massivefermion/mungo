# gleam_mongo

A mongodb driver for gleam

## Quick start

```sh
gleam shell # Run an Erlang shell
```

## Installation

```sh
gleam add gleam_mongo
```

## Roadmap

- [x] support basic mongodb commands
- [x] support aggregation
- [x] support connection strings
- [x] support authentication
- [ ] support mongodb cursors
- [ ] support connection pooling
- [ ] support bulk operations
- [ ] support transactions
- [ ] support other mongodb commands
- [ ] support tls
- [ ] support clusters
- [ ] support change streams

## Usage

```gleam
import gleam/result
import comics/draw
import bson/value
import mongo
import mongo/utils
import mongo/aggregation.{add_fields, aggregate, exec, lookup}

pub fn main() {
  let assert Ok(comix_db) =
    mongo.connect("mongodb://Sketch:RoadKill@localhost/comix_zone")

  let characters =
    comix_db
    |> mongo.collection("characters")

  characters
  |> mongo.insert_one(value.Document([
    #("name", value.Str("Alissa")),
    #("race", value.Str("human")),
  ]))

  characters
  |> mongo.update_one(
    value.Document([#("name", value.Str("Mortus"))]),
    value.Document([#("$set", value.Document([#("race", value.Str("mutant"))]))]),
    [utils.Upsert],
  )

  characters
  |> aggregate
  |> lookup(
    from: "styles",
    local_field: "name",
    foreign_field: "subject",
    alias: "style",
  )
  |> add_fields(value.Document([
    #(
      "style",
      value.Document([
        #("$arrayElemAt", value.Array([value.Str("$style"), value.Integer(0)])),
      ]),
    ),
  ]))
  |> exec
  |> result.unwrap([])
  |> draw.characters
}
```

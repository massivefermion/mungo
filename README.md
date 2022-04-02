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
- [ ] support bulk operations
- [ ] support other mongodb commands
- [ ] support mongodb cursors
- [ ] support connection pooling
- [ ] support transactions
- [ ] support tls
- [ ] support clusters

## Usage

### Connection

```gleam
import mongo
import bson/types
import comics/draw
import mongo/utils
import gleam/result
import mongo/aggregation.{add_fields, aggregate, exec, lookup}

pub fn main() {
  assert Ok(comix_db) =
    mongo.connect("mongodb://Sketch:RoadKill@localhost/comix_zone")

  let characters =
    comix_db
    |> mongo.collection("characters")

  characters
  |> mongo.insert_one(types.Document([
    #("name", types.Str("Alissa")),
    #("race", types.Str("human")),
  ]))
  |> io.debug

  characters
  |> mongo.update_one(
    types.Document([#("name", types.Str("Mortus"))]),
    types.Document([#("$set", types.Document([#("race", types.Str("mutant"))]))]),
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
  |> add_fields(types.Document([
    #(
      "style",
      types.Document([
        #("$arrayElemAt", types.Array([types.Str("$style"), types.Integer(0)])),
      ]),
    ),
  ]))
  |> exec
  |> result.unwrap([])
  |> draw.characters
}
```

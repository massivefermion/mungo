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
- [ ] support authentication
- [ ] support other mongodb commands
- [ ] support mongodb cursors
- [ ] support connection pooling
- [ ] support tls
- [ ] support clusters

## Usage

### Connection

```gleam
import mongo
import bson/types
import mongo/utils
import mongo/aggregation.{aggregate, exec, lookup, match}

pub fn main() {
  assert Ok(db) = mongo.connect("mongodb://localhost/app_db")

  let users =
    db
    |> mongo.collection("users")

  collection
  |> mongo.insert_one(types.Document([
    #("first_name", types.Str("Steve")),
    #("last_name", types.Str("Wozniak")),
  ]))

  collection
  |> mongo.update_one(
    types.Document([#("first_name", types.Str("Dennis"))]),
    types.Document([
      #("$set", types.Document([#("last_name", types.Str("Ritchie"))])),
    ]),
    [utils.Upsert],
  )

  collection
  |> aggregate()
  |> match(types.Document([#("first_name", types.Str("Dennis"))]))
  |> lookup(
    from: "technologies",
    local_field: "known_for",
    foreign_field: "name",
    alias: "known_for",
  )
  |> exec()
}
```

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
- [ ] support authentication
- [ ] support connection strings
- [ ] support tls
- [ ] support other mongodb commands
- [ ] support connection pooling
- [ ] support clusters

## Usage

### Connection

```gleam
import mongo
import bson/types
import mongo/utils
import mongo/aggregation.{aggregate, exec, lookup, match}

pub fn main() {
  assert Ok(conn) = mongo.connect("127.0.0.1", 27017)

  let db =
    conn
    |> mongo.db("app_db")

  let collection =
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

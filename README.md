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
- [x] support mongodb cursors
- [ ] support connection pooling
- [ ] support bulk operations
- [ ] support transactions
- [ ] support other mongodb commands
- [ ] support tls
- [ ] support clusters
- [ ] support change streams

## Usage

```gleam
import gleam/uri
import gleam/option
import mongo
import mongo/cursor
import mongo/crud.{Sort, Upsert}
import mongo/aggregation.{Let, add_fields, aggregate, exec, match}
import bson/value

pub fn main() {
  let encoded_password = uri.percent_encode("strong password")
  let assert Ok(db) =
    mongo.connect(
      "mongodb://app-dev:" <> encoded_password <> "@localhost/app-db?authSource=admin",
    )

  let users =
    db
    |> mongo.collection("users")

  let _ =
    users
    |> mongo.insert_many([
      value.Document([
        #("username", value.Str("jmorrow")),
        #("name", value.Str("vincent freeman")),
        #("email", value.Str("jmorrow@gattaca.eu")),
        #("age", value.Int32(32)),
      ]),
      value.Document([
        #("username", value.Str("real-jerome")),
        #("name", value.Str("jerome eugene morrow")),
        #("email", value.Str("real-jerome@running.at")),
        #("age", value.Int32(32)),
      ]),
    ])

  let _ =
    users
    |> mongo.update_one(
      value.Document([#("username", value.Str("real-jerome"))]),
      value.Document([
        #(
          "$set",
          value.Document([
            #("username", value.Str("eugene")),
            #("email", value.Str("eugene@running.at ")),
          ]),
        ),
      ]),
      [Upsert],
    )

  let assert Ok(yahoo_cursor) =
    users
    |> mongo.find_many(
      value.Document([#("email", value.Regex(#("yahoo", "")))]),
      [Sort(value.Document([#("username", value.Int32(-1))]))],
    )
  let _yahoo_users = cursor.to_list(yahoo_cursor)

  let assert Ok(underage_lindsey_cursor) =
    users
    |> aggregate([Let(value.Document([#("minimum_age", value.Int32(21))]))])
    |> match(value.Document([
      #(
        "$expr",
        value.Document([
          #("$lt", value.Array([value.Str("$age"), value.Str("$$minimum_age")])),
        ]),
      ),
    ]))
    |> add_fields(value.Document([
      #(
        "first_name",
        value.Document([
          #(
            "$arrayElemAt",
            value.Array([
              value.Document([
                #("$split", value.Array([value.Str("$name"), value.Str(" ")])),
              ]),
              value.Int32(0),
            ]),
          ),
        ]),
      ),
    ]))
    |> match(value.Document([#("first_name", value.Str("lindsey"))]))
    |> exec

  let #(_underage_lindsey, underage_lindsey_cursor) =
    underage_lindsey_cursor
    |> cursor.next

  let assert #(option.None, _) =
    underage_lindsey_cursor
    |> cursor.next
}
```

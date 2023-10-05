# mungo (formerly gleam_mongo)
> mungo: a felted fabric made from the shredded fibre of repurposed woollen cloth
---


A mongodb driver for gleam

## Quick start

```sh
gleam shell # Run an Erlang shell
```

## Installation

```sh
gleam add mungo
```

## Roadmap

- [x] support basic mongodb commands
- [x] support aggregation
- [x] support connection strings
- [x] support authentication
- [x] support mongodb cursors
- [ ] support connection pooling
- [ ] support bulk operations
- [ ] support tls
- [ ] support clusters
- [ ] support transactions
- [ ] support change streams
- [ ] support other mongodb commands

## Usage

```gleam
import gleam/uri
import gleam/option
import mungo
import mungo/crud.{Sort, Upsert}
import mungo/aggregation.{Let, add_fields, aggregate, exec, match}
import bison/value

pub fn main() {
  let encoded_password = uri.percent_encode("strong password")
  let assert Ok(db) =
    mungo.connect(
      "mongodb://app-dev:" <> encoded_password <> "@localhost/app-db?authSource=admin",
    )

  let users =
    db
    |> mungo.collection("users")

  let _ =
    users
    |> mungo.insert_many([
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
    |> mungo.update_one(
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
    |> mungo.find_many(
      value.Document([#("email", value.Regex(#("yahoo", "")))]),
      [Sort(value.Document([#("username", value.Int32(-1))]))],
    )
  let _yahoo_users = mungo.to_list(yahoo_cursor)

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

  let assert #(option.Some(_underage_lindsey), underage_lindsey_cursor) =
    underage_lindsey_cursor
    |> mungo.next

  let assert #(option.None, _) =
    underage_lindsey_cursor
    |> mungo.next
}
```

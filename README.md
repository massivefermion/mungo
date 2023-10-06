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
- [ ] support tls
- [ ] support clusters
- [ ] support bulk operations
- [ ] support transactions
- [ ] support change streams
- [ ] support other mongodb commands

## Usage

```gleam
import gleam/uri
import gleam/option
import mungo
import mungo/crud.{Sort, Upsert}
import mungo/aggregation.{
  Let, add_fields, aggregate, match, pipelined_lookup, to_cursor, unwind,
}
import bison/bson

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
      [
        #("username", bson.Str("jmorrow")),
        #("name", bson.Str("vincent freeman")),
        #("email", bson.Str("jmorrow@gattaca.eu")),
        #("age", bson.Int32(32)),
      ],
      [
        #("username", bson.Str("real-jerome")),
        #("name", bson.Str("jerome eugene morrow")),
        #("email", bson.Str("real-jerome@running.at")),
        #("age", bson.Int32(32)),
      ],
    ])

  let _ =
    users
    |> mungo.update_one(
      [#("username", bson.Str("real-jerome"))],
      [
        #(
          "$set",
          bson.Document([
            #("username", bson.Str("eugene")),
            #("email", bson.Str("eugene@running.at ")),
          ]),
        ),
      ],
      [Upsert],
    )

  let assert Ok(yahoo_cursor) =
    users
    |> mungo.find_many(
      [#("email", bson.Regex(#("yahoo", "")))],
      [Sort(bson.Document([#("username", bson.Int32(-1))]))],
    )
  let _yahoo_users = mungo.to_list(yahoo_cursor)

  let assert Ok(underage_lindsey_cursor) =
    users
    |> aggregate([Let(bson.Document([#("minimum_age", bson.Int32(21))]))])
    |> match([
      #(
        "$expr",
        bson.Document([
          #("$lt", bson.Array([bson.Str("$age"), bson.Str("$$minimum_age")])),
        ]),
      ),
    ])
    |> add_fields([
      #(
        "first_name",
        bson.Document([
          #(
            "$arrayElemAt",
            bson.Array([
              bson.Document([
                #("$split", bson.Array([bson.Str("$name"), bson.Str(" ")])),
              ]),
              bson.Int32(0),
            ]),
          ),
        ]),
      ),
    ])
    |> match([#("first_name", bson.Str("lindsey"))])
    |> pipelined_lookup(
      from: "profiles",
      define: [#("user", bson.Str("$username"))],
      pipeline: [
        bson.Document([
          #(
            "$match",
            bson.Document([
              #(
                "$expr",
                bson.Document([
                  #(
                    "$eq",
                    bson.Array([bson.Str("$username"), bson.Str("$$user")]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ],
      alias: "profile",
    )
    |> unwind("$profile", False)
    |> to_cursor

  let assert #(option.Some(_underage_lindsey), underage_lindsey_cursor) =
    underage_lindsey_cursor
    |> mungo.next

  let assert #(option.None, _) =
    underage_lindsey_cursor
    |> mungo.next
}
```

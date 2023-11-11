![mungo](https://raw.githubusercontent.com/massivefermion/mungo/main/banner.png)

[![Package Version](https://img.shields.io/hexpm/v/mungo)](https://hex.pm/packages/mungo)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/mungo/)

# mungo (formerly gleam_mongo)
> mungo: a felted fabric made from the shredded fibre of repurposed woollen cloth
---


A mongodb driver for gleam

## <img width=32 src=https://raw.githubusercontent.com/massivefermion/mungo/main/icon.png> Quick start

```sh
gleam shell # Run an Erlang shell
```

## <img width=32 src=https://raw.githubusercontent.com/massivefermion/mungo/main/icon.png> Installation

```sh
gleam add mungo
```

## <img width=32 src=https://raw.githubusercontent.com/massivefermion/mungo/main/icon.png> Roadmap

- [x] support basic mongodb commands
- [x] support aggregation
- [x] support connection strings
- [x] support authentication
- [x] support mongodb cursors
- [ ] support connection pooling
- [ ] support bulk operations
- [ ] support clusters
- [ ] support tls
- [ ] support transactions
- [ ] support change streams
- [ ] support other mongodb commands

## <img width=32 src=https://raw.githubusercontent.com/massivefermion/mungo/main/icon.png> Usage

```gleam
import gleam/option
import mungo
import mungo/crud.{Sort, Upsert}
import mungo/aggregation.{
  Let, add_fields, aggregate, match, pipelined_lookup, to_cursor, unwind,
}
import bison/bson

pub fn main() {
  let assert Ok(client) =
    mungo.start(
      "mongodb://app-dev:passwd@localhost/app-db?authSource=admin",
      512,
    )

  let users =
    client
    |> mungo.collection("users")

  let _ =
    users
    |> mungo.insert_many(
      [
        [
          #("username", bson.String("jmorrow")),
          #("name", bson.String("vincent freeman")),
          #("email", bson.String("jmorrow@gattaca.eu")),
          #("age", bson.Int32(32)),
        ],
        [
          #("username", bson.String("real-jerome")),
          #("name", bson.String("jerome eugene morrow")),
          #("email", bson.String("real-jerome@running.at")),
          #("age", bson.Int32(32)),
        ],
      ],
      128,
    )

  let _ =
    users
    |> mungo.update_one(
      [#("username", bson.String("real-jerome"))],
      [
        #(
          "$set",
          bson.Document([
            #("username", bson.String("eugene")),
            #("email", bson.String("eugene@running.at ")),
          ]),
        ),
      ],
      [Upsert],
      128,
    )

  let assert Ok(yahoo_cursor) =
    users
    |> mungo.find_many(
      [#("email", bson.Regex(#("yahoo", "")))],
      [Sort([#("username", bson.Int32(-1))])],
      128,
    )
  let _yahoo_users = mungo.to_list(yahoo_cursor, 128)

  let assert Ok(underage_lindsey_cursor) =
    users
    |> aggregate([Let([#("minimum_age", bson.Int32(21))])], 128)
    |> match([
      #(
        "$expr",
        bson.Document([
          #(
            "$lt",
            bson.Array([bson.String("$age"), bson.String("$$minimum_age")]),
          ),
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
                #(
                  "$split",
                  bson.Array([bson.String("$name"), bson.String(" ")]),
                ),
              ]),
              bson.Int32(0),
            ]),
          ),
        ]),
      ),
    ])
    |> match([#("first_name", bson.String("lindsey"))])
    |> pipelined_lookup(
      from: "profiles",
      define: [#("user", bson.String("$username"))],
      pipeline: [
        [
          #(
            "$match",
            bson.Document([
              #(
                "$expr",
                bson.Document([
                  #(
                    "$eq",
                    bson.Array([bson.String("$username"), bson.String("$$user")]),
                  ),
                ]),
              ),
            ]),
          ),
        ],
      ],
      alias: "profile",
    )
    |> unwind("$profile", False)
    |> to_cursor

  let assert #(option.Some(_underage_lindsey), underage_lindsey_cursor) =
    underage_lindsey_cursor
    |> mungo.next(128)

  let assert #(option.None, _) =
    underage_lindsey_cursor
    |> mungo.next(128)
}
```

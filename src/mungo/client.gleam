import gleam/uri
import gleam/bool
import gleam/list
import gleam/string
import gleam/option
import gleam/result
import gleam/bit_string
import mungo/tcp
import mungo/scram
import bison/bson
import bison.{decode, encode}

pub opaque type ConnectionInfo {
  ConnectionInfo(
    host: String,
    port: Int,
    db: String,
    auth: option.Option(#(String, String)),
    auth_source: option.Option(String),
  )
}

pub type Database {
  Database(socket: tcp.Socket, name: String)
}

pub type Collection {
  Collection(db: Database, name: String)
}

pub fn connect(uri: String) -> Result(Database, Nil) {
  use info <- result.then(parse_connection_string(uri))
  case info {
    ConnectionInfo(host, port, db, auth, auth_source) -> {
      use socket <- result.then(tcp.connect(host, port))
      case auth {
        option.None -> Ok(Database(socket, db))
        option.Some(#(username, password)) -> {
          use _ <- result.then(case auth_source {
            option.None -> authenticate(socket, username, password, db)
            option.Some(source) ->
              authenticate(socket, username, password, source)
          })
          Ok(Database(socket, db))
        }
      }
    }
  }
}

pub fn collection(db: Database, name: String) -> Collection {
  Collection(db, name)
}

pub fn get_more(collection: Collection, id: Int, batch_size: Int) {
  execute(
    collection,
    bson.Document([
      #("getMore", bson.Int64(id)),
      #("collection", bson.Str(collection.name)),
      #("batchSize", bson.Int32(batch_size)),
    ]),
  )
}

pub fn execute(
  collection: Collection,
  cmd: bson.Value,
) -> Result(List(#(String, bson.Value)), #(Int, String)) {
  case collection.db {
    Database(socket, name) ->
      case send_cmd(socket, name, cmd) {
        Ok([
          #("ok", bson.Double(0.0)),
          #("errmsg", bson.Str(msg)),
          #("code", bson.Int32(code)),
          #("codeName", _),
        ]) -> Error(#(code, msg))
        Ok(result) -> Ok(result)
        Error(Nil) -> Error(#(-2, ""))
      }
  }
}

fn authenticate(
  socket: tcp.Socket,
  username: String,
  password: String,
  auth_source: String,
) {
  let first_payload = scram.first_payload(username)

  let first = scram.first_message(first_payload)

  use reply <- result.then(send_cmd(socket, auth_source, first))

  use #(server_params, server_payload, cid) <- result.then(scram.parse_first_reply(
    reply,
  ))

  use #(second, server_signature) <- result.then(scram.second_message(
    server_params,
    first_payload,
    server_payload,
    cid,
    password,
  ))

  use reply <- result.then(send_cmd(socket, auth_source, second))

  case reply {
    [#("ok", bson.Double(0.0)), ..] -> Error(Nil)
    reply -> scram.parse_second_reply(reply, server_signature)
  }
}

fn send_cmd(
  socket: tcp.Socket,
  db: String,
  cmd: bson.Value,
) -> Result(List(#(String, bson.Value)), Nil) {
  let assert bson.Document(cmd) = cmd
  let cmd = list.key_set(cmd, "$db", bson.Str(db))
  let encoded = encode(cmd)
  let size = bit_string.byte_size(encoded) + 21

  let packet =
    [<<size:32-little, 0:32, 0:32, 2013:32-little, 0:32, 0>>, encoded]
    |> bit_string.concat
  case tcp.send(socket, packet) {
    tcp.OK ->
      case tcp.receive(socket) {
        Ok(response) -> {
          let <<_:168, rest:bit_string>> = response
          case decode(rest) {
            Ok(result) -> Ok(result)
            Error(Nil) -> Error(Nil)
          }
        }
        Error(Nil) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn parse_connection_string(uri: String) -> Result(ConnectionInfo, Nil) {
  use parsed <- result.then(uri.parse(uri))
  use <- bool.guard(parsed.scheme != option.Some("mongodb"), Error(Nil))
  use <- bool.guard(
    option.is_none(parsed.host) || parsed.host == option.Some(""),
    Error(Nil),
  )
  use <- bool.guard(list.contains(["", "/"], parsed.path), Error(Nil))

  let assert option.Some(host) = parsed.host
  let port = option.unwrap(parsed.port, 27_017)
  let path = parsed.path
  let [_, db] = string.split(path, "/")
  use db <- result.then(uri.percent_decode(db))
  use <- bool.guard(
    option.is_none(parsed.userinfo),
    Ok(ConnectionInfo(
      host,
      port,
      db,
      auth: option.None,
      auth_source: option.None,
    )),
  )

  let assert option.Some(userinfo) = parsed.userinfo
  case string.split(userinfo, ":") {
    ["", _] -> Error(Nil)
    [_, ""] -> Error(Nil)
    [username, password] ->
      case
        [username, password]
        |> list.map(uri.percent_decode)
      {
        [Ok(username), Ok(password)] ->
          case parsed.query {
            option.Some(query) -> {
              use opts <- result.then(uri.parse_query(query))
              case list.key_find(opts, "authSource") {
                Ok(auth_source) ->
                  ConnectionInfo(
                    host,
                    port,
                    db,
                    auth: option.Some(#(username, password)),
                    auth_source: option.Some(auth_source),
                  )
                  |> Ok
                Error(Nil) ->
                  ConnectionInfo(
                    host,
                    port,
                    db,
                    auth: option.Some(#(username, password)),
                    auth_source: option.None,
                  )
                  |> Ok
              }
            }
            option.None ->
              ConnectionInfo(
                host,
                port,
                db,
                auth: option.Some(#(username, password)),
                auth_source: option.None,
              )
              |> Ok
          }
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

import tcp
import gleam/uri
import gleam/list
import bson/types
import mongo/scram
import gleam/string
import gleam/option
import gleam/bit_string
import bson.{decode, encode}

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
  try info = parse_connection_string(uri)
  case info {
    ConnectionInfo(host, port, db, auth, auth_source) -> {
      try socket = tcp.connect(host, port)
      case auth {
        option.None -> Ok(Database(socket, db))
        option.Some(#(username, password)) -> {
          try _reply = case auth_source {
            option.None ->
              socket
              |> authenticate(username, password, db)
            option.Some(source) ->
              socket
              |> authenticate(username, password, source)
          }
          Ok(Database(socket, db))
        }
      }
    }
  }
}

pub fn collection(db: Database, name: String) -> Collection {
  Collection(db, name)
}

pub fn execute(
  collection: Collection,
  cmd: types.Value,
) -> Result(List(#(String, types.Value)), #(Int, String)) {
  case collection.db {
    Database(socket, name) ->
      case socket
      |> send_cmd(name, cmd) {
        Ok([
          #("ok", types.Double(0.0)),
          #("errmsg", types.Str(msg)),
          #("code", types.Integer(code)),
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

  try reply =
    socket
    |> send_cmd(auth_source, first)

  try #(server_params, server_payload, cid) = scram.parse_first_reply(reply)

  try #(second, _server_signature) =
    scram.second_message(
      server_params,
      first_payload,
      server_payload,
      cid,
      password,
    )

  try reply =
    socket
    |> send_cmd(auth_source, second)

  case reply {
    [#("ok", types.Double(0.0)), ..] -> Error(Nil)
    reply -> Ok(reply)
  }
}

fn send_cmd(
  socket: tcp.Socket,
  db: String,
  cmd: types.Value,
) -> Result(List(#(String, types.Value)), Nil) {
  assert types.Document(cmd) = cmd
  let cmd = list.append(cmd, [#("$db", types.Str(db))])
  let encoded = encode(cmd)
  let size = bit_string.byte_size(encoded) + 21

  let packet =
    [<<size:32-little, 0:32, 0:32, 2013:32-little, 0:32, 0>>, encoded]
    |> bit_string.concat
  case socket
  |> tcp.send(packet) {
    tcp.Ok ->
      case socket
      |> tcp.receive() {
        Ok(response) -> {
          let <<_:168, rest:bit_string>> = response
          rest
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
  try parsed = uri.parse(uri)
  case parsed.scheme {
    option.Some("mongodb") ->
      case parsed.host {
        option.Some("") -> Error(Nil)
        option.Some(host) -> {
          let port =
            parsed.port
            |> option.unwrap(27017)
          case parsed.path {
            "" -> Error(Nil)
            "/" -> Error(Nil)
            path -> {
              let [_, db] = string.split(path, "/")
              try db = uri.percent_decode(db)
              case parsed.userinfo {
                option.Some(userinfo) ->
                  case string.split(userinfo, ":") {
                    ["", _] -> Error(Nil)
                    [_, ""] -> Error(Nil)
                    [username, password] ->
                      case [username, password]
                      |> list.map(uri.percent_decode) {
                        [Ok(username), Ok(password)] ->
                          case parsed.query {
                            option.Some(query) -> {
                              try opts =
                                query
                                |> uri.parse_query
                              case list.key_find(opts, "authSource") {
                                Ok(auth_source) ->
                                  Ok(ConnectionInfo(
                                    host,
                                    port,
                                    db,
                                    auth: option.Some(#(username, password)),
                                    auth_source: option.Some(auth_source),
                                  ))
                                Error(Nil) ->
                                  Ok(ConnectionInfo(
                                    host,
                                    port,
                                    db,
                                    auth: option.Some(#(username, password)),
                                    auth_source: option.None,
                                  ))
                              }
                            }
                            option.None ->
                              Ok(ConnectionInfo(
                                host,
                                port,
                                db,
                                auth: option.Some(#(username, password)),
                                auth_source: option.None,
                              ))
                          }
                        _ -> Error(Nil)
                      }
                    _ -> Error(Nil)
                  }
                option.None ->
                  Ok(ConnectionInfo(
                    host,
                    port,
                    db,
                    auth: option.None,
                    auth_source: option.None,
                  ))
              }
            }
          }
        }
        option.None -> Error(Nil)
      }
    option.Some(_) -> Error(Nil)
    option.None -> Error(Nil)
  }
}

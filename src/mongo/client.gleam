import tcp
import gleam/uri
import bson/types
import gleam/list
import gleam/string
import gleam/option
import gleam/bit_string
import bson.{decode, encode}

pub opaque type Auth {
  Auth(username: String, password: String)
}

pub opaque type ConnectionInfo {
  ConnectionInfo(
    host: String,
    port: Int,
    db: String,
    auth: option.Option(Auth),
    auth_source: option.Option(String),
  )
}

pub opaque type Database {
  Database(socket: tcp.Socket, name: String)
}

pub type Collection {
  Collection(db: Database, name: String)
}

pub fn connect(uri: String) -> Result(Database, Nil) {
  case parse_connection_string(uri) {
    Ok(info) ->
      case info {
        ConnectionInfo(host, port, db, _auth, _auth_source) ->
          case tcp.connect(host, port) {
            Ok(socket) -> Ok(Database(socket, db))
            Error(_) -> Error(Nil)
          }
      }
    Error(Nil) -> Error(Nil)
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

fn parse_connection_string(uri: String) -> Result(ConnectionInfo, Nil) {
  case uri.parse(uri) {
    Ok(parsed) ->
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
                  case parsed.userinfo {
                    option.Some(userinfo) ->
                      case string.split(userinfo, ":") {
                        ["", _] -> Error(Nil)
                        [_, ""] -> Error(Nil)
                        [username, password] ->
                          case parsed.query {
                            option.Some(query) ->
                              case query
                              |> uri.parse_query {
                                Ok(opts) ->
                                  case list.key_find(opts, "authSource") {
                                    Ok(auth_source) ->
                                      Ok(ConnectionInfo(
                                        host,
                                        port,
                                        db,
                                        auth: option.Some(Auth(
                                          username,
                                          password,
                                        )),
                                        auth_source: option.Some(auth_source),
                                      ))
                                    Error(Nil) ->
                                      Ok(ConnectionInfo(
                                        host,
                                        port,
                                        db,
                                        auth: option.Some(Auth(
                                          username,
                                          password,
                                        )),
                                        auth_source: option.None,
                                      ))
                                  }
                                Error(Nil) -> Error(Nil)
                              }
                            option.None ->
                              Ok(ConnectionInfo(
                                host,
                                port,
                                db,
                                auth: option.Some(Auth(username, password)),
                                auth_source: option.None,
                              ))
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
    Error(Nil) -> Error(Nil)
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
    tcp.OK ->
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

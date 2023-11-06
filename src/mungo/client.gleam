import gleam/int
import gleam/uri
import gleam/bool
import gleam/list
import gleam/string
import gleam/result
import gleam/option
import gleam/bit_array
import mungo/tcp
import mungo/scram
import mungo/error
import mug
import gleam/otp/actor
import gleam/erlang/process
import bison/bson
import bison.{decode, encode}

pub type Message {
  Shutdown
  GetTimeout(process.Subject(Int))
  Command(
    List(#(String, bson.Value)),
    process.Subject(Result(List(#(String, bson.Value)), error.Error)),
  )
}

pub fn start(uri: String, timeout: Int) {
  use client <- result.then(
    connect(uri, timeout)
    |> result.map_error(fn(error: error.Error) {
      case error {
        error.ConnectionStringError ->
          actor.InitFailed(process.Abnormal("Invalid connection string"))
        error.TCPError(_) -> {
          actor.InitFailed(process.Abnormal("TCP connection error"))
        }
        _ -> actor.InitFailed(process.Abnormal(""))
      }
    }),
  )

  use actor <- result.then(actor.start(
    client,
    fn(msg: Message, client) {
      case msg {
        Command(cmd, reply_with) -> {
          case execute(client, cmd, timeout) {
            Ok(#(reply, client)) -> {
              actor.send(reply_with, Ok(reply))
              actor.continue(client)
            }

            Error(error) -> {
              actor.send(reply_with, Error(error))
              actor.continue(client)
            }
          }
        }

        GetTimeout(reply_with) -> {
          actor.send(reply_with, timeout)
          actor.continue(client)
        }

        Shutdown -> actor.Stop(process.Normal)
      }
    },
  ))

  let client_pid = process.subject_owner(actor)
  list.each(
    client.connections,
    fn(conn) { change_socket_owner(conn.socket, client_pid) },
  )

  Ok(actor)
}

pub opaque type Connection {
  Connection(socket: mug.Socket, primary: Bool)
}

pub opaque type Client {
  Client(db: String, connections: List(Connection))
}

pub type Collection {
  Collection(name: String, client: process.Subject(Message), timeout: Int)
}

fn connect(uri: String, timeout: Int) -> Result(Client, error.Error) {
  use info <- result.then(parse_connection_string(uri))

  case info {
    #(auth, hosts, db) -> {
      use connections <- result.then(list.try_map(
        hosts,
        fn(host) {
          use socket <- result.then(
            tcp.connect(host.0, host.1, timeout)
            |> result.map_error(fn(error) { error.TCPError(error) }),
          )

          use is_primary <- result.then(is_primary(socket, db, timeout))
          Ok(Connection(socket, is_primary))
        },
      ))

      case auth {
        option.None -> Ok(Client(db, connections))
        option.Some(#(username, password, auth_source)) -> {
          list.try_each(
            list.map(connections, fn(connection) { connection.socket }),
            authenticate(_, username, password, auth_source, timeout),
          )
          |> result.replace(Client(db, connections))
        }
      }
    }
  }
}

pub fn collection(
  client: process.Subject(Message),
  name: String,
) -> Result(Collection, process.CallError(msg)) {
  process.try_call(client, GetTimeout, 1024)
  |> result.map(fn(timeout) { Collection(name, client, timeout) })
  |> result.replace_error(process.CallTimeout)
}

fn execute(
  client: Client,
  cmd: List(#(String, bson.Value)),
  timeout: Int,
) -> Result(#(List(#(String, bson.Value)), Client), error.Error) {
  case client {
    Client(name, connections) -> {
      let assert Ok(Connection(socket, True)) =
        list.find(connections, fn(connection) { connection.primary })

      send_cmd(socket, name, cmd, timeout)
      |> result.map(fn(reply) {
        case reply {
          [
            #("ok", bson.Double(0.0)),
            #("errmsg", bson.Str(msg)),
            #("code", bson.Int32(code)),
            #("codeName", _),
          ] -> {
            let assert Ok(error) =
              list.key_find(error.code_to_server_error, code)
            let error = error(msg)

            case error.is_retriable_error(error) {
              True ->
                case error.is_not_primary_error(error) {
                  True -> {
                    use connections <- result.then(
                      client.connections
                      |> list.try_map(fn(connection) {
                        use is_primary <- result.then(is_primary(
                          connection.socket,
                          client.db,
                          timeout,
                        ))
                        Ok(Connection(socket, is_primary))
                      }),
                    )

                    let assert Ok(Connection(socket, True)) =
                      list.find(
                        connections,
                        fn(connection) {
                          case
                            is_primary(connection.socket, client.db, timeout)
                          {
                            Ok(is_primary) -> is_primary
                            Error(_) -> False
                          }
                        },
                      )

                    send_cmd(socket, name, cmd, timeout)
                    |> result.map(fn(reply) {
                      case reply {
                        [
                          #("ok", bson.Double(0.0)),
                          #("errmsg", bson.Str(msg)),
                          #("code", bson.Int32(code)),
                          #("codeName", _),
                        ] -> {
                          let assert Ok(error) =
                            list.key_find(error.code_to_server_error, code)
                          Error(error.ServerError(error(msg)))
                        }

                        reply -> Ok(#(reply, client))
                      }
                    })
                    |> result.flatten
                  }

                  False ->
                    send_cmd(socket, name, cmd, timeout)
                    |> result.map(fn(reply) {
                      case reply {
                        [
                          #("ok", bson.Double(0.0)),
                          #("errmsg", bson.Str(msg)),
                          #("code", bson.Int32(code)),
                          #("codeName", _),
                        ] -> {
                          let assert Ok(error) =
                            list.key_find(error.code_to_server_error, code)
                          Error(error.ServerError(error(msg)))
                        }

                        reply -> Ok(#(reply, client))
                      }
                    })
                    |> result.flatten
                }
              False -> Error(error.ServerError(error))
            }
          }

          reply -> Ok(#(reply, client))
        }
      })
      |> result.flatten
    }
  }
}

fn is_primary(socket: mug.Socket, db: String, timeout: Int) {
  send_cmd(socket, db, [#("hello", bson.Int32(1))], timeout)
  |> result.map(fn(reply) {
    case list.key_find(reply, "isWritablePrimary") {
      Ok(bson.Boolean(True)) -> True
      Ok(bson.Boolean(True)) | Error(Nil) -> False
    }
  })
}

fn authenticate(
  socket: mug.Socket,
  username: String,
  password: String,
  auth_source: String,
  timeout: Int,
) {
  let first_payload = scram.first_payload(username)

  let first = scram.first_message(first_payload)

  use reply <- result.then(send_cmd(socket, auth_source, first, timeout))

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

  use reply <- result.then(send_cmd(socket, auth_source, second, timeout))

  case reply {
    [#("ok", bson.Double(0.0)), ..] ->
      Error(error.ServerError(error.AuthenticationFailed("")))
    reply -> scram.parse_second_reply(reply, server_signature)
  }
}

fn send_cmd(
  socket: mug.Socket,
  db: String,
  cmd: List(#(String, bson.Value)),
  timeout: Int,
) -> Result(List(#(String, bson.Value)), error.Error) {
  let cmd = list.key_set(cmd, "$db", bson.Str(db))
  let encoded = encode(cmd)
  let size = bit_array.byte_size(encoded) + 21

  let packet =
    [<<size:32-little, 0:32, 0:32, 2013:32-little, 0:32, 0>>, encoded]
    |> bit_array.concat

  tcp.execute(socket, packet, timeout)
  |> result.map(fn(reply) {
    let <<_:168, rest:bits>> = reply
    decode(rest)
    |> result.replace_error(error.StructureError)
  })
  |> result.map_error(fn(tcp_error) { error.TCPError(tcp_error) })
  |> result.flatten
  // |> result.map(fn(_) {
  //   tcp.receive(socket, timeout)
  //   |> result.map(fn(reply) {
  //     let <<_:168, rest:bits>> = reply
  //     decode(rest)
  //     |> result.replace_error(error.StructureError)
  //   })
  //   |> result.map_error(fn(tcp_error) { error.TCPError(tcp_error) })
  //   |> result.flatten
  // })
  // |> result.map_error(fn(tcp_error) { error.TCPError(tcp_error) })
  // |> result.flatten
}

fn parse_connection_string(uri: String) {
  use <- bool.guard(
    !string.starts_with(uri, "mongodb://"),
    Error(error.ConnectionStringError),
  )
  let uri = string.drop_left(uri, 10)

  use #(auth, rest) <- result.then(case string.split_once(uri, "@") {
    Ok(#(auth, rest)) ->
      case string.split_once(auth, ":") {
        Ok(#(username, password)) if username != "" && password != "" ->
          case
            [username, password]
            |> list.map(uri.percent_decode)
          {
            [Ok(username), Ok(password)] ->
              Ok(#(option.Some(#(username, password)), rest))
            _ -> Error(error.ConnectionStringError)
          }
        _ -> Error(error.ConnectionStringError)
      }
    Error(Nil) -> Ok(#(option.None, uri))
  })

  use #(hosts, db_and_options) <- result.then(
    string.split_once(rest, "/")
    |> result.replace_error(error.ConnectionStringError),
  )
  use hosts <- result.then(
    hosts
    |> string.split(",")
    |> list.map(fn(host) {
      case string.starts_with(host, ":") {
        True -> Error(error.ConnectionStringError)
        False -> Ok(host)
      }
    })
    |> list.try_map(fn(host) {
      host
      |> result.map(fn(host) {
        case string.split_once(host, ":") {
          Ok(#(host, port)) -> {
            use port <- result.then(
              int.parse(port)
              |> result.replace_error(error.ConnectionStringError),
            )
            Ok(#(host, port))
          }
          Error(Nil) -> Ok(#(host, 27_017))
        }
      })
      |> result.flatten
    }),
  )

  case string.split(db_and_options, "?") {
    [db] if db != "" -> {
      use db <- result.then(
        uri.percent_decode(db)
        |> result.replace_error(error.ConnectionStringError),
      )
      Ok(#(
        auth
        |> option.map(fn(auth) { #(auth.0, auth.1, db) }),
        hosts,
        db,
      ))
    }

    [db, "authSource=" <> auth_source] if db != "" -> {
      use db <- result.then(
        uri.percent_decode(db)
        |> result.replace_error(error.ConnectionStringError),
      )
      Ok(#(
        auth
        |> option.map(fn(auth) { #(auth.0, auth.1, auth_source) }),
        hosts,
        db,
      ))
    }

    _ -> Error(error.ConnectionStringError)
  }
}

@external(erlang, "gen_tcp", "controlling_process")
fn change_socket_owner(socket: mug.Socket, pid: process.Pid) -> b

import tcp
import bson/types
import gleam/bit_string
import bson.{decode, encode}

pub opaque type Connection {
  Connection(socket: tcp.Socket)
}

pub opaque type Database {
  Database(connection: Connection, name: String)
}

pub type Collection {
  Collection(db: Database, name: String)
}

pub fn connect(ip: String, port: Int) -> Result(Connection, Nil) {
  case tcp.connect(ip, port) {
    Ok(socket) -> Ok(Connection(socket))
    Error(Nil) -> Error(Nil)
  }
}

pub fn db(connection: Connection, name: String) -> Database {
  Database(connection, name)
}

pub fn collection(db: Database, name: String) -> Collection {
  Collection(db, name)
}

pub fn execute(
  collection: Collection,
  cmd: types.Value,
) -> Result(List(#(String, types.Value)), Nil) {
  assert types.Document(body) = cmd
  let cmd = [#("$db", types.Str(collection.db.name)), ..body]
  let encoded = encode(cmd)
  let size = bit_string.byte_size(encoded) + 21
  let packet =
    [<<size:32-little, 0:32, 0:32, 2013:32-little, 0:32, 0>>, encoded]
    |> bit_string.concat

  case collection.db.connection.socket
  |> tcp.send(packet) {
    tcp.OK ->
      case collection.db.connection.socket
      |> tcp.receive() {
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

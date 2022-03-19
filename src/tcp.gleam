import gleam/list
import gleam/string
import gleam/bit_string

pub external type Socket

pub type TCPResult {
  OK
}

type TCPOption {
  Binary
  Active(Bool)
}

external fn tcp_connect(List(Int), Int, List(TCPOption)) -> Result(Socket, Nil) =
  "gen_tcp" "connect"

external fn tcp_send(Socket, BitString) -> TCPResult =
  "gen_tcp" "send"

external fn tcp_receive(Socket, Int) -> Result(BitString, Nil) =
  "gen_tcp" "recv"

pub fn connect(host: String, port: Int) {
  tcp_connect(
    host
    |> string.to_graphemes
    |> list.map(fn(char) {
      let <<code>> =
        char
        |> bit_string.from_string
      code
    }),
    port,
    [Binary, Active(False)],
  )
}

pub fn send(socket, data) {
  tcp_send(socket, data)
}

pub fn receive(socket) {
  tcp_receive(socket, 0)
}

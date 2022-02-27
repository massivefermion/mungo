import gleam/int
import gleam/list
import gleam/string

pub external type Socket

pub type TCPResult {
  OK
}

type TCPOption {
  Binary
  Active(Bool)
}

external fn tcp_connect(
  #(Int, Int, Int, Int),
  Int,
  List(TCPOption),
) -> Result(Socket, Nil) =
  "gen_tcp" "connect"

external fn tcp_send(Socket, BitString) -> TCPResult =
  "gen_tcp" "send"

external fn tcp_receive(Socket, Int) -> Result(BitString, Nil) =
  "gen_tcp" "recv"

pub fn connect(host: String, port: Int) {
  let [a, b, c, d] =
    string.split(host, ".")
    |> list.map(fn(i) {
      i
      |> int.parse
    })
    |> list.map(fn(i) {
      assert Ok(i) = i
      i
    })

  tcp_connect(#(a, b, c, d), port, [Binary, Active(False)])
}

pub fn send(socket, data) {
  tcp_send(socket, data)
}

pub fn receive(socket) {
  tcp_receive(socket, 0)
}

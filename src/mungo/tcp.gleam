import gleam/bit_array
import gleam/erlang/process
import gleam/int
import gleam/option
import gleam/order
import gleam/result

import mug

pub fn connect(host: String, port: Int, timeout: Int) {
  mug.connect(mug.ConnectionOptions(host, port, timeout))
}

pub fn execute(socket: mug.Socket, packet: BitArray, timeout: Int) {
  let selector =
    process.new_selector()
    |> mug.selecting_tcp_messages(mapper)

  use _ <- result.then(send(socket, packet))
  internal_receive(socket, selector, now(), timeout, option.None, <<>>)
}

fn send(socket: mug.Socket, packet: BitArray) {
  mug.send(socket, packet)
}

fn internal_receive(
  socket,
  selector,
  start_time: Int,
  timeout: Int,
  remaining_size: option.Option(Int),
  storage: BitArray,
) -> Result(BitArray, mug.Error) {
  mug.receive_next_packet_as_message(socket)

  selector
  |> process.select(timeout)
  |> result.replace_error(mug.Timeout)
  |> result.flatten
  |> result.map(fn(packet) {
    use remaining_size <- result.then(case remaining_size {
      option.None ->
        case bit_array.byte_size(packet) > 4 {
          True -> {
            let assert <<size:32-little, _:bits>> = packet
            Ok(size - bit_array.byte_size(packet))
          }
          False -> Error(mug.Ebadmsg)
        }
      option.Some(remaining_size) ->
        Ok(remaining_size - bit_array.byte_size(packet))
    })

    let storage = bit_array.append(storage, packet)
    case now() - start_time >= timeout * 1_000_000 {
      True -> Error(mug.Timeout)
      False ->
        case int.compare(remaining_size, 0) {
          order.Eq -> Ok(storage)
          order.Lt -> Error(mug.Ebadmsg)
          order.Gt ->
            internal_receive(
              socket,
              selector,
              start_time,
              timeout,
              option.Some(remaining_size),
              storage,
            )
        }
    }
  })
  |> result.flatten
}

fn mapper(message: mug.TcpMessage) -> Result(BitArray, mug.Error) {
  case message {
    mug.Packet(_, packet) -> Ok(packet)
    mug.SocketClosed(_) -> Error(mug.Closed)
    mug.TcpError(_, error) -> Error(error)
  }
}

@external(erlang, "erlang", "monotonic_time")
fn now() -> Int

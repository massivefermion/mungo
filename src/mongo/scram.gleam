import gleam/int
import bson/types
import gleam/list
import gleam/base
import bson/generic
import gleam/string
import gleam/crypto
import gleam/bit_string
import gleam/bitwise.{exclusive_or as bxor}

pub fn first_payload(username: String) {
  let nonce =
    crypto.strong_random_bytes(24)
    |> base.encode64(True)

  [
    "n=",
    username
    |> clean_username,
    ",r=",
    nonce,
  ]
  |> string.concat
}

pub fn first_message(payload) {
  let payload =
    ["n,,", payload]
    |> string.concat
    |> generic.from_string

  types.Document([
    #("saslStart", types.Boolean(True)),
    #("mechanism", types.Str("SCRAM-SHA-256")),
    #("payload", types.Binary(types.Generic(payload))),
    #("autoAuthorize", types.Boolean(True)),
    #("options", types.Document([#("skipEmptyExchange", types.Boolean(True))])),
  ])
}

pub fn parse_first_reply(reply: List(#(String, types.Value))) {
  case reply {
    [#("ok", types.Double(0.0)), ..] -> Error(Nil)

    [
      #("conversationId", types.Integer(cid)),
      #("done", types.Boolean(False)),
      #("payload", types.Binary(types.Generic(data))),
      #("ok", types.Double(1.0)),
    ] -> {
      try data =
        data
        |> generic.to_string
      try [#("r", rnonce), #("s", salt), #("i", i)] = parse_payload(data)
      case int.parse(i) {
        Ok(iterations) ->
          case iterations >= 4096 {
            True -> Ok(#(#(rnonce, salt, iterations), data, cid))
            False -> Error(Nil)
          }
        Error(Nil) -> Error(Nil)
      }
    }
  }
}

pub fn second_message(
  server_params,
  first_payload,
  server_payload,
  cid,
  password,
) {
  let #(rnonce, salt, iterations) = server_params

  try salt = base.decode64(salt)

  let salted_password = hi(password, salt, iterations)

  let client_key =
    crypto.hmac(
      "Client Key"
      |> bit_string.from_string,
      crypto.Sha256,
      salted_password,
    )

  let server_key =
    crypto.hmac(
      "Server Key"
      |> bit_string.from_string,
      crypto.Sha256,
      salted_password,
    )

  let stored_key = crypto.hash(crypto.Sha256, client_key)

  let auth_message =
    [first_payload, ",", server_payload, ",c=biws,r=", rnonce]
    |> string.concat
    |> generic.from_string

  let client_signature =
    crypto.hmac(generic.to_bit_string(auth_message), crypto.Sha256, stored_key)

  let second_payload =
    [
      "c=biws,r=",
      rnonce,
      ",p=",
      xor(client_key, client_signature, <<>>)
      |> base.encode64(True),
    ]
    |> string.concat
    |> generic.from_string

  let server_signature =
    crypto.hmac(
      auth_message
      |> generic.to_bit_string,
      crypto.Sha256,
      server_key,
    )

  #(
    types.Document([
      #("saslContinue", types.Boolean(True)),
      #("conversationId", types.Integer(cid)),
      #("payload", types.Binary(types.Generic(second_payload))),
    ]),
    server_signature,
  )
  |> Ok
}

pub fn parse_second_reply(
  reply: List(#(String, types.Value)),
  server_signature: BitString,
) {
  case reply {
    [#("ok", types.Double(0.0)), ..] -> Error(Nil)
    [
      #("conversationId", _),
      #("done", types.Boolean(True)),
      #("payload", types.Binary(types.Generic(data))),
      #("ok", types.Double(1.0)),
    ] -> {
      try data =
        data
        |> generic.to_string
      try [#("v", data)] = parse_payload(data)
      try received_signature = base.decode64(data)
      case
        bit_string.byte_size(server_signature) == bit_string.byte_size(
          received_signature,
        ) && crypto.secure_compare(server_signature, received_signature)
      {
        True -> Ok(Nil)
        False -> Error(Nil)
      }
    }
  }
}

fn parse_payload(payload: String) {
  payload
  |> string.split(",")
  |> list.try_map(fn(item) { string.split_once(item, "=") })
}

fn clean_username(username: String) {
  username
  |> string.replace("=", "=3D")
  |> string.replace(",", "=2C")
}

pub fn hi(password, salt, iterations) {
  // should cache with unique key constructed from params
  pbkdf2(crypto.Sha256, password, salt, iterations, 32)
}

external fn pbkdf2(
  crypto.HashAlgorithm,
  String,
  BitString,
  Int,
  Int,
) -> BitString =
  "crypto" "pbkdf2_hmac"

fn xor(a: BitString, b: BitString, storage: BitString) -> BitString {
  let <<fa, ra:bit_string>> = a
  let <<fb, rb:bit_string>> = b

  let new_storage =
    [storage, <<bxor(fa, fb)>>]
    |> bit_string.concat

  case [ra, rb] {
    [<<>>, <<>>] -> new_storage
    _ -> xor(ra, rb, new_storage)
  }
}

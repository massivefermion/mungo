import gleam/int
import gleam/list
import gleam/dict
import gleam/result
import gleam/string
import gleam/bit_array
import gleam/crypto
import mungo/error
import bison/bson
import bison/generic

pub fn first_payload(username: String) {
  let nonce =
    crypto.strong_random_bytes(24)
    |> bit_array.base64_encode(True)

  ["n=", clean_username(username), ",r=", nonce]
  |> string.concat
}

pub fn first_message(payload) {
  let payload =
    ["n,,", payload]
    |> string.concat
    |> generic.from_string

  [
    #("saslStart", bson.Boolean(True)),
    #("mechanism", bson.String("SCRAM-SHA-256")),
    #("payload", bson.Binary(bson.Generic(payload))),
    #("autoAuthorize", bson.Boolean(True)),
    #(
      "options",
      bson.Document(dict.from_list([#("skipEmptyExchange", bson.Boolean(True))]),
      ),
    ),
  ]
}

pub fn parse_first_reply(reply: dict.Dict(String, bson.Value)) {
  case
    #(
      dict.get(reply, "ok"),
      dict.get(reply, "done"),
      dict.get(reply, "conversationId"),
      dict.get(reply, "payload"),
      dict.get(reply, "errmsg"),
    )
  {
    #(Ok(bson.Double(0.0)), _, _, _, Ok(bson.String(msg))) ->
      Error(error.ServerError(error.AuthenticationFailed(msg)))

    #(
      Ok(bson.Double(1.0)),
      Ok(bson.Boolean(False)),
      Ok(bson.Int32(cid)),
      Ok(bson.Binary(bson.Generic(data))),
      _,
    ) -> {
      use data <- result.then(
        generic.to_string(data)
        |> result.replace_error(
          error.ServerError(error.AuthenticationFailed(
            "First payload is not a string",
          )),
        ),
      )

      case parse_payload(data) {
        Ok([#("r", rnonce), #("s", salt), #("i", i)]) ->
          case int.parse(i) {
            Ok(iterations) ->
              case iterations >= 4096 {
                True -> Ok(#(#(rnonce, salt, iterations), data, cid))
                False ->
                  Error(
                    error.ServerError(error.AuthenticationFailed(
                      "Iterations should be an integer",
                    )),
                  )
              }
            Error(Nil) ->
              Error(
                error.ServerError(error.AuthenticationFailed(
                  "Iterations was not found",
                )),
              )
          }
        _ ->
          Error(
            error.ServerError(error.AuthenticationFailed("Invalid first payload",
            )),
          )
      }
    }
    _ ->
      Error(error.ServerError(error.AuthenticationFailed("Invalid first reply")),
      )
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

  use salt <- result.then(
    bit_array.base64_decode(salt)
    |> result.replace_error(
      error.ServerError(error.AuthenticationFailed(
        "Salt is not base64 encoded string",
      )),
    ),
  )

  let salted_password = hi(password, salt, iterations)

  let client_key =
    crypto.hmac(
      bit_array.from_string("Client Key"),
      crypto.Sha256,
      salted_password,
    )

  let server_key =
    crypto.hmac(
      bit_array.from_string("Server Key"),
      crypto.Sha256,
      salted_password,
    )

  let stored_key = crypto.hash(crypto.Sha256, client_key)

  let auth_message =
    [first_payload, ",", server_payload, ",c=biws,r=", rnonce]
    |> string.concat
    |> generic.from_string

  let client_signature =
    crypto.hmac(generic.to_bit_array(auth_message), crypto.Sha256, stored_key)

  let second_payload =
    [
      "c=biws,r=",
      rnonce,
      ",p=",
      xor(client_key, client_signature, <<>>)
      |> bit_array.base64_encode(True),
    ]
    |> string.concat
    |> generic.from_string

  let server_signature =
    crypto.hmac(generic.to_bit_array(auth_message), crypto.Sha256, server_key)

  #(
    [
      #("saslContinue", bson.Boolean(True)),
      #("conversationId", bson.Int32(cid)),
      #("payload", bson.Binary(bson.Generic(second_payload))),
    ],
    server_signature,
  )
  |> Ok
}

pub fn parse_second_reply(
  reply: dict.Dict(String, bson.Value),
  server_signature: BitArray,
) {
  case
    #(
      dict.get(reply, "ok"),
      dict.get(reply, "done"),
      dict.get(reply, "payload"),
    )
  {
    #(Ok(bson.Double(0.0)), _, _) ->
      Error(error.ServerError(error.AuthenticationFailed("")))

    #(
      Ok(bson.Double(1.0)),
      Ok(bson.Boolean(True)),
      Ok(bson.Binary(bson.Generic(data))),
    ) -> {
      use data <- result.then(
        generic.to_string(data)
        |> result.replace_error(
          error.ServerError(error.AuthenticationFailed("")),
        ),
      )

      case parse_payload(data) {
        Ok([#("v", data)]) -> {
          use received_signature <- result.then(
            bit_array.base64_decode(data)
            |> result.replace_error(
              error.ServerError(error.AuthenticationFailed("")),
            ),
          )

          case
            bit_array.byte_size(server_signature)
            == bit_array.byte_size(received_signature)
            && crypto.secure_compare(server_signature, received_signature)
          {
            True -> Ok(Nil)
            False -> Error(error.ServerError(error.AuthenticationFailed("")))
          }
        }
        _ -> Error(error.ServerError(error.AuthenticationFailed("")))
      }
    }
    _ -> Error(error.ServerError(error.AuthenticationFailed("")))
  }
}

fn parse_payload(payload: String) {
  payload
  |> string.split(",")
  |> list.try_map(fn(item) { string.split_once(item, "=") })
  |> result.replace_error(error.ServerError(error.AuthenticationFailed("")))
}

fn clean_username(username: String) {
  username
  |> string.replace("=", "=3D")
  |> string.replace(",", "=2C")
}

pub fn hi(password, salt, iterations) {
  // TODO: should cache with unique key constructed from params
  pbkdf2(crypto.Sha256, password, salt, iterations, 32)
}

@external(erlang, "crypto", "pbkdf2_hmac")
fn pbkdf2(
  alg: crypto.HashAlgorithm,
  password: String,
  salt: BitArray,
  iterations: Int,
  key_len: Int,
) -> BitArray

fn xor(a: BitArray, b: BitArray, storage: BitArray) -> BitArray {
  let assert <<fa, ra:bits>> = a
  let assert <<fb, rb:bits>> = b

  let new_storage =
    [storage, <<int.bitwise_exclusive_or(fa, fb)>>]
    |> bit_array.concat

  case [ra, rb] {
    [<<>>, <<>>] -> new_storage
    _ -> xor(ra, rb, new_storage)
  }
}

import gleam/json
import wisp.{type Response}

pub fn user_uuid_missing_error() -> Response {
  json.object([#("error_message", json.string("user_uuid key is required."))])
  |> json.to_string_builder()
  |> wisp.json_response(400)
}

pub fn permissions_key_is_required_error() -> Response {
  json.object([#("error_message", json.string("permissions key is required."))])
  |> json.to_string_builder()
  |> wisp.json_response(400)
}

pub fn malformed_payload_error() -> Response {
  json.object([#("error_message", json.string("malformed payload."))])
  |> json.to_string_builder()
  |> wisp.json_response(400)
}

pub fn invalid_user_uuid_error() -> Response {
  json.object([#("error_message", json.string("invalid user_uuid."))])
  |> json.to_string_builder()
  |> wisp.json_response(400)
}

pub fn user_already_exists_error() -> Response {
  json.object([
    #("error_message", json.string("a user with this uuid already exists.")),
  ])
  |> json.to_string_builder()
  |> wisp.json_response(400)
}

pub fn no_permissions_found_error() -> Response {
  json.object([#("error_message", json.string("no permissions found."))])
  |> json.to_string_builder()
  |> wisp.json_response(404)
}

import gleam/http
import gleam/http/response
import gleam/json
import gleam/option.{None, Some}
import gleam/string_builder
import gleeunit/should
import wisp
import wisp/testing

pub fn main() {
  get_user_test()
  post_user_test()
  patch_user_test()
}

pub fn post_user_test() {
  let random_uuid = "b28f3cc9-6829-4683-b504-d43c11ae872d"
  let json =
    json.object([
      #("user_uuid", json.string(random_uuid)),
      #("permissions", json.string("testing")),
    ])
  let request = testing.post_json("/api/permissions", [], json)

  request.method
  |> should.equal(http.Post)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/api/permissions")
  request.query
  |> should.equal(None)

  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<json.to_string(json):utf8>>))
}

pub fn patch_user_test() {
  let random_uuid = "b28f3cc9-6829-4683-b504-d43c11ae872d"
  let json =
    json.object([
      #("user_uuid", json.string(random_uuid)),
      #("permissions", json.string("moar testing")),
    ])
  let request = testing.patch_json("/api/permissions", [], json)

  request.method
  |> should.equal(http.Patch)
  request.headers
  |> should.equal([#("content-type", "application/json")])
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/api/permissions")
  request.query
  |> should.equal(None)

  request
  |> wisp.read_body_to_bitstring
  |> should.equal(Ok(<<json.to_string(json):utf8>>))
}

pub fn get_user_test() {
  let random_uuid = "b28f3cc9-6829-4683-b504-d43c11ae872d"
  let json =
    json.object([
      #("user_uuid", json.string(random_uuid)),
      #("permissions", json.string("testing")),
    ])
  let request = testing.get("/api/permissions/" <> random_uuid, [])

  request.method
  |> should.equal(http.Get)
  request.host
  |> should.equal("localhost")
  request.port
  |> should.equal(None)
  request.path
  |> should.equal("/api/permissions/" <> random_uuid)
  request.query
  |> should.equal(None)
}

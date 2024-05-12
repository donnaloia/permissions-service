import app/web.{type Context}
import bison/bson
import bison/object_id
import bison/uuid
import gleam/dict
import gleam/dynamic.{
  type DecodeError, type DecodeErrors, type Dynamic, DecodeError,
}
import gleam/http.{Get, Patch, Post}
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import mungo
import mungo/crud.{Sort, Upsert}
import wisp.{type Request, type Response}

//import youid/uuid

pub fn get_permissions_view(req: Request, ctx: Context) -> Response {
  // Dispatch to the appropriate handler based on the HTTP method.
  case req.method {
    Get -> get_user_permissions(req, ctx)
    Post -> create_user_permission(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

// lists all users permissions
pub fn get_user_permissions(req: Request, ctx: Context) -> Response {
  json.object([#("data", json.array([], json.object))])
  |> json.to_string_builder()
  |> wisp.json_response(200)
}

pub fn get_permission_view(req: Request, ctx: Context, id: String) -> Response {
  case req.method {
    Get -> get_user_permission(req, ctx, id)
    Patch -> update_user_permission(req, ctx, id)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

// gets a single users permissions
pub fn get_user_permission(req: Request, ctx: Context, id: String) -> Response {
  io.debug(id)
  let assert Ok(validated_uuid) = uuid.from_string(id)
  //let assert Ok(validated_uuid) = uuid.from_string(id)
  let assert Ok(client) = mungo.start(ctx.mongo_connection_string, 512)

  let assert Ok(permissions) =
    client
    |> mungo.collection("permissions")
    |> mungo.find_one(
      [#("_id", bson.Binary(bson.UUID(validated_uuid)))],
      [],
      128,
    )
  io.print("printing permissions from get user permission")
  io.debug(permissions)
  //Some(Document(dict.from_list([#("_id", Binary(Uuid(Uuid(<<85, 14, 132, 0, 226, 155, 65, 212, 167, 22, 68, 102, 85, 68, 0, 0>>)))), #("permissions", String("test perms"))])))
  let users =
    json.object([#("data", json.array([], json.object))])
    |> json.to_string_builder()
    |> wisp.json_response(200)
}

// pub type ValidationError {
//   InvalidJson
//   UserUUIDRequired
//   PermissionRequired
//   InvalidUUID
// }

// updates a single users permissions
pub fn update_user_permission(
  req: Request,
  ctx: Context,
  _id: String,
) -> Response {
  use json <- wisp.require_json(req)
  //let assert Ok(user) = decode_user_perms(json)
  case decode_user_perms(json) {
    Error([DecodeError("field", "nothing", ["user_uuid"])]) -> {
      json.object([
        #("error_message", json.string("user_uuid key is required.")),
      ])
      |> json.to_string_builder()
      |> wisp.json_response(400)
    }
    Error([DecodeError("field", "nothing", ["permissions"])]) -> {
      json.object([
        #("error_message", json.string("permissions key is required.")),
      ])
      |> json.to_string_builder()
      |> wisp.json_response(400)
    }
    Error(_) -> {
      json.object([#("id", json.string("malformed payload."))])
      |> json.to_string_builder()
      |> wisp.json_response(400)
    }
    Ok(user) -> {
      let assert Ok(validated_uuid) = uuid.from_string(user.user_uuid)
      // TODO: add more validation here in case the user_uuid is not a valid uuid
      let assert Ok(client) = mungo.start(ctx.mongo_connection_string, 512)

      let new_permissions = [#("permissions", bson.String(user.permissions))]
      let updated_permissions = dict.from_list(new_permissions)

      let assert Ok(permissions) =
        client
        |> mungo.collection("permissions")
        |> mungo.update_one(
          [#("_id", bson.Binary(bson.UUID(validated_uuid)))],
          [#("$set", bson.Document(updated_permissions))],
          [Upsert],
          128,
        )

      json.object([
        #("id", json.string(user.user_uuid)),
        #("permissions", json.string(user.permissions)),
      ])
      |> json.to_string_builder()
      |> wisp.json_response(200)
    }
  }
}

// creates a single users permissions
pub fn create_user_permission(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req)
  //let assert Ok(user) = decode_user_perms(json)
  case decode_user_perms(json) {
    Error([DecodeError("field", "nothing", ["user_uuid"])]) -> {
      json.object([
        #("error_message", json.string("user_uuid key is required.")),
      ])
      |> json.to_string_builder()
      |> wisp.json_response(400)
    }
    Error([DecodeError("field", "nothing", ["permissions"])]) -> {
      json.object([
        #("error_message", json.string("permissions key is required.")),
      ])
      |> json.to_string_builder()
      |> wisp.json_response(400)
    }
    Error(_) -> {
      json.object([#("id", json.string("malformed payload."))])
      |> json.to_string_builder()
      |> wisp.json_response(400)
    }
    Ok(user) -> {
      let assert Ok(validated_uuid) = uuid.from_string(user.user_uuid)
      // TODO: add more validation here in case the user_uuid is not a valid uuid
      let assert Ok(client) = mungo.start(ctx.mongo_connection_string, 512)

      let new_permissions = [#("permissions", bson.String(user.permissions))]
      let updated_permissions = dict.from_list(new_permissions)

      let assert Ok(permissions) =
        client
        |> mungo.collection("permissions")
        |> mungo.insert_one(
          [
            #("_id", bson.Binary(bson.UUID(validated_uuid))),
            #("permissions", bson.String(user.permissions)),
          ],
          128,
        )

      json.object([
        #("id", json.string(user.user_uuid)),
        #("permissions", json.string(user.permissions)),
      ])
      |> json.to_string_builder()
      |> wisp.json_response(200)
    }
  }
}

fn decode_user_perms(json: Dynamic) -> Result(UserPermission, DecodeErrors) {
  let decoder =
    dynamic.decode2(
      UserPermission,
      dynamic.field("user_uuid", dynamic.string),
      dynamic.field("permissions", dynamic.string),
    )
  decoder(json)
  // Error([DecodeError("field", "nothing", ["user_uuid"])])
}

pub type UserPermission {
  UserPermission(user_uuid: String, permissions: String)
}

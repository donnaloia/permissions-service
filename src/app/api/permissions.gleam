import app/errors
import app/web.{type Context}
import bison/bson
import bison/uuid
import gleam/dict
import gleam/dynamic.{
  type DecodeError, type DecodeErrors, type Dynamic, DecodeError,
}
import gleam/http.{Get, Patch, Post}
import gleam/io
import gleam/json
import gleam/option.{None, Some}
import mungo
import mungo/crud.{Upsert}
import wisp.{type Request, type Response}

// routing for creating a single users permissions
pub fn get_permissions_view(req: Request, ctx: Context) -> Response {
  case req.method {
    Post -> create_user_permission(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

// routing for get and update a single users permissions
pub fn get_permission_view(req: Request, ctx: Context, id: String) -> Response {
  case req.method {
    Get -> get_user_permission(req, ctx, id)
    Patch -> update_user_permission(req, ctx, id)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

// gets a single users permissions
pub fn get_user_permission(req: Request, ctx: Context, id: String) -> Response {
  case uuid.from_string(id) {
    Ok(validated_uuid) -> {
      let assert Ok(client) = mungo.start(ctx.mongo_connection_string, 512)

      let assert Ok(permissions) =
        client
        |> mungo.collection("permissions")
        |> mungo.find_one(
          [#("_id", bson.Binary(bson.UUID(validated_uuid)))],
          [],
          128,
        )

      //Some(Document(dict.from_list([#("_id", Binary(Uuid(Uuid(<<85, 14, 132, 0, 226, 155, 65, 212, 167, 22, 68, 102, 85, 68, 0, 0>>)))), #("permissions", String("test perms"))])))

      case permissions {
        option.Some(bson.Document(value)) -> {
          let assert Ok(uuid) = dict.get(value, "_id")
          let uuid = case uuid {
            bson.Binary(bson.UUID(uuid)) -> uuid.to_string(uuid)
            _ -> ""
          }

          let assert Ok(perms) = dict.get(value, "permissions")
          let perms = case perms {
            bson.String(value) -> value
            _ -> ""
          }
          json.object([
            #("id", json.string(uuid)),
            #("permissions", json.string(perms)),
          ])
          |> json.to_string_builder()
          |> wisp.json_response(200)
        }
        option.Some(_) -> {
          errors.no_record_found_error()
        }
        None -> {
          errors.no_record_found_error()
        }
      }
    }
    Error(_) -> {
      errors.invalid_user_uuid_error()
    }
  }
}

// updates a single users permissions
pub fn update_user_permission(
  req: Request,
  ctx: Context,
  _id: String,
) -> Response {
  use json <- wisp.require_json(req)
  case decode_user_perms(json) {
    Error([DecodeError("field", "nothing", ["user_uuid"])]) -> {
      errors.user_uuid_missing_error()
    }
    Error([DecodeError("field", "nothing", ["permissions"])]) -> {
      errors.permissions_key_is_required_error()
    }
    Error(_) -> {
      errors.malformed_payload_error()
    }
    Ok(user) -> {
      case uuid.from_string(user.user_uuid) {
        Ok(validated_uuid) -> {
          let assert Ok(client) = mungo.start(ctx.mongo_connection_string, 512)

          let new_permissions = [
            #("permissions", bson.String(user.permissions)),
          ]
          let updated_permissions = dict.from_list(new_permissions)

          let assert Ok(_permissions) =
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
        Error(_) -> {
          errors.invalid_user_uuid_error()
        }
      }
    }
  }
}

// creates a single users permissions
pub fn create_user_permission(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req)
  case decode_user_perms(json) {
    Error([DecodeError("field", "nothing", ["user_uuid"])]) -> {
      errors.user_uuid_missing_error()
    }
    Error([DecodeError("field", "nothing", ["permissions"])]) -> {
      errors.permissions_key_is_required_error()
    }
    Error(_) -> {
      errors.malformed_payload_error()
    }
    Ok(user) -> {
      case uuid.from_string(user.user_uuid) {
        Ok(validated_uuid) -> {
          let assert Ok(client) = mungo.start(ctx.mongo_connection_string, 512)

          let mongo_write =
            client
            |> mungo.collection("permissions")
            |> mungo.insert_one(
              [
                #("_id", bson.Binary(bson.UUID(validated_uuid))),
                #("permissions", bson.String(user.permissions)),
              ],
              128,
            )
          case mongo_write {
            Ok(_) -> {
              json.object([
                #("id", json.string(user.user_uuid)),
                #("permissions", json.string(user.permissions)),
              ])
              |> json.to_string_builder()
              |> wisp.json_response(201)
            }
            Error(_) -> {
              errors.user_already_exists_error()
            }
          }
        }
        Error(_) -> {
          errors.invalid_user_uuid_error()
        }
      }
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
}

pub type UserPermission {
  UserPermission(user_uuid: String, permissions: String)
}

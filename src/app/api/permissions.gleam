import app/errors
import app/types.{type Context}
import bison/bson
import bison/uuid
import decode
import gleam/dict
import gleam/dynamic.{
  type DecodeError, type DecodeErrors, type Dynamic, DecodeError,
}
import gleam/http.{Get, Patch, Post}
import gleam/io
import gleam/json.{type Json}
import gleam/list

import gleam/option.{None, Some}
import gleam/result
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

      case permissions {
        option.Some(bson.Document(value)) -> {
          let assert Ok(uuid) = dict.get(value, "_id")
          let validated_uuid = case uuid {
            bson.Binary(bson.UUID(uuid)) -> uuid.to_string(uuid)
            _ -> ""
          }

          let permissions_kvs = dict.to_list(value)

          let json =
            list.map(permissions_kvs, fn(kv) {
              #("id", bson_to_json_value(kv.1))
            })

          json.object(json)
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

pub fn create_user_permission(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req)
  case convert_json_to_user_permission(json) {
    Error([DecodeError("field", "nothing", ["user_uuid"])]) -> {
      errors.user_uuid_missing_error()
    }
    Error([DecodeError("field", "nothing", ["organizations"])]) -> {
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
                #(
                  "organizations",
                  bson.Array(list.map(user.organizations, organization_to_bson)),
                ),
              ],
              128,
            )
          case mongo_write {
            Ok(_) -> {
              user_permission_to_json(user)
              |> json.to_string_builder
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

// updates a single users permissions
pub fn update_user_permission(
  req: Request,
  ctx: Context,
  _id: String,
) -> Response {
  use json <- wisp.require_json(req)
  case convert_json_to_user_permission(json) {
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

          let assert Ok(permissions) =
            client
            |> mungo.collection("permissions")
            |> mungo.update_one(
              [#("_id", bson.Binary(bson.UUID(validated_uuid)))],
              [
                #(
                  "$set",
                  bson.Array(list.map(user.organizations, organization_to_bson)),
                ),
              ],
              [Upsert],
              128,
            )
          user_permission_to_json(user)
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

pub fn convert_json_to_user_permission(
  json: Dynamic,
) -> Result(UserPermission, DecodeErrors) {
  let service_decoder =
    decode.into({
      use name <- decode.parameter
      use roles <- decode.parameter
      Service(name, roles)
    })
    |> decode.field("name", decode.string)
    |> decode.field("roles", decode.list(decode.string))

  let application_decoder =
    decode.into({
      use name <- decode.parameter
      use services <- decode.parameter
      Application(name, services)
    })
    |> decode.field("name", decode.string)
    |> decode.field("services", decode.list(service_decoder))

  let organization_decoder =
    decode.into({
      use name <- decode.parameter
      use applications <- decode.parameter
      Organization(name, applications)
    })
    |> decode.field("name", decode.string)
    |> decode.field("applications", decode.list(application_decoder))

  let user_permission_decoder =
    decode.into({
      use user_uuid <- decode.parameter
      use organizations <- decode.parameter
      UserPermission(user_uuid, organizations)
    })
    |> decode.field("user_uuid", decode.string)
    |> decode.field("organizations", decode.list(organization_decoder))

  user_permission_decoder
  |> decode.from(json)
}

pub type UserPermission {
  UserPermission(user_uuid: String, organizations: List(Organization))
}

pub type Organization {
  Organization(name: String, applications: List(Application))
}

pub type Application {
  Application(name: String, services: List(Service))
}

pub type Service {
  Service(name: String, roles: List(String))
}

pub fn user_permission_to_json(user_permission: UserPermission) -> Json {
  json.object([
    #("id", json.string(user_permission.user_uuid)),
    #(
      "organizations",
      json.array(user_permission.organizations, of: organization_to_json),
    ),
  ])
}

pub fn organization_to_json(organization: Organization) -> Json {
  json.object([
    #("name", json.string(organization.name)),
    #(
      "applications",
      json.array(organization.applications, of: application_to_json),
    ),
  ])
}

pub fn application_to_json(application: Application) -> Json {
  json.object([
    #("name", json.string(application.name)),
    #("services", json.array(application.services, of: service_to_json)),
  ])
}

pub fn service_to_json(service: Service) -> Json {
  json.object([
    #("name", json.string(service.name)),
    #("roles", json.array(service.roles, of: json.string)),
  ])
}

/// individual functions to convert userpermission, organization, application, service to bson
/// this replaces the recursive function that does not work due to type mismatch
pub fn service_to_bson(service: Service) -> bson.Value {
  let name = #("name", bson.String(service.name))
  let roles = #("roles", bson.Array(list.map(service.roles, bson.String)))
  let dict = dict.from_list([name, roles])
  bson.Document(dict)
}

pub fn application_to_bson(application: Application) -> bson.Value {
  let services = list.map(application.services, service_to_bson)
  [
    #("name", bson.String(application.name)),
    #("services", bson.Array(services)),
  ]
  |> dict.from_list()
  |> bson.Document
}

pub fn organization_to_bson(organization: Organization) -> bson.Value {
  let applications = list.map(organization.applications, application_to_bson)
  [
    #("name", bson.String(organization.name)),
    #("applications", bson.Array(applications)),
  ]
  |> dict.from_list()
  |> bson.Document
}

pub fn permission_to_bson(user_permission: UserPermission) -> bson.Value {
  let assert Ok(uuid) = uuid.from_string(user_permission.user_uuid)
  let organizations =
    list.map(user_permission.organizations, organization_to_bson)
  [
    #("_id", bson.Binary(bson.UUID(uuid))),
    #("organizations", bson.Array(organizations)),
  ]
  |> dict.from_list()
  |> bson.Document
}

pub fn bson_to_json_value(value: bson.Value) {
  case value {
    bson.Binary(bson.UUID(inner)) -> json.string(uuid.to_string(inner))
    bson.String(inner) -> {
      io.debug("case match")
      io.debug(inner)
      json.string(inner)
    }
    bson.Int32(inner) | bson.Int64(inner) -> json.int(inner)
    bson.Double(inner) -> json.float(inner)
    bson.Array(inner) -> json.array(inner, bson_to_json_value)
    bson.Document(inner) -> {
      let kv_list = dict.to_list(inner)
      let json_list =
        list.map(kv_list, fn(kv) { #(kv.0, bson_to_json_value(kv.1)) })
      json.object(json_list)
    }
    _ -> json.string("decoding error")
  }
}

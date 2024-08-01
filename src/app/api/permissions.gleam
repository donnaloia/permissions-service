import app/errors
import app/types.{type Context}
import bison/bson
import bison/ejson/decoder.{from_canonical as json_to_bson}
import bison/ejson/encoder.{to_canonical as bson_to_json}
import bison/uuid
import decode
import gleam/dict.{type Dict}
import gleam/dynamic.{
  type DecodeError, type DecodeErrors, type Dynamic, DecodeError,
}
import gleam/http.{Get, Patch, Post}
import gleam/io
import gleam/json
import gleam/list
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

      case permissions {
        option.Some(bson.Document(value)) -> {
          let assert Ok(uuid) = dict.get(value, "_id")
          let uuid = case uuid {
            bson.Binary(bson.UUID(uuid)) -> uuid.to_string(uuid)
            _ -> ""
          }

          let assert Ok(organizations) = dict.get(value, "organizations")
          let organizations = case organizations {
            bson.Array(val) -> bson_to_json(value)
            _ -> ""
          }

          json.object([
            #("id", json.string(uuid)),
            #("permissions", json.string(organizations)),
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
  case run(json) {
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
          let new_permissions = [#("permissions", bson.String("ok"))]
          let updated_permissions = dict.from_list(new_permissions)

          // need to pass the json as a string to json_to_bson
          //let updated_permissions = json_to_bson(user_bson.organizations)

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
            #("permissions", json.string("user.permissions")),
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

pub fn translate_to_bson(obj: PermissionsObject) -> bson.Value {
  // recursive function to convert userpermission, organization, application, service to bson
  case obj {
    UserPermissionA(permission) -> {
      let organizations = list.map(permission.organizations, translate_to_bson)
      bson.Document([user_uuid, #("organizations", bson.Array(organizations))])
    }
    OrganizationA(organization) -> {
      let organization_name = #(
        "organization_name",
        bson.String(organization.organization_name),
      )
      let applications = list.map(organization.applications, translate_to_bson)
      bson.Document([
        organization_name,
        #("applications", bson.Array(applications)),
      ])
    }
    ApplicationA(application) -> {
      let name = #("name", bson.String(application.name))
      let services = list.map(application.services, translate_to_bson)
      bson.Document([name, #("services", bson.Array(services))])
    }
    Service(service) -> {
      let name = #("name", bson.String(service.name))
      let roles = #(
        "roles",
        bson.Array(list.map(service.roles, bson.String(service.roles))),
      )
      bson.Document([name, roles])
    }
  }
}

// creates a single users permissions
pub fn create_user_permission(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req)
  case run(json) {
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
          // how to convert user.organizations from List(Organization) to List(Value)

          let mongo_write =
            client
            |> mungo.collection("permissions")
            |> mungo.insert_one(
              [
                #("_id", bson.Binary(bson.UUID(validated_uuid))),
                #(
                  "permissions",
                  bson.Array(list.map(
                    user.organizations,
                    translate_to_bson(user.organizations),
                  )),
                ),
              ],
              128,
            )
          case mongo_write {
            Ok(_) -> {
              json.object([
                #("id", json.string(user.user_uuid)),
                #(
                  "permissions",
                  json.array(user.organizations, of: json.object),
                ),
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

pub fn run(json: Dynamic) -> Result(PermissionsObject, DecodeErrors) {
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
      use organization_name <- decode.parameter
      use applications <- decode.parameter
      Organization(organization_name, applications)
    })
    |> decode.field("organization_name", decode.string)
    |> decode.field("applications", decode.list(application_decoder))

  let user_permission_decoder =
    decode.into({
      use user_uuid <- decode.parameter
      use organizations <- decode.parameter
      UserPermission(user_uuid, organizations)
    })
    |> decode.field("name", decode.string)
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

pub type PermissionsObject {
  UserPermissionA(UserPermission)
  OrganizationA(Organization)
  ApplicationA(Application)
  ServiceA(Service)
}
// {
//   "user_id": "1234",
//   "organizations": [
//     {
//       "organization_name": "organization_A",
//       "applications": [  // List of applications for organization_A
//         {
//           "name": "app_1",
//           "services": [
//             {
//               "name": "service_1",
//               "roles": ["admin"]
//             },
//             {
//               "name": "service_2",
//               "roles": ["developer"]
//             }
//           ]
//         },
//         {
//           "name": "app_2",
//           "services": [
//             {
//               "name": "service_3",
//               "roles": ["read_only"]
//             }
//           ]
//         }
//       ],
//       "services": {  // Optional: Top-level services for organization_A
//         "service_4": {
//           "roles": ["editor"]
//         }
//       }
//     },
//     {
//       "organization_name": "organization_B",
//       "services": {  // Organization_B might not have applications
//         "service_5": {
//           "roles": ["developer"]
//         }
//       }
//     }
//   ]
// }

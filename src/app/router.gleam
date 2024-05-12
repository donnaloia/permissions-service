import app/api/permissions
import app/web.{type Context}
import gleam/string_builder
import wisp.{type Request, type Response}

//pub type Collection

/// The HTTP request handler- your application!
/// 
pub fn handle_request(req: Request, ctx: Context) -> Response {
  // Apply the middleware stack for this request/response.
  use req <- web.middleware(req)

  // Later we'll use templates, but for now a string will do.
  let body = string_builder.from_string("<h1>Hello, Joe!</h1>")
  let body2 = string_builder.from_string("<h1>waddup</h1>")

  case wisp.path_segments(req) {
    ["permissions"] -> wisp.html_response(body, 200)
    ["test"] -> wisp.html_response(body2, 200)
    ["api", "permissions"] -> permissions.get_permissions_view(req, ctx)
    ["api", "permissions", uuid] ->
      permissions.get_permission_view(req, ctx, uuid)
    _ -> wisp.not_found()
  }
}
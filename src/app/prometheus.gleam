import app/types.{type Context}
import gleam/http.{Get, Post}
import gleam/http/response.{Response as HttpResponse}
import gleam/string_builder
import radish
import wisp.{type Request, type Response}

pub fn collect_metrics(
  _request,
  ctx: Context,
  handler: fn() -> wisp.Response,
) -> wisp.Response {
  let response = handler()
  let assert Ok(redis_client) =
    radish.start(ctx.redis_host, 6379, [
      radish.Timeout(128),
      radish.Auth(ctx.redis_password),
    ])
  let _recorded_metric = case response {
    HttpResponse(201, _, _) -> radish.incr(redis_client, "201", 128)
    HttpResponse(200, _, _) -> radish.incr(redis_client, "200", 128)
    HttpResponse(404, _, _) -> radish.incr(redis_client, "404", 128)
    HttpResponse(_, _, _) -> radish.incr(redis_client, "server_error", 128)
  }

  response
}

// routing for prometheus exposition endpoint
pub fn get_prometheus_data_view(req: Request, ctx) -> Response {
  case req.method {
    Get -> get_permissions_metrics(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

// constructs and returns our metrics in exposition format for prometheus
pub fn get_permissions_metrics(req: Request, ctx: Context) -> Response {
  let assert Ok(redis_client) =
    radish.start(ctx.redis_host, 6379, [
      radish.Timeout(128),
      radish.Auth(ctx.redis_password),
    ])
  let assert Ok(successful_get) = radish.get(redis_client, "200", 128)
  let assert Ok(successful_post) = radish.get(redis_client, "201", 128)
  let assert Ok(not_found) = radish.get(redis_client, "404", 128)
  let assert Ok(server_error) = radish.get(redis_client, "server_error", 128)
  let body =
    string_builder.from_string(
      "http_status_200{path=\"/api/v1/permissions\"}"
      <> successful_get
      <> "\nhttp_status_201{path=\"/api/v1/permissions\"}"
      <> successful_post
      <> "\nhttp_status_404{path=\"/api/v1/permissions\"}"
      <> not_found
      <> "\nhttp_status_server_error{path=\"/api/v1/permissions\"}"
      <> server_error,
    )
  wisp.html_response(body, 200)
}

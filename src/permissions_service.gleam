import app/router
import app/types.{type Context}
import app/web
import gleam/erlang/os
import gleam/erlang/process
import gleam/io
import gleam/result
import mist
import wisp

pub fn main() {
  // This sets the logger to print INFO level logs, and other sensible defaults
  // for a web application.
  wisp.configure_logger()

  let secret_key = load_application_secret()
  let db_user = load_mongodb_user()
  let db_password = load_mongodb_password()
  let db_collection = load_mongodb_collection()
  let redis_host = load_redis_hostname()
  let redis_password = load_redis_password()
  let mongo_connection_string =
    "mongodb://"
    <> db_user
    <> ":"
    <> db_password
    <> "@mongodb:27017/"
    <> db_collection

  let context =
    types.Context(
      mongo_connection_string: mongo_connection_string,
      secret_key: secret_key,
      redis_host: redis_host,
      redis_password: redis_password,
    )

  let handler = router.handle_request(_, context)

  let assert Ok(_) =
    handler
    |> wisp.mist_handler(secret_key)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http
  process.sleep_forever()
}

fn load_application_secret() -> String {
  os.get_env("SECRET_KEY")
  |> result.unwrap("APPLICATION_SECRET is not set.")
}

fn load_mongodb_user() -> String {
  os.get_env("DB_USER")
  |> result.unwrap("MONGO_USER is not set.")
}

fn load_mongodb_password() -> String {
  os.get_env("DB_PASSWORD")
  |> result.unwrap("MONGO_PASSWORD is not set.")
}

fn load_mongodb_collection() -> String {
  os.get_env("DB_COLLECTION")
  |> result.unwrap("permissions")
}

fn load_redis_hostname() -> String {
  os.get_env("REDIS_HOST")
  |> result.unwrap("redis_host")
}

fn load_redis_password() -> String {
  os.get_env("REDIS_PASSWORD")
  |> result.unwrap("redis_password")
}

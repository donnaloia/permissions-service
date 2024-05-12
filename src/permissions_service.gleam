import app/router

// import app/web.{type Collection}
import app/web
import gleam/erlang/os
import gleam/erlang/process
import gleam/io
import gleam/list
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
  let db_permissions_database = load_mongodb_database()
  let db_host = load_mongodb_host()
  let mongo_connection_string =
    "mongodb://admin:password@mongodb:27017/permissions"
  let context =
    web.Context(
      mongo_connection_string: mongo_connection_string,
      secret_key: secret_key,
    )
  // The handle_request function is partially applied with the context to make
  // the request handler function that only takes a request.
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

fn load_mongodb_database() -> String {
  os.get_env("DB_DATABASE")
  |> result.unwrap("MONGO_AUTH_DATABASE is not set.")
}

fn load_mongodb_host() -> String {
  "postgres"
  // os.get_env("DB_HOST")
  // |> result.unwrap("DB_HOST is not set.")
}

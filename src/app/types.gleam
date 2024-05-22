pub type Context {
  Context(
    mongo_connection_string: String,
    secret_key: String,
    redis_host: String,
    redis_password: String,
  )
}

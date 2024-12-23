
# Permissions Service

A modern standalone drop-in permissions microservice written in gleam.


## Features

- REST API endpoints to manage user permissions (see endpoints below)
- flexible permissions structure gives clients flexibility/freedom to design their own permissions schema
- designed to work flawlessly with my [Gleam Authentication Service](https://github.com/donnaloia/auth_server) in a distributed or integrated system
- initial testing suggests performance improvements over comparable service written in Flask
- built-in observability with Prometheus and Grafana (Can be disabled easily if desired)


## Tech Stack

**Containerization:** Docker

**DB:** MongoDB

**Cache:** Redis

**Server:** Written in Gleam

**Observability:** Prometheus, Grafana




## Run Locally
docker-compose spins up a mongodb, redis, prometheus, and grafana instance as well as the actual gleam permissions service for testing.
To deploy this project locally run:

```bash
  docker-compose build
  docker-compose up
```


## REST API Reference


#### All endpoints require a valid access-token


| HTTP Header | Type     | Description                |
| :-------- | :------- | :------------------------- |
| `Bearer <access_token>` | `string` | Your API access token |


#### Get User Permission

```http
  GET /api/v1/users/${uuid}/permissions/
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uuid`    | `string` | **Required**. Uuid of user to fetch |


#### Create User Permission

```http
  GET /api/v1/permissions/
```


| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uuid`      | `string` | **Required**. Uuid of the user we are creating permissions for|
| `permissions`| `json` | **Required**. Json of permissions mapped to hierarchal resources|


#### Update User Permission

```http
  POST /api/v1/permissions/
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uuid`      | `string` | **Required**. Uuid of the user we are updating permissions for|
| `permissions`| `json` | **Required**. Json of permissions mapped to hierarchal resources|


## Todo

- add support for kubernetes
- add more test coverage
- CLI admin tool

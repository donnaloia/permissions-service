
# Permissions Service

A modern standalone drop-in permissions microservice written in gleam.

![Erlang](https://img.shields.io/badge/Erlang-white.svg?style=for-the-badge&logo=erlang&logoColor=a90533)![MongoDB](https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white)![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?style=for-the-badge&logo=redis&logoColor=white)![Grafana](https://img.shields.io/badge/grafana-%23F46800.svg?style=for-the-badge&logo=grafana&logoColor=white)![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=Prometheus&logoColor=white)![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)

![example workflow](https://github.com/donnaloia/permissions-service/actions/workflows/docker-build-push.yml/badge.svg)


## Features

- REST API endpoints to manage user permissions (see endpoints below)
- flexible permissions structure gives clients flexibility/freedom to design their own permissions schema
- designed to work flawlessly with my [Gleam Authentication Service](https://github.com/donnaloia/auth_server) in a distributed or integrated system
- initial testing suggests performance improvements over comparable service written in Flask
- built-in observability with Prometheus and Grafana (Can be disabled easily if desired)
- based on RBAC principles, but more flexible


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

```json
{
   "user_uuid": "30943f82-16b6-437f-ba4e-31516e302462",
   "organizations": [
      {
         "name": "some awesome organization",
         "applications": [
            {
               "name": "name of subresource",
               "services": [
                  {
                     "name": "doing something cool",
                     "roles": [
                        "admin",
                        "god"
                     ]
                  }
               ]
            }
         ]
      }
   ]
}
```


#### Create User Permission

```http
  GET /api/v1/permissions/
```


| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uuid`      | `string` | **Required**. Uuid of the user we are creating permissions for|
| `permissions`| `json` | **Required**. Json of permissions mapped to hierarchal resources|

```json
{
   "user_uuid": "30943f82-16b6-437f-ba4e-31516e302462",
   "organizations": [
      {
         "name": "some awesome organization",
         "applications": [
            {
               "name": "name of subresource",
               "services": [
                  {
                     "name": "doing something cool",
                     "roles": [
                        "admin",
                        "god"
                     ]
                  }
               ]
            }
         ]
      }
   ]
}
```


#### Update User Permission

```http
  POST /api/v1/permissions/
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uuid`      | `string` | **Required**. Uuid of the user we are updating permissions for|
| `permissions`| `json` | **Required**. Json of permissions mapped to hierarchal resources|

```json
{
   "user_uuid": "30943f82-16b6-437f-ba4e-31516e302462",
   "organizations": [
      {
         "name": "some awesome organization",
         "applications": [
            {
               "name": "name of subresource",
               "services": [
                  {
                     "name": "doing something cool",
                     "roles": [
                        "admin",
                        "god"
                     ]
                  }
               ]
            }
         ]
      }
   ]
}
```


## Todo

- add support for kubernetes
- add more test coverage
- CLI admin tool

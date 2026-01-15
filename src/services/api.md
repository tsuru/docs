# Service API workflow

tsuru sends requests to the service API for the following actions:

- Create a new instance (`tsuru service-instance-add`)
- Update a service instance (`tsuru service-instance-update`)
- Bind an app to the service instance (`tsuru service-instance-bind`)
- Unbind an app from the service instance (`tsuru service-instance-unbind`)
- Destroy the service instance (`tsuru service-instance-remove`)
- Check the status of the service instance (`tsuru service-instance-status`)
- Display additional info (`tsuru service-info` and `tsuru service-instance-info`)

## API Specification

The API specification is available as an OpenAPI v3 specification at [SwaggerHub](https://app.swaggerhub.com/apis/tsuru/tsuru-service_api/1.0.0).

## Authentication

tsuru authenticates with the service API using HTTP basic authentication. The user can be the username or name of the service, and the password is defined in the service manifest.

## Content-types

tsuru uses `application/x-www-form-urlencoded` in requests and expects `application/json` in responses.

Example request:

```http
POST /resources HTTP/1.1
Host: myserviceapi.com
User-Agent: Go 1.1 package http
Content-Length: 38
Accept: application/json
Authorization: Basic dXNlcjpwYXNzd29yZA==
Content-Type: application/x-www-form-urlencoded

name=myinstance&plan=small&team=myteam
```

## Listing available plans

**Endpoint:** `GET /resources/plans`

tsuru gets the list of plans when user runs `tsuru service-info`.

Example request:

```http
GET /resources/plans HTTP/1.1
Host: myserviceapi.com
Accept: application/json
Authorization: Basic dXNlcjpwYXNzd29yZA==
```

**Response codes:**

| Code | Description |
|------|-------------|
| 200 | Success. Return JSON list of plans |
| 500 | Failure. Include error explanation in body |

Example response:

```json
[
  {"name": "small", "description": "plan for small instances"},
  {"name": "medium", "description": "plan for medium instances"},
  {"name": "huge", "description": "plan for huge instances"}
]
```

## Creating a new instance

**Endpoint:** `POST /resources`

Triggered by `tsuru service-instance-add mysql mysql_instance`.

Example request:

```http
POST /resources HTTP/1.1
Host: myserviceapi.com
Content-Type: application/x-www-form-urlencoded

name=mysql_instance&plan=small&team=myteam&user=username&tag=tag1&tag=tag2
```

**Response codes:**

| Code | Description |
|------|-------------|
| 201 | Instance created successfully |
| 500 | Failure. Include error explanation in body |

## Updating a service instance

**Endpoint:** `PUT /resources/<instance-name>`

This endpoint is **optional**. Triggered by `tsuru service-instance-update`.

Example request:

```http
PUT /resources/mysql_instance HTTP/1.1
Host: myserviceapi.com
Content-Type: application/x-www-form-urlencoded

description=new-description&tag=tag1&tag=tag2&team=new-team-owner&plan=new-plan
```

**Response codes:**

| Code | Description |
|------|-------------|
| 200 | Instance updated successfully |
| 404 | Endpoint not implemented (ignored by tsuru) |
| 500 | Failure. Include error explanation in body |

## Binding an app to a service instance

tsuru has two bind endpoints:

### Unit binding: `POST /resources/<instance-name>/bind`

Called every time an app adds a unit. Parameters:
- `app-host`: Host where the app is accessible
- `app-name`: Name of the app
- `unit-host`: Address of the unit

### App binding: `POST /resources/<instance-name>/bind-app`

Called once when an app is bound to a service. Parameters:
- `app-host`: Host where the app is accessible
- `app-name`: Name of the app

Example request:

```http
POST /resources/myinstance/bind-app HTTP/1.1
Host: myserviceapi.com
Content-Type: application/x-www-form-urlencoded

app-host=myapp.cloud.tsuru.io&app-name=myapp
```

**Response codes:**

| Code | Description |
|------|-------------|
| 201 | Success. Return JSON with environment variables |
| 404 | Service instance not found |
| 412 | Instance still being provisioned |
| 500 | Failure. Include error explanation in body |

Example response:

```json
{
  "MYSQL_HOST": "10.10.10.10",
  "MYSQL_PORT": 3306,
  "MYSQL_USER": "ROOT",
  "MYSQL_PASSWORD": "s3cr3t",
  "MYSQL_DATABASE_NAME": "myapp"
}
```

## Unbinding an app from a service instance

### Unit unbinding: `DELETE /resources/<instance-name>/bind`

Called every time an app removes a unit.

### App unbinding: `DELETE /resources/<instance-name>/bind-app`

Called once when the binding is removed.

Example request:

```http
DELETE /resources/myinstance/bind-app HTTP/1.1
Host: myserviceapi.com
Content-Type: application/x-www-form-urlencoded

app-host=myapp.cloud.tsuru.io&app-name=myapp
```

**Response codes:**

| Code | Description |
|------|-------------|
| 200 | Successfully unbound |
| 404 | Service instance not found |
| 500 | Failure. Include error explanation in body |

## Removing an instance

**Endpoint:** `DELETE /resources/<instance-name>`

Triggered by `tsuru service-instance-remove mysql mysql_instance -y`.

Example request:

```http
DELETE /resources/myinstance HTTP/1.1
Host: myserviceapi.com
Authorization: Basic dXNlcjpwYXNzd29yZA==
```

**Response codes:**

| Code | Description |
|------|-------------|
| 200 | Instance removed successfully |
| 404 | Service instance not found |
| 500 | Failure. Include error explanation in body |

## Checking the status of an instance

**Endpoint:** `GET /resources/<instance-name>/status`

Triggered by `tsuru service-instance-status mysql mysql_instance`.

Example request:

```http
GET /resources/myinstance/status HTTP/1.1
Host: myserviceapi.com
Authorization: Basic dXNlcjpwYXNzd29yZA==
```

**Response codes:**

| Code | Description |
|------|-------------|
| 202 | Instance is being provisioned (pending) |
| 204 | Instance is running and ready |
| 500 | Instance is not running. Include explanation in body |

## Additional info about an instance

**Endpoint:** `GET /resources/<instance-name>`

This endpoint is **optional**. Provides extra information for `tsuru service-info` and `tsuru service-instance-info`.

Example response:

```json
[
  {"label": "my label", "value": "my value"},
  {"label": "myLabel2.0", "value": "my value 2.0"}
]
```

**Response codes:**

| Code | Description |
|------|-------------|
| 200 | Success. Return JSON with label/value pairs |
| 404 | No extra info available |

# TSURU_SERVICES environment variable

tsuru exports a special environment variable in applications that use services. This variable is named `TSURU_SERVICES`.

## Structure

The value is a JSON object describing all service instances that the application uses. Each key represents a service, and contains a list of service instances with their names and environment variables.

## Example

```json
{
  "mysql": [
    {
      "instance_name": "mydb",
      "envs": {
        "DATABASE_NAME": "mydb",
        "DATABASE_USER": "mydb",
        "DATABASE_PASSWORD": "secret",
        "DATABASE_HOST": "mysql.mycompany.com"
      }
    },
    {
      "instance_name": "otherdb",
      "envs": {
        "DATABASE_NAME": "otherdb",
        "DATABASE_USER": "otherdb",
        "DATABASE_PASSWORD": "secret",
        "DATABASE_HOST": "mysql.mycompany.com"
      }
    }
  ],
  "redis": [
    {
      "instance_name": "powerredis",
      "envs": {
        "REDIS_HOST": "remote.redis.company.com:6379"
      }
    }
  ],
  "mongodb": []
}
```

In this example:

- **mysql**: Two instances (`mydb` and `otherdb`), each with their own database credentials
- **redis**: One instance (`powerredis`) with connection info
- **mongodb**: Service is bound but has no instances yet

## Usage

You can parse this variable in your application to dynamically discover and connect to service instances:

```python
import os
import json

services = json.loads(os.environ.get('TSURU_SERVICES', '{}'))

# Get MySQL connection info
if 'mysql' in services and services['mysql']:
    mysql_instance = services['mysql'][0]
    db_host = mysql_instance['envs']['DATABASE_HOST']
    db_name = mysql_instance['envs']['DATABASE_NAME']
```

This is particularly useful when your application uses multiple instances of the same service type.

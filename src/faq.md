# Frequently Asked Questions

## How do environment variables work?

All configurations in tsuru are handled through environment variables. If you need to connect with a third-party service (e.g., Twitter's API), you'll likely need extra configurations like `client_id`. In tsuru, you can export these as environment variables, visible only to your application's processes.

### Service bindings

When you bind your application to a service, the service API can return environment variables for tsuru to export in your application's units. This allows seamless integration between your app and the service instance.

For example, binding to a MySQL service might automatically set:
- `MYSQL_HOST`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- `MYSQL_DATABASE`

See [TSURU_SERVICES environment variable](services/environment_variables.md) for more details on how service environment variables are structured.

## How does the quota system work?

Quotas are handled per application and per user:

### User quotas

Every user has a quota for the number of applications they can create. For example, with a default quota of 2 applications, attempting to create a third will result in a quota exceeded error.

### Application quotas

Each application has a quota limiting the maximum number of units it can have. This prevents runaway scaling and helps manage cluster resources.

### Managing quotas

Administrators can:
- Set default quotas in the configuration file
- Change quotas for specific users or apps using the `tsuru` command

```bash
# View app quota
tsuru app quota view -a myapp

# Change app quota
tsuru app quota change -a myapp 10
```

## How does routing work?

tsuru has a router API interface, which makes it easy to change how routing works with any provisioner.

The default router implementation is [kubernetes-router](https://github.com/tsuru/kubernetes-router).

### Multiple routers

Since version 0.10.0, tsuru supports multiple routers. You can:

1. Configure a default router in your configuration
2. Define custom routers per plan

This allows different applications to use different routing strategies based on their requirements.

### Router configuration

Routers are configured in `tsuru.conf`:

```yaml
routers:
  my-router:
    type: api
    api-url: http://router-api.example.com
    default: true
```

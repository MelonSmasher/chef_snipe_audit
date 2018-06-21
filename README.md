# snipe_audit

A Chef cookbook that will automatically send Windows PC information to your Snipe inventory server.

### Platforms

- Windows

### Chef

- Chef 12.0 or later

## Attribute Example

```json
{
  "snipe": {
    "server": {
      "host_name": "snipe.example.com",
      "port": 80,
      "use_https": false
    },
    "user": {
      "api_token": "Your-API-Token-Here"
    },
    "fields": {
      "os": {
        "name": "_snipeit_operating_system_77",
        "version": "_snipeit_os_version_78"
      }
    }
  }
}
```

## Usage

### snipe_audit::default

Just include `snipe_audit` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[snipe_audit]"
  ]
}
```
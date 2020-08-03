# Consumer Rate Limiting plugin for Kong

[![Build Status](https://travis-ci.org/nokia/consumer-rate-limiting.svg?branch=master)](https://travis-ci.org/nokia/consumer-rate-limiting)

## Description

<b>Consumer Rate Limiting</b> is a [Kong](https://getkong.org/) plugin, which allows to define more configurable request limiting, than the built-in Rate Limiting plugin. Consumer Rate Limiting allows to dynamically define different limits for every consumer and API via Kong Admin API. Limits are reset every month.

| Call count   | Consumer 1 | Consumer 2 | Consumer 3 |
|--------------|------------|------------|------------|
| API 1        | 100        | 50         | 1000       |
| API 2        | 150        | 40         | 500        |
| API 3        | 50         | 40         | 500        |

The above table shows an example configuration you can achieve using this plugin.

### Usage

The plugin can be installed using LuaRocks:

```
luarocks install kong-consumer-rate-limiting
```

Before starting Kong you need to set the environment variable `KONG_CUSTOM_PLUGINS`:
```
export KONG_CUSTOM_PLUGINS=consumer-rate-limiting
```

To enable the plugin in Kong:
```
$ curl -X POST http://kong:8001/plugins \
    --data "name=consumer-rate-limiting"
```

### Request processing
This plugin integrates with generic Kong authentication plugins, so you can use any available authorization plugin to identify consumers.

If the plugin gets an authenticated call it looks, if the consumer has a limit defined for the API his calling. If not it look at the default limits. If no limits are defined the call is passed through the plugin.

In case the consumer already exceeded the call count, the call is not passed to the destination API and a HTTP response with code 429 is send back.

## Admin API routes

### POST /consumer-rate-limiting/consumers
Set limits for consumers.

```
POST /consumer-rate-limiting/consumers
{
	"consumer_id": "consumer_1"
    "quotas": [
    	{
        	"api_id": "api_1",
            "quota": 100
        },
        {
        	"api_id": "api_2",
            "quota": 150
        },
        {
        	"api_id": "api_3",
            "quota": 50
        }
    ]
}
```

### GET /consumer-rate-limiting/consumer/:id
Get current consumer limits and call counts

### POST /consumer-rate-limiting/default
Sets default limits for undefined consumers


## License

This project is licensed under the BSD-3-Clause license - see the [LICENSE](https://github.com/nokia/consumer-rate-limiting/blob/master/LICENSE).
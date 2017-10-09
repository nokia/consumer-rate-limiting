package = "kong-consumer-rate-limiting"
version = "1.0.0-0"
source = {
    url = "git://github.com/nokia/consumer-rate-limiting",
    tag = "1.0.0",
    dir = "consumer-rate-limiting"
}
description = {
    summary = "Consumer Rate Limiting is a Kong plugin, which allows to define request limiting rules",
    detailed = [[
        Consumer Rate Limiting is a Kong plugin, which allows to define more configurable request limiting, than the built-in Rate Limiting plugin. Consumer Rate Limiting allows to define different limits for every consumer and API via Kong Admin API. Limits are reset every month.
	]],
    homepage = "https://github.com/nokia/consumer-rate-limiting",
    license = "BSD 3-Clause"
}
build = {
    type = "builtin",
    modules = {
		["kong.plugins.consumer-rate-limiting.gateway"] = "kong/plugins/consumer-rate-limiting/gateway.lua",
		["kong.plugins.consumer-rate-limiting.api"] = "kong/plugins/consumer-rate-limiting/api.lua",
		["kong.plugins.consumer-rate-limiting.controller"] = "kong/plugins/consumer-rate-limiting/controller.lua",
		["kong.plugins.consumer-rate-limiting.daos"] = "kong/plugins/consumer-rate-limiting/daos.lua",
		["kong.plugins.consumer-rate-limiting.handler"] = "kong/plugins/consumer-rate-limiting/handler.lua",
		["kong.plugins.consumer-rate-limiting.schema"] = "kong/plugins/consumer-rate-limiting/schema.lua",
		["kong.plugins.consumer-rate-limiting.timeutils"] = "kong/plugins/consumer-rate-limiting/timeutils.lua",
		["kong.plugins.consumer-rate-limiting.migrations.cassandra"] = "kong/plugins/consumer-rate-limiting/migrations/cassandra.lua",
		["kong.plugins.consumer-rate-limiting.migrations.postgres"] = "kong/plugins/consumer-rate-limiting/migrations/postgres.lua"
    }
}
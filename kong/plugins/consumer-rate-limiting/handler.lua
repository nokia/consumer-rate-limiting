local responses = require "kong.tools.responses"

local BasePlugin = require "kong.plugins.base_plugin"
local ConsumerRateLimiting = BasePlugin:extend()

local timeutils = require "kong.plugins.consumer-rate-limiting.timeutils"
local Controller = require "kong.plugins.consumer-rate-limiting.controller"
local gateway = require "kong.plugins.consumer-rate-limiting.gateway"

function ConsumerRateLimiting:new()
  ConsumerRateLimiting.super.new(self, "consumer-rate-limiting")
end

function ConsumerRateLimiting:access(conf)
  ConsumerRateLimiting.super.access(self)

  local user = ngx.ctx.authenticated_consumer
  local api = ngx.ctx.api

  local ctrl = Controller(gateway.CounterGateway(), gateway.QuotaGateway(), timeutils.PeriodGenerator("months"))

  local should_proxy, call_count = ctrl.handle(user, api)

  if call_count ~= nil then
    ngx.req.set_header("X-Consumer-Rate-Limiting", call_count)
  end

  if should_proxy == false then
    responses.send(429, "API quota limit exceeded")
  end
end

return ConsumerRateLimiting

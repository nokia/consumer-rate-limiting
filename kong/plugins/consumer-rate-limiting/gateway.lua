
local function QuotaGateway(singletons)
  if singletons == nil then
    singletons = require "kong.singletons"
    cache = singletons.cache
  end

  local self = {}

  function self.get(consumer_id, api_name)
    function find_quota_for_api(consumer_id)
      ngx.log(ngx.DEBUG, string.format("(consumer-rate-limiting) finding quota: consumer_id=%s api_name=%s", consumer_id, api_name))

      local tb = singletons.dao.consumerratelimiting_quotas
      local quotas, err = tb:find_all({consumer_id = consumer_id})
      if err then
        return response.HTTP_INTERNAL_SERVER_ERROR(err)
      end

      if #quotas > 0 then
        for i = 1, #quotas do
          if string.find(api_name, quotas[i].api_id, 0, true) then
            ngx.log(ngx.DEBUG, "(consumer-rate-limiting) quota found: ", quotas[i].quota)
            return quotas[i].quota
          end
        end
      end
      ngx.log(ngx.DEBUG, "(consumer-rate-limiting) no quota found!")
      return nil
    end

    local cache_key = singletons.dao.consumerratelimiting_quotas:cache_key(consumer_id, api_name)

    local quota, err = cache:get(cache_key, nil, find_quota_for_api, consumer_id)

    if quota == nil then
      local cache_key = singletons.dao.consumerratelimiting_quotas:cache_key("default", api_name)
      quota, err = cache:get(cache_key, nil, find_quota_for_api, "default")
    end

    return quota
  end

  return self
end

local function CounterGateway(singletons)
  if singletons == nil then
    singletons = require "kong.singletons"
  end

  local self = {}

  function self.increment(user, api, period)
    local row, err = singletons.dao.consumerratelimiting_call_count:find({
      consumer_id = user,
      api_id = api,
      period = period
    })

    if row then
      local call_count = row.call_count + 1
      singletons.dao.consumerratelimiting_call_count:update({
        call_count = call_count
      }, {
        consumer_id = user,
        api_id = api,
        period = period
      })
    else
      local res, err = singletons.dao.consumerratelimiting_call_count:insert({
        consumer_id = user,
        api_id = api,
        period = period,
        call_count = 1
      })
    end
  end

  function self.get(user, api, period)
    local row, err = singletons.dao.consumerratelimiting_call_count:find({
      consumer_id = user,
      api_id = api,
      period = period
    })
    if row then
      return row.call_count
    else
      return -1
    end
  end

  return self
end

return {
  QuotaGateway = QuotaGateway,
  CounterGateway = CounterGateway
}
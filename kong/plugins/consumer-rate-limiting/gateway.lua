
local function QuotaGateway(singletons)
  if singletons == nil then
    singletons = require "kong.singletons"
  end

  local self = {}

  function self.get(user, api)
    function find_quota_for_api(quotas)
      if #quotas > 0 then
        for i = 1, #quotas do
          if string.find(api, quotas[i].api_id, 0, true) then
            return quotas[i].quota
          end
        end
      end
      return nil
    end

    local tb = singletons.dao.consumerratelimiting_quotas

    local rows, err = tb:find_all({
      consumer_id = user
    })

    local quota = find_quota_for_api(rows)

    if quota == nil then
      rows, err = tb:find_all({
        consumer_id = "default"
      })
      quota = find_quota_for_api(rows)
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
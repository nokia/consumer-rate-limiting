
local function Controller(_count_gateway, _quota_gateway, _period_generator)
  local self = {
    count_gateway = _count_gateway,
    quota_gateway = _quota_gateway,
    period_generator = _period_generator
  }

  function self.handle(consumer, api)
    if consumer == nil then
      return true, nil
    end

    local period = self.period_generator.get_period(os.time())
    self.count_gateway.increment(consumer.id, api.name, period)
    local call_count = self.count_gateway.get(consumer.id, api.name, period)
    local quota = self.quota_gateway.get(consumer.id, api.name)

    if quota == nil or quota == -1 then
      return true, call_count
    end

    if call_count > quota then
      return false, call_count
    end
    return true, call_count
  end

  return self
end

return Controller



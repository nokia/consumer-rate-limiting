local responses = require "kong.tools.responses"

local function save_quotas(tb, user_id, quotas)
  local rows, err = tb:find_all({
    consumer_id = user_id
  })

  for i = 1, #rows do
    tb:delete({
      consumer_id = user_id,
      api_id = rows[i].api_id
    })
  end

  for i = 1, #quotas do
    local res, err = tb:insert({
      consumer_id = user_id,
      api_id = quotas[i].api_id,
      quota = quotas[i].quota
    })
  end
end

return {
  ["/consumer-rate-limiting/consumers"] = {
    POST = function(self, dao_factory, helpers)
      local user_id = self.params.consumer_id
      local quotas = self.params.quotas
      save_quotas(dao_factory.consumerratelimiting_quotas, user_id, quotas)
      return responses.send(200, "OK")
    end
  },
  ["/consumer-rate-limiting/consumer/:id"] = {
    GET = function(self, dao_factory, helpers)
      local quota_rows, err = dao_factory.consumerratelimiting_quotas:find_all({
        consumer_id = self.params.id
      })

      local call_rows, err = dao_factory.consumerratelimiting_quotas:find_all({
        consumer_id = self.params.id
      })

      local res = {
        quotas = quota_rows,
        call_count = call_rows
      }

      return responses.send(200, res)
    end
  },
  ["/consumer-rate-limiting/default/"] = {
    POST = function(self, dao_factory, helpers)
      local user_id = "default"
      local quotas = self.params.quotas
      save_quotas(dao_factory.consumerratelimiting_quotas, user_id, quotas)
      return responses.send(200, "OK")
    end
  }
}
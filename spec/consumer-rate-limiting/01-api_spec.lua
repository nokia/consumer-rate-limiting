local helpers = require "spec.helpers"

local cjson = require "cjson"

local function generateBody(user, quotas)
  return cjson.encode({
    consumer_id = user,
    quotas = quotas
  })
end

local function generateRequest(user, quotas)
  return {
    method = "POST",
    path = "/consumer-rate-limiting/consumers",
    headers = {
      content_type = "application/json"
    },
    body = generateBody(user, quotas)
  }
end

local function checkQuotaRow(user, api, quota)
  local row = assert(helpers.dao.consumerratelimiting_quotas:find({
    consumer_id = user,
    api_id = api
  }))
  assert.equals(quota, row.quota)
end

describe("Consumer Rate Limiting plugin", function()

  before_each(function()
    helpers.kill_all()
    helpers.dao:drop_schema()
    helpers.run_migrations()

    tested_plugin = assert(helpers.dao.plugins:insert {
      name = "consumer-rate-limiting",
    })

    assert(helpers.start_kong {custom_plugins = "consumer-rate-limiting"})
  end)

  after_each(function()
    helpers.stop_kong()
    helpers.dao:drop_schema()
  end)

  describe("Admin API", function()
    it("POST to default endpoint should add quotas to database", function()
      local res = assert(helpers.admin_client():send({
        method = "POST",
        path = "/consumer-rate-limiting/default",
        headers = {
          content_type = "application/json"
        },
        body = cjson.encode({
          quotas = {
            { api_id = "api1", quota = 20 },
            { api_id = "api2", quota = 100 }
          }
        })
      }))

      assert.equals(200, res.status)
      checkQuotaRow("default", "api1", 20)
      checkQuotaRow("default", "api2", 100)
    end)

    it("POST to users endpoint with one consumer should add it to database", function()
      local res = assert(helpers.admin_client():send(generateRequest(
        "user1", {
          { api_id = "api1", quota = 10 },
          { api_id = "api2", quota = 5 }
        }
      )))

      assert.equals(200, res.status)
      checkQuotaRow("user1", "api1", 10)
      checkQuotaRow("user1", "api2", 5)
    end)

    it("POST to users endpoint with existing quote should update the old one", function()
      local res = assert(helpers.admin_client():send(generateRequest(
        "user1", {
          { api_id = "api1", quota = 10 },
          { api_id = "api2", quota = 5 }
        }
      )))

      checkQuotaRow("user1", "api1", 10)

      local res = assert(helpers.admin_client():send(generateRequest(
        "user1", {
          { api_id = "api1", quota = 5 }
        }
      )))

      checkQuotaRow("user1", "api1", 5)
      assert.equals(nil, helpers.dao.consumerratelimiting_quotas:find({
        consumer_id = "user1",
        api_id = "api2"
      }))
    end)

    it("GET to user endpoint should return current quota", function()
      assert(helpers.admin_client():send(generateRequest(
        "user1", {
          { api_id = "api1", quota = 10 }
        }
      )))

      assert(helpers.dao.consumerratelimiting_call_count:insert({
        consumer_id = "user1",
        api_id = "api1",
        period = 1,
        call_count = 1
      }))

      local res = assert(helpers.admin_client():send {
          method = "GET",
          path = "/consumer-rate-limiting/consumer/user1",
          headers = {
            content_type = "application/json"
          },
        }
      )
    end)
  end)
end)
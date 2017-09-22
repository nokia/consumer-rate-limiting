local helpers = require "spec.helpers"

local cjson = require "cjson"

local function createConsumer(name, apikey)
  local consumer = assert(helpers.dao.consumers:insert {
    custom_id = name
  })
  assert(helpers.dao.keyauth_credentials:insert {
    key = apikey,
    consumer_id = consumer.id
  })
  return consumer
end

local function addConsumerQuota(consumer, api, quota)
  helpers.dao.consumerratelimiting_quotas:insert({
    consumer_id = consumer.id,
    api_id = api,
    quota = quota
  })
end

describe("User Rate Limiting plugin", function()

  before_each(function()
    helpers.kill_all()
    helpers.dao:drop_schema()
    helpers.run_migrations()

    tested_plugin = assert(helpers.dao.plugins:insert {
      name = "consumer-rate-limiting",
    })

    assert(helpers.dao.apis:insert {
      name = "openapi",
      hosts = { "openapi.org" },
      upstream_url = "http://10.131.38.183"
    })

    api = assert(helpers.dao.apis:insert {
      name = "1httpbin-1",
      hosts = { "1httpbin.org" },
      upstream_url = "http://10.131.38.183"
    })

    local api2 = assert(helpers.dao.apis:insert {
      name = "2httpbin",
      hosts = { "2httpbin.org" },
      upstream_url = "http://10.131.38.183"
    })

    matching_api = assert(helpers.dao.apis:insert {
      name = "zeppelin123",
      hosts = { "zeppelin.org" },
      upstream_url = "http://10.131.38.183"
    })

    assert(helpers.dao.plugins:insert {
      name = "key-auth",
      api_id = api.id
    })

    assert(helpers.dao.plugins:insert {
      name = "key-auth",
      api_id = api2.id
    })

    assert(helpers.dao.plugins:insert {
      name = "key-auth",
      api_id = matching_api.id
    })

    local user1 = createConsumer("user1", "apikey1")
    local user2 = createConsumer("user2", "apikey2")
    limitUser = createConsumer("user3", "apikey3")

    addConsumerQuota(user1, api.name, 100)
    addConsumerQuota(user1, api2.name, 100)
    addConsumerQuota(user2, api.name, 100)
    addConsumerQuota(user2, api2.name, 100)

    assert(helpers.start_kong {custom_plugins = "consumer-rate-limiting"})
  end)

  after_each(function()
    helpers.stop_kong()
    helpers.dao:drop_schema()
  end)

  it("unauthenticated user should be proxied", function()
    local res = assert(helpers.proxy_client():send {
      method = "GET",
      path = "/get",
      headers = {
        ["Host"] = "openapi.org"
      }
    })

    assert.equals(200, res.status)
  end)

  describe("counting", function()
    it("should store current quota in X-ConsumerRateLimiting header", function()
      for i = 1, 5 do
        local res = assert(helpers.proxy_client():send {
          method = "GET",
          path = "/get?apikey=apikey1",
          headers = {
            ["Host"] = "1httpbin.org"
          }
        })

        local bodyStr, err = res:read_body()
        local body = cjson.decode(bodyStr)
        assert.equals(tostring(i), body.headers["X-Consumer-Rate-Limiting"])
      end
    end)

    it("each user should have own quota count", function()
      for i = 1, 2 do
        local res = assert(helpers.proxy_client():send {
          method = "GET",
          path = "/get?apikey=apikey"..i,
          headers = {
            ["Host"] = "1httpbin.org"
          }
        })

        local bodyStr, err = res:read_body()
        local body = cjson.decode(bodyStr)
        assert.equals("1", body.headers["X-Consumer-Rate-Limiting"])
      end
    end)

    it("each api has a own quota count", function()
      for i = 1, 2 do
        local res = assert(helpers.proxy_client():send {
          method = "GET",
          path = "/get?apikey=apikey1",
          headers = {
            ["Host"] = i.."httpbin.org"
          }
        })

        local bodyStr, err = res:read_body()
        local body = cjson.decode(bodyStr)
        assert.equals("1", body.headers["X-Consumer-Rate-Limiting"])
      end
    end)
  end)

  describe("limiting", function()
    it("should block if quota in not available", function()
      local res = assert(helpers.proxy_client():send {
        method = "GET",
        path = "/get?apikey=apikey3",
        headers = {
          ["Host"] = "1httpbin.org"
        }
      })

      assert.equals(429, res.status)
    end)

    it("should use default quotas if available", function()
      addConsumerQuota({id = "default"}, api.name, 1)

      local res = assert(helpers.proxy_client():send {
        method = "GET",
        path = "/get?apikey=apikey3",
        headers = {
          ["Host"] = "1httpbin.org"
        }
      })

      assert.equals(200, res.status)
    end)

    it("should return 429, if quota is exceeded", function()
      addConsumerQuota(limitUser, api.name, 1)

      local res = assert(helpers.proxy_client():send {
        method = "GET",
        path = "/get?apikey=apikey3",
        headers = {
          ["Host"] = "1httpbin.org"
        }
      })

      assert.equals(200, res.status)

      local res = assert(helpers.proxy_client():send {
        method = "GET",
        path = "/get?apikey=apikey3",
        headers = {
          ["Host"] = "1httpbin.org"
        }
      })

      assert.equals(429, res.status)
    end)
  end)

  describe("api matching", function()
    it("should be matched if api in quota is substring of api name", function()
      addConsumerQuota(limitUser, "zeppelin", 1)
      
      local res = assert(helpers.proxy_client():send {
        method = "GET",
        path = "/get?apikey=apikey3",
        headers = {
          ["Host"] = "zeppelin.org"
        }
      })

      assert.equals(200, res.status)

      local res = assert(helpers.proxy_client():send {
        method = "GET",
        path = "/get?apikey=apikey3",
        headers = {
          ["Host"] = "zeppelin.org"
        }
      })

      assert.equals(429, res.status)
    end)
  end)

end)
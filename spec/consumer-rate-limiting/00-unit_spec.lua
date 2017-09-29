local timeutils = require("kong.plugins.consumer-rate-limiting.timeutils")
local Controller = require("kong.plugins.consumer-rate-limiting.controller")
local gateway = require("kong.plugins.consumer-rate-limiting.gateway")

describe("Timeutils module", function()
  describe("get_timestamp_keys() function", function()
    it("should return proper time keys", function()
      local timestamp = 1503411059

      local keys = timeutils.get_timestamp_keys(timestamp)

      assert.equals(1503411059, keys.seconds)
      assert.equals(25056850, keys.minutes)
      assert.equals(417614, keys.hours)
      assert.equals(17400, keys.days)
      assert.equals(580, keys.months)
    end)
  end)
end)

describe("Consumer Rate Limiting", function()

  describe("controller", function()

    local function generate_count_gateway(get)
      return mock({
        increment = function() end,
        get = function() return get end
      })
    end
    local function generate_quota_gateway(get)
      return mock({
        get = function() return get end
      })
    end
    local function generate_period_generator(period)
      return mock({
        get_period = function() return period end
      })
    end

    it("should proxy unauthorized users", function()
      local count_gateway = generate_count_gateway(0)
      local period_generator = generate_period_generator({minutes = 10})
      local quota_gateway = generate_quota_gateway(0)

      local ctrl = Controller(count_gateway, quota_gateway, period_generator)

      assert.equals(true, ctrl.handle(nil, {name = "zeppelin1"}))
    end)

    it("should count requests per user, application and period", function()
      local count_gateway = generate_count_gateway(0)
      local period_generator = generate_period_generator(10)
      local quota_gateway = generate_quota_gateway(0)

      local ctrl = Controller(count_gateway, quota_gateway, period_generator)
      ctrl.handle({id = "user1"}, {name = "zeppelin1"})

      assert.stub(count_gateway.increment).was.called_with("user1", "zeppelin1", 10)
    end)

    it("should return true if quota is not set for a user and api", function()
      local count_gateway = generate_count_gateway(10)
      local period_generator = generate_period_generator({minutes = 10})
      local quota_gateway = generate_quota_gateway(nil)

      local ctrl = Controller(count_gateway, quota_gateway, period_generator)
      
      assert.equals(true, ctrl.handle({id = "user1"}, {name = "zeppelin1"}))
    end)

    it("should return false if quota is exceeded for an user and api", function()
      local count_gateway = generate_count_gateway(10)
      local period_generator = generate_period_generator({minutes = 10})
      local quota_gateway = generate_quota_gateway(9)

      local ctrl = Controller(count_gateway, quota_gateway, period_generator)
      
      assert.equals(false, ctrl.handle({id = "user1"}, {name = "zeppelin1"}))
    end)

    it("should return true if quota is set to -1", function()
      local count_gateway = generate_count_gateway(1)
      local period_generator = generate_period_generator({minutes = 10})
      local quota_gateway = generate_quota_gateway(-1)

      local ctrl = Controller(count_gateway, quota_gateway, period_generator)
      
      assert.equals(true, ctrl.handle({id = "user1"}, {name = "zeppelin1"}))
    end)

    it("should return true if quota is not exceeded for an user and api", function()
      local count_gateway = generate_count_gateway(1)
      local period_generator = generate_period_generator({minutes = 10})
      local quota_gateway = generate_quota_gateway(1)

      local ctrl = Controller(count_gateway, quota_gateway, period_generator)
      
      assert.equals(true, ctrl.handle({id = "user1"}, {name = "zeppelin1"}))
    end)

    it("should return call count as a second return parameter", function()
      local count_gateway = generate_count_gateway(10)
      local period_generator = generate_period_generator({minutes = 10})
      local quota_gateway = generate_quota_gateway(1)

      local ctrl = Controller(count_gateway, quota_gateway, period_generator)
      
      local _, call_count = ctrl.handle({id = "user1"}, {name = "zeppelin1"})

      assert.equals(10, call_count)
    end)
  end)

  describe("period generator", function()
    it("should return month since epoch", function()
      local tests = {
        {100, 0},
        {2592000, 1}
      }

      local generator = timeutils.PeriodGenerator()

      for _, test in pairs(tests) do
        assert.equals(test[2], generator.get_period(test[1]))
      end
    end)
  end)

  describe("quota gateway", function()
    local function createSingletonMock(find_all_func)
      return {
        dao = {
          consumerratelimiting_quotas = mock({
            find_all = find_all_func
          })
        }
      }
    end
  
    it("should return default quota, if quota for user isn't present", function()
      local singletons = createSingletonMock(function(self, tb)
        if tb.consumer_id == "default" then
          return {{quota = 10, api_id = "api1"}}, nil
        else
          return {}, nil
        end
      end)

      local gw = gateway.QuotaGateway(singletons)
      assert.equals(10, gw.get("user1", "api1"))
    end)

    it("should return nil, if default quota isn't present", function()
      local singletons = createSingletonMock(function(self, tb)
        return {}, nil
      end)

      local gw = gateway.QuotaGateway(singletons)
      assert.equals(nil, gw.get("user1", "api1"))
    end)

    it("should return quota, where the api name is substring of provided api name", function()
      local singletons = createSingletonMock(function(self, tb)
        return {
          {consumer_id = "user1", api_id = "subapi", quota = 1},
          {consumer_id = "user1", api_id = "mainapi", quota = 2},
        }, nil
      end)

      local gw = gateway.QuotaGateway(singletons)
      assert.equals(2, gw.get("user1", "mainapi-1"))
    end)
  end)

  describe("count gateway", function()
    describe("get", function()
      local function createSingletonMock(row, err)
        return {
          dao = {
            consumerratelimiting_call_count = mock({
              find = function(self, tb)
                return row, err
              end
            })
          }
        }
      end

      it("should call database", function()
        local singletons = createSingletonMock({}, nil)
        local tb = singletons.dao.consumerratelimiting_call_count
        local gw = gateway.CounterGateway(singletons)
        gw.get("user1", "api1", 10)
        assert.stub(tb.find)
          .was.called_with(tb, {
            consumer_id = "user1",
            api_id = "api1",
            period = 10
          })
      end)

      it("should return -1, if there is no entry in database", function()
        local singletons = createSingletonMock(nil, nil)
        local tb = singletons.dao.consumerratelimiting_call_count
        local gw = gateway.CounterGateway(singletons)
        assert.equals(-1, gw.get("user1", "api1", 10))
      end)

      it("should return call count, if there is a entry in database", function()
        local singletons = createSingletonMock({call_count = 5}, nil)
        local tb = singletons.dao.consumerratelimiting_call_count
        local gw = gateway.CounterGateway(singletons)
        assert.equals(5, gw.get("user1", "api1", 10))
      end)
    end)

    describe("increment", function()
      local function createSingletonMock(row, err)
        return {
          dao = {
            consumerratelimiting_call_count = mock({
              find = function(self, tb)
                return row, err
              end,
              insert = function(self, tb) end,
              update = function(self, tb, filter) end
            })
          }
        }
      end

      it("should create now row, if count for user doesn't exist", function()
        local singletons = createSingletonMock(nil, nil)
        local tb = singletons.dao.consumerratelimiting_call_count

        local gw = gateway.CounterGateway(singletons)
        gw.increment("user1", "api1", 10)

        assert.stub(tb.insert)
          .was.called_with(tb, {
            consumer_id = "user1",
            api_id = "api1",
            period = 10,
            call_count = 1
          })
      end)

      it("should increment current value, if count exists", function()
        local singletons = createSingletonMock({call_count = 5}, nil)
        local tb = singletons.dao.consumerratelimiting_call_count

        local gw = gateway.CounterGateway(singletons)
        gw.increment("user1", "api1", 10)

        assert.stub(tb.update)
          .was.called_with(tb, { call_count = 6 }, {
            consumer_id = "user1",
            api_id = "api1",
            period = 10,
          })
      end)

    end)
  end)

end)
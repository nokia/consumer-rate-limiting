local QUOTA_SCHEMA = {
  primary_key = {"consumer_id", "api_id"},
  table = "consumerratelimiting_quotas",
  fields = {
    consumer_id = {type = "string", required = true},
    api_id = {type = "string", required = true},
    quota = {type = "integer"}
  }
}

local CALL_COUNT_SCHEMA = {
  primary_key = {"consumer_id", "api_id", "period"},
  table = "consumerratelimiting_call_count",
  fields = {
    consumer_id = {type = "string", required = true},
    api_id = {type = "string", required = true},
    period = {type = "integer", required = true},
    call_count = {type = "integer"}
  }
}

return {
  consumerratelimiting_quotas = QUOTA_SCHEMA,
  consumerratelimiting_call_count = CALL_COUNT_SCHEMA
}
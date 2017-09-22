timeutils = {}

function timeutils.get_timestamp_keys(timestamp)
  return { 
    seconds = timestamp,
    minutes = math.floor(timestamp/60),
    hours = math.floor(timestamp/3600),
    days = math.floor(timestamp/86400),
    months = math.floor(timestamp/2592000)
  }
end

function timeutils.PeriodGenerator()
  local self = {}

  function self.get_period(timestamp)
    return timeutils.get_timestamp_keys(timestamp).months
  end

  return self
end

return timeutils
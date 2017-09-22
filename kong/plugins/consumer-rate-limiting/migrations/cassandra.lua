return {
  {
    name = "2017-09-20-165400_init_consumerratelimiting",
    up = [[
      CREATE TABLE IF NOT EXISTS consumerratelimiting_quotas (
        consumer_id text,
        api_id text,
        quota int,
        PRIMARY KEY (consumer_id, api_id)
      );
      CREATE TABLE IF NOT EXISTS consumerratelimiting_call_count (
        consumer_id text,
        api_id text,
        period int,
        call_count int,
        PRIMARY KEY (consumer_id, api_id, period)
      );
    ]],
    down = [[
      DROP TABLE consumerratelimiting_quotas;
      DROP TABLE consumerratelimiting_call_count;
    ]]
  }
}
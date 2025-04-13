CREATE DATABASE IF NOT EXISTS kafka;
CREATE TABLE kafka.schedule
(
    id Int32,
    course_id Int32,
    lecturer_id Int32,
    start_dt Int32,
    end_dt Int32,
    course_days String,
    op String,
    cdc_ts Int64,
    source_table String
)
ENGINE = Kafka('kafka:9092', 'L1_datalake_schedule', 'clickhouse_schedule_consumer', 'JSONEachRow')
SETTINGS
    kafka_thread_per_consumer = 0,
    kafka_num_consumers = 1;

CREATE TABLE L1_datalake.schedule
(
    id String,
    course_id String,
    lecturer_id String,
    start_dt Date32,
    end_dt Date32,
    course_days String,
    op String,
    cdc_ts DateTime,
    source_table String
)
ENGINE = MergeTree()
ORDER BY (id, cdc_ts);

CREATE MATERIALIZED VIEW kafka.schedule_mv TO L1_datalake.schedule AS
SELECT
    toString(id) AS id,
    toString(course_id) AS course_id,
    toString(lecturer_id) AS lecturer_id,
    toDate32(start_dt) AS start_dt,
    toDate32(end_dt) AS end_dt,
    course_days,
    op,
    toDateTime(cdc_ts) AS cdc_ts,
    source_table,
FROM kafka.schedule
SETTINGS
    stream_like_engine_allow_direct_select = 1;

-- Run these commands inside the ClickHouse client after connecting:
-- docker exec -it clickhouse clickhouse-client -u user --password password --database L1_datalake --multiline

-- PART A: Create Final Target Tables (Datalake Layer in 'L1_datalake')

CREATE TABLE IF NOT EXISTS L1_datalake.course (
        id Int32,
        name String,
        -- Debezium Metadata
        op String,
        cdc_ts DateTime,
        source_table String,
        inserted_at DateTime DEFAULT now()
    ) ENGINE = ReplacingMergeTree(inserted_at) -- Keep latest state based on event time
    ORDER BY (id);

CREATE TABLE IF NOT EXISTS L1_datalake.schedule (
        id Int32,
        course_id Int32,
        lecturer_id Int32,
        start_dt Date,
        end_dt Date,
        course_days String,
        op String,
        cdc_ts DateTime,
        source_table String,
        inserted_at DateTime DEFAULT now()
    ) ENGINE = ReplacingMergeTree(inserted_at)
    ORDER BY (id);

CREATE TABLE IF NOT EXISTS L1_datalake.enrollment (
        id Int32,
        student_id Int32,
        schedule_id Int32,
        academic_year String,
        semester Int32,
        enroll_dt Date,
        op String,
        cdc_ts DateTime,
        source_table String,
        inserted_at DateTime DEFAULT now()
    ) ENGINE = ReplacingMergeTree(inserted_at)
    ORDER BY (id);

CREATE TABLE IF NOT EXISTS L1_datalake.course_attendance (
        id Int32,
        student_id Int32,
        schedule_id Int32,
        attend_dt Date,
        op String,
        cdc_ts DateTime,
        source_table String,
        inserted_at DateTime DEFAULT now()
    ) ENGINE = MergeTree() -- Use MergeTree if attendance records are immutable facts
    PARTITION BY toYYYYMM(attend_dt) -- Example partitioning, adjust if needed
    ORDER BY (schedule_id, student_id, attend_dt, id);

-- PART B: Create Kafka Engine Tables (Datalake Layer in 'L1_datalake')

CREATE DATABASE IF NOT EXISTS kafka;

CREATE TABLE IF NOT EXISTS kafka.course (
        id Int32,
        name String,
        op String,
        cdc_ts DateTime,
        source_table String, -- Field added by Beam
) ENGINE = Kafka
    SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'L1_datalake_course', -- Matches Beam output topic
    kafka_group_name = 'clickhouse_group_course', -- Unique consumer group per table
    kafka_format = 'JSONEachRow',       -- Assumes Beam outputs one JSON per line
    kafka_skip_broken_messages = 1;     -- Skip messages CH can't parse

CREATE TABLE IF NOT EXISTS kafka.schedule (
        id Int32,
        course_id Int32,
        lecturer_id Int32,
        start_dt Date,
        end_dt Date,
        course_days String,
        op String,
        cdc_ts DateTime,
        source_table String,
) ENGINE = Kafka
    SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'L1_datalake_schedule',
    kafka_group_name = 'clickhouse_group_schedule',
    kafka_format = 'JSONEachRow',
    kafka_skip_broken_messages = 1;

CREATE TABLE IF NOT EXISTS kafka.enrollment (
    id Int32,
    student_id Int32,
    schedule_id Int32,
    academic_year String,
    semester Int32,
    enroll_dt Date,
    op String,
    cdc_ts DateTime,
    source_table String,
) ENGINE = Kafka
    SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'L1_datalake_enrollment',
    kafka_group_name = 'clickhouse_group_enrollment',
    kafka_format = 'JSONEachRow',
    kafka_skip_broken_messages = 1;

CREATE TABLE IF NOT EXISTS kafka.course_attendance (
    id Int32,
    student_id Int32,
    schedule_id Int32,
    attend_dt Date,
    op String,
    cdc_ts DateTime,
    source_table String,
) ENGINE = Kafka
    SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'L1_datalake_course_attendance',
    kafka_group_name = 'clickhouse_group_attendance',
    kafka_format = 'JSONEachRow',
    kafka_skip_broken_messages = 1;


-- PART C: Create Materialized Views (Link Kafka to Final Tables in 'L1_datalake')

CREATE MATERIALIZED VIEW IF NOT EXISTS kafka.mv_course TO L1_datalake.course AS
SELECT id, name, op, cdc_ts, source_table, now() as event_time FROM kafka.course;

CREATE MATERIALIZED VIEW IF NOT EXISTS kafka.mv_schedule TO L1_datalake.schedule AS
SELECT id, course_id, lecturer_id, start_dt, end_dt, course_days, op, cdc_ts, source_table, now() as inserted_at FROM kafka.schedule;

CREATE MATERIALIZED VIEW IF NOT EXISTS kafka.mv_enrollment TO L1_datalake.enrollment AS
SELECT id, student_id, schedule_id, academic_year, semester, enroll_dt, op, cdc_ts, source_table, now() as inserted_at FROM kafka.enrollment;

CREATE MATERIALIZED VIEW IF NOT EXISTS kafka.mv_course_attendance TO L1_datalake.course_attendance AS
SELECT id, student_id, schedule_id, attend_dt, op, cdc_ts, source_table, now() as inserted_at FROM kafka.course_attendance;

-- PART D: Create Data Warehouse Schema and Target Report Table

CREATE DATABASE IF NOT EXISTS data_warehouse;

CREATE TABLE IF NOT EXISTS data_warehouse.report (
    semester_id String,       -- e.g., '2019/2020_S1'
    week_id UInt8,            -- Week number (1-53)
    course_name String,
    attendance Float64,   -- Percentage (0-100)
    calculation_time DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(calculation_time) -- Keep the latest calculation for a given key
ORDER BY (semester_id, week_id, course_name); -- Primary key for ReplacingMergeTree

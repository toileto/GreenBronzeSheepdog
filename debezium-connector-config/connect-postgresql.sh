curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" \
http://localhost:8083/connectors/ -d '{
  "name": "school-pg-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres-source",
    "database.port": "5432",
    "database.user": "user",
    "database.password": "password",
    "database.dbname": "source",
    "database.server.name": "pgsch1",
    "schema.include.list": "school_data",
    "table.include.list": "school_data.schedule,school_data.course_attendance,school_data.enrollment,school_data.course",
    "plugin.name": "pgoutput",
    "publication.autocreate.mode": "filtered",
    "slot.name": "debezium_connect_slot",
    "publication.name": "debezium_connect_pub",
    "topic.prefix": "pgsch1_raw",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "route",
    "transforms.route.type": "io.debezium.transforms.ByLogicalTableRouter",
    "transforms.route.topic.regex": "(.*).school_data.(.*)",
    "transforms.route.topic.replacement": "$2",
    "topic.creation.enable": "true",
    "topic.creation.default.replication.factor": 1,
    "topic.creation.default.partitions": 5,
    "snapshot.mode": "initial"
  }
}'

#docker exec -it kafka kafka-console-consumer \
#    --bootstrap-server kafka:9092 \
#    --topic cdc_source_combined \
#    --from-beginning

#docker exec -it kafka kafka-console-consumer \
#    --bootstrap-server kafka:9092 \
#    --topic L1_datalake_course \
#    --from-beginning

#docker exec -it kafka kafka-console-consumer \
#    --bootstrap-server kafka:9092 \
#    --topic L1_datalake_schedule \
#    --from-beginning

#docker exec -it kafka kafka-console-consumer \
#    --bootstrap-server kafka:9092 \
#    --topic schedule \
#    --from-beginning

#{"id": 5, "course_id": 2, "lecturer_id": 56, "start_dt": 18288, "end_dt": 18378, "course_days": "2,4", "op": "c", "cdc_ts": 1744481523700, "source_table": "schedule"}

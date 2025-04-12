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
    "table.include.list": "school_data.course,school_data.enrollment,school_data.schedule,school_data.course_attendance",
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
    "transforms.route.topic.regex": "(.*)",
    "transforms.route.topic.replacement": "cdc_source_combined"
  }
}'

#docker exec -it kafka kafka-console-consumer \
#    --bootstrap-server kafka:9092 \
#    --topic cdc_source_combined \
#    --from-beginning
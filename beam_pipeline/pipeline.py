import json
import argparse
from typing import Dict, Any

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.io.kafka import ReadFromKafka, WriteToKafka

class ParseAndPrint(beam.DoFn):
    def process(self, record):
        try:
            # Parse the Kafka message value (assuming it's a JSON string)
            parsed_record = dict()
            for item in record:
                decoded_item = item.decode('utf-8')
                item_dict = json.loads(decoded_item)

                #  Combine dictionaries, handling potential key conflicts.
                parsed_record.update(item_dict)


            data = dict()
            data = parsed_record['after']
            data['op'] = parsed_record['op']
            data['cdc_ts'] = parsed_record['ts_ms']
            data['source_table'] = parsed_record['source']['table']

            yield data

        except json.JSONDecodeError as e:
            print(f"Error parsing record: {e}")
            print(f"Raw record: {record}")
            yield {"error": str(e), "raw_record": record}

def run(bootstrap_servers, topic, pipeline_args=None):
    pipeline_options = PipelineOptions(pipeline_args, streaming=True)
    # pipeline_options = PipelineOptions(pipeline_args)

    with beam.Pipeline(options=pipeline_options) as pipeline:
        parsed_records = (
            pipeline
                | 'Read from Kafka' >> ReadFromKafka(
                        consumer_config={
                            'bootstrap.servers': bootstrap_servers,
                            'auto.offset.reset': 'earliest',
                            'group.id': 'agriaku',
                            'enable.auto.commit': 'true'
                        },
                        topics=[topic],
                        with_metadata=False,
                        max_num_records=5
                    )
                | 'Parse Message' >> beam.ParDo(ParseAndPrint())
        )

        process_records = (
            parsed_records
            | "EnforceBytes" >> beam.Map(lambda record: (
                record['source_table'].encode('utf-8'),
                json.dumps(record).encode('utf-8')
                )
            ).with_output_types(tuple[bytes, bytes])
            | "WriteToKafka" >> WriteToKafka(
                producer_config={
                    'bootstrap.servers': bootstrap_servers,
                    'group.id': 'agriaku'
                },
                topic="L1_datalake_schedule"
            )
        )

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--bootstrap_servers',
        default='localhost:29092',
        help='Kafka bootstrap servers'
    )
    parser.add_argument(
        '--topic',
        default='schedule',
        help='Kafka topic to read from'
    )

    known_args, pipeline_args = parser.parse_known_args()

    print(f"Starting Beam pipeline to read from Kafka topic: {known_args.topic}")
    print(f"Connecting to Kafka at: {known_args.bootstrap_servers}")
    print("Press Ctrl+C to stop the pipeline")

    run(
        bootstrap_servers=known_args.bootstrap_servers,
        topic=known_args.topic,
        pipeline_args=pipeline_args
    )
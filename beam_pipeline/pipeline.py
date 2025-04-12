import json
import argparse
from typing import Dict, Any

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.io.kafka import ReadFromKafka

class ParseAndPrint(beam.DoFn):
    def process(self, record):
        try:
            # Parse the Kafka message value (assuming it's a JSON string)
            parsed_record = dict()
            for item in record:
                decoded_item = item.decode('utf-8')
                item_dict = json.loads(decoded_item)

                #  Combine dictionaries, handling potential key conflicts.
                #  If a key exists in both, the value from the *second*
                #  dictionary (item_dict) will overwrite the value from the first.
                parsed_record.update(item_dict)

            # parsed_record = json.loads(record.decode('utf-8'))

            # Extract relevant information
            operation = parsed_record.get('op')
            table = parsed_record.get('source', {}).get('table')

            if operation == 'c':
                op_type = "INSERT"
            elif operation == 'u':
                op_type = "UPDATE"
            elif operation == 'd':
                op_type = "DELETE"
            else:
                op_type = f"UNKNOWN ({operation})"

            # # Print the record with some basic information
            # print(f"\n=== {op_type} on {table} ===")
            # print(f"Before: {parsed_record.get('before')}")
            # print(f"After: {parsed_record.get('after')}")
            # print(f"Source: {parsed_record.get('source')}")
            # print(f"Transaction: {parsed_record.get('transaction')}")
            # print("===========================\n")

            yield parsed_record

        except json.JSONDecodeError as e:
            print(f"Error parsing record: {e}")
            print(f"Raw record: {record}")
            yield {"error": str(e), "raw_record": record}

def run(bootstrap_servers, topic, pipeline_args=None):
    # pipeline_options = PipelineOptions(pipeline_args, streaming=True)
    pipeline_options = PipelineOptions(pipeline_args)

    with beam.Pipeline(options=pipeline_options) as pipeline:
        (
            pipeline
                | 'Read from Kafka' >> ReadFromKafka(
                        consumer_config={
                            'bootstrap.servers': bootstrap_servers,
                            'auto.offset.reset': 'earliest'
                        },
                        topics=[topic],
                        with_metadata=False,
                        max_num_records=5
                    )
                | 'Parse Message' >> beam.ParDo(ParseAndPrint())
                | 'Print' >> beam.Map(print)
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
        default='cdc_source_combined',
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
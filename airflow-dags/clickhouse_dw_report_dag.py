# ./airflow-dags/clickhouse_dw_report_dag.py
from __future__ import annotations
import pendulum
from airflow.models.dag import DAG
from airflow.operators.python import PythonOperator

CLICKHOUSE_TRANSFORM_SQL = """
CREATE SCHEMA IF NOT EXISTS data_warehouse;
CREATE TABLE IF NOT EXISTS data_warehouse.report ( SEMESTER_ID String, WEEK_ID UInt8, COURSE_NAME String, ATTENDANCE_PCT Float64, calculation_time DateTime DEFAULT now() ) ENGINE = ReplacingMergeTree(calculation_time) ORDER BY (SEMESTER_ID, WEEK_ID, COURSE_NAME);
WITH EnrolledPerSchedule AS ( SELECT schedule_id, concat(academic_year, '_S', toString(semester)) AS semester_id, count(DISTINCT student_id) AS enrolled_count FROM L1_datalake.enrollment FINAL WHERE __op != 'd' GROUP BY schedule_id, semester_id ), AttendedPerScheduleWeek AS ( SELECT ca.schedule_id, concat(e.academic_year, '_S', toString(e.semester)) AS semester_id, toWeek(ca.attend_dt) AS week_id, count(DISTINCT ca.student_id) AS attended_count FROM L1_datalake.course_attendance AS ca JOIN L1_datalake.enrollment FINAL AS e ON ca.student_id = e.student_id AND ca.schedule_id = e.schedule_id WHERE e.__op != 'd' GROUP BY ca.schedule_id, semester_id, week_id ) INSERT INTO data_warehouse.report (SEMESTER_ID, WEEK_ID, COURSE_NAME, ATTENDANCE_PCT) SELECT COALESCE(A.semester_id, E.semester_id) AS SEMESTER_ID, A.week_id AS WEEK_ID, crs.name AS COURSE_NAME, if(sum(E.enrolled_count) = 0, 0, sum(A.attended_count) / sum(E.enrolled_count) * 100) AS ATTENDANCE_PCT FROM AttendedPerScheduleWeek AS A FULL OUTER JOIN EnrolledPerSchedule AS E ON A.schedule_id = E.schedule_id AND A.semester_id = E.semester_id JOIN L1_datalake.schedule FINAL AS sch ON COALESCE(A.schedule_id, E.schedule_id) = sch.id JOIN L1_datalake.course FINAL AS crs ON sch.course_id = crs.id WHERE sch.__op != 'd' AND crs.__op != 'd' GROUP BY SEMESTER_ID, WEEK_ID, COURSE_NAME;
"""


def run_clickhouse_dw_transformation(**context):
    try:
        import importlib;
        importlib.import_module('clickhouse_driver')
    except ImportError:
        import subprocess; print("Installing clickhouse-driver..."); subprocess.check_call(
            ['pip', 'install', 'clickhouse-driver'])
    finally:
        from clickhouse_driver import Client
    client = Client(host='clickhouse', user='user', password='password', database='L1_datalake')
    print("Connected to ClickHouse. Executing DW Transformation SQL...");
    client.execute(CLICKHOUSE_TRANSFORM_SQL);
    print("Transformation SQL executed.")


with DAG(dag_id='clickhouse_data_warehouse_report_builder', start_date=pendulum.datetime(2024, 1, 1, tz="UTC"),
         schedule='@daily', catchup=False, tags=['clickhouse', 'datawarehouse', 'report', 'school'],
         doc_md="Builds weekly attendance report in `data_warehouse.report`.", ) as dag: build_report_task = PythonOperator(
    task_id='build_weekly_attendance_report', python_callable=run_clickhouse_dw_transformation, )

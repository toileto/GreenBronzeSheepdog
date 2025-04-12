-- ./postgres-init-scripts/init.sql

CREATE SCHEMA IF NOT EXISTS school_data;
ALTER SCHEMA school_data OWNER TO "user";

CREATE TABLE school_data.course ( id SERIAL PRIMARY KEY, name VARCHAR(255) );
ALTER TABLE school_data.course REPLICA IDENTITY FULL;
ALTER TABLE school_data.course OWNER TO "user";

CREATE TABLE school_data.schedule ( id SERIAL PRIMARY KEY, course_id INT, lecturer_id INT, start_dt DATE, end_dt DATE, course_days VARCHAR(50) );
ALTER TABLE school_data.schedule REPLICA IDENTITY FULL;
ALTER TABLE school_data.schedule OWNER TO "user";

CREATE TABLE school_data.enrollment ( id SERIAL PRIMARY KEY, student_id INT, schedule_id INT, academic_year VARCHAR(10), semester INT, enroll_dt DATE );
ALTER TABLE school_data.enrollment REPLICA IDENTITY FULL;
ALTER TABLE school_data.enrollment OWNER TO "user";

CREATE TABLE school_data.course_attendance ( id SERIAL PRIMARY KEY, student_id INT, schedule_id INT, attend_dt DATE );
ALTER TABLE school_data.course_attendance REPLICA IDENTITY FULL;
ALTER TABLE school_data.course_attendance OWNER TO "user";

GRANT USAGE ON SCHEMA school_data TO "user";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA school_data TO "user";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA school_data TO "user";
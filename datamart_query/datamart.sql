

WITH schedule_and_course AS (
	SELECT
		schedule.* EXCEPT(COURSE_DAYS,ID),
		schedule.ID AS SCHEDULE_ID,
		arrayJoin(splitByChar(',', schedule.COURSE_DAYS)) AS COURSE_DAYS,
		course.NAME
	FROM
		challenge.schedule

		LEFT JOIN challenge.course
		ON schedule.COURSE_ID = course.ID
),

course_data AS (
	SELECT
		schedule_and_course.*,
		enrollment_data.* EXCEPT(SCHEDULE_ID)
	FROM
		schedule_and_course

		LEFT JOIN (
			SELECT
				SEMESTER AS SEMESTER_ID,
				SCHEDULE_ID,
				COUNT(DISTINCT STUDENT_ID) AS TOTAL_STUDENT
			FROM
				challenge.enrollment
			GROUP BY 1, 2
		) enrollment_data
		ON enrollment_data.SCHEDULE_ID = schedule_and_course.SCHEDULE_ID
),

calculate_attendance AS (
	SELECT
		ATTEND_DT,
		SCHEDULE_ID,
		COUNT(DISTINCT STUDENT_ID) AS STUDENT_ATTENDING
	FROM
		challenge.course_attendance
	GROUP BY
		ATTEND_DT,
		SCHEDULE_ID
),

detailed_attendance AS (
	-- This is good enough for a fact table (e.g. fact_attendance)
	SELECT
		DISTINCT
		calculate_attendance.*,
		course_data.NAME,
		course_data.SEMESTER_ID,
		course_data.TOTAL_STUDENT
	FROM calculate_attendance

		LEFT JOIN course_data
		ON course_data.SCHEDULE_ID = calculate_attendance.SCHEDULE_ID
		AND calculate_attendance.ATTEND_DT BETWEEN course_data.START_DT AND course_data.END_DT
),

get_study_week AS (
	SELECT DISTINCT
		SCHEDULE_ID,
		ATTEND_DT,
		toStartOfMonth(ATTEND_DT) AS truncated_date,
		toWeek(ATTEND_DT) AS iso_week
	FROM
		detailed_attendance
)

, get_dense_rank_of_week AS (
	SELECT
		*,
		DENSE_RANK() OVER(PARTITION BY SCHEDULE_ID ORDER BY truncated_date, iso_week) AS WEEK_NUMBER
	FROM get_study_week
	ORDER BY 1, 2, 3
),

final_data AS (
	SELECT
		detailed_attendance.*,
		get_dense_rank_of_week.WEEK_NUMBER
	FROM detailed_attendance

		LEFT JOIN get_dense_rank_of_week
		ON detailed_attendance.SCHEDULE_ID = get_dense_rank_of_week.SCHEDULE_ID
		AND detailed_attendance.ATTEND_DT = get_dense_rank_of_week.ATTEND_DT
)

SELECT
	SEMESTER_ID AS SEMESTER,
	WEEK_NUMBER AS WEEK_ID,
	NAME AS COURSE_NAME,
	100 * SUM(STUDENT_ATTENDING) / SUM(TOTAL_STUDENT) AS ATTENDANCE_PERCENTAGE
FROM
	final_data
GROUP BY
	SEMESTER,
	WEEK_ID,
	COURSE_NAME
ORDER BY
	SEMESTER,
	COURSE_NAME,
	WEEK_ID;

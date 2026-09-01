-- 000001_init の巻き戻し。
-- REPOSITORIES.md §4.3 のとおり down を必ず書き、CI で up → down → up を検証する。

BEGIN;

DROP VIEW IF EXISTS available_task_option;

DROP TABLE IF EXISTS review_queue;
DROP TABLE IF EXISTS srs_state;
DROP TABLE IF EXISTS user_type_stat;
DROP TABLE IF EXISTS daily_task;
DROP TABLE IF EXISTS user_task;
DROP TABLE IF EXISTS attempt;
DROP TABLE IF EXISTS user_progress;
DROP TABLE IF EXISTS app_user;
DROP TABLE IF EXISTS question;
DROP TABLE IF EXISTS skill_node_prerequisite;
DROP TABLE IF EXISTS skill_node;
DROP TABLE IF EXISTS skill;
DROP TABLE IF EXISTS raw_source;

DROP TYPE IF EXISTS review_decision;
DROP TYPE IF EXISTS question_status;
DROP TYPE IF EXISTS question_type;

COMMIT;

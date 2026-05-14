-- ============================================================
-- Создание ролей СУБД (PostgreSQL)
-- ============================================================

-- Роль для пациентов (базовый доступ)
CREATE ROLE app_reader NOLOGIN;

-- Роль для врачей (операционный доступ)
CREATE ROLE app_operator NOLOGIN;

-- Роль для администраторов (полный доступ)
CREATE ROLE app_admin NOLOGIN;

-- ============================================================
-- Настройка привилегий
-- ============================================================

-- 1. Привилегии app_reader (Пациент)
-- Подключение к БД
GRANT CONNECT ON DATABASE patientgate_db TO app_reader;
-- Доступ к схеме public
GRANT USAGE ON SCHEMA public TO app_reader;

-- Чтение справочников
GRANT SELECT ON services TO app_reader;
GRANT SELECT ON doctors TO app_reader;

GRANT SELECT ON appointments TO app_reader;
GRANT SELECT ON patients TO app_reader;

-- Право на выполнение процедуры записи
GRANT EXECUTE ON PROCEDURE sp_book_appointment(INTEGER, INTEGER, INTEGER, TIMESTAMP) TO app_reader;


-- 2. Привилегии app_operator (Врач)
GRANT CONNECT ON DATABASE patientgate_db TO app_operator;
GRANT USAGE ON SCHEMA public TO app_operator;

-- Чтение всех данных
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_operator;

-- Обновление статусов записей и внесение мед. данных
GRANT UPDATE (status) ON appointments TO app_operator;
GRANT INSERT, SELECT ON medical_records TO app_operator;

-- Право на выполнение процедур завершения и отмены
GRANT EXECUTE ON PROCEDURE sp_complete_appointment(INTEGER, TEXT, TEXT) TO app_operator;
GRANT EXECUTE ON PROCEDURE sp_cancel_appointment(INTEGER) TO app_operator;


-- 3. Привилегии app_admin (Администратор)
GRANT CONNECT ON DATABASE patientgate_db TO app_admin;
GRANT USAGE ON SCHEMA public TO app_admin;

-- Полные права на все текущие таблицы
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_admin;
-- Полные права на последовательности (для SERIAL полей)
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_admin;
-- Право выполнять любые процедуры
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_admin;

-- Настройка прав по умолчанию для новых таблиц (чтобы админу не выдавать права вручную каждый раз)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_admin;


-- ============================================================
-- Создание пользователей БД и назначение ролей
-- ============================================================

-- 1. Пользователь-пациент (пример)
CREATE USER db_patient WITH PASSWORD 'patient_pass';
GRANT app_reader TO db_patient;

-- 2. Пользователь-врач (пример)
CREATE USER db_doctor WITH PASSWORD 'doctor_pass';
GRANT app_operator TO db_doctor;

-- 3. Пользователь-админ
CREATE USER db_admin WITH PASSWORD 'admin_pass';
GRANT app_admin TO db_admin;

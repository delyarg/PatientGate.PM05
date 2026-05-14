CREATE OR REPLACE PROCEDURE sp_book_appointment(
    IN p_patient_id INT,
    IN p_doctor_id INT,
    IN p_service_id INT,
    IN p_start_time TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_duration INT;
    v_end_time TIMESTAMP;
    v_conflict INT;
BEGIN
    -- Получаем длительность услуги
    SELECT duration_minutes INTO v_duration FROM services WHERE id = p_service_id;
    
    IF v_duration IS NULL THEN
        RAISE EXCEPTION 'Услуга не найдена';
    END IF;

    -- Вычисляем время окончания
    v_end_time := p_start_time + (v_duration || ' minutes')::INTERVAL;

    -- Проверка на пересечение с существующими записями (статусы pending или confirmed)
    SELECT COUNT(*) INTO v_conflict
    FROM appointments
    WHERE doctor_id = p_doctor_id
      AND status IN ('pending', 'confirmed')
      AND (start_time, end_time) OVERLAPS (p_start_time, v_end_time);

    IF v_conflict > 0 THEN
        RAISE EXCEPTION 'Время занято другим пациентом';
    END IF;

    -- Вставка записи
    INSERT INTO appointments (patient_id, doctor_id, service_id, start_time, end_time, status)
    VALUES (p_patient_id, p_doctor_id, p_service_id, p_start_time, v_end_time, 'pending');
END;
$$;

CREATE OR REPLACE PROCEDURE sp_complete_appointment(
    IN p_appointment_id INT,
    IN p_diagnosis TEXT,
    IN p_recommendations TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Обновление статуса приема
    UPDATE appointments
    SET status = 'completed'
    WHERE id = p_appointment_id AND status != 'completed';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Прием не найден или уже завершен';
    END IF;

    -- Создание медицинской карты
    INSERT INTO medical_records (appointment_id, diagnosis, recommendations)
    VALUES (p_appointment_id, p_diagnosis, p_recommendations);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_cancel_appointment(
    IN p_appointment_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_status VARCHAR(20);
BEGIN
    SELECT start_time, status INTO v_start_time, v_status
    FROM appointments
    WHERE id = p_appointment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Запись не найдена';
    END IF;

    IF v_status = 'completed' THEN
        RAISE EXCEPTION 'Нельзя отменить завершенный прием';
    END IF;

    IF v_start_time < NOW() + INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'Отмена возможна не позднее чем за 24 часа до приема';
    END IF;

    UPDATE appointments
    SET status = 'cancelled'
    WHERE id = p_appointment_id;
END;
$$;
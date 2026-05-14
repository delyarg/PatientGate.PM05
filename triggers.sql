CREATE OR REPLACE FUNCTION fn_log_price_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.price IS DISTINCT FROM NEW.price THEN
        INSERT INTO service_price_history (service_id, old_price, new_price)
        VALUES (NEW.id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_price_change
AFTER UPDATE ON services
FOR EACH ROW
EXECUTE FUNCTION fn_log_price_change();

CREATE OR REPLACE FUNCTION fn_set_appointment_end_time()
RETURNS TRIGGER AS $$
DECLARE
    v_duration INT;
BEGIN
    -- Получаем длительность услуги
    SELECT duration_minutes INTO v_duration
    FROM services
    WHERE id = NEW.service_id;

    IF v_duration IS NULL THEN
        RAISE EXCEPTION 'Некорректный ID услуги';
    END IF;

    -- Устанавливаем время окончания
    NEW.end_time := NEW.start_time + (v_duration || ' minutes')::INTERVAL;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_appointment_time
BEFORE INSERT OR UPDATE OF start_time, service_id ON appointments
FOR EACH ROW
EXECUTE FUNCTION fn_set_appointment_end_time();
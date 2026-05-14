-- Пользователи (родительская таблица)
INSERT INTO users (login, password_hash, role) VALUES
    ('ivanov_p', '$2b$12$LJ3m4ys3...', 'patient'),
    ('petrova_m', '$2b$12$LJ3m4ys3...', 'patient'),
    ('smirnov_a', '$2b$12$LJ3m4ys3...', 'doctor'),
    ('kozlova_e', '$2b$12$LJ3m4ys3...', 'doctor'),
    ('admin_main', '$2b$12$LJ3m4ys3...', 'admin');

-- Пациенты
INSERT INTO patients (user_id, first_name, last_name, phone, email, birth_date, address) VALUES
    (1, 'Иван', 'Иванов', '+79001112233', 'ivanov@mail.ru', '1985-05-12', 'г. Москва, ул. Ленина, д. 1'),
    (2, 'Мария', 'Петрова', '+79004445566', 'petrova@mail.ru', '1990-08-20', 'г. Москва, ул. Пушкина, д. 5');

-- Врачи
INSERT INTO doctors (user_id, first_name, last_name, specialization, cabinet_number, bio) VALUES
    (3, 'Алексей', 'Смирнов', 'Терапевт', '101', 'Врач высшей категории, стаж 15 лет'),
    (4, 'Елена', 'Козлова', 'Кардиолог', '205', 'Специалист по функциональной диагностике');

-- Услуги
INSERT INTO services (name, price, duration_minutes, description) VALUES
    ('Первичный прием терапевта', 1500.00, 30, 'Консультация, осмотр, назначение анализов'),
    ('ЭКГ с расшифровкой', 800.00, 15, 'Снятие электрокардиограммы и описание'),
    ('Повторный прием кардиолога', 1200.00, 20, 'Коррекция лечения по результатам анализов');

-- Записи на прием
INSERT INTO appointments (patient_id, doctor_id, service_id, start_time, end_time, status, notes) VALUES
    (1, 1, 1, '2026-05-15 10:00:00', '2026-05-15 10:30:00', 'confirmed', 'Жалобы на головную боль'),
    (2, 2, 2, '2026-05-15 11:00:00', '2026-05-15 11:15:00', 'completed', 'Плановое обследование'),
    (1, 2, 3, '2026-05-16 14:00:00', '2026-05-16 14:20:00', 'pending', NULL);

-- Медицинские записи
INSERT INTO medical_records (appointment_id, diagnosis, treatment_plan, recommendations) VALUES
    (2, 'Синусовая аритмия', 'Прием магния B6, контроль ЭКГ через месяц', 'Исключить кофеин, соблюдать режим сна');
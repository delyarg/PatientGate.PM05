--
-- PostgreSQL database dump
--

\restrict udMhRiHwN4MOT6scww03Wn1JwALmPvCKzRel7lP3NhX2ZTDZT2ZlJtS3UdcyX4i

-- Dumped from database version 15.17 (Debian 15.17-1.pgdg13+1)
-- Dumped by pg_dump version 15.17 (Debian 15.17-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fn_log_price_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_log_price_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.price IS DISTINCT FROM NEW.price THEN
        INSERT INTO service_price_history (service_id, old_price, new_price)
        VALUES (NEW.id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_log_price_change() OWNER TO postgres;

--
-- Name: fn_set_appointment_end_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_set_appointment_end_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.fn_set_appointment_end_time() OWNER TO postgres;

--
-- Name: sp_book_appointment(integer, integer, integer, timestamp without time zone); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_book_appointment(IN p_patient_id integer, IN p_doctor_id integer, IN p_service_id integer, IN p_start_time timestamp without time zone)
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


ALTER PROCEDURE public.sp_book_appointment(IN p_patient_id integer, IN p_doctor_id integer, IN p_service_id integer, IN p_start_time timestamp without time zone) OWNER TO postgres;

--
-- Name: sp_cancel_appointment(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_cancel_appointment(IN p_appointment_id integer)
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


ALTER PROCEDURE public.sp_cancel_appointment(IN p_appointment_id integer) OWNER TO postgres;

--
-- Name: sp_complete_appointment(integer, text, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_complete_appointment(IN p_appointment_id integer, IN p_diagnosis text, IN p_recommendations text)
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


ALTER PROCEDURE public.sp_complete_appointment(IN p_appointment_id integer, IN p_diagnosis text, IN p_recommendations text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: appointments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments (
    id integer NOT NULL,
    patient_id integer NOT NULL,
    doctor_id integer NOT NULL,
    service_id integer NOT NULL,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT appointments_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'confirmed'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT valid_time_range CHECK ((end_time > start_time))
);


ALTER TABLE public.appointments OWNER TO postgres;

--
-- Name: appointments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.appointments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.appointments_id_seq OWNER TO postgres;

--
-- Name: appointments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.appointments_id_seq OWNED BY public.appointments.id;


--
-- Name: doctors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doctors (
    id integer NOT NULL,
    user_id integer NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    specialization character varying(100) NOT NULL,
    cabinet_number character varying(10),
    bio text
);


ALTER TABLE public.doctors OWNER TO postgres;

--
-- Name: doctors_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.doctors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.doctors_id_seq OWNER TO postgres;

--
-- Name: doctors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.doctors_id_seq OWNED BY public.doctors.id;


--
-- Name: medical_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medical_records (
    id integer NOT NULL,
    appointment_id integer NOT NULL,
    diagnosis text,
    treatment_plan text,
    recommendations text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.medical_records OWNER TO postgres;

--
-- Name: medical_records_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.medical_records_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.medical_records_id_seq OWNER TO postgres;

--
-- Name: medical_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.medical_records_id_seq OWNED BY public.medical_records.id;


--
-- Name: patients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patients (
    id integer NOT NULL,
    user_id integer NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    phone character varying(20) NOT NULL,
    email character varying(100),
    birth_date date,
    address text
);


ALTER TABLE public.patients OWNER TO postgres;

--
-- Name: patients_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.patients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.patients_id_seq OWNER TO postgres;

--
-- Name: patients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.patients_id_seq OWNED BY public.patients.id;


--
-- Name: service_price_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_price_history (
    id integer NOT NULL,
    service_id integer NOT NULL,
    old_price numeric(10,2),
    new_price numeric(10,2),
    changed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.service_price_history OWNER TO postgres;

--
-- Name: service_price_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_price_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_price_history_id_seq OWNER TO postgres;

--
-- Name: service_price_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_price_history_id_seq OWNED BY public.service_price_history.id;


--
-- Name: services; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services (
    id integer NOT NULL,
    name character varying(150) NOT NULL,
    price numeric(10,2) NOT NULL,
    duration_minutes integer NOT NULL,
    description text,
    CONSTRAINT services_duration_minutes_check CHECK ((duration_minutes > 0)),
    CONSTRAINT services_price_check CHECK ((price >= (0)::numeric))
);


ALTER TABLE public.services OWNER TO postgres;

--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.services_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.services_id_seq OWNER TO postgres;

--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.services_id_seq OWNED BY public.services.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    login character varying(50) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(20) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    password_salt character varying(32) NOT NULL,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['patient'::character varying, 'doctor'::character varying, 'admin'::character varying])::text[])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_appointments_full; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_appointments_full AS
 SELECT a.id AS appointment_id,
    (((p.first_name)::text || ' '::text) || (p.last_name)::text) AS patient_name,
    (((d.first_name)::text || ' '::text) || (d.last_name)::text) AS doctor_name,
    d.specialization,
    s.name AS service_name,
    s.price,
    a.start_time,
    a.end_time,
    a.status,
    a.notes
   FROM (((public.appointments a
     JOIN public.patients p ON ((a.patient_id = p.id)))
     JOIN public.doctors d ON ((a.doctor_id = d.id)))
     JOIN public.services s ON ((a.service_id = s.id)));


ALTER TABLE public.v_appointments_full OWNER TO postgres;

--
-- Name: v_doctor_stats; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_doctor_stats AS
 SELECT d.id AS doctor_id,
    (((d.first_name)::text || ' '::text) || (d.last_name)::text) AS doctor_name,
    d.specialization,
    count(a.id) AS total_appointments,
    COALESCE(sum(s.price), (0)::numeric) AS total_revenue
   FROM ((public.doctors d
     LEFT JOIN public.appointments a ON (((d.id = a.doctor_id) AND ((a.status)::text = 'completed'::text))))
     LEFT JOIN public.services s ON ((a.service_id = s.id)))
  GROUP BY d.id, d.first_name, d.last_name, d.specialization;


ALTER TABLE public.v_doctor_stats OWNER TO postgres;

--
-- Name: appointments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments ALTER COLUMN id SET DEFAULT nextval('public.appointments_id_seq'::regclass);


--
-- Name: doctors id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors ALTER COLUMN id SET DEFAULT nextval('public.doctors_id_seq'::regclass);


--
-- Name: medical_records id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_records ALTER COLUMN id SET DEFAULT nextval('public.medical_records_id_seq'::regclass);


--
-- Name: patients id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients ALTER COLUMN id SET DEFAULT nextval('public.patients_id_seq'::regclass);


--
-- Name: service_price_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_price_history ALTER COLUMN id SET DEFAULT nextval('public.service_price_history_id_seq'::regclass);


--
-- Name: services id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services ALTER COLUMN id SET DEFAULT nextval('public.services_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointments (id, patient_id, doctor_id, service_id, start_time, end_time, status, notes, created_at) FROM stdin;
1	1	1	1	2026-05-15 10:00:00	2026-05-15 10:30:00	confirmed	Жалобы на головную боль	2026-05-14 14:10:01.43739
2	2	2	2	2026-05-15 11:00:00	2026-05-15 11:15:00	completed	Плановое обследование	2026-05-14 14:10:01.43739
3	1	2	3	2026-05-16 14:00:00	2026-05-16 14:20:00	completed	\N	2026-05-14 14:10:01.43739
5	1	1	2	2026-05-14 17:46:00	2026-05-14 18:01:00	pending	\N	2026-05-14 14:46:57.740143
4	1	1	1	2026-05-20 15:00:00	2026-05-20 15:30:00	cancelled	\N	2026-05-14 14:23:06.216902
\.


--
-- Data for Name: doctors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.doctors (id, user_id, first_name, last_name, specialization, cabinet_number, bio) FROM stdin;
1	3	Алексей	Смирнов	Терапевт	101	Врач высшей категории, стаж 15 лет
2	4	Елена	Козлова	Кардиолог	205	Специалист по функциональной диагностике
\.


--
-- Data for Name: medical_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.medical_records (id, appointment_id, diagnosis, treatment_plan, recommendations, created_at) FROM stdin;
1	2	Синусовая аритмия	Прием магния B6, контроль ЭКГ через месяц	Исключить кофеин, соблюдать режим сна	2026-05-14 14:10:01.43739
2	3	ОРВИ	\N	Обильное питье, постельный режим	2026-05-14 14:24:20.798934
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patients (id, user_id, first_name, last_name, phone, email, birth_date, address) FROM stdin;
1	1	Иван	Иванов	+79001112233	ivanov@mail.ru	1985-05-12	г. Москва, ул. Ленина, д. 1
2	2	Мария	Петрова	+79004445566	petrova@mail.ru	1990-08-20	г. Москва, ул. Пушкина, д. 5
3	6	Test	Test	+71231231212	example@example.com	\N	\N
\.


--
-- Data for Name: service_price_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_price_history (id, service_id, old_price, new_price, changed_at) FROM stdin;
1	1	1500.00	1800.00	2026-05-14 14:31:33.080452
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (id, name, price, duration_minutes, description) FROM stdin;
2	ЭКГ с расшифровкой	800.00	15	Снятие электрокардиограммы и описание
3	Повторный прием кардиолога	1200.00	20	Коррекция лечения по результатам анализов
1	Первичный прием терапевта	1800.00	30	Консультация, осмотр, назначение анализов
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, login, password_hash, role, created_at, password_salt) FROM stdin;
1	ivanov_p	$2b$12$LJ3m4ys3...	patient	2026-05-14 14:10:01.43739	aabbccdd11223344aabbccdd11223344
2	petrova_m	$2b$12$LJ3m4ys3...	patient	2026-05-14 14:10:01.43739	aabbccdd11223344aabbccdd11223344
3	smirnov_a	$2b$12$LJ3m4ys3...	doctor	2026-05-14 14:10:01.43739	aabbccdd11223344aabbccdd11223344
4	kozlova_e	$2b$12$LJ3m4ys3...	doctor	2026-05-14 14:10:01.43739	aabbccdd11223344aabbccdd11223344
5	admin_main	$2b$12$LJ3m4ys3...	admin	2026-05-14 14:10:01.43739	aabbccdd11223344aabbccdd11223344
6	Testuser	$2y$10$Q7.ivdQDqNsQqRNinCFg0uLyneEwoNjU1dneAnqDQ0CvJ7IK4EgZi	patient	2026-05-14 15:00:33.007907	4c74f01bbf7690f88e1ea1f78b3f995b
\.


--
-- Name: appointments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointments_id_seq', 5, true);


--
-- Name: doctors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.doctors_id_seq', 2, true);


--
-- Name: medical_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.medical_records_id_seq', 2, true);


--
-- Name: patients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.patients_id_seq', 3, true);


--
-- Name: service_price_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_price_history_id_seq', 1, true);


--
-- Name: services_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_id_seq', 3, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 6, true);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


--
-- Name: doctors doctors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_pkey PRIMARY KEY (id);


--
-- Name: doctors doctors_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_user_id_key UNIQUE (user_id);


--
-- Name: medical_records medical_records_appointment_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_records
    ADD CONSTRAINT medical_records_appointment_id_key UNIQUE (appointment_id);


--
-- Name: medical_records medical_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_records
    ADD CONSTRAINT medical_records_pkey PRIMARY KEY (id);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);


--
-- Name: patients patients_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_user_id_key UNIQUE (user_id);


--
-- Name: service_price_history service_price_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_price_history
    ADD CONSTRAINT service_price_history_pkey PRIMARY KEY (id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: users users_login_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_login_key UNIQUE (login);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_appointments_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_date ON public.appointments USING btree (start_time);


--
-- Name: idx_appointments_doctor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_doctor ON public.appointments USING btree (doctor_id);


--
-- Name: idx_appointments_patient; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_patient ON public.appointments USING btree (patient_id);


--
-- Name: services trg_log_price_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_log_price_change AFTER UPDATE ON public.services FOR EACH ROW EXECUTE FUNCTION public.fn_log_price_change();


--
-- Name: appointments trg_validate_appointment_time; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_appointment_time BEFORE INSERT OR UPDATE OF start_time, service_id ON public.appointments FOR EACH ROW EXECUTE FUNCTION public.fn_set_appointment_end_time();


--
-- Name: appointments appointments_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id) ON DELETE CASCADE;


--
-- Name: appointments appointments_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id) ON DELETE CASCADE;


--
-- Name: appointments appointments_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id) ON DELETE RESTRICT;


--
-- Name: doctors doctors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: medical_records medical_records_appointment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medical_records
    ADD CONSTRAINT medical_records_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointments(id) ON DELETE CASCADE;


--
-- Name: patients patients_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO app_reader;
GRANT USAGE ON SCHEMA public TO app_operator;
GRANT USAGE ON SCHEMA public TO app_admin;


--
-- Name: FUNCTION fn_log_price_change(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_log_price_change() TO app_admin;


--
-- Name: FUNCTION fn_set_appointment_end_time(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_set_appointment_end_time() TO app_admin;


--
-- Name: PROCEDURE sp_book_appointment(IN p_patient_id integer, IN p_doctor_id integer, IN p_service_id integer, IN p_start_time timestamp without time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_book_appointment(IN p_patient_id integer, IN p_doctor_id integer, IN p_service_id integer, IN p_start_time timestamp without time zone) TO app_reader;


--
-- Name: PROCEDURE sp_cancel_appointment(IN p_appointment_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_cancel_appointment(IN p_appointment_id integer) TO app_operator;


--
-- Name: PROCEDURE sp_complete_appointment(IN p_appointment_id integer, IN p_diagnosis text, IN p_recommendations text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_complete_appointment(IN p_appointment_id integer, IN p_diagnosis text, IN p_recommendations text) TO app_operator;


--
-- Name: TABLE appointments; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.appointments TO app_reader;
GRANT SELECT ON TABLE public.appointments TO app_operator;
GRANT ALL ON TABLE public.appointments TO app_admin;


--
-- Name: COLUMN appointments.status; Type: ACL; Schema: public; Owner: postgres
--

GRANT UPDATE(status) ON TABLE public.appointments TO app_operator;


--
-- Name: SEQUENCE appointments_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.appointments_id_seq TO app_admin;


--
-- Name: TABLE doctors; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.doctors TO app_reader;
GRANT SELECT ON TABLE public.doctors TO app_operator;
GRANT ALL ON TABLE public.doctors TO app_admin;


--
-- Name: SEQUENCE doctors_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.doctors_id_seq TO app_admin;


--
-- Name: TABLE medical_records; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE public.medical_records TO app_operator;
GRANT ALL ON TABLE public.medical_records TO app_admin;


--
-- Name: SEQUENCE medical_records_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.medical_records_id_seq TO app_admin;


--
-- Name: TABLE patients; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.patients TO app_reader;
GRANT SELECT ON TABLE public.patients TO app_operator;
GRANT ALL ON TABLE public.patients TO app_admin;


--
-- Name: SEQUENCE patients_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.patients_id_seq TO app_admin;


--
-- Name: TABLE service_price_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.service_price_history TO app_operator;
GRANT ALL ON TABLE public.service_price_history TO app_admin;


--
-- Name: SEQUENCE service_price_history_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.service_price_history_id_seq TO app_admin;


--
-- Name: TABLE services; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.services TO app_reader;
GRANT SELECT ON TABLE public.services TO app_operator;
GRANT ALL ON TABLE public.services TO app_admin;


--
-- Name: SEQUENCE services_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.services_id_seq TO app_admin;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.users TO app_operator;
GRANT ALL ON TABLE public.users TO app_admin;


--
-- Name: SEQUENCE users_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.users_id_seq TO app_admin;


--
-- Name: TABLE v_appointments_full; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_appointments_full TO app_operator;
GRANT ALL ON TABLE public.v_appointments_full TO app_admin;


--
-- Name: TABLE v_doctor_stats; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_doctor_stats TO app_operator;
GRANT ALL ON TABLE public.v_doctor_stats TO app_admin;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO app_admin;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO app_admin;


--
-- PostgreSQL database dump complete
--

\unrestrict udMhRiHwN4MOT6scww03Wn1JwALmPvCKzRel7lP3NhX2ZTDZT2ZlJtS3UdcyX4i


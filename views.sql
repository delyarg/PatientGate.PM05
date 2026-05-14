CREATE OR REPLACE VIEW v_appointments_full AS
SELECT
    a.id AS appointment_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    d.first_name || ' ' || d.last_name AS doctor_name,
    d.specialization,
    s.name AS service_name,
    s.price,
    a.start_time,
    a.end_time,
    a.status,
    a.notes
FROM appointments a
JOIN patients p ON a.patient_id = p.id
JOIN doctors d ON a.doctor_id = d.id
JOIN services s ON a.service_id = s.id;

CREATE OR REPLACE VIEW v_doctor_stats AS
SELECT
    d.id AS doctor_id,
    d.first_name || ' ' || d.last_name AS doctor_name,
    d.specialization,
    COUNT(a.id) AS total_appointments,
    COALESCE(SUM(s.price), 0) AS total_revenue
FROM doctors d
LEFT JOIN appointments a ON d.id = a.doctor_id AND a.status = 'completed'
LEFT JOIN services s ON a.service_id = s.id
GROUP BY d.id, d.first_name, d.last_name, d.specialization;
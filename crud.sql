INSERT INTO appointments (patient_id, doctor_id, service_id, start_time, status, notes)
VALUES (1, 1, 1, '2026-05-25 10:00:00', 'pending', 'Тестовая запись');

SELECT 
    a.id AS appointment_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    d.specialization AS doctor_spec,
    s.name AS service_name,
    a.start_time,
    a.status
FROM appointments a
JOIN patients p ON a.patient_id = p.id
JOIN doctors d ON a.doctor_id = d.id
JOIN services s ON a.service_id = s.id
WHERE a.status = 'pending'
ORDER BY a.start_time DESC;

UPDATE appointments
SET status = 'confirmed'
WHERE id = LASTVAL();

DELETE FROM appointments
WHERE id = LASTVAL() AND status = 'cancelled';

SELECT a.id, p.last_name, d.last_name
FROM appointments a
INNER JOIN patients p ON a.patient_id = p.id
INNER JOIN doctors d ON a.doctor_id = d.id;

SELECT p.last_name, a.id AS appointment_id
FROM patients p
LEFT JOIN appointments a ON p.id = a.patient_id;

SELECT s.name, COUNT(a.id) as order_count
FROM appointments a
RIGHT JOIN services s ON a.service_id = s.id
GROUP BY s.name;
-- 1. Комнаты с наибольшим количеством отмен
SELECT 
    r.room_name,
    COUNT(b.booking_id) as cancel_count
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
WHERE b.status_id = (SELECT status_id FROM booking_statuses WHERE status_name = 'canceled')
GROUP BY r.room_name
ORDER BY cancel_count DESC
LIMIT 5;

-- 2. Пересекающиеся бронирования (возможные конфликты)
SELECT 
    b1.booking_id as booking_1,
    b2.booking_id as booking_2,
    r.room_name,
    b1.start_time as start_1,
    b1.end_time as end_1,
    b2.start_time as start_2,
    b2.end_time as end_2
FROM bookings b1
JOIN bookings b2 ON b1.room_id = b2.room_id AND b1.booking_id < b2.booking_id
JOIN rooms r ON b1.room_id = r.room_id
WHERE b1.status_id = (SELECT status_id FROM booking_statuses WHERE status_name = 'booked')
AND b2.status_id = (SELECT status_id FROM booking_statuses WHERE status_name = 'booked')
AND (b1.start_time, b1.end_time) OVERLAPS (b2.start_time, b2.end_time);

-- 3. Пользователи с наибольшим числом действий
SELECT 
    u.username,
    COUNT(l.log_id) as action_count
FROM action_logs l
JOIN users u ON l.user_id = u.user_id
GROUP BY u.username
ORDER BY action_count DESC
LIMIT 5;

-- 4. Свободные комнаты в ближайшие 2 часа
SELECT 
    r.room_name,
    r.capacity,
    r.equipment
FROM rooms r
WHERE r.status_id = (SELECT status_id FROM room_statuses WHERE status_name = 'free')
AND NOT EXISTS (
    SELECT 1 
    FROM bookings b
    WHERE b.room_id = r.room_id
    AND b.status_id = (SELECT status_id FROM booking_statuses WHERE status_name = 'booked')
    AND (CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '2 hours') OVERLAPS (b.start_time, b.end_time)
);

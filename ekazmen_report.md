# Отчет по экзаминационной работе

## Архитектура базы данных
База данных спроектирована с учетом требований к целостности, производительности и безопасности

### **1. Таблицы и связи**
- **room_statuses:** Справочник статусов комнат (``` free ```, ```booked```, ```under_maintance```).
- **rooms:** Информация о переговорных комнатах (название, вместимость, оборудование, статус, дата создания).
- **tenants:** Данные об арендаторах (название компании, местоположение офиса)
- **roles:** Справочник ролей пользователей (``` user ```, ``` admin ```, ``` auditor ```).
- **users:** Пользователи системы (имя, связь с арендатором, роль).
- **booking_statuses:** Справочник статусов бронирований (``` booked ```, ``` canceled ```, ``` completed ```
- **bookings:** История бронирований (комната, арнедатор, пользователь, статус, время начала и окончания).
- **action_logs:** Логи операций (пользователь, тип действия, детали, временная метка ```TIMESTAMP```)

  ### Связи:
  - Внешние ключи обеспечивают целостность (пример: ```bookings.room_id``` -> ```rooms.room_id```).
  - Индексы (```idx_bookings_room_id```, ```idx_bookings_start_time```, ```idx_bookings_status_id```, ```idx_action_logs_user_id```) оптимизируют запросы

## 2. Роли и безопасность
Реализовано три роли:
- **sky_user:** Может бронировать комнаты и просматривать данные арендаторов, статусов и свои брони.
- **sky_admin:** Полный доступ ко всем таблицам и операциям.
- **sky_auditor:*** Доступ только для чтения к логам, бронированиям и связанными данным.

  Права доступа строго разграничены с использованием ```GRANT``` для соответствия функционалу ролей.

  ## 3. Представления

  - **active_bookings:** Показывает текущие бронирования со статусом ```booked``` и временем окончания после текущего момента.
  - **caneled_bookings:** Список отмененных или просроченных бронирований.
  - **bookings_by_company:** Статистика бронирований по компаниям (количество, статус, временные рамки).
 
  ## 4. Процедуры и триггеры
    - **Процедура ```book_room```:**
      - Проверяет доступность комнаты и отсутствие конфликтов по времени.
      - Создает запись в ```bookings```, обновляет статус комнаты на ```booked```.
      - Логирует действие в ```action_logs```.
     
      - **Триггер ```on_booking_cancel```:**
        - Срабатывает при обновлении статуса брони на ```canceled```.
        - Меняет статус комнаты на ```free``` и логирует отмену.
       
      - **Функция ```ger_room_booking_history:```
        - Возвращает историю бронирований для указанной комнтаы с соритировкой по времени.

  ## 5. Диагностика
  Диагностически запросы выявляют:
  - Команты с наибольшим числом отмен.
  - Пересекающиеся бронирования для обнаружения конфликтов.
  - Свободные комнаты в ближайшие 2 часа
       
  
      














# Код всей бд, а так-же ERD-диаграмма и результаты выполнения запросов
## Таблицы
table room_statuses
```sql
CREATE TABLE room_statuses (
status_id SERIAL PRIMARY KEY,
	status_name VARCHAR(50) NOT NULL UNIQUE
);
```

table rooms
```sql
CREATE TABLE rooms (
room_id SERIAL PRIMARY KEY,
	room_name VARCHAR(100) NOT NULL,
	capacity INT NOT NULL CHECK (capacity > 0),
	equipment TEXT,
	status_id INT NOT NULL REFERENCES room_statuses(status_id),
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

table tenants
```sql
CREATE TABLE tenants (
tenant_id SERIAL PRIMARY KEY,
	company_name VARCHAR(100) NOT NULL,
	office_location VARCHAR(100),
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

table roles
```sql
CREATE TABLE roles (
role_id SERIAL PRIMARY KEY,
	role_name VARCHAR(50) NOT NULL UNIQUE
);
```

table users
```sql
CREATE TABLE users (
user_id SERIAL PRIMARY KEY,
	username VARCHAR(50) NOT NULL UNIQUE,
	tenant_id INT REFERENCES tenants(tenant_id),
	role_id INT NOT NULL REFERENCES roles(role_id),
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```
table booking_statuses
```sql
CREATE TABLE booking_statuses (
status_id SERIAL PRIMARY KEY,
	status_name VARCHAR(50) NOT NULL UNIQUE
);
```
table bookings
```sql
CREATE TABLE bookings (
booking_id SERIAL PRIMARY KEY,
	room_id INT NOT NULL REFERENCES rooms(room_id),
	tenant_id INT NOT NULL REFERENCES tenants(tenant_id),
	user_id INT NOT NULL REFERENCES users(user_id),
	status_id INT NOT NULL REFERENCES booking_statuses(status_id),
	start_time TIMESTAMP NOT NULL,
	end_time TIMESTAMP NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	CHECK (end_time > start_time)
);
```

table action_logs
```sql
CREATE TABLE action_logs (
log_id SERIAL PRIMARY KEY,
	user_id INT REFERENCES users(user_id),
	action_type VARCHAR(50) NOT NULL,
	application_details TEXT,
	action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Индексы
```sql
CREATE INDEX idx_bookings_room_id ON bookings(room_id);

CREATE INDEX idx_bookings_start_time ON bookings(start_time);

CREATE INDEX idx_bookings_status_id ON bookings(status_id);

CREATE INDEX idx_action_logs_user_id ON action_logs(user_id);
```

## Тест дата
```sql
INSERT INTO room_statuses (status_name)
VALUES ('free'), ('booked'), ('under_maintance');

INSERT INTO booking_statuses(status_name)
VALUES ('booked'), ('canceled'), ('completed');

INSERT INTO roles(role_name) 
VALUES ('user'), ('admin'), ('auditor');
```

## Создание пользователей и назначение прав

```sql
CREATE ROLE sky_user;
CREATE ROLE sky_admin;
CREATE ROLE sky_auditor;
```

```sql
GRANT SELECT, INSERT ON bookings, rooms TO sky_user;
GRANT SELECT ON tenants, booking_statuses, room_statuses TO sky_user;

GRANT ALL ON ALL TABLES IN SCHEMA public TO sky_admin;

```

## Создание представлений

```sql
CREATE VIEW active_bookings AS
SELECT
b.booking_id,
r.room_name,
t.company_name,
b.start_time,
b.end_time,
bs.status_name
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
JOIN tenants t ON b.tenant_id = t.tenant_id
JOIN booking_statuses bs ON b.status_id = bs.status_id
WHERE b.status_id = (SELECT status_id FROM booking_statuses WHERE status_name = 'booked')
AND b.end_time > CURRENT_TIMESTAMP;
```

```sql
CREATE VIEW canceled_bookings AS
SELECT
b.booking_id,
r.room_name,
t.company_name,
b.start_time,
b.end_time,
bs.status_name
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
JOIN tenants t ON b.tenant_id = t.tenant_id
JOIN booking_statuses bs ON b.status_id = bs.status_id
WHERE b.status_id IN (
SELECT status_id FROM booking_statuses
	WHERE status_name IN ('canceled')
) OR b.end_time < CURRENT_TIMESTAMP;
```

```sql
CREATE VIEW bookings_by_company AS
SELECT
t.company_name,
COUNT(b.booking_id) as booking_count,
bs.status_name,
MIN(b.start_time) as earliest_booking,
MAX(b.end_time) as latest_booking
FROM bookings b
JOIN tenants t ON b.tenant_id = t.tenant_id
JOIN booking_statuses bs ON b.status_id = bs.status_id
GROUP BY t.company_name, bs.status_name;
```

## Создание процедур, триггеров, функций

booking function
```sql
CREATE OR REPLACE PROCEDURE book_room(
    p_room_id INT,
    p_tenant_id INT,
    p_user_id INT,
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP
)
LANGUAGE plpgsql AS $$
DECLARE
    v_room_status INT;
    v_booked_status INT;
BEGIN
    
    SELECT status_id INTO v_room_status 
    FROM rooms 
    WHERE room_id = p_room_id;

    IF v_room_status != (SELECT status_id FROM room_statuses WHERE status_name = 'free') THEN
        RAISE EXCEPTION 'Комната недоступна для бронирования';
    END IF;

   
    IF EXISTS (
        SELECT 1 
        FROM bookings 
        WHERE room_id = p_room_id 
        AND status_id = (SELECT status_id FROM booking_statuses WHERE status_name = 'booked')
        AND (p_start_time, p_end_time) OVERLAPS (start_time, end_time)
    ) THEN
        RAISE EXCEPTION 'Конфликт бронирования: комната уже забронирована на это время';
    END IF;

    
    SELECT status_id INTO v_booked_status 
    FROM booking_statuses 
    WHERE status_name = 'booked';

    INSERT INTO bookings (room_id, tenant_id, user_id, status_id, start_time, end_time)
    VALUES (p_room_id, p_tenant_id, p_user_id, v_booked_status, p_start_time, p_end_time);

    
    UPDATE rooms 
    SET status_id = (SELECT status_id FROM room_statuses WHERE status_name = 'booked')
    WHERE room_id = p_room_id;

    
    INSERT INTO action_logs (user_id, action_type, application_details)
    VALUES (p_user_id, 'BOOKING', 
            'Бронирование комнаты ' || p_room_id || ' с ' || p_start_time || ' по ' || p_end_time);
    
    COMMIT;
END;
$$;
```

booking cancel trigger
```sql

CREATE OR REPLACE FUNCTION cancel_booking_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status_id = (SELECT status_id FROM booking_statuses WHERE status_name = 'canceled') THEN
        
        UPDATE rooms 
        SET status_id = (SELECT status_id FROM room_statuses WHERE status_name = 'free')
        WHERE room_id = OLD.room_id;

        
        INSERT INTO action_logs (user_id, action_type, application_details)
        VALUES (OLD.user_id, 'CANCELLATION', 
                'Отмена бронирования ' || OLD.booking_id || ' для комнаты ' || OLD.room_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER on_booking_cancel
AFTER UPDATE OF status_id ON bookings
FOR EACH ROW
EXECUTE FUNCTION cancel_booking_trigger();
```

create booking history function
```sql
CREATE OR REPLACE FUNCTION get_room_booking_history(p_room_id INT)
RETURNS TABLE (
    booking_id INT,
    company_name VARCHAR,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    status_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.booking_id,
        t.company_name,
        b.start_time,
        b.end_time,
        bs.status_name
    FROM bookings b
    JOIN tenants t ON b.tenant_id = t.tenant_id
    JOIN booking_statuses bs ON b.status_id = bs.status_id
    WHERE b.room_id = p_room_id
    ORDER BY b.start_time DESC;
END;
$$ LANGUAGE plpgsql;
```
**ERD-диаграмма**
![ERD-диаграмма](https://i.imgur.com/AMl6zOV.jpeg)


**Комнаты с наибольшим количеством отказов**
![Отказы](https://i.imgur.com/PcwVCdi.jpeg)

**Комнаты с пересекающимися бронированиями**
![Бронь](https://i.imgur.com/AIuRjh3.jpeg)

**Пользователи с наибольшим числом действий**
![Действия](https://i.imgur.com/5sfwLOg.jpeg)

**Свободные комнаты в ближайшие 2 часа**
![Комнаты](https://i.imgur.com/CMKsIR0.jpeg)


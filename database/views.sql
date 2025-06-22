-- Pogledi za lakše dohvaćanje podataka
-- Pogled za osnovne informacije o biljkama
CREATE OR REPLACE VIEW v_plants_overview AS
SELECT p.id,
    p.name,
    pt.name as plant_type,
    pt.scientific_name,
    p.planted_date,
    (CURRENT_DATE - p.planted_date) as days_old,
    p.location,
    p.is_active,
    p.created_at,
    -- Broj slika
    COALESCE(img_count.image_count, 0) as image_count,
    -- Zadnji događaj
    last_event.last_event_date,
    last_event.last_event_type,
    -- Broj ukupnih događaja
    COALESCE(event_count.total_events, 0) as total_events,
    -- Zadnje mjerenje
    last_measurement.last_height,
    last_measurement.last_health_status,
    last_measurement.last_measurement_date
FROM plants p
    LEFT JOIN plant_types pt ON p.plant_type_id = pt.id
    LEFT JOIN (
        SELECT plant_id,
            COUNT(*) as image_count
        FROM plant_images
        GROUP BY plant_id
    ) img_count ON p.id = img_count.plant_id
    LEFT JOIN (
        SELECT e.plant_id,
            MAX(e.event_date) as last_event_date,
            et.name as last_event_type
        FROM events e
            JOIN event_types et ON e.event_type_id = et.id
        WHERE e.id IN (
                SELECT id
                FROM events e2
                WHERE e2.plant_id = e.plant_id
                ORDER BY e2.event_date DESC
                LIMIT 1
            )
        GROUP BY e.plant_id,
            et.name
    ) last_event ON p.id = last_event.plant_id
    LEFT JOIN (
        SELECT plant_id,
            COUNT(*) as total_events
        FROM events
        GROUP BY plant_id
    ) event_count ON p.id = event_count.plant_id
    LEFT JOIN (
        SELECT DISTINCT ON (m.plant_id) m.plant_id,
            m.height_cm as last_height,
            m.health_status as last_health_status,
            m.measurement_date as last_measurement_date
        FROM measurements m
        ORDER BY m.plant_id,
            m.measurement_date DESC
    ) last_measurement ON p.id = last_measurement.plant_id;
-- Pogled za događaje s dodatnim informacijama
CREATE OR REPLACE VIEW v_events_detailed AS
SELECT e.id,
    e.plant_id,
    p.name as plant_name,
    e.event_type_id,
    et.name as event_type_name,
    et.color as event_color,
    e.event_date,
    e.description,
    e.notes,
    e.reminder_date,
    e.is_completed,
    e.created_at,
    -- Broj dana do događaja
    EXTRACT(
        DAY
        FROM e.event_date - CURRENT_TIMESTAMP
    )::INTEGER as days_until_event,
    -- Da li je u prošlosti
    CASE
        WHEN e.event_date < CURRENT_TIMESTAMP THEN true
        ELSE false
    END as is_overdue
FROM events e
    JOIN plants p ON e.plant_id = p.id
    JOIN event_types et ON e.event_type_id = et.id;
-- Pogled za statistike po tipovima biljaka
CREATE OR REPLACE VIEW v_plant_type_stats AS
SELECT pt.id,
    pt.name,
    pt.scientific_name,
    COUNT(p.id) as total_plants,
    COUNT(
        CASE
            WHEN p.is_active THEN 1
        END
    ) as active_plants,
    ROUND(AVG(CURRENT_DATE - p.planted_date), 0)::INTEGER as avg_age_days,
    -- Prosječan broj događaja po biljci
    ROUND(AVG(event_stats.event_count), 2) as avg_events_per_plant,
    -- Prosječno zdravstveno stanje
    ROUND(AVG(health_stats.avg_health), 2) as avg_health_status
FROM plant_types pt
    LEFT JOIN plants p ON pt.id = p.plant_type_id
    LEFT JOIN (
        SELECT plant_id,
            COUNT(*) as event_count
        FROM events
        GROUP BY plant_id
    ) event_stats ON p.id = event_stats.plant_id
    LEFT JOIN (
        SELECT plant_id,
            AVG(health_status) as avg_health
        FROM measurements
        WHERE health_status IS NOT NULL
        GROUP BY plant_id
    ) health_stats ON p.id = health_stats.plant_id
GROUP BY pt.id,
    pt.name,
    pt.scientific_name;
-- Pogled za rast biljaka (temporalna analiza)
CREATE OR REPLACE VIEW v_plant_growth_timeline AS
SELECT m.plant_id,
    p.name as plant_name,
    m.measurement_date,
    m.height_cm,
    m.width_cm,
    m.leaf_count,
    m.health_status,
    -- Rast od prethodnog mjerenja
    LAG(m.height_cm) OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date
    ) as prev_height,
    m.height_cm - LAG(m.height_cm) OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date
    ) as height_growth,
    -- Broj dana od prethodnog mjerenja
    EXTRACT(
        DAY
        FROM m.measurement_date - LAG(m.measurement_date) OVER (
                PARTITION BY m.plant_id
                ORDER BY m.measurement_date
            )
    )::INTEGER as days_since_last_measurement,
    -- Trend rasta
    CASE
        WHEN m.height_cm > LAG(m.height_cm) OVER (
            PARTITION BY m.plant_id
            ORDER BY m.measurement_date
        ) THEN 'Raste'
        WHEN m.height_cm < LAG(m.height_cm) OVER (
            PARTITION BY m.plant_id
            ORDER BY m.measurement_date
        ) THEN 'Opada'
        ELSE 'Stagnira'
    END as growth_trend
FROM measurements m
    JOIN plants p ON m.plant_id = p.id
WHERE m.height_cm IS NOT NULL
ORDER BY m.plant_id,
    m.measurement_date;
-- Pogled za aktivne podsjetnika
CREATE OR REPLACE VIEW v_active_reminders AS
SELECT r.id,
    r.plant_id,
    p.name as plant_name,
    r.event_type_id,
    et.name as event_type_name,
    et.color as event_color,
    r.reminder_date,
    r.message,
    r.is_sent,
    r.is_completed,
    -- Broj dana do podsjetnika
    EXTRACT(
        DAY
        FROM r.reminder_date - CURRENT_TIMESTAMP
    )::INTEGER as days_until_reminder,
    -- Status podsjetnika
    CASE
        WHEN r.is_completed THEN 'Završeno'
        WHEN r.reminder_date < CURRENT_TIMESTAMP
        AND NOT r.is_sent THEN 'Zakasnilo'
        WHEN r.reminder_date <= CURRENT_TIMESTAMP + INTERVAL '1 day' THEN 'Hitno'
        WHEN r.reminder_date <= CURRENT_TIMESTAMP + INTERVAL '3 days' THEN 'Uskoro'
        ELSE 'Budućnost'
    END as reminder_status
FROM reminders r
    JOIN plants p ON r.plant_id = p.id
    JOIN event_types et ON r.event_type_id = et.id
WHERE NOT r.is_completed
ORDER BY r.reminder_date ASC;
-- Pogled za kalendar događaja
CREATE OR REPLACE VIEW v_calendar_events AS
SELECT 'event' as item_type,
    e.id as item_id,
    e.plant_id,
    p.name as plant_name,
    et.name as title,
    e.description,
    e.event_date as date,
    et.color,
    e.is_completed,
    false as is_reminder
FROM events e
    JOIN plants p ON e.plant_id = p.id
    JOIN event_types et ON e.event_type_id = et.id
UNION ALL
SELECT 'reminder' as item_type,
    r.id as item_id,
    r.plant_id,
    p.name as plant_name,
    'Podsjetnik: ' || et.name as title,
    r.message as description,
    r.reminder_date as date,
    et.color,
    r.is_completed,
    true as is_reminder
FROM reminders r
    JOIN plants p ON r.plant_id = p.id
    JOIN event_types et ON r.event_type_id = et.id
WHERE NOT r.is_completed
ORDER BY date ASC;
-- Pogled za mjerenja s dodatnim informacijama
CREATE OR REPLACE VIEW v_measurements_overview AS
SELECT m.id,
    m.plant_id,
    p.name as plant_name,
    pt.name as plant_type,
    m.measurement_date,
    m.height_cm,
    m.width_cm,
    m.leaf_count,
    m.flower_count,
    m.health_status,
    CASE
        m.health_status
        WHEN 1 THEN 'Vrlo loše'
        WHEN 2 THEN 'Loše'
        WHEN 3 THEN 'Osrednje'
        WHEN 4 THEN 'Dobro'
        WHEN 5 THEN 'Izvrsno'
        ELSE 'Nepoznato'
    END as health_description,
    m.notes,
    -- Usporedba s prethodnim mjerenjem
    LAG(m.height_cm) OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date
    ) as previous_height,
    m.height_cm - LAG(m.height_cm) OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date
    ) as height_change,
    LAG(m.leaf_count) OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date
    ) as previous_leaves,
    m.leaf_count - LAG(m.leaf_count) OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date
    ) as leaf_change,
    LAG(m.health_status) OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date
    ) as previous_health,
    m.health_status - LAG(m.health_status) OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date
    ) as health_change,
    -- Statistike
    EXTRACT(
        DAY
        FROM CURRENT_TIMESTAMP - m.measurement_date
    )::INTEGER as days_ago,
    ROW_NUMBER() OVER (
        PARTITION BY m.plant_id
        ORDER BY m.measurement_date DESC
    ) as measurement_rank
FROM measurements m
    JOIN plants p ON m.plant_id = p.id
    LEFT JOIN plant_types pt ON p.plant_type_id = pt.id
ORDER BY m.measurement_date DESC;
-- Pogled za statistike rasta po biljkama
CREATE OR REPLACE VIEW v_growth_statistics AS
SELECT p.id as plant_id,
    p.name as plant_name,
    pt.name as plant_type,
    COUNT(m.id) as total_measurements,
    MIN(m.measurement_date) as first_measurement,
    MAX(m.measurement_date) as last_measurement,
    EXTRACT(
        DAY
        FROM MAX(m.measurement_date) - MIN(m.measurement_date)
    )::INTEGER as measurement_period_days,
    -- Visina
    (
        SELECT height_cm
        FROM measurements
        WHERE plant_id = p.id
        ORDER BY measurement_date ASC
        LIMIT 1
    ) as initial_height,
    (
        SELECT height_cm
        FROM measurements
        WHERE plant_id = p.id
        ORDER BY measurement_date DESC
        LIMIT 1
    ) as current_height,
    COALESCE(
        (
            SELECT height_cm
            FROM measurements
            WHERE plant_id = p.id
            ORDER BY measurement_date DESC
            LIMIT 1
        ) - (
            SELECT height_cm
            FROM measurements
            WHERE plant_id = p.id
            ORDER BY measurement_date ASC
            LIMIT 1
        ), 0
    ) as total_growth,
    MAX(m.height_cm) as max_height_reached,
    -- Listovi
    (
        SELECT leaf_count
        FROM measurements
        WHERE plant_id = p.id
        ORDER BY measurement_date ASC
        LIMIT 1
    ) as initial_leaves,
    (
        SELECT leaf_count
        FROM measurements
        WHERE plant_id = p.id
        ORDER BY measurement_date DESC
        LIMIT 1
    ) as current_leaves,
    MAX(m.leaf_count) as max_leaves_reached,
    -- Zdravlje
    ROUND(AVG(m.health_status), 2) as avg_health_status,
    MIN(m.health_status) as min_health_status,
    MAX(m.health_status) as max_health_status,
    (
        SELECT health_status
        FROM measurements
        WHERE plant_id = p.id
        ORDER BY measurement_date DESC
        LIMIT 1
    ) as current_health_status,
    -- Trend rasta (zadnjih 30 dana)
    CASE
        WHEN (
            SELECT COUNT(*)
            FROM measurements
            WHERE plant_id = p.id
                AND measurement_date >= CURRENT_TIMESTAMP - INTERVAL '30 days'
        ) >= 2 THEN CASE
            WHEN (
                SELECT height_cm
                FROM measurements
                WHERE plant_id = p.id
                    AND measurement_date >= CURRENT_TIMESTAMP - INTERVAL '30 days'
                ORDER BY measurement_date DESC
                LIMIT 1
            ) > (
                SELECT height_cm
                FROM measurements
                WHERE plant_id = p.id
                    AND measurement_date >= CURRENT_TIMESTAMP - INTERVAL '30 days'
                ORDER BY measurement_date ASC
                LIMIT 1
            ) THEN 'Raste'
            WHEN (
                SELECT height_cm
                FROM measurements
                WHERE plant_id = p.id
                    AND measurement_date >= CURRENT_TIMESTAMP - INTERVAL '30 days'
                ORDER BY measurement_date DESC
                LIMIT 1
            ) < (
                SELECT height_cm
                FROM measurements
                WHERE plant_id = p.id
                    AND measurement_date >= CURRENT_TIMESTAMP - INTERVAL '30 days'
                ORDER BY measurement_date ASC
                LIMIT 1
            ) THEN 'Opada'
            ELSE 'Stabilno'
        END
        ELSE 'Nedovoljno podataka'
    END as growth_trend_30days,
    p.planted_date,
    (CURRENT_DATE - p.planted_date) as plant_age_days
FROM plants p
    LEFT JOIN plant_types pt ON p.plant_type_id = pt.id
    LEFT JOIN measurements m ON p.id = m.plant_id
WHERE p.is_active = TRUE
GROUP BY p.id,
    p.name,
    pt.name,
    p.planted_date
ORDER BY total_measurements DESC,
    p.name;
-- Pogled za zdravstvene signale
CREATE OR REPLACE VIEW v_health_alerts AS
SELECT p.id as plant_id,
    p.name as plant_name,
    pt.name as plant_type,
    latest_measurement.health_status as current_health,
    latest_measurement.measurement_date as last_measurement_date,
    EXTRACT(
        DAY
        FROM CURRENT_TIMESTAMP - latest_measurement.measurement_date
    )::INTEGER as days_since_measurement,
    CASE
        WHEN latest_measurement.health_status = 1 THEN 'KRITIČNO'
        WHEN latest_measurement.health_status = 2 THEN 'LOŠE'
        WHEN latest_measurement.health_status = 3 THEN 'UPOZORENJE'
        WHEN EXTRACT(
            DAY
            FROM CURRENT_TIMESTAMP - latest_measurement.measurement_date
        ) > 30 THEN 'ZASTARJELI PODACI'
        ELSE 'OK'
    END as alert_level,
    CASE
        WHEN latest_measurement.health_status <= 2 THEN 'Biljka zahtijeva hitnu pažnju - zdravstveno stanje je loše'
        WHEN latest_measurement.health_status = 3 THEN 'Biljka pokazuje znakove stresa - provjerite uvjete'
        WHEN EXTRACT(
            DAY
            FROM CURRENT_TIMESTAMP - latest_measurement.measurement_date
        ) > 30 THEN 'Dugo nema novih mjerenja - preporuča se provjera'
        ELSE 'Biljka je u dobrom stanju'
    END as alert_message,
    latest_measurement.notes as last_notes
FROM plants p
    LEFT JOIN plant_types pt ON p.plant_type_id = pt.id
    LEFT JOIN (
        SELECT DISTINCT ON (plant_id) plant_id,
            health_status,
            measurement_date,
            notes
        FROM measurements
        ORDER BY plant_id,
            measurement_date DESC
    ) latest_measurement ON p.id = latest_measurement.plant_id
WHERE p.is_active = TRUE
    AND (
        latest_measurement.health_status <= 3
        OR EXTRACT(
            DAY
            FROM CURRENT_TIMESTAMP - latest_measurement.measurement_date
        ) > 30
        OR latest_measurement.plant_id IS NULL
    )
ORDER BY CASE
        WHEN latest_measurement.health_status = 1 THEN 1
        WHEN latest_measurement.health_status = 2 THEN 2
        WHEN latest_measurement.health_status = 3 THEN 3
        WHEN EXTRACT(
            DAY
            FROM CURRENT_TIMESTAMP - latest_measurement.measurement_date
        ) > 30 THEN 4
        ELSE 5
    END,
    latest_measurement.health_status ASC;
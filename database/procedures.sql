-- Pohranjene procedure i funkcije
-- Funkcija za dohvaćanje aktivnih biljaka
CREATE OR REPLACE FUNCTION get_active_plants() RETURNS TABLE (
        id INTEGER,
        name VARCHAR(100),
        plant_type_name VARCHAR(100),
        planted_date DATE,
        location VARCHAR(100),
        days_since_planted INTEGER
    ) AS $$ BEGIN RETURN QUERY
SELECT p.id,
    p.name,
    pt.name as plant_type_name,
    p.planted_date,
    p.location,
    EXTRACT(
        DAY
        FROM CURRENT_DATE - p.planted_date
    )::INTEGER as days_since_planted
FROM plants p
    LEFT JOIN plant_types pt ON p.plant_type_id = pt.id
WHERE p.is_active = TRUE
ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql;
-- Funkcija za dohvaćanje povijesti biljke (temporalni upit)
CREATE OR REPLACE FUNCTION get_plant_history(plant_id_param INTEGER) RETURNS TABLE (
        id INTEGER,
        name VARCHAR(100),
        location VARCHAR(100),
        valid_from TIMESTAMP,
        valid_to TIMESTAMP,
        operation_type VARCHAR(10),
        changed_at TIMESTAMP
    ) AS $$ BEGIN RETURN QUERY
SELECT ph.id,
    ph.name,
    ph.location,
    ph.valid_from,
    ph.valid_to,
    ph.operation_type,
    ph.changed_at
FROM plants_history ph
WHERE ph.id = plant_id_param
ORDER BY ph.changed_at DESC;
END;
$$ LANGUAGE plpgsql;
-- Funkcija za dohvaćanje biljke u određenom vremenu (temporalni upit)
CREATE OR REPLACE FUNCTION get_plant_at_time(plant_id_param INTEGER, time_param TIMESTAMP) RETURNS TABLE (
        id INTEGER,
        name VARCHAR(100),
        plant_type_id INTEGER,
        location VARCHAR(100),
        notes TEXT
    ) AS $$ BEGIN RETURN QUERY
SELECT p.id,
    p.name,
    p.plant_type_id,
    p.location,
    p.notes
FROM plants p
WHERE p.id = plant_id_param
    AND p.valid_from <= time_param
    AND p.valid_to > time_param
UNION ALL
SELECT ph.id,
    ph.name,
    ph.plant_type_id,
    ph.location,
    ph.notes
FROM plants_history ph
WHERE ph.id = plant_id_param
    AND ph.valid_from <= time_param
    AND ph.valid_to > time_param;
END;
$$ LANGUAGE plpgsql;
-- Procedura za kreiranje kompletnog događaja s podsjetnikom
CREATE OR REPLACE FUNCTION create_event_with_reminder(
        p_plant_id INTEGER,
        p_event_type_id INTEGER,
        p_event_date TIMESTAMP,
        p_description TEXT DEFAULT NULL,
        p_custom_reminder_days INTEGER DEFAULT NULL
    ) RETURNS INTEGER AS $$
DECLARE new_event_id INTEGER;
reminder_days INTEGER;
BEGIN -- Kreiraj događaj
INSERT INTO events (plant_id, event_type_id, event_date, description)
VALUES (
        p_plant_id,
        p_event_type_id,
        p_event_date,
        p_description
    )
RETURNING id INTO new_event_id;
-- Određi broj dana za podsjetnik
IF p_custom_reminder_days IS NOT NULL THEN reminder_days := p_custom_reminder_days;
ELSE
SELECT default_reminder_days INTO reminder_days
FROM event_types
WHERE id = p_event_type_id;
END IF;
-- Kreiraj podsjetnik ako je potrebno
IF reminder_days > 0 THEN
INSERT INTO reminders (plant_id, event_type_id, reminder_date, message)
VALUES (
        p_plant_id,
        p_event_type_id,
        p_event_date - INTERVAL '1 day' * reminder_days,
        'Podsjetnik: ' || (
            SELECT name
            FROM event_types
            WHERE id = p_event_type_id
        ) || ' za biljku ' || (
            SELECT name
            FROM plants
            WHERE id = p_plant_id
        )
    );
END IF;
RETURN new_event_id;
END;
$$ LANGUAGE plpgsql;
-- Funkcija za statistike rasta biljke
CREATE OR REPLACE FUNCTION get_plant_growth_stats(plant_id_param INTEGER) RETURNS TABLE (
        plant_id INTEGER,
        plant_name VARCHAR(100),
        total_measurements INTEGER,
        first_measurement_date TIMESTAMP,
        last_measurement_date TIMESTAMP,
        current_height_cm DECIMAL(5, 2),
        max_height_cm DECIMAL(5, 2),
        height_growth_cm DECIMAL(5, 2),
        current_leaf_count INTEGER,
        max_leaf_count INTEGER,
        current_health_status INTEGER,
        avg_health_status DECIMAL(3, 2)
    ) AS $$ BEGIN RETURN QUERY
SELECT p.id as plant_id,
    p.name as plant_name,
    COUNT(m.id)::INTEGER as total_measurements,
    MIN(m.measurement_date) as first_measurement_date,
    MAX(m.measurement_date) as last_measurement_date,
    (
        SELECT m2.height_cm
        FROM measurements m2
        WHERE m2.plant_id = plant_id_param
        ORDER BY m2.measurement_date DESC
        LIMIT 1
    ) as current_height_cm,
    MAX(m.height_cm) as max_height_cm,
    COALESCE(
        (
            SELECT m2.height_cm
            FROM measurements m2
            WHERE m2.plant_id = plant_id_param
            ORDER BY m2.measurement_date DESC
            LIMIT 1
        ) - (
            SELECT m3.height_cm
            FROM measurements m3
            WHERE m3.plant_id = plant_id_param
            ORDER BY m3.measurement_date ASC
            LIMIT 1
        ), 0
    ) as height_growth_cm,
    (
        SELECT m2.leaf_count
        FROM measurements m2
        WHERE m2.plant_id = plant_id_param
        ORDER BY m2.measurement_date DESC
        LIMIT 1
    ) as current_leaf_count,
    MAX(m.leaf_count) as max_leaf_count,
    (
        SELECT m2.health_status
        FROM measurements m2
        WHERE m2.plant_id = plant_id_param
        ORDER BY m2.measurement_date DESC
        LIMIT 1
    ) as current_health_status,
    ROUND(AVG(m.health_status), 2) as avg_health_status
FROM plants p
    LEFT JOIN measurements m ON p.id = m.plant_id
WHERE p.id = plant_id_param
GROUP BY p.id,
    p.name;
END;
$$ LANGUAGE plpgsql;
-- Funkcija za pronalaženje biljaka koje trebaju pažnju
CREATE OR REPLACE FUNCTION get_plants_needing_attention() RETURNS TABLE (
        plant_id INTEGER,
        plant_name VARCHAR(100),
        reason TEXT,
        urgency INTEGER,
        -- 1=low, 2=medium, 3=high
        last_event_date TIMESTAMP
    ) AS $$ BEGIN RETURN QUERY -- Biljke koje dugo nisu zalijevane
SELECT p.id as plant_id,
    p.name as plant_name,
    'Dugo nije zalijevana - ' || EXTRACT(
        DAY
        FROM CURRENT_TIMESTAMP - COALESCE(last_water.event_date, p.created_at)
    )::TEXT || ' dana' as reason,
    CASE
        WHEN EXTRACT(
            DAY
            FROM CURRENT_TIMESTAMP - COALESCE(last_water.event_date, p.created_at)
        ) > 14 THEN 3
        WHEN EXTRACT(
            DAY
            FROM CURRENT_TIMESTAMP - COALESCE(last_water.event_date, p.created_at)
        ) > 7 THEN 2
        ELSE 1
    END as urgency,
    last_water.event_date as last_event_date
FROM plants p
    LEFT JOIN (
        SELECT e.plant_id,
            MAX(e.event_date) as event_date
        FROM events e
            JOIN event_types et ON e.event_type_id = et.id
        WHERE et.name = 'Zalijevanje'
            AND e.is_completed = TRUE
        GROUP BY e.plant_id
    ) last_water ON p.id = last_water.plant_id
WHERE p.is_active = TRUE
    AND EXTRACT(
        DAY
        FROM CURRENT_TIMESTAMP - COALESCE(last_water.event_date, p.created_at)
    ) > 5
UNION ALL
-- Biljke s lošim zdravstvenim stanjem
SELECT p.id as plant_id,
    p.name as plant_name,
    'Loše zdravstveno stanje - ' || latest_health.health_status::TEXT || '/5' as reason,
    CASE
        WHEN latest_health.health_status <= 2 THEN 3
        WHEN latest_health.health_status = 3 THEN 2
        ELSE 1
    END as urgency,
    latest_health.measurement_date as last_event_date
FROM plants p
    JOIN (
        SELECT DISTINCT ON (m.plant_id) m.plant_id,
            m.health_status,
            m.measurement_date
        FROM measurements m
        WHERE m.health_status IS NOT NULL
        ORDER BY m.plant_id,
            m.measurement_date DESC
    ) latest_health ON p.id = latest_health.plant_id
WHERE p.is_active = TRUE
    AND latest_health.health_status <= 3
ORDER BY urgency DESC,
    last_event_date ASC;
END;
$$ LANGUAGE plpgsql;
-- Funkcija za dobivanje nadolazećih podsjetnika
CREATE OR REPLACE FUNCTION get_upcoming_reminders(days_ahead INTEGER DEFAULT 7) RETURNS TABLE (
        reminder_id INTEGER,
        plant_name VARCHAR(100),
        event_type_name VARCHAR(50),
        reminder_date TIMESTAMP,
        message TEXT,
        days_until INTEGER
    ) AS $$ BEGIN RETURN QUERY
SELECT r.id as reminder_id,
    p.name as plant_name,
    et.name as event_type_name,
    r.reminder_date,
    r.message,
    EXTRACT(
        DAY
        FROM r.reminder_date - CURRENT_TIMESTAMP
    )::INTEGER as days_until
FROM reminders r
    JOIN plants p ON r.plant_id = p.id
    JOIN event_types et ON r.event_type_id = et.id
WHERE r.is_sent = FALSE
    AND r.is_completed = FALSE
    AND r.reminder_date <= CURRENT_TIMESTAMP + INTERVAL '1 day' * days_ahead
    AND r.reminder_date >= CURRENT_TIMESTAMP
ORDER BY r.reminder_date ASC;
END;
$$ LANGUAGE plpgsql;
-- Funkcija za dohvaćanje trenda mjerenja (zadnjih N mjerenja)
CREATE OR REPLACE FUNCTION get_measurement_trend(
        plant_id_param INTEGER,
        days_back INTEGER DEFAULT 30
    ) RETURNS TABLE (
        measurement_date TIMESTAMP,
        height_cm DECIMAL(5, 2),
        width_cm DECIMAL(5, 2),
        leaf_count INTEGER,
        health_status INTEGER,
        notes TEXT,
        days_ago INTEGER
    ) AS $$ BEGIN RETURN QUERY
SELECT m.measurement_date,
    m.height_cm,
    m.width_cm,
    m.leaf_count,
    m.health_status,
    m.notes,
    EXTRACT(
        DAY
        FROM CURRENT_TIMESTAMP - m.measurement_date
    )::INTEGER as days_ago
FROM measurements m
WHERE m.plant_id = plant_id_param
    AND m.measurement_date >= CURRENT_TIMESTAMP - INTERVAL '1 day' * days_back
ORDER BY m.measurement_date DESC;
END;
$$ LANGUAGE plpgsql;
-- Funkcija za analizu zdravlja svih biljaka
CREATE OR REPLACE FUNCTION get_plants_health_analysis() RETURNS TABLE (
        plant_id INTEGER,
        plant_name VARCHAR(100),
        plant_type VARCHAR(100),
        current_health_status INTEGER,
        avg_health_status DECIMAL(3, 2),
        health_trend VARCHAR(20),
        last_measurement_date TIMESTAMP,
        days_since_measurement INTEGER,
        needs_attention BOOLEAN
    ) AS $$ BEGIN RETURN QUERY
SELECT p.id as plant_id,
    p.name as plant_name,
    pt.name as plant_type,
    latest.current_health_status,
    ROUND(health_avg.avg_health, 2) as avg_health_status,
    CASE
        WHEN latest.current_health_status > health_avg.avg_health THEN 'Poboljšava se'
        WHEN latest.current_health_status < health_avg.avg_health THEN 'Pogoršava se'
        ELSE 'Stabilno'
    END as health_trend,
    latest.last_measurement_date,
    EXTRACT(
        DAY
        FROM CURRENT_TIMESTAMP - latest.last_measurement_date
    )::INTEGER as days_since_measurement,
    CASE
        WHEN latest.current_health_status <= 2 THEN TRUE
        WHEN EXTRACT(
            DAY
            FROM CURRENT_TIMESTAMP - latest.last_measurement_date
        ) > 30 THEN TRUE
        ELSE FALSE
    END as needs_attention
FROM plants p
    LEFT JOIN plant_types pt ON p.plant_type_id = pt.id
    LEFT JOIN (
        SELECT m1.plant_id,
            m1.health_status as current_health_status,
            m1.measurement_date as last_measurement_date
        FROM measurements m1
        WHERE m1.id = (
                SELECT m2.id
                FROM measurements m2
                WHERE m2.plant_id = m1.plant_id
                ORDER BY m2.measurement_date DESC
                LIMIT 1
            )
    ) latest ON p.id = latest.plant_id
    LEFT JOIN (
        SELECT plant_id,
            AVG(health_status) as avg_health
        FROM measurements
        WHERE measurement_date >= CURRENT_TIMESTAMP - INTERVAL '90 days'
        GROUP BY plant_id
    ) health_avg ON p.id = health_avg.plant_id
WHERE p.is_active = TRUE
ORDER BY needs_attention DESC,
    latest.current_health_status ASC;
END;
$$ LANGUAGE plpgsql;
-- Funkcija za dodavanje novog mjerenja s validacijom
CREATE OR REPLACE FUNCTION add_measurement(
        plant_id_param INTEGER,
        height_cm_param DECIMAL(5, 2) DEFAULT NULL,
        width_cm_param DECIMAL(5, 2) DEFAULT NULL,
        leaf_count_param INTEGER DEFAULT NULL,
        flower_count_param INTEGER DEFAULT NULL,
        health_status_param INTEGER DEFAULT NULL,
        notes_param TEXT DEFAULT NULL
    ) RETURNS INTEGER AS $$
DECLARE measurement_id INTEGER;
plant_exists BOOLEAN;
BEGIN -- Provjeri da li biljka postoji i aktivna je
SELECT EXISTS(
        SELECT 1
        FROM plants
        WHERE id = plant_id_param
            AND is_active = TRUE
    ) INTO plant_exists;
IF NOT plant_exists THEN RAISE EXCEPTION 'Biljka s ID % ne postoji ili nije aktivna',
plant_id_param;
END IF;
-- Validacija health_status
IF health_status_param IS NOT NULL
AND (
    health_status_param < 1
    OR health_status_param > 5
) THEN RAISE EXCEPTION 'Health status mora biti između 1 i 5';
END IF;
-- Dodaj mjerenje
INSERT INTO measurements (
        plant_id,
        height_cm,
        width_cm,
        leaf_count,
        flower_count,
        health_status,
        notes
    )
VALUES (
        plant_id_param,
        height_cm_param,
        width_cm_param,
        leaf_count_param,
        flower_count_param,
        health_status_param,
        notes_param
    )
RETURNING id INTO measurement_id;
-- Stvori automatski događaj za mjerenje
INSERT INTO events (
        plant_id,
        event_type_id,
        event_date,
        description,
        is_completed
    )
SELECT plant_id_param,
    et.id,
    CURRENT_TIMESTAMP,
    'Automatsko mjerenje: ' || COALESCE('Visina ' || height_cm_param || 'cm', '') || COALESCE(', Listovi ' || leaf_count_param, '') || COALESCE(', Zdravlje ' || health_status_param || '/5', ''),
    TRUE
FROM event_types et
WHERE et.name = 'Mjerenje';
RETURN measurement_id;
END;
$$ LANGUAGE plpgsql;
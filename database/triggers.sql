-- Trigeri za aktivne baze podataka
-- Trigger za ažuriranje updated_at kolone
CREATE OR REPLACE FUNCTION update_timestamp() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Primjena trigger-a na sve tablice s updated_at kolumnama
CREATE TRIGGER trigger_update_plants_timestamp BEFORE
UPDATE ON plants FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trigger_update_plant_types_timestamp BEFORE
UPDATE ON plant_types FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trigger_update_events_timestamp BEFORE
UPDATE ON events FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trigger_update_measurements_timestamp BEFORE
UPDATE ON measurements FOR EACH ROW EXECUTE FUNCTION update_timestamp();
-- Temporalni trigger za praćenje promjena u tablici plants
CREATE OR REPLACE FUNCTION plants_temporal_trigger() RETURNS TRIGGER AS $$ BEGIN -- Za UPDATE operacije
    IF TG_OP = 'UPDATE' THEN -- Zatvaramo stari zapis
UPDATE plants
SET valid_to = CURRENT_TIMESTAMP
WHERE id = OLD.id
    AND valid_to = '9999-12-31 23:59:59';
-- Postavljamo novi valid_from
NEW.valid_from = CURRENT_TIMESTAMP;
NEW.valid_to = '9999-12-31 23:59:59';
-- Dodajemo stari zapis u historiju
INSERT INTO plants_history (
        id,
        name,
        plant_type_id,
        planted_date,
        location,
        notes,
        is_active,
        created_at,
        updated_at,
        valid_from,
        valid_to,
        operation_type,
        changed_by,
        changed_at
    )
VALUES (
        OLD.id,
        OLD.name,
        OLD.plant_type_id,
        OLD.planted_date,
        OLD.location,
        OLD.notes,
        OLD.is_active,
        OLD.created_at,
        OLD.updated_at,
        OLD.valid_from,
        CURRENT_TIMESTAMP,
        'UPDATE',
        current_user,
        CURRENT_TIMESTAMP
    );
RETURN NEW;
END IF;
-- Za DELETE operacije
IF TG_OP = 'DELETE' THEN -- Dodajemo obrisani zapis u historiju
INSERT INTO plants_history (
        id,
        name,
        plant_type_id,
        planted_date,
        location,
        notes,
        is_active,
        created_at,
        updated_at,
        valid_from,
        valid_to,
        operation_type,
        changed_by,
        changed_at
    )
VALUES (
        OLD.id,
        OLD.name,
        OLD.plant_type_id,
        OLD.planted_date,
        OLD.location,
        OLD.notes,
        OLD.is_active,
        OLD.created_at,
        OLD.updated_at,
        OLD.valid_from,
        CURRENT_TIMESTAMP,
        'DELETE',
        current_user,
        CURRENT_TIMESTAMP
    );
RETURN OLD;
END IF;
-- Za INSERT operacije
IF TG_OP = 'INSERT' THEN -- Dodajemo novi zapis u historiju
INSERT INTO plants_history (
        id,
        name,
        plant_type_id,
        planted_date,
        location,
        notes,
        is_active,
        created_at,
        updated_at,
        valid_from,
        valid_to,
        operation_type,
        changed_by,
        changed_at
    )
VALUES (
        NEW.id,
        NEW.name,
        NEW.plant_type_id,
        NEW.planted_date,
        NEW.location,
        NEW.notes,
        NEW.is_active,
        NEW.created_at,
        NEW.updated_at,
        NEW.valid_from,
        NEW.valid_to,
        'INSERT',
        current_user,
        CURRENT_TIMESTAMP
    );
RETURN NEW;
END IF;
RETURN NULL;
END;
$$ LANGUAGE plpgsql;
-- Primjena temporalnog trigger-a
CREATE TRIGGER plants_temporal_audit
AFTER
INSERT
    OR
UPDATE
    OR DELETE ON plants FOR EACH ROW EXECUTE FUNCTION plants_temporal_trigger();
-- Trigger za automatsko kreiranje podsjetnika
CREATE OR REPLACE FUNCTION create_reminder_for_event() RETURNS TRIGGER AS $$
DECLARE default_days INTEGER;
BEGIN -- Dohvaćamo defaultni broj dana za podsjetnik
SELECT default_reminder_days INTO default_days
FROM event_types
WHERE id = NEW.event_type_id;
-- Kreiramo podsjetnik ako je defaultni broj dana > 0
IF default_days > 0 THEN
INSERT INTO reminders (plant_id, event_type_id, reminder_date, message)
VALUES (
        NEW.plant_id,
        NEW.event_type_id,
        NEW.event_date - INTERVAL '1 day' * default_days,
        'Podsjetnik: ' || (
            SELECT name
            FROM event_types
            WHERE id = NEW.event_type_id
        ) || ' za biljku ' || (
            SELECT name
            FROM plants
            WHERE id = NEW.plant_id
        )
    );
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER create_event_reminder
AFTER
INSERT ON events FOR EACH ROW EXECUTE FUNCTION create_reminder_for_event();
-- Trigger za automatsko kreiranje sljedećeg događaja na temelju frekvencije
CREATE OR REPLACE FUNCTION schedule_next_event() RETURNS TRIGGER AS $$
DECLARE frequency_days INTEGER;
event_name VARCHAR(50);
BEGIN -- Samo ako je događaj označen kao završen
IF NEW.is_completed = TRUE
AND OLD.is_completed = FALSE THEN
SELECT et.name INTO event_name
FROM event_types et
WHERE et.id = NEW.event_type_id;
-- Određujemo frekvenciju na temelju tipa događaja i biljke
IF event_name = 'Zalijevanje' THEN
SELECT pt.watering_frequency_days INTO frequency_days
FROM plants p
    JOIN plant_types pt ON p.plant_type_id = pt.id
WHERE p.id = NEW.plant_id;
ELSIF event_name = 'Gnojenje' THEN
SELECT pt.fertilizing_frequency_days INTO frequency_days
FROM plants p
    JOIN plant_types pt ON p.plant_type_id = pt.id
WHERE p.id = NEW.plant_id;
ELSE frequency_days := NULL;
-- Ne kreiramo automatski sljedeći događaj
END IF;
-- Kreiramo sljedeći događaj
IF frequency_days IS NOT NULL THEN
INSERT INTO events (plant_id, event_type_id, event_date, description)
VALUES (
        NEW.plant_id,
        NEW.event_type_id,
        CURRENT_TIMESTAMP + INTERVAL '1 day' * frequency_days,
        'Automatski kreirano: ' || event_name
    );
END IF;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER schedule_recurring_event
AFTER
UPDATE ON events FOR EACH ROW EXECUTE FUNCTION schedule_next_event();
-- Trigger za provjeru zdravlja biljke na temelju mjerenja
CREATE OR REPLACE FUNCTION check_plant_health() RETURNS TRIGGER AS $$ BEGIN -- Ako je zdravstveno stanje loše (1 ili 2), kreiraj podsjetnik
    IF NEW.health_status <= 2 THEN
INSERT INTO reminders (plant_id, event_type_id, reminder_date, message)
VALUES (
        NEW.plant_id,
        (
            SELECT id
            FROM event_types
            WHERE name = 'Prskanje'
        ),
        CURRENT_TIMESTAMP + INTERVAL '1 day',
        'Upozorenje: Biljka ' || (
            SELECT name
            FROM plants
            WHERE id = NEW.plant_id
        ) || ' ima loše zdravstveno stanje. Potrebna je pažnja!'
    );
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER monitor_plant_health
AFTER
INSERT ON measurements FOR EACH ROW EXECUTE FUNCTION check_plant_health();
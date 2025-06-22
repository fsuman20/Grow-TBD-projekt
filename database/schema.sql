-- Kreiranje baze podataka za praćenje biljaka
-- Aktivne i temporalne baze podataka

-- Tablica za tipove biljaka
CREATE TABLE plant_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    scientific_name VARCHAR(150),
    description TEXT,
    care_instructions TEXT,
    watering_frequency_days INTEGER DEFAULT 7,
    fertilizing_frequency_days INTEGER DEFAULT 30,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tablica za biljke
CREATE TABLE plants (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    plant_type_id INTEGER REFERENCES plant_types(id),
    planted_date DATE NOT NULL,
    location VARCHAR(100),
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Temporalne kolone
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_to TIMESTAMP DEFAULT '9999-12-31 23:59:59'
);

-- Historijska tablica za biljke (temporalna)
CREATE TABLE plants_history (
    id INTEGER,
    name VARCHAR(100),
    plant_type_id INTEGER,
    planted_date DATE,
    location VARCHAR(100),
    notes TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    valid_from TIMESTAMP,
    valid_to TIMESTAMP,
    operation_type VARCHAR(10), -- INSERT, UPDATE, DELETE
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tablica za tipove događaja
CREATE TABLE event_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    default_reminder_days INTEGER DEFAULT 1,
    color VARCHAR(7) DEFAULT '#007bff' -- HEX color
);

-- Tablica za događaje
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    plant_id INTEGER REFERENCES plants(id) ON DELETE CASCADE,
    event_type_id INTEGER REFERENCES event_types(id),
    event_date TIMESTAMP NOT NULL,
    description TEXT,
    notes TEXT,
    reminder_date TIMESTAMP,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tablica za slike
CREATE TABLE plant_images (
    id SERIAL PRIMARY KEY,
    plant_id INTEGER REFERENCES plants(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255),
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    file_size INTEGER,
    mime_type VARCHAR(100)
);

-- Tablica za podsjetnici
CREATE TABLE reminders (
    id SERIAL PRIMARY KEY,
    plant_id INTEGER REFERENCES plants(id) ON DELETE CASCADE,
    event_type_id INTEGER REFERENCES event_types(id),
    reminder_date TIMESTAMP NOT NULL,
    message TEXT NOT NULL,
    is_sent BOOLEAN DEFAULT FALSE,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tablica za mjerenja (visina, širina, broj listova...)
CREATE TABLE measurements (
    id SERIAL PRIMARY KEY,
    plant_id INTEGER REFERENCES plants(id) ON DELETE CASCADE,
    measurement_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    height_cm DECIMAL(5,2),
    width_cm DECIMAL(5,2),
    leaf_count INTEGER,
    flower_count INTEGER,
    health_status INTEGER CHECK (health_status >= 1 AND health_status <= 5), -- 1-5 skala
    notes TEXT
);

-- Indeksi za performanse
CREATE INDEX idx_plants_type ON plants(plant_type_id);
CREATE INDEX idx_plants_active ON plants(is_active);
CREATE INDEX idx_plants_temporal ON plants(valid_from, valid_to);
CREATE INDEX idx_events_plant ON events(plant_id);
CREATE INDEX idx_events_date ON events(event_date);
CREATE INDEX idx_events_reminder ON events(reminder_date);
CREATE INDEX idx_reminders_date ON reminders(reminder_date);
CREATE INDEX idx_reminders_sent ON reminders(is_sent);
CREATE INDEX idx_measurements_plant_date ON measurements(plant_id, measurement_date);

-- Početni podaci
INSERT INTO event_types (name, description, default_reminder_days, color) VALUES
('Zalijevanje', 'Zalijevanje biljke', 1, '#007bff'),
('Gnojenje', 'Dodavanje gnojiva', 3, '#28a745'),
('Presađivanje', 'Presađivanje u veći lonac', 7, '#ffc107'),
('Obrezivanje', 'Obrezivanje listova i grana', 2, '#dc3545'),
('Prskanje', 'Prskanje protiv štetočina', 1, '#6f42c1'),
('Mjerenje', 'Mjerenje rasta biljke', 0, '#20c997');

INSERT INTO plant_types (name, scientific_name, description, care_instructions, watering_frequency_days, fertilizing_frequency_days) VALUES
('Ficus', 'Ficus benjamina', 'Popularna sobna biljka s malim listovima', 'Zalijevanje jednom tjedno, svijetlo mjesto bez direktnog sunca', 7, 30),
('Monstera', 'Monstera deliciosa', 'Tropska biljka s velikim perforiranim listovima', 'Zalijevanje kada se zemlja osuši, visoka vlažnost zraka', 10, 21),
('Pothos', 'Epipremnum aureum', 'Jednostavna za uzgoj, penjajuća biljka', 'Zalijevanje kada se površina zemlje osuši', 7, 30),
('Sansevieria', 'Sansevieria trifasciata', 'Nezahtjevna biljka, poznata kao "zmijski jezik"', 'Rijetko zalijevanje, podnosi suše uvjete', 14, 60),
('Aloe Vera', 'Aloe barbadensis', 'Sučulenta s ljekovitim svojstvima', 'Zalijevanje svake 2-3 tjedna, dobro dreniranje', 17, 90);

-- Demo biljke za testiranje
INSERT INTO plants (name, plant_type_id, planted_date, location, notes) VALUES
('Moj Ficus', 1, '2024-01-15', 'Dnevni boravak - prozor', 'Kupljen u vrtnom centru, dobro se prilagodio'),
('Velika Monstera', 2, '2023-08-20', 'Spavaća soba', 'Narasla je puno otkako je presađena'),
('Pothos na zidu', 3, '2024-03-10', 'Kuhinja - polica', 'Penje se po zidu, treba podršku');

-- Demo mjerenja za praćenje rasta
INSERT INTO measurements (plant_id, measurement_date, height_cm, width_cm, leaf_count, health_status, notes) VALUES
-- Ficus (ID 1) - postupan rast kroz 6 mjeseci
(1, '2024-01-20', 25.0, 20.0, 8, 4, 'Početno mjerenje nakon kupnje'),
(1, '2024-02-20', 27.5, 22.0, 10, 4, 'Dobro se prilagodio, novi listovi'),
(1, '2024-03-20', 30.0, 25.0, 12, 5, 'Izvrsno stanje, mnogo novih listova'),
(1, '2024-04-20', 32.5, 27.0, 15, 4, 'Nastavio rasti, potrebno presađivanje'),
(1, '2024-05-20', 35.0, 30.0, 18, 5, 'Presađen u veći lonac, odličan rast'),
(1, '2024-06-15', 37.5, 32.0, 20, 4, 'Stalni rast, zdravi listovi'),

-- Monstera (ID 2) - veća biljka s varijabilnim zdravljem
(2, '2023-09-01', 45.0, 35.0, 6, 3, 'Početno mjerenje, adaptacija na novi dom'),
(2, '2023-10-01', 48.0, 38.0, 7, 4, 'Bolje se prilagodila, novi list'),
(2, '2023-12-01', 52.0, 42.0, 8, 5, 'Zimski period, dobro stanje'),
(2, '2024-02-01', 55.0, 45.0, 9, 4, 'Proljetni rast počinje'),
(2, '2024-04-01', 60.0, 50.0, 12, 5, 'Eksplozivan rast, 3 nova lista'),
(2, '2024-06-10', 65.0, 55.0, 14, 4, 'Kontinuiran rast, potrebno više prostora'),

-- Pothos (ID 3) - brz rast penjajuće biljke
(3, '2024-03-15', 15.0, 25.0, 12, 4, 'Mlada biljka, dobro stanje'),
(3, '2024-04-15', 20.0, 35.0, 18, 5, 'Brz rast, počinje se penjati'),
(3, '2024-05-15', 30.0, 45.0, 25, 5, 'Izvrsno prilagođavanje, bujan rast'),
(3, '2024-06-18', 40.0, 60.0, 32, 4, 'Nastavlja se penjati, možda treba potpora');

-- Demo događaji (events) za praćenje njege biljaka
INSERT INTO events (plant_id, event_type_id, event_date, description, notes, is_completed) VALUES
-- Ficus (ID 1) događaji
(1, 1, '2024-01-16', 'Prvo zalijevanje nakon kupnje', 'Umjereno zalijevanje, zemlja je bila suha', true),
(1, 1, '2024-01-23', 'Redovno tjedno zalijevanje', 'Biljka se dobro prilagodila', true),
(1, 1, '2024-01-30', 'Zalijevanje', 'Listovi su zdravi i sjajni', true),
(1, 2, '2024-02-15', 'Prvo gnojenje', 'Tekuće gnojivo za sobne biljke', true),
(1, 1, '2024-02-21', 'Zalijevanje nakon gnojenja', 'Vidljiv rast novih listova', true),
(1, 3, '2024-05-18', 'Presađivanje u veći lonac', 'Korijenje je ispunilo stari lonac', true),
(1, 1, '2024-06-20', 'Zalijevanje', 'Prvi put u novom loncu', true),
(1, 1, '2024-06-27', 'Predviđeno zalijevanje', 'Treba provjeriti vlažnost zemlje', false),

-- Monstera (ID 2) događaji
(2, 1, '2023-08-22', 'Prvo zalijevanje u novom domu', 'Velika količina vode zbog veličine', true),
(2, 1, '2023-09-01', 'Zalijevanje', 'Zemlja je bila prilično suha', true),
(2, 2, '2023-09-10', 'Gnojenje', 'Specijalno gnojivo za tropske biljke', true),
(2, 1, '2023-09-15', 'Zalijevanje', 'Dobra reakcija na gnojivo', true),
(2, 4, '2023-12-05', 'Obrezivanje žutih listova', 'Uklonjen jedan veliki žuti list', true),
(2, 1, '2024-02-05', 'Proljetno zalijevanje', 'Povećana količina zbog sezone rasta', true),
(2, 2, '2024-02-15', 'Proljetno gnojenje', 'Početak sezone aktivnog rasta', true),
(2, 1, '2024-04-03', 'Zalijevanje', 'Nova tri lista u razvoju', true),
(2, 5, '2024-04-20', 'Prskanje protiv štitastih uši', 'Preventivno prskanje', true),
(2, 1, '2024-06-12', 'Zalijevanje', 'Potrebno više prostora', true),
(2, 1, '2024-06-25', 'Predviđeno zalijevanje', 'Ljeto - češće zalijevanje', false),

-- Pothos (ID 3) događaji
(3, 1, '2024-03-12', 'Prvo zalijevanje mlode biljke', 'Mala količina, mlada biljka', true),
(3, 1, '2024-03-19', 'Zalijevanje', 'Brz rast, zdravi listovi', true),
(3, 2, '2024-04-01', 'Prvo gnojenje', 'Razrijeđeno gnojivo', true),
(3, 1, '2024-04-17', 'Zalijevanje', 'Počinje se penjati', true),
(3, 1, '2024-05-01', 'Zalijevanje', 'Dodana potpora za penjanje', true),
(3, 1, '2024-05-17', 'Zalijevanje', 'Bujan rast, mnogo novih listova', true),
(3, 2, '2024-06-01', 'Gnojenje', 'Pojačano gnojivo zbog brzog rasta', true),
(3, 1, '2024-06-20', 'Zalijevanje', 'Treba veća potpora', true),
(3, 1, '2024-06-26', 'Predviđeno zalijevanje', 'Redovno održavanje', false);

-- Demo podsjetnici (reminders) za aktivne zadatke
INSERT INTO reminders (plant_id, event_type_id, reminder_date, message, is_sent, is_completed) VALUES
-- Aktivni podsjetnici za sve biljke
(1, 1, '2024-06-27 09:00:00', 'Vrijeme je za zalijevanje - Moj Ficus', false, false),
(1, 2, '2024-07-15 10:00:00', 'Vrijeme je za gnojenje - Moj Ficus (mjesečno gnojenje)', false, false),
(2, 1, '2024-06-25 09:00:00', 'Vrijeme je za zalijevanje - Velika Monstera', false, false),
(2, 3, '2024-07-10 10:00:00', 'Razmisli o presađivanju - Velika Monstera (potrebno više prostora)', false, false),
(3, 1, '2024-06-26 09:00:00', 'Vrijeme je za zalijevanje - Pothos na zidu', false, false),
(3, 4, '2024-06-28 10:00:00', 'Provjeri potporu za penjanje - Pothos na zidu', false, false),

-- Budući podsjetnici
(1, 4, '2024-07-05 10:00:00', 'Provjeri da li treba obrezivanje - Moj Ficus', false, false),
(2, 5, '2024-07-20 10:00:00', 'Preventivno prskanje - Velika Monstera', false, false),
(3, 2, '2024-07-01 10:00:00', 'Vrijeme je za gnojenje - Pothos na zidu', false, false);

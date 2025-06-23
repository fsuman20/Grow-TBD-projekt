<p align="center">
<img src="static/img/full_logo.png" alt="Plant Tracker" width="auto" height="400" display: block>
</p> 

# 🌱 Grow - Aplikacija za praćenje skrbi o biljkama

Sveobuhvatna web aplikacija za praćenje i upravljanje skrbi o biljkama izgrađena s Flask-om i PostgreSQL-om, koja uključuje napredne temporalne i aktivne koncepte baze podataka.

![Početni zaslon](static/img/Snimka%20zaslona_22-6-2025_5275_127.0.0.1.jpeg)

## ✨ Značajke

- 🌿 **Upravljanje biljkama** - Dodavanje, uređivanje i praćenje vaših biljaka s detaljnim informacijama
- 📅 **Planiranje događaja** - Raspored zalijevanja, gnojenja, presađivanja i obrezivanja  
- 🔔 **Pametni podsjetnici** - Automatski sustav obavještavanja za skrb o biljkama
- 📸 **Foto galerija** - Praćenje napretka rasta kroz slike s vremenskim oznakama
- 📊 **Mjerenja rasta** - Praćenje visine, širine, zdravlja i statistika rasta
- 🕐 **Temporalna baza podataka** - Praćenje promjena tijekom vremena s potpunim zapisom revizije
- ⚙️ **Značajke aktivne baze podataka** - Okidači, procedure, pogledi i funkcije
- 📱 **Responzivni dizajn** - Optimizirano za desktop i mobilne uređaje

## 🚀 Brzi početak

### Preduvjeti
- Python 3.8+
- PostgreSQL 12+

### Instalacija
 ** MOguće je da je skripta pokvarena u tom slučaj potrebno je manulano instalirati requirements i stvoriti databazu i izvršiti sql
#### Windows
```bash
# Kloniraj repozitorij
git clone <repository-url>
cd "TBD projekt"

# Pokreni setup skriptu (stvara bazu podataka, instalira ovisnosti, pokreće app)
setup_grow.bat
```

#### Linux/macOS
```bash
# Kloniraj repozitorij
git clone <repository-url>
cd "TBD projekt"

# Učini skriptu izvršnom i pokreni
chmod +x setup_grow.sh
./setup_grow.sh
```

Aplikacija će biti dostupna na: **http://localhost:5000**

Za detaljne upute za postavku, pogledajte [SETUP_GUIDE.md](SETUP_GUIDE.md)

## 🏗️ Tehnološki stog

- **Backend**: Python Flask
- **Baza podataka**: PostgreSQL s temporalnim značajkama
- **ORM**: SQLAlchemy s Flask-SQLAlchemy  
- **Frontend**: Bootstrap 5, HTML, CSS, JavaScript
- **Forme**: Flask-WTF i WTForms
- **Upload datoteka**: Werkzeug za sigurno rukovanje slikama

## 📁 Struktura projekta

```
TBD projekt/
├── app.py                 # Glavna Flask aplikacija
├── models.py             # SQLAlchemy modeli baze podataka
├── forms.py              # WTForms definicije
├── database/             # SQL skripte
│   ├── schema.sql        # Tablice i početni podaci
│   ├── triggers.sql      # Okidači baze podataka
│   ├── procedures.sql    # Spremljene procedure
│   └── views.sql         # Pogledi baze podataka
├── templates/            # Jinja2 HTML predlošci
├── static/              # CSS, JS, slike
├── uploads/             # Korisničke uploadane slike
├── setup_grow.bat/.sh   # Setup skripte
└── requirements.txt     # Python ovisnosti
```

## 🗃️ Arhitektura baze podataka

### Osnovne tablice
- `plants` - Glavni zapisi biljaka s temporalnim stupcima
- `plant_types` - Vrste/varijante biljaka  
- `events` - Događaji skrbi (zalijevanje, gnojenje, itd.)
- `measurements` - Podaci za praćenje rasta
- `plant_images` - Foto galerija
- `reminders` - Automatska obavještenja
- `plants_history` - Temporalni trag revizije

### Značajke aktivne baze podataka
- **Okidači**: Automatsko ažuriranje vremenskih oznaka, stvaranje podsjetnika, ponavljajući događaji
- **Spremljene procedure**: Složene operacije za upravljanje skrbi o biljkama
- **Pogledi**: Pojednostavljeni uzorci pristupa podacima
- **Funkcije**: Pomoćne funkcije za statistike i izvještavanje

### Značajke temporalne baze podataka
- **Praćenje promjena**: Automatsko praćenje svih modifikacija biljaka
- **Povijesni upiti**: Dohvaćanje stanja biljke u bilo kojoj točci vremena
- **Trag revizije**: Potpuna povijest s informacijama o korisniku i vremenskim oznakama

## 🔧 API krajnje točke

### REST API
- `GET /api/calendar` - Podaci kalendara događaja i podsjetnika
- `GET /uploads/<filename>` - Služenje uploadanih slika

### Temporalni upiti (SQL funkcije)
- `get_plant_history(plant_id)` - Povijest promjena biljke
- `get_plants_needing_attention()` - Biljke koje trebaju skrb

## 🧪 Testiranje značajki

### Dodavanje test podataka
1. Idite na "Biljke" → "Dodaj biljku"
2. Unesite ime biljke i odaberite vrstu
3. Spremite biljku

### Testiranje temporalnih funkcija
```sql
-- Dodajte biljku preko web sučelja, zatim u PostgreSQL-u:
SELECT * FROM plants WHERE id = 1;
UPDATE plants SET location = 'Nova lokacija' WHERE id = 1;
SELECT * FROM get_plant_history(1);
```

### Testiranje automatskih podsjetnika
1. Dodajte događaj "Zalijevanje"
2. Provjerite da li je automatski podsjetnik stvoren
3. Idite na "Podsjetnici" za pregled



## 📄 Licenca

Ovaj projekt je licenciran pod MIT licencom

## 👨‍💻 Autor

Frane Suman - Kolegij Teorija baza podataka  
Razvijeno u akademske svrhe


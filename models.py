from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, date, timedelta
from sqlalchemy import text

db = SQLAlchemy()


class PlantType(db.Model):
    __tablename__ = 'plant_types'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False, unique=True)
    scientific_name = db.Column(db.String(150))
    description = db.Column(db.Text)
    care_instructions = db.Column(db.Text)
    watering_frequency_days = db.Column(db.Integer, default=7)
    fertilizing_frequency_days = db.Column(db.Integer, default=30)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Veza s biljkama
    plants = db.relationship('Plant', backref='plant_type', lazy=True)
    
    def __repr__(self):
        return f'<PlantType {self.name}>'

class Plant(db.Model):
    __tablename__ = 'plants'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    plant_type_id = db.Column(db.Integer, db.ForeignKey('plant_types.id'))
    planted_date = db.Column(db.Date, nullable=False)
    location = db.Column(db.String(100))
    notes = db.Column(db.Text)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
      # Temporalne kolone
    valid_from = db.Column(db.DateTime, default=datetime.utcnow)
    valid_to = db.Column(db.DateTime, default=datetime(9999, 12, 31, 23, 59, 59))
    
    # Veze s drugim tablicama
    events = db.relationship('Event', backref='plant', lazy=True, cascade='all, delete-orphan')
    images = db.relationship('PlantImage', backref='plant', lazy=True, cascade='all, delete-orphan')
    reminders = db.relationship('Reminder', backref='plant', lazy=True, cascade='all, delete-orphan')
    measurements = db.relationship('Measurement', backref='plant', lazy=True, cascade='all, delete-orphan')
    
    @property
    def days_since_planted(self):
        return (date.today() - self.planted_date).days
    
    @property
    def age_text(self):
        days = self.days_since_planted
        if days < 30:
            return f"{days} dana"
        elif days < 365:
            months = days // 30
            return f"{months} mjeseci"
        else:
            years = days // 365
            months = (days % 365) // 30
            if months > 0:
                return f"{years} godina, {months} mjeseci"
            return f"{years} godina"
    
    @property
    def latest_measurement(self):
        """Dohvaća najnovije mjerenje biljke"""
        return (Measurement.query.filter_by(plant_id=self.id)
                .order_by(Measurement.measurement_date.desc()).first())
    
    @property
    def current_height(self):
        """Trenutna visina biljke prema najnovijem mjerenju"""
        latest = self.latest_measurement
        return latest.height_cm if latest and latest.height_cm else None
    
    @property
    def current_health_status(self):
        """Trenutno zdravstveno stanje prema najnovijem mjerenju"""
        latest = self.latest_measurement
        return latest.health_status if latest else None
    
    @property
    def current_health_text(self):
        """Tekstualni opis trenutnog zdravstvenog stanja"""
        latest = self.latest_measurement
        return latest.health_status_text if latest else 'Nema mjerenja'
    
    @property
    def growth_trend(self):
        """Trend rasta u zadnjih 30 dana"""
        recent_measurements = Measurement.query.filter(
            Measurement.plant_id == self.id,
            Measurement.measurement_date >= (datetime.utcnow() - 
                                           timedelta(days=30)),
            Measurement.height_cm.isnot(None)
        ).order_by(Measurement.measurement_date).all()
        
        if len(recent_measurements) < 2:
            return 'Nedovoljno podataka'
        
        first_height = recent_measurements[0].height_cm
        last_height = recent_measurements[-1].height_cm
        
        if last_height > first_height:
            return 'Raste'
        elif last_height < first_height:
            return 'Opada'
        else:
            return 'Stabilno'
    
    @property
    def total_growth(self):
        """Ukupan rast od prvog mjerenja"""
        measurements = Measurement.query.filter(
            Measurement.plant_id == self.id,
            Measurement.height_cm.isnot(None)
        ).order_by(Measurement.measurement_date).all()
        
        if len(measurements) < 2:
            return None
        
        return float(measurements[-1].height_cm - measurements[0].height_cm)
    
    @property
    def measurement_count(self):
        """Broj mjerenja za ovu biljku"""
        return Measurement.query.filter_by(plant_id=self.id).count()
    
    def needs_attention(self):
        """Provjerava treba li biljka pažnju na osnovi mjerenja"""
        latest = self.latest_measurement
        if not latest:
            return True, "Nema mjerenja"
        
        days_since = (datetime.utcnow() - latest.measurement_date).days
        if days_since > 30:
            return True, f"Zadnje mjerenje prije {days_since} dana"
        
        if latest.health_status and latest.health_status <= 2:
            return True, f"Loše zdravstveno stanje ({latest.health_status_text})"
        
        return False, "U dobrom stanju"


    
    def __repr__(self):
        return f'<Plant {self.name}>'

class EventType(db.Model):
    __tablename__ = 'event_types'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), nullable=False, unique=True)
    description = db.Column(db.Text)
    default_reminder_days = db.Column(db.Integer, default=1)
    color = db.Column(db.String(7), default='#007bff')
    
    # Veze
    events = db.relationship('Event', backref='event_type', lazy=True)
    reminders = db.relationship('Reminder', backref='event_type', lazy=True)
    
    def __repr__(self):
        return f'<EventType {self.name}>'

class Event(db.Model):
    __tablename__ = 'events'
    
    id = db.Column(db.Integer, primary_key=True)
    plant_id = db.Column(db.Integer, db.ForeignKey('plants.id'), nullable=False)
    event_type_id = db.Column(db.Integer, db.ForeignKey('event_types.id'))
    event_date = db.Column(db.DateTime, nullable=False)
    description = db.Column(db.Text)
    notes = db.Column(db.Text)
    reminder_date = db.Column(db.DateTime)
    is_completed = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    @property
    def days_until_event(self):
        if self.event_date:
            delta = self.event_date.date() - date.today()
            return delta.days
        return None
    
    @property
    def is_overdue(self):
        if self.event_date:
            return self.event_date < datetime.now() and not self.is_completed
        return False
    
    def __repr__(self):
        return f'<Event {self.id}: {self.event_type.name if self.event_type else "Unknown"} for {self.plant.name if self.plant else "Unknown"}>'

class PlantImage(db.Model):
    __tablename__ = 'plant_images'
    
    id = db.Column(db.Integer, primary_key=True)
    plant_id = db.Column(db.Integer, db.ForeignKey('plants.id'), nullable=False)
    filename = db.Column(db.String(255), nullable=False)
    original_filename = db.Column(db.String(255))
    upload_date = db.Column(db.DateTime, default=datetime.utcnow)
    description = db.Column(db.Text)
    file_size = db.Column(db.Integer)
    mime_type = db.Column(db.String(100))
    
    def __repr__(self):
        return f'<PlantImage {self.filename}>'

class Reminder(db.Model):
    __tablename__ = 'reminders'
    
    id = db.Column(db.Integer, primary_key=True)
    plant_id = db.Column(db.Integer, db.ForeignKey('plants.id'), nullable=False)
    event_type_id = db.Column(db.Integer, db.ForeignKey('event_types.id'))
    reminder_date = db.Column(db.DateTime, nullable=False)
    message = db.Column(db.Text, nullable=False)
    is_sent = db.Column(db.Boolean, default=False)
    is_completed = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    @property
    def days_until_reminder(self):
        if self.reminder_date:
            delta = self.reminder_date.date() - date.today()
            return delta.days
        return None
    
    @property
    def status(self):
        if self.is_completed:
            return 'Završeno'
        elif self.reminder_date < datetime.now() and not self.is_sent:
            return 'Zakasnilo'
        elif self.reminder_date <= datetime.now() + timedelta(days=1):
            return 'Hitno'
        elif self.reminder_date <= datetime.now() + timedelta(days=3):
            return 'Uskoro'
        else:
            return 'Budućnost'
    
    def __repr__(self):
        return f'<Reminder {self.id} for {self.plant.name if self.plant else "Unknown"}>'

class Measurement(db.Model):
    __tablename__ = 'measurements'
    
    id = db.Column(db.Integer, primary_key=True)
    plant_id = db.Column(db.Integer, db.ForeignKey('plants.id'), nullable=False)
    measurement_date = db.Column(db.DateTime, default=datetime.utcnow)
    height_cm = db.Column(db.Numeric(5, 2))
    width_cm = db.Column(db.Numeric(5, 2))
    leaf_count = db.Column(db.Integer)
    flower_count = db.Column(db.Integer)
    health_status = db.Column(db.Integer)  # 1-5 skala
    notes = db.Column(db.Text)
    
    @property
    def health_status_text(self):
        if self.health_status:
            statuses = {
                1: 'Vrlo loše',
                2: 'Loše', 
                3: 'Osrednje',
                4: 'Dobro',
                5: 'Izvrsno'
            }
            return statuses.get(self.health_status, 'Nepoznato')
        return 'Nije izmjereno'
    
    def __repr__(self):
        return f'<Measurement {self.id} for {self.plant.name if self.plant else "Unknown"}>'

# Pomoćne klase za temporalne upite
class PlantHistory(db.Model):
    __tablename__ = 'plants_history'
    
    id = db.Column(db.Integer)
    name = db.Column(db.String(100))
    plant_type_id = db.Column(db.Integer)
    planted_date = db.Column(db.Date)
    location = db.Column(db.String(100))
    notes = db.Column(db.Text)
    is_active = db.Column(db.Boolean)
    created_at = db.Column(db.DateTime)
    updated_at = db.Column(db.DateTime)
    valid_from = db.Column(db.DateTime)
    valid_to = db.Column(db.DateTime)
    operation_type = db.Column(db.String(10))
    changed_by = db.Column(db.String(100))
    changed_at = db.Column(db.DateTime, primary_key=True)
    
    def __repr__(self):
        return f'<PlantHistory {self.id}: {self.operation_type} at {self.changed_at}>'

# Pomoćne funkcije za rad s bazom podataka
def get_active_plants():
    """Dohvaća aktivne biljke koristeći PostgreSQL funkciju"""
    result = db.session.execute(text("SELECT * FROM get_active_plants()"))
    return result.fetchall()

def get_plant_history(plant_id):
    """Dohvaća povijest biljke"""
    result = db.session.execute(text("SELECT * FROM get_plant_history(:plant_id)"), {"plant_id": plant_id})
    return result.fetchall()

def get_plant_at_time(plant_id, time_param):
    """Dohvaća stanje biljke u određenom vremenu"""
    result = db.session.execute(
        text("SELECT * FROM get_plant_at_time(:plant_id, :time_param)"), 
        {"plant_id": plant_id, "time_param": time_param}
    )
    return result.fetchone()

def create_event_with_reminder(plant_id, event_type_id, event_date, description=None, custom_reminder_days=None):
    """Kreira događaj s automatskim podsjetnikom"""
    result = db.session.execute(
        text("SELECT create_event_with_reminder(:plant_id, :event_type_id, :event_date, :description, :custom_reminder_days)"),
        {
            "plant_id": plant_id,
            "event_type_id": event_type_id, 
            "event_date": event_date,
            "description": description,
            "custom_reminder_days": custom_reminder_days
        }
    )
    db.session.commit()
    return result.scalar()

def get_plant_growth_stats(plant_id):
    """Dohvaća statistike rasta biljke"""
    result = db.session.execute(text("SELECT * FROM get_plant_growth_stats(:plant_id)"), {"plant_id": plant_id})
    return result.fetchone()

def get_plants_needing_attention():
    """Dohvaća biljke koje trebaju pažnju"""
    result = db.session.execute(text("SELECT * FROM get_plants_needing_attention()"))
    return result.fetchall()

def get_upcoming_reminders(days_ahead=7):
    """Dohvaća nadolazeće podsjetrike"""
    result = db.session.execute(text("SELECT * FROM get_upcoming_reminders(:days_ahead)"), {"days_ahead": days_ahead})
    return result.fetchall()

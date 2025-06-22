# -*- coding: utf-8 -*-
import os
import uuid
from datetime import datetime
from flask import (Flask, render_template, request, redirect, url_for, 
                   flash, send_from_directory)
from markupsafe import Markup
from flask_migrate import Migrate
from werkzeug.utils import secure_filename
from werkzeug.exceptions import RequestEntityTooLarge
from dotenv import load_dotenv
from models import (db, Plant, PlantType, Event, EventType, PlantImage,
                    Reminder, Measurement,
                    get_plant_history, get_plants_needing_attention,
                    get_upcoming_reminders, get_plant_growth_stats)
from forms import (PlantForm, EventForm, MeasurementForm,
                   ImageUploadForm)

# Učitaj environment varijable
load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY') or 'dev-secret-key'
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or \
    'postgresql://postgres:suman@localhost/grow_app'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Postavke za UTF-8 encoding
app.config['JSON_AS_ASCII'] = False

# Upload konfiguracija
UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER') or 'uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

# Kreiraj upload direktorij ako ne postoji
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Inicijaliziraj ekstenzije
db.init_app(app)
migrate = Migrate(app, db)

# Postavi UTF-8 encoding za sve odgovore
@app.after_request
def after_request(response):
    response.headers['Content-Type'] = 'text/html; charset=utf-8'
    return response

# Template filters i context processors
@app.template_filter('datetime')
def datetime_filter(dt):
    """Format datetime objekta"""
    if dt:
        return dt.strftime('%d.%m.%Y %H:%M')
    return ''

@app.template_filter('date')
def date_filter(dt):
    """Format datuma"""
    if dt:
        return dt.strftime('%d.%m.%Y')
    return ''

@app.template_filter('nl2br')
def nl2br_filter(text):
    """Convert newlines to HTML <br> tags"""
    if text:
        return Markup(text.replace('\n', '<br>'))
    return ''

@app.context_processor
def inject_current_date():
    """Dodaj trenutni datum u sve template-ove"""
    return {
        'current_date': datetime.now(),
        'today': datetime.now().strftime('%d.%m.%Y')
    }


def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@app.route('/')
def index():
    """Glavna stranica s pregledom"""    # Dohvati osnovne statistike
    total_plants = Plant.query.filter_by(is_active=True).count()
    total_events = Event.query.count()
    
    # Nadolazeći podsjetnici (sljedeći 7 dana)
    upcoming_reminders = get_upcoming_reminders(7)
    
    # Biljke koje trebaju pažnju
    plants_needing_attention = get_plants_needing_attention()
    
    # Najnoviji događaji
    recent_events = Event.query.join(Plant).join(EventType)\
        .filter(Plant.is_active == True)\
        .order_by(Event.created_at.desc())\
        .limit(5).all()
    
    # Najnovije slike
    recent_images = PlantImage.query.join(Plant)\
        .filter(Plant.is_active == True)\
        .order_by(PlantImage.upload_date.desc())\
        .limit(6).all()
    
    return render_template('index.html',
                          total_plants=total_plants,
                          total_events=total_events,
                          upcoming_reminders=upcoming_reminders,
                          plants_needing_attention=plants_needing_attention,
                          recent_events=recent_events,
                          recent_images=recent_images)


@app.route('/plants')
def plants():
    """Lista svih biljaka"""
    page = request.args.get('page', 1, type=int)
    search = request.args.get('search', '')
    plant_type_id = request.args.get('type', 0, type=int)
    
    query = Plant.query.filter_by(is_active=True)
    
    if search:
        query = query.filter(Plant.name.contains(search))
    
    if plant_type_id > 0:
        query = query.filter_by(plant_type_id=plant_type_id)
    
    plants = query.order_by(Plant.created_at.desc())\
        .paginate(page=page, per_page=12, error_out=False)
    
    plant_types = PlantType.query.all()
    
    return render_template('plants/list.html', 
                          plants=plants, 
                          plant_types=plant_types,
                          search=search,
                          selected_type=plant_type_id)


@app.route('/plants/<int:id>')
def plant_detail(id):
    """Detalji biljke"""
    plant = Plant.query.get_or_404(id)
    
    # Dohvati statistic rasta
    growth_stats = get_plant_growth_stats(id)
    
    # Najnoviji događaji
    events = Event.query.filter_by(plant_id=id)\
        .order_by(Event.event_date.desc()).limit(10).all()
    
    # Najnovije slike
    images = PlantImage.query.filter_by(plant_id=id)\
        .order_by(PlantImage.upload_date.desc()).all()
    
    # Najnovija mjerenja
    measurements = Measurement.query.filter_by(plant_id=id)\
        .order_by(Measurement.measurement_date.desc()).limit(5).all()
    
    # Nadolazeći podsjetnici
    reminders = Reminder.query.filter_by(plant_id=id, is_completed=False)\
        .order_by(Reminder.reminder_date.asc()).all()
    
    return render_template('plants/detail.html',
                          plant=plant,
                          growth_stats=growth_stats,
                          events=events,
                          images=images,
                          measurements=measurements,
                          reminders=reminders)


@app.route('/plants/add', methods=['GET', 'POST'])
def add_plant():
    """Dodaj novu biljku"""
    form = PlantForm()
    
    if form.validate_on_submit():
        plant = Plant(
            name=form.name.data,
            plant_type_id=form.plant_type_id.data if form.plant_type_id.data > 0 else None,
            planted_date=form.planted_date.data,
            location=form.location.data,
            notes=form.notes.data
        )
        
        db.session.add(plant)
        db.session.commit()
        
        flash(f'Biljka "{plant.name}" je uspješno dodana!', 'success')
        return redirect(url_for('plant_detail', id=plant.id))
    
    return render_template('plants/form.html', form=form, title='Dodaj biljku')


@app.route('/plants/<int:id>/edit', methods=['GET', 'POST'])
def edit_plant(id):
    """Uredi biljku"""
    plant = Plant.query.get_or_404(id)
    form = PlantForm(obj=plant)
    
    if form.validate_on_submit():
        form.populate_obj(plant)
        db.session.commit()
        
        flash(f'Biljka "{plant.name}" je uspješno ažurirana!', 'success')
        return redirect(url_for('plant_detail', id=plant.id))
    
    return render_template('plants/form.html', form=form, 
                          title=f'Uredi biljku: {plant.name}')


@app.route('/plants/<int:id>/history')
def plant_history(id):
    """Prikaz temporalne povijesti biljke"""
    plant = Plant.query.get_or_404(id)
    history = get_plant_history(id)
    
    return render_template('plants/history.html', 
                          plant=plant, 
                          history=history)


@app.route('/events')
def events():
    """Lista događaja"""
    page = request.args.get('page', 1, type=int)
    plant_id = request.args.get('plant', 0, type=int)
    event_type_id = request.args.get('type', 0, type=int)
    
    query = Event.query.join(Plant).filter(Plant.is_active == True)
    
    if plant_id > 0:
        query = query.filter(Event.plant_id == plant_id)
    
    if event_type_id > 0:
        query = query.filter(Event.event_type_id == event_type_id)
    
    events = query.order_by(Event.event_date.desc())\
        .paginate(page=page, per_page=20, error_out=False)
    
    plants = Plant.query.filter_by(is_active=True).all()
    event_types = EventType.query.all()
    
    return render_template('events/list.html',
                          events=events,
                          plants=plants,
                          event_types=event_types,
                          selected_plant=plant_id,
                          selected_type=event_type_id)


@app.route('/events/add', methods=['GET', 'POST'])
def add_event():
    """Dodaj novi događaj"""
    form = EventForm()
    
    if form.validate_on_submit():
        event = Event(
            plant_id=form.plant_id.data,
            event_type_id=form.event_type_id.data,
            event_date=form.event_date.data,
            description=form.description.data,
            notes=form.notes.data,
            is_completed=form.is_completed.data
        )
        
        db.session.add(event)
        db.session.commit()
        
        flash('Događaj je uspješno dodan!', 'success')
        return redirect(url_for('events'))
    
    # Postavi defaultni datum na danas
    if not form.event_date.data:
        form.event_date.data = datetime.now()
    
    return render_template('events/form.html', form=form, title='Dodaj događaj')


@app.route('/events/<int:id>/complete', methods=['POST'])
def complete_event(id):
    """Označi događaj kao završen"""
    event = Event.query.get_or_404(id)
    event.is_completed = True
    db.session.commit()
    
    flash('Događaj je označen kao završen!', 'success')
    return redirect(request.referrer or url_for('events'))


@app.route('/events/<int:id>/edit', methods=['GET', 'POST'])
def edit_event(id):
    """Uredi događaj"""
    event = Event.query.get_or_404(id)
    form = EventForm(obj=event)
    
    if form.validate_on_submit():
        form.populate_obj(event)
        db.session.commit()
        
        flash('Događaj je uspješno ažuriran!', 'success')
        return redirect(url_for('events'))
    
    return render_template('events/form.html', form=form, 
                          title=f'Uredi događaj: {event.event_type.name if event.event_type else "Nepoznato"}')


@app.route('/events/<int:id>/delete', methods=['POST'])
def delete_event(id):
    """Obriši događaj"""
    event = Event.query.get_or_404(id)
    db.session.delete(event)
    db.session.commit()
    
    flash('Događaj je uspješno obrisan!', 'success')
    return redirect(request.referrer or url_for('events'))


@app.route('/measurements')
def measurements():
    """Lista mjerenja"""
    page = request.args.get('page', 1, type=int)
    plant_id = request.args.get('plant', 0, type=int)
    
    query = Measurement.query.join(Plant).filter(Plant.is_active == True)
    
    if plant_id > 0:
        query = query.filter(Measurement.plant_id == plant_id)
    
    measurements = query.order_by(Measurement.measurement_date.desc())\
        .paginate(page=page, per_page=20, error_out=False)
    
    plants = Plant.query.filter_by(is_active=True).all()
    
    return render_template('measurements/list.html',
                          measurements=measurements,
                          plants=plants,
                          selected_plant=plant_id)


@app.route('/measurements/add', methods=['GET', 'POST'])
def add_measurement():
    """Dodaj novo mjerenje"""
    form = MeasurementForm()
    
    # Preselektiraj biljku iz URL parametra
    plant_id = request.args.get('plant', 0, type=int)
    if plant_id > 0 and not form.plant_id.data:
        form.plant_id.data = plant_id
    
    if form.validate_on_submit():
        measurement = Measurement(
            plant_id=form.plant_id.data,
            measurement_date=form.measurement_date.data,
            height_cm=form.height_cm.data,
            width_cm=form.width_cm.data,
            leaf_count=form.leaf_count.data,
            flower_count=form.flower_count.data,
            health_status=form.health_status.data if form.health_status.data > 0 else None,
            notes=form.notes.data
        )
        
        db.session.add(measurement)
        db.session.commit()
        
        flash('Mjerenje je uspješno dodano!', 'success')
        return redirect(url_for('plant_detail', id=form.plant_id.data))
    
    # Postavi defaultni datum na danas
    if not form.measurement_date.data:
        form.measurement_date.data = datetime.now()
    
    return render_template('measurements/form.html', form=form, title='Dodaj mjerenje')


@app.route('/measurements/<int:id>/edit', methods=['GET', 'POST'])
def edit_measurement(id):
    """Uredi mjerenje"""
    measurement = Measurement.query.get_or_404(id)
    form = MeasurementForm(obj=measurement)
    
    if form.validate_on_submit():
        form.populate_obj(measurement)
        db.session.commit()
        flash('Mjerenje je uspješno ažurirano!', 'success')
        return redirect(url_for('measurements'))
    
    return render_template('measurements/form.html', form=form, title='Uredi mjerenje', measurement=measurement)


@app.route('/measurements/<int:id>/delete', methods=['POST'])
def delete_measurement(id):
    """Obriši mjerenje"""
    measurement = Measurement.query.get_or_404(id)
    db.session.delete(measurement)
    db.session.commit()
    flash('Mjerenje je uspješno obrisano!', 'success')
    return redirect(url_for('measurements'))


@app.route('/gallery')
def gallery():
    """Galerija slika"""
    page = request.args.get('page', 1, type=int)
    plant_id = request.args.get('plant', 0, type=int)
    
    query = PlantImage.query.join(Plant).filter(Plant.is_active == True)
    
    if plant_id > 0:
        query = query.filter(PlantImage.plant_id == plant_id)
    
    images = query.order_by(PlantImage.upload_date.desc())\
        .paginate(page=page, per_page=24, error_out=False)
    
    plants = Plant.query.filter_by(is_active=True).all()
    
    return render_template('gallery/list.html',
                          images=images,
                          plants=plants,
                          selected_plant=plant_id)


@app.route('/gallery/upload', methods=['GET', 'POST'])
def upload_image():
    """Učitaj sliku"""
    form = ImageUploadForm()
    
    if form.validate_on_submit():
        file = form.image.data
        
        if file and allowed_file(file.filename):
            # Generiraj jedinstveno ime datoteke
            filename = secure_filename(file.filename)
            name, ext = os.path.splitext(filename)
            unique_filename = f"{uuid.uuid4().hex}{ext}"
            
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], unique_filename)
            file.save(filepath)
            
            # Stvori zapis u bazi
            image = PlantImage(
                plant_id=form.plant_id.data,
                filename=unique_filename,
                original_filename=filename,
                description=form.description.data,
                file_size=os.path.getsize(filepath),
                mime_type=file.content_type
            )
            
            db.session.add(image)
            db.session.commit()
            
            flash('Slika je uspješno učitana!', 'success')
            return redirect(url_for('gallery'))
    
    return render_template('gallery/upload.html', form=form, title='Učitaj sliku')


@app.route('/uploads/<filename>')
def uploaded_file(filename):
    """Serviraj učitane datoteke"""
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


@app.route('/reminders')
def reminders():
    """Lista podsjetnika"""
    active_reminders = Reminder.query.filter_by(is_completed=False)\
        .join(Plant).filter(Plant.is_active == True)\
        .order_by(Reminder.reminder_date.asc()).all()
    
    return render_template('reminders/list.html', reminders=active_reminders)


@app.route('/reminders/<int:id>/complete', methods=['POST'])
def complete_reminder(id):
    """Označi podsjetnik kao završen"""
    reminder = Reminder.query.get_or_404(id)
    reminder.is_completed = True
    db.session.commit()
    
    flash('Podsjetnik je označen kao završen!', 'success')
    return redirect(request.referrer or url_for('reminders'))


@app.errorhandler(404)
def not_found_error(error):
    return render_template('errors/404.html'), 404


@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return render_template('errors/500.html'), 500


@app.errorhandler(RequestEntityTooLarge)
def too_large(error):
    flash('Datoteka je prevelika. Maksimalna veličina je 16MB.', 'error')
    return redirect(request.url)


# CLI naredbe
@app.cli.command()
def init_db():
    """Inicijaliziraj bazu podataka"""
    db.create_all()
    print('Baza podataka je inicijalizirana.')


@app.cli.command()
def seed_db():
    """Dodaj početne podatke"""
    # Provjeri postoje li već podaci
    if PlantType.query.first():
        print('Podaci već postoje.')
        return
    
    # Dodaj osnovne tipove biljaka (već su u SQL skripti)
    print('Početni podaci su dodani kroz SQL skripte.')


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

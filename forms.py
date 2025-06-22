from flask_wtf import FlaskForm
from flask_wtf.file import FileField, FileAllowed
from wtforms import (StringField, TextAreaField, SelectField, DateField,
                     DateTimeField, IntegerField, DecimalField, BooleanField,
                     SubmitField)
from wtforms.validators import DataRequired, Length, NumberRange, Optional
from models import PlantType, EventType


class PlantForm(FlaskForm):
    name = StringField('Naziv biljke', 
                      validators=[DataRequired(), Length(min=1, max=100)])
    plant_type_id = SelectField('Tip biljke', coerce=int,
                               validators=[DataRequired()])
    planted_date = DateField('Datum sadnje', validators=[DataRequired()])
    location = StringField('Lokacija', validators=[Length(max=100)])
    notes = TextAreaField('Bilješke')
    submit = SubmitField('Spremi')
    
    def __init__(self, *args, **kwargs):
        super(PlantForm, self).__init__(*args, **kwargs)
        self.plant_type_id.choices = [(0, 'Odaberite tip biljke')] + [
            (pt.id, pt.name) for pt in PlantType.query.all()
        ]


class PlantTypeForm(FlaskForm):
    name = StringField('Naziv', 
                      validators=[DataRequired(), Length(min=1, max=100)])
    scientific_name = StringField('Znanstveni naziv',
                                 validators=[Length(max=150)])
    description = TextAreaField('Opis')
    care_instructions = TextAreaField('Upute za njegu')
    watering_frequency_days = IntegerField('Frekvencija zalijevanja (dani)',
                                         validators=[NumberRange(min=1, max=365)],
                                         default=7)
    fertilizing_frequency_days = IntegerField('Frekvencija gnojenja (dani)',
                                            validators=[NumberRange(min=1, max=365)],
                                            default=30)
    submit = SubmitField('Spremi')


class EventForm(FlaskForm):
    plant_id = SelectField('Biljka', coerce=int, validators=[DataRequired()])
    event_type_id = SelectField('Tip događaja', coerce=int,
                               validators=[DataRequired()])
    event_date = DateTimeField('Datum i vrijeme događaja',
                              validators=[DataRequired()],
                              format='%Y-%m-%d %H:%M')
    description = TextAreaField('Opis')
    notes = TextAreaField('Bilješke')
    is_completed = BooleanField('Završeno')
    submit = SubmitField('Spremi')
    
    def __init__(self, *args, **kwargs):
        super(EventForm, self).__init__(*args, **kwargs)
        from models import Plant
        self.plant_id.choices = [(0, 'Odaberite biljku')] + [
            (p.id, p.name) for p in Plant.query.filter_by(is_active=True).all()        ]
        self.event_type_id.choices = [(0, 'Odaberite tip događaja')] + [
            (et.id, et.name) for et in EventType.query.all()
        ]


class MeasurementForm(FlaskForm):
    plant_id = SelectField('Biljka', coerce=int, validators=[DataRequired()])
    measurement_date = DateTimeField('Datum mjerenja',
                                    validators=[DataRequired()],
                                    format='%Y-%m-%d %H:%M')
    height_cm = DecimalField('Visina (cm)', validators=[Optional(),
                            NumberRange(min=0, max=999.99)], places=2)
    width_cm = DecimalField('Širina (cm)', validators=[Optional(),
                           NumberRange(min=0, max=999.99)], places=2)
    leaf_count = IntegerField('Broj listova', validators=[Optional(),
                             NumberRange(min=0, max=9999)])
    flower_count = IntegerField('Broj cvijetova', validators=[Optional(),
                               NumberRange(min=0, max=9999)])
    health_status = SelectField('Zdravstveno stanje', coerce=int,
                               validators=[Optional()],
                               choices=[
                                   (0, 'Odaberite stanje'),
                                   (1, '1 - Vrlo loše'),
                                   (2, '2 - Loše'),
                                   (3, '3 - Osrednje'),
                                   (4, '4 - Dobro'),
                                   (5, '5 - Izvrsno')
                               ])
    notes = TextAreaField('Bilješke')
    submit = SubmitField('Spremi mjerenje')
    
    def __init__(self, *args, **kwargs):
        super(MeasurementForm, self).__init__(*args, **kwargs)
        from models import Plant
        self.plant_id.choices = [(0, 'Odaberite biljku')] + [
            (p.id, p.name) for p in Plant.query.filter_by(is_active=True).all()
        ]


class ReminderForm(FlaskForm):
    plant_id = SelectField('Biljka', coerce=int, validators=[DataRequired()])
    event_type_id = SelectField('Tip događaja', coerce=int,
                               validators=[DataRequired()])
    reminder_date = DateTimeField('Datum podsjetnika',
                                 validators=[DataRequired()],
                                 format='%Y-%m-%d %H:%M')
    message = TextAreaField('Poruka', validators=[DataRequired()])
    submit = SubmitField('Stvori podsjetnik')
    
    def __init__(self, *args, **kwargs):
        super(ReminderForm, self).__init__(*args, **kwargs)
        from models import Plant
        self.plant_id.choices = [(0, 'Odaberite biljku')] + [
            (p.id, p.name) for p in Plant.query.filter_by(is_active=True).all()
        ]
        self.event_type_id.choices = [(0, 'Odaberite tip događaja')] + [
            (et.id, et.name) for et in EventType.query.all()
        ]


class ImageUploadForm(FlaskForm):
    plant_id = SelectField('Biljka', coerce=int, validators=[DataRequired()])
    image = FileField('Slika', validators=[
        DataRequired(),
        FileAllowed(['jpg', 'jpeg', 'png', 'gif'], 
                   'Samo jpg, jpeg, png i gif datoteke!')
    ])
    description = TextAreaField('Opis slike')
    submit = SubmitField('Učitaj sliku')
    
    def __init__(self, *args, **kwargs):
        super(ImageUploadForm, self).__init__(*args, **kwargs)
        from models import Plant
        self.plant_id.choices = [(0, 'Odaberite biljku')] + [
            (p.id, p.name) for p in Plant.query.filter_by(is_active=True).all()
        ]


class SearchForm(FlaskForm):
    """Obrazac za pretraživanje"""
    query = StringField('Pretraži', validators=[Length(max=200)])
    plant_type = SelectField('Filtriraj po tipu', coerce=int)
    date_from = DateField('Od datuma', validators=[Optional()])
    date_to = DateField('Do datuma', validators=[Optional()])
    submit = SubmitField('Pretraži')
    
    def __init__(self, *args, **kwargs):
        super(SearchForm, self).__init__(*args, **kwargs)
        self.plant_type.choices = [(0, 'Svi tipovi')] + [
            (pt.id, pt.name) for pt in PlantType.query.all()
        ]

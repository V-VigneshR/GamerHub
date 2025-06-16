from flask_wtf import FlaskForm
from wtforms import StringField, IntegerField, TextAreaField, SelectField, PasswordField
from wtforms.validators import DataRequired, Length, NumberRange

class BoardGameForm(FlaskForm):
    name = StringField('Name', validators=[DataRequired(), Length(max=100)])
    level = IntegerField('Level', validators=[NumberRange(min=1, max=10)])
    min_players = IntegerField('min_players', validators=[NumberRange(min=1)])
    max_players = IntegerField('max_players', validators=[NumberRange(min=1)])
    game_type = SelectField('game_type', choices=[
        ('strategy', 'Strategy'),
        ('party', 'Party'),
        ('card', 'Card Game'),
        ('dice', 'Dice Game')
    ], validators=[DataRequired()])

class ReviewForm(FlaskForm):
    text = TextAreaField('Review', validators=[DataRequired()])
    rating = IntegerField('Rating (1–5 Stars)', validators=[
    DataRequired(), NumberRange(min=1, max=5)
])

class UserForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired(), Length(max=100)])
    password = PasswordField('Password', validators=[DataRequired()])
    role = SelectField('Role', choices=[('USER', 'User'), ('MANAGER', 'Manager')])

class LoginForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired()])
    password = PasswordField('Password', validators=[DataRequired()])
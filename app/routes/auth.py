from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_user, logout_user, current_user, login_required
from app.models import db, User
from app.forms import UserForm, LoginForm

auth = Blueprint('auth', __name__, url_prefix='/auth')


@auth.route('/new_user', methods=['GET', 'POST'])
def new_user():
    if current_user.is_authenticated:
        flash("You're already logged in.", "info")
        return redirect(url_for('main.home'))

    form = UserForm()
    if form.validate_on_submit():
        existing_user = User.query.filter_by(username=form.username.data).first()
        if existing_user:
            flash('Username already exists. Choose another one.', 'error')
            return redirect(url_for('auth.new_user'))

        new_user = User(
            username=form.username.data,
            role=form.role.data
        )
        new_user.set_password(form.password.data)
        db.session.add(new_user)
        db.session.commit()

        flash(f"User {new_user.username} created! Please log in.", "success")
        return redirect(url_for('auth.login'))

    return render_template('new_user.html', form=form)


@auth.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        flash("You're already logged in.", "info")
        return redirect(url_for('main.home'))

    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user and user.check_password(form.password.data):
            login_user(user)
            flash(f"Welcome back, {user.username}!", "success")
            return redirect(url_for('main.home'))  # 👈 Always redirect to homepage after login

        flash('Invalid username or password.', 'error')

    return render_template('login.html', form=form)

@auth.route('/logout', methods=['POST'])
@login_required
def logout():
    logout_user()
    flash("You have been logged out.", "info")
    return redirect(url_for('main.home'))

from flask import Flask, render_template
from flask_login import LoginManager
from flask_bcrypt import Bcrypt
from flask_mail import Mail
from config import config
from app.models import db, User
from dotenv import load_dotenv
import os
from app.context_processors import inject_flagged_review_count

load_dotenv()

# Global extensions
bcrypt = Bcrypt()
mail = Mail()

def create_app(config_name='default'):
    base_dir = os.path.abspath(os.path.dirname(__file__))
    template_dir = os.path.join(os.path.dirname(base_dir), 'templates')
    static_dir = os.path.join(os.path.dirname(base_dir), 'static')
    
    app = Flask(__name__, template_folder=template_dir, static_folder=static_dir)
    app.config.from_object(config[config_name])

    # Initialize extensions
    db.init_app(app)
    app.context_processor(inject_flagged_review_count)
    bcrypt.init_app(app)
    mail.init_app(app)

    # Setup Login Manager
    login_manager = LoginManager(app)
    login_manager.login_view = 'auth.login'

    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))
    
    # Register Blueprints
    from .routes import main, auth, api
    app.register_blueprint(main)
    app.register_blueprint(auth)
    app.register_blueprint(api)

    # Error Handlers
    @app.errorhandler(404)
    def not_found_error(error):
        return render_template('error/404.html'), 404

    @app.errorhandler(403)
    def forbidden_error(error):
        return render_template('error/permission-denied.html'), 403
    
    # Only create tables in development mode or when explicitly requested
    # Remove automatic db.create_all() from here
    # This will be handled in run.py for development and via migration scripts for production

    return app

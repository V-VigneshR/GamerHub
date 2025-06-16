from flask_mail import Message
from flask import current_app
from app import mail

def send_email(subject, recipients, body):
    with current_app.app_context():
        msg = Message(subject=subject, recipients=recipients, body=body)
        mail.send(msg)

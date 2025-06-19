import unittest
from flask import url_for
from app import create_app, db
from app.models import User
from werkzeug.security import generate_password_hash

class RouteTests(unittest.TestCase):

    def setUp(self):
        self.app = create_app()
        self.app.config['TESTING'] = True
        self.app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.app.config['WTF_CSRF_ENABLED'] = False

        self.client = self.app.test_client()
        self.ctx = self.app.app_context()
        self.ctx.push()
        db.create_all()

    def tearDown(self):
        db.session.remove()
        db.drop_all()
        self.ctx.pop()

    def test_home_route(self):
        """Test if home page loads correctly with or without games"""
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Digital Games', response.data)

    def test_new_user_get(self):
        """GET request to /new_user should load the registration form"""
        response = self.client.get('/auth/new_user')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Add a User', response.data)
        self.assertIn(b'User name:', response.data)

    def test_new_user_post_success(self):
        """POST request should create a new user if valid data is given"""
        response = self.client.post('/auth/new_user', data={
            'username': 'testuser',
            'password': 'password123',
            'role': 'USER'
        }, follow_redirects=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn(b'User testuser created! Please log in.', response.data)

        user = User.query.filter_by(username='testuser').first()
        self.assertIsNotNone(user)

    def test_new_user_post_duplicate_username(self):
        """POST should fail if username already exists"""
        user = User(username='dupeuser', role='USER')
        user.set_password('pass')
        db.session.add(user)
        db.session.commit()

        response = self.client.post('/auth/new_user', data={
            'username': 'dupeuser',
            'password': 'newpass',
            'role': 'USER'
        }, follow_redirects=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Username already exists', response.data)

if __name__ == '__main__':
    unittest.main()

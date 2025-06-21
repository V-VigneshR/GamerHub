from app import create_app, db
import os

def init_database(app):
    """Initialize database with proper error handling"""
    with app.app_context():
        try:
            # Ensure instance directory exists
            instance_path = app.instance_path
            if not os.path.exists(instance_path):
                os.makedirs(instance_path, exist_ok=True)
                print(f"Created instance directory: {instance_path}")
            
            # Create all tables
            db.create_all()
            print("✓ Database tables created successfully")
            
            # Test database write access
            from sqlalchemy import text
            db.session.execute(text("SELECT 1"))
            db.session.commit()
            print("✓ Database write access verified")
            
        except Exception as e:
            print(f"❌ Database initialization failed: {e}")
            print("This might be a permissions issue.")
            raise

app = create_app()

if __name__ == '__main__':
    print("=== Starting GamerHub Application ===")
    
    # Initialize database only when running directly (development)
    init_database(app)
    
    print("Starting Flask development server...")
    app.run(host="0.0.0.0", port=5000, debug=True)

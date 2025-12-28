"""
Database configuration - Engine, Session, Base
"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# Database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://admin:admin@localhost:5432/kingdom")

# Create engine
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """Get database session for request"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database tables"""
    # Import all models to register them with Base
    from .models import User, PlayerState, Kingdom, UserKingdom, Contract, Property, CityBoundary, CheckInHistory
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created")


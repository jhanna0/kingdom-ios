"""
Database configuration - Engine, Session, Base
"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# Database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://admin:admin@localhost:5432/kingdom")

# Create engine with Lambda-optimized settings
engine = create_engine(
    DATABASE_URL,
    pool_size=1,  # Small pool for Lambda
    max_overflow=0,  # No overflow connections
    pool_pre_ping=True,  # Verify connection before using
    pool_recycle=3600,  # Recycle connections after 1 hour
    connect_args={
        "connect_timeout": 5,  # 5 second connection timeout
    }
)
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


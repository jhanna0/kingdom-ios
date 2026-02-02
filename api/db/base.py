"""
Database configuration - Engine, Session, Base
"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
import json
import boto3
from botocore.exceptions import ClientError

def get_database_url():
    """Get database URL from Secrets Manager or environment variable"""
    # Check if we're using Secrets Manager
    secret_name = os.getenv("RDS_SECRET_NAME")
    
    if secret_name:
        # Fetch credentials from Secrets Manager
        try:
            client = boto3.client('secretsmanager', region_name='us-east-1')
            response = client.get_secret_value(SecretId=secret_name)
            secret = json.loads(response['SecretString'])
            
            # Build DATABASE_URL from components
            username = secret['username']
            password = secret['password']
            endpoint = os.getenv("RDS_ENDPOINT")
            port = os.getenv("RDS_PORT", "5432")
            database = os.getenv("RDS_DATABASE", "postgres")
            
            return f"postgresql://{username}:{password}@{endpoint}:{port}/{database}"
        except ClientError as e:
            print(f"❌ Error fetching secret: {e}")
            raise
    
    # Fallback to DATABASE_URL environment variable (for local dev)
    return os.getenv("DATABASE_URL", "postgresql://admin:admin@localhost:5432/kingdom")

# Database URL from environment or Secrets Manager
DATABASE_URL = get_database_url()

# Create engine with Lambda-optimized settings
engine = create_engine(
    DATABASE_URL,
    pool_size=10,  # Small pool for Lambda
    max_overflow=10,  # No overflow connections
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
    from .models import (
        User, PlayerState, Kingdom, UserKingdom, Contract, Property, 
        CityBoundary, CheckInHistory, PlayerActivityLog
    )
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created")


"""
User model - Authentication and account data ONLY
"""
from sqlalchemy import Column, String, DateTime, Boolean, BigInteger, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime

from ..base import Base


class User(Base):
    """
    User accounts - authentication and profile only
    Game state is in PlayerState table
    Supports Apple Sign In
    """
    __tablename__ = "users"
    
    # Primary key - PostgreSQL auto-incrementing integer
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    
    # Authentication - OAuth providers
    apple_user_id = Column(String, unique=True, nullable=False, index=True)
    email = Column(String, nullable=True)
    
    # Profile
    display_name = Column(String, nullable=False)
    avatar_url = Column(String, nullable=True)
    
    # Hometown - for unique display_name constraint
    hometown_kingdom_id = Column(String, nullable=True, index=True)
    
    # Account status
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    last_login = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationships
    player_state = relationship("PlayerState", uselist=False, backref="user", cascade="all, delete-orphan")
    kingdoms = relationship("UserKingdom", back_populates="user")
    contracts = relationship("Contract", back_populates="creator", foreign_keys="Contract.created_by")
    
    # Unique constraint: display_name must be unique per hometown
    __table_args__ = (
        UniqueConstraint('display_name', 'hometown_kingdom_id', name='unique_name_per_hometown'),
    )
    
    def __repr__(self):
        return f"<User(id='{self.id}', display_name='{self.display_name}')>"

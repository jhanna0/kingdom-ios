"""
Item Model - Single source of truth for all game items
Synced from code (routers/resources.py RESOURCES dict) on API startup
"""
from sqlalchemy import Column, String, Text, Integer, Boolean, DateTime
from sqlalchemy.sql import func
from ..base import Base


class Item(Base):
    """
    Reference table for all game items.
    
    This table is synced from the RESOURCES dict in routers/resources.py on startup.
    Code remains authoritative - this table just provides DB-level queryability and FK constraints.
    """
    __tablename__ = "items"
    
    id = Column(String(64), primary_key=True)  # e.g. "meat", "sinew", "iron"
    display_name = Column(String(128), nullable=False)
    icon = Column(String(64), nullable=False)  # SF Symbol name
    color = Column(String(32), nullable=False)  # SwiftUI color name
    description = Column(Text)
    category = Column(String(32), nullable=False)  # "currency", "material", "consumable", "crafting"
    display_order = Column(Integer, default=0)
    is_tradeable = Column(Boolean, default=True)  # Can be sold on market
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


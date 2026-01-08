"""
Player Inventory Model
======================
Stores player items with quantities. Item definitions live in code (resources.py).
This is the proper way to handle items - NOT columns per item type!
"""
from sqlalchemy import Column, Integer, BigInteger, String, ForeignKey, UniqueConstraint
from ..base import Base


class PlayerInventory(Base):
    """
    Player inventory - stores item_id + quantity pairs.
    
    Item definitions (name, icon, etc) come from api/routers/resources.py
    This table just tracks what players own.
    """
    __tablename__ = "player_inventory"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    item_id = Column(String, nullable=False)  # e.g. "sinew", "meat", "hunting_bow"
    quantity = Column(Integer, default=1, nullable=False)
    
    # Each player can only have one row per item type
    __table_args__ = (
        UniqueConstraint('user_id', 'item_id', name='uq_player_item'),
    )


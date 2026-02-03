"""
Book Usage Model
================
Tracks each time a book is used to skip/reduce cooldowns.

CRITICAL: Books are purchased with real money. This table provides full
traceability for support issues and debugging:
1. Did the cooldown actually get skipped?
2. What was the state before/after?
3. What error occurred if it failed?
"""
from sqlalchemy import Column, Integer, BigInteger, String, DateTime, Boolean, ForeignKey
from sqlalchemy.sql import func
from ..base import Base


class BookUsage(Base):
    """
    Book usage record.
    
    Each row represents a single book usage attempt. Records whether it
    succeeded or failed, and captures full state for debugging.
    """
    __tablename__ = "book_usages"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    # What the book was used on
    slot = Column(String, nullable=False)  # personal, building, crafting
    action_type = Column(String, nullable=True)  # Optional: specific action being skipped
    
    # Effect requested
    effect = Column(String, nullable=False)  # "skip_cooldown" or "reduce_cooldown"
    cooldown_reduction_minutes = Column(Integer, nullable=True)  # Only for reduce_cooldown
    
    # Result tracking - DID IT ACTUALLY WORK?
    success = Column(Boolean, nullable=False)  # Did the operation succeed?
    error_message = Column(String, nullable=True)  # Error details if failed
    
    # Book balance tracking
    books_before = Column(Integer, nullable=False)  # Balance before attempt
    books_after = Column(Integer, nullable=False)   # Balance after (verify deduction happened)
    
    # Cooldown state tracking - PROVE it worked
    cooldowns_found = Column(Integer, nullable=True)  # How many cooldowns were in the slot
    cooldowns_modified = Column(Integer, nullable=True)  # How many we actually modified
    
    # Timestamp
    used_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

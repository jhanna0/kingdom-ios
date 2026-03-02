"""
Treasury Transaction Log - Track all gold movements involving treasuries
"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, ForeignKey
from datetime import datetime

from ..base import Base


class TreasuryTransaction(Base):
    __tablename__ = "treasury_transactions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)
    
    transaction_type = Column(String, nullable=False)  # 'withdraw', 'deposit', 'transfer'
    
    from_kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=True, index=True)
    to_kingdom_id = Column(String, ForeignKey("kingdoms.id"), nullable=True, index=True)
    
    amount = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

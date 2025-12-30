"""
Kingdom updates and notifications
"""
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from db import User, Kingdom, Contract


def build_kingdom_updates(db: Session, user: User) -> List[Dict[str, Any]]:
    """Build updates for kingdoms where user is ruler"""
    
    # Get kingdoms where user is ruler
    ruled_kingdoms = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).all()
    
    kingdoms_list = []
    for kingdom in ruled_kingdoms:
        # Count open contracts in this kingdom
        open_contracts = db.query(Contract).filter(
            Contract.kingdom_id == kingdom.id,
            Contract.status == 'open'
        ).count()
        
        kingdoms_list.append({
            "id": kingdom.id,
            "name": kingdom.name,
            "level": kingdom.level,
            "population": kingdom.population,
            "treasury": kingdom.treasury,
            "open_contracts": open_contracts
        })
    
    return kingdoms_list


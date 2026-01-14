"""
Player summary builder
"""
from sqlalchemy.orm import Session
from typing import Dict, Any
from db import User, PlayerState, Contract


def build_player_summary(db: Session, user: User, state: PlayerState) -> Dict[str, Any]:
    """Build player summary with gold, level, XP, etc."""
    
    # Calculate XP needed for next level
    xp_to_next_level = (state.level * 100) - state.experience
    if xp_to_next_level < 0:
        xp_to_next_level = 0
    
    # Count contracts where user has contributed
    # Contracts use action_contributions JSONB field, not assignee_id
    user_id_str = str(user.id)
    
    all_contracts = db.query(Contract).all()
    active_contracts = sum(1 for c in all_contracts 
                          if c.status == 'in_progress' 
                          and c.action_contributions 
                          and user_id_str in c.action_contributions)
    
    ready_contracts = sum(1 for c in all_contracts 
                         if c.status == 'completed' 
                         and c.action_contributions 
                         and user_id_str in c.action_contributions)
    
    # Compute kingdoms_ruled from kingdoms table
    from db import Kingdom
    kingdoms_ruled = db.query(Kingdom).filter(Kingdom.ruler_id == user.id).count()
    
    return {
        "gold": int(state.gold),
        "level": state.level,
        "experience": state.experience,
        "xp_to_next_level": xp_to_next_level,
        "skill_points": state.skill_points,
        "reputation": 0,  # TODO: get from user_kingdoms for current kingdom
        "kingdoms_ruled": kingdoms_ruled,
        "active_contracts": active_contracts,
        "ready_contracts": ready_contracts
    }


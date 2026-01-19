"""
FORAGING API ROUTER
===================
Two-round foraging with bonus round!

Flow:
1. POST /foraging/start - Get BOTH rounds pre-calculated upfront
   - Round 1: Berries (food) + potential seed trail
   - Round 2: Seeds (only if seed trail found in R1)
2. Frontend reveals locally + animates transition if bonus round
3. POST /foraging/collect - Claim ALL rewards (berries + seeds)
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime

from db import get_db
from db.models import User
from db.models.inventory import PlayerInventory
from db.models.player_state import PlayerState
from db.models.foraging_session import ForagingSession as ForagingSessionDB
from routers.auth import get_current_user
from systems.foraging.foraging_manager import ForagingManager
from systems.foraging.config import GRID_SIZE, MAX_REVEALS, MATCHES_TO_WIN, BUSH_DISPLAY, GRID_CONFIG, ROUND1_WIN_CONFIG, ROUND2_WIN_CONFIG


router = APIRouter(prefix="/foraging", tags=["foraging"])

_manager = ForagingManager()


class EmptyRequest(BaseModel):
    pass


@router.get("/config")
def get_config():
    """Get display config for frontend."""
    return {
        "grid_size": GRID_SIZE,
        "max_reveals": MAX_REVEALS,
        "matches_to_win": MATCHES_TO_WIN,
        "bush_types": BUSH_DISPLAY,
        "hidden_icon": GRID_CONFIG["bush_hidden_icon"],
        "hidden_color": GRID_CONFIG["bush_hidden_color"],
        "bonus_hidden_icon": GRID_CONFIG["bonus_hidden_icon"],
        "bonus_hidden_color": GRID_CONFIG["bonus_hidden_color"],
        # Skill info
        "round1_skill": ROUND1_WIN_CONFIG["skill"],
        "round2_skill": ROUND2_WIN_CONFIG["skill"],
    }


@router.post("/start")
def start_foraging(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Start foraging - returns EVERYTHING pre-calculated for BOTH rounds.
    """
    player_id = user.id
    
    # Get player skills
    state = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
    leadership = state.leadership if state else 0
    merchant = state.merchant if state else 0
    kingdom_id = state.current_kingdom_id if state else None
    
    # End any existing active session
    existing = db.query(ForagingSessionDB).filter(
        ForagingSessionDB.user_id == player_id,
        ForagingSessionDB.status == 'active'
    ).first()
    if existing:
        existing.status = 'cancelled'
        db.commit()
    
    # Create new session with skill-adjusted probabilities
    session = _manager.create_session(
        player_id=player_id,
        leadership=leadership,
        merchant=merchant,
    )
    
    # Store in database
    db_session = ForagingSessionDB(
        session_id=session.session_id,
        user_id=player_id,
        kingdom_id=kingdom_id,
        status='active',
        session_data=session.to_dict(),
        has_bonus_round=session.has_bonus_round,
        round1_won=session.round1.is_winner,
        round2_won=session.round2.is_winner if session.round2 else False,
        has_rare_drop=session.round2.has_rare_drop if session.round2 else False,
        expires_at=ForagingSessionDB.default_expiry(),
    )
    db.add(db_session)
    db.commit()
    
    return {
        "success": True,
        "session": session.to_dict(),
        "skills_used": {
            "round1": {"skill": "leadership", "level": leadership},
            "round2": {"skill": "merchant", "level": merchant},
        },
    }


@router.post("/collect")
def collect_rewards(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Collect ALL rewards from the session.
    """
    player_id = user.id
    
    # Get active session from database
    db_session = db.query(ForagingSessionDB).filter(
        ForagingSessionDB.user_id == player_id,
        ForagingSessionDB.status == 'active'
    ).first()
    
    if not db_session:
        raise HTTPException(status_code=400, detail="No active session")
    
    if db_session.is_expired:
        db_session.status = 'expired'
        db.commit()
        raise HTTPException(status_code=400, detail="Session expired")
    
    # Get session data
    session_data = db_session.session_data
    
    # Build rewards list
    rewards = []
    
    # Round 1 rewards
    round1 = session_data.get("round1", {})
    if round1.get("is_winner") and round1.get("reward_amount", 0) > 0:
        reward_config = round1.get("reward_config", {})
        rewards.append({
            "round": 1,
            "item": reward_config.get("item"),
            "amount": round1.get("reward_amount"),
            "display_name": reward_config.get("display_name"),
        })
    
    # Round 2 rewards
    round2 = session_data.get("round2")
    if round2:
        if round2.get("is_winner") and round2.get("reward_amount", 0) > 0:
            reward_config = round2.get("reward_config", {})
            rewards.append({
                "round": 2,
                "item": reward_config.get("item"),
                "amount": round2.get("reward_amount"),
                "display_name": reward_config.get("display_name"),
            })
        
        # Check for rare drops in round 2 rewards array
        for r in round2.get("rewards", []):
            if r.get("item") == "rare_egg":
                rewards.append({
                    "round": 2,
                    "item": "rare_egg",
                    "amount": 1,
                    "display_name": r.get("display_name", "Rare Egg"),
                    "is_rare": True,
                })
    
    # Add ALL rewards to inventory
    for reward in rewards:
        item_id = reward.get("item")
        amount = reward.get("amount", 0)
        
        if item_id and amount > 0:
            inv = db.query(PlayerInventory).filter(
                PlayerInventory.user_id == player_id,
                PlayerInventory.item_id == item_id
            ).first()
            
            if inv:
                inv.quantity += amount
            else:
                inv = PlayerInventory(
                    user_id=player_id,
                    item_id=item_id,
                    quantity=amount
                )
                db.add(inv)
    
    # Mark session as collected
    db_session.status = 'collected'
    db_session.collected_at = datetime.utcnow()
    db.commit()
    
    # Return result
    primary_reward = rewards[0] if rewards else None
    return {
        "success": True,
        "is_winner": len(rewards) > 0,
        "rewards": rewards,
        "reward_item": primary_reward["item"] if primary_reward else None,
        "reward_amount": primary_reward["amount"] if primary_reward else 0,
    }


@router.post("/end")
def end_foraging(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """End session without collecting."""
    player_id = user.id
    
    db_session = db.query(ForagingSessionDB).filter(
        ForagingSessionDB.user_id == player_id,
        ForagingSessionDB.status == 'active'
    ).first()
    
    if db_session:
        db_session.status = 'cancelled'
        db.commit()
    
    return {"success": True}

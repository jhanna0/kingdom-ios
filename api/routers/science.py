"""
SCIENCE MINIGAME API ROUTER
===========================
High/Low guessing game - test your scientific intuition!

CRITICAL: Backend PRE-CALCULATES all numbers. Frontend is DUMB!

Flow:
1. POST /science/start - Get first number (all rounds pre-calculated, stored in DB)
2. POST /science/guess - Submit HIGH or LOW guess, backend validates
3. POST /science/collect - Claim ALL rewards (gold + blueprint)
4. POST /science/end - Quit without collecting
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime

from db import get_db
from db.models import User
from db.models.player_state import PlayerState
from db.models.science_session import ScienceSession as ScienceSessionDB
from db.models.science_stats import ScienceStats
from db.models.inventory import PlayerInventory
from routers.auth import get_current_user
from routers.actions.tax_utils import apply_kingdom_tax
from systems.science.science_manager import ScienceManager, ScienceSession
from systems.science.config import (
    SKILL_CONFIG,
    UI_STRINGS,
    THEME_CONFIG,
    ENTRY_COST,
    MIN_SCIENCE_LEVEL,
    MAX_GUESSES,
    REWARD_CONFIG,
)


router = APIRouter(prefix="/science", tags=["science"])

_manager = ScienceManager()


def _get_player_blueprints(db: Session, player_id: int) -> int:
    """Get player's current blueprint count from inventory."""
    inv = db.query(PlayerInventory).filter(
        PlayerInventory.user_id == player_id,
        PlayerInventory.item_id == "blueprint"
    ).first()
    return inv.quantity if inv else 0


class EmptyRequest(BaseModel):
    pass


class GuessRequest(BaseModel):
    guess: str  # "high" or "low"


@router.get("/config")
def get_config():
    """Get display config for frontend - ALL UI strings from backend!"""
    streak_rewards = [
        {
            "streak": streak,
            "gold": cfg.get("gold", 0),
            "blueprint": cfg.get("blueprint", 0),
            "message": cfg.get("message", ""),
        }
        for streak, cfg in sorted(REWARD_CONFIG.items(), key=lambda kv: kv[0])
    ]
    return {
        "skill": SKILL_CONFIG,
        "ui": UI_STRINGS,
        "theme": THEME_CONFIG,
        "min_level": MIN_SCIENCE_LEVEL,
        "entry_cost": ENTRY_COST,
        "max_guesses": MAX_GUESSES,
        "streak_rewards": streak_rewards,
    }


@router.get("/stats")
def get_stats(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Get player's science stats."""
    stats = db.query(ScienceStats).filter(ScienceStats.user_id == user.id).first()
    
    if not stats:
        return {
            "experiments_completed": 0,
            "total_guesses": 0,
            "correct_guesses": 0,
            "accuracy": 0.0,
            "best_streak": 0,
            "perfect_games": 0,
            "total_gold_earned": 0,
            "total_blueprints_earned": 0,
        }
    
    return stats.to_dict()


@router.post("/start")
def start_science(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Start science minigame - ALL numbers pre-calculated!
    
    Costs ENTRY_COST gold to start.
    Returns the first number. Backend has already determined all future numbers.
    """
    player_id = user.id
    
    # Get player state
    state = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
    if not state:
        raise HTTPException(status_code=400, detail="No player state")
    
    # Check science level requirement
    science_level = state.science or 0
    if science_level < MIN_SCIENCE_LEVEL:
        raise HTTPException(status_code=400, detail=f"Requires Science T{MIN_SCIENCE_LEVEL}")
    
    # Check gold
    if state.gold < ENTRY_COST:
        raise HTTPException(status_code=400, detail=f"Not enough gold. Need {ENTRY_COST}g")
    
    # Deduct entry cost
    state.gold -= ENTRY_COST
    
    science_level = state.science or 0
    
    # End any existing active session
    existing = db.query(ScienceSessionDB).filter(
        ScienceSessionDB.user_id == player_id,
        ScienceSessionDB.status == 'active'
    ).first()
    if existing:
        existing.status = 'cancelled'
        db.commit()
    
    # Create new session with ALL numbers pre-calculated
    session = _manager.create_session(
        player_id=player_id,
        science_level=science_level,
    )
    
    # Store in database (includes all pre-calc'd answers!)
    db_session = ScienceSessionDB(
        session_id=session.session_id,
        user_id=player_id,
        status='active',
        session_data=session.to_db_dict(),  # Full data with hidden answers
        current_streak=0,
        expires_at=ScienceSessionDB.default_expiry(),
    )
    db.add(db_session)
    db.commit()
    
    return {
        "success": True,
        "session": session.to_dict(),  # Safe dict - hides future answers!
        "skill_info": {
            "skill": "science",
            "level": science_level,
        },
        "cost": ENTRY_COST,
        "player_gold": state.gold,
        "player_blueprints": _get_player_blueprints(db, player_id),
    }


@router.post("/guess")
def make_guess(
    request: GuessRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Submit a guess - backend validates against pre-calculated answer!
    
    Frontend sends "high" or "low", backend tells them if they're right.
    """
    player_id = user.id
    
    # Get active session from database
    db_session = db.query(ScienceSessionDB).filter(
        ScienceSessionDB.user_id == player_id,
        ScienceSessionDB.status == 'active'
    ).first()
    
    if not db_session:
        raise HTTPException(status_code=400, detail="No active session")
    
    if db_session.is_expired:
        db_session.status = 'expired'
        db.commit()
        raise HTTPException(status_code=400, detail="Session expired")
    
    # Reconstruct session from DB data
    session = ScienceSession.from_db_dict(db_session.session_data)
    
    # Process the guess against pre-calculated answer
    result = _manager.make_guess(session, request.guess)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Invalid guess"))
    
    # Update database with new state
    db_session.session_data = session.to_db_dict()
    db_session.current_streak = session.streak
    
    if session.is_game_over:
        db_session.final_streak = session.streak
    
    db.commit()
    
    # Get player state for current gold
    state = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
    
    # Return result (includes whether correct, the hidden number, etc.)
    return {
        "success": True,
        **result,
        "session": session.to_dict(),
        "player_gold": state.gold if state else 0,
        "player_blueprints": _get_player_blueprints(db, player_id),
    }


@router.post("/collect")
def collect_rewards(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Collect rewards from the session.
    
    Rewards based on streak:
    - Early streaks: gold (scales by config + science bonus)
    - Max streak: blueprint
    """
    player_id = user.id
    
    # Get active session
    db_session = db.query(ScienceSessionDB).filter(
        ScienceSessionDB.user_id == player_id,
        ScienceSessionDB.status == 'active'
    ).first()
    
    if not db_session:
        raise HTTPException(status_code=400, detail="No active session")
    
    if db_session.is_expired:
        db_session.status = 'expired'
        db.commit()
        raise HTTPException(status_code=400, detail="Session expired")
    
    # Reconstruct session
    session = ScienceSession.from_db_dict(db_session.session_data)
    
    # Collect rewards
    result = _manager.collect_rewards(session)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Cannot collect"))
    
    # Add rewards to player
    gross_gold = result.get("gold", 0)
    blueprint = result.get("blueprint", 0)
    
    # Get player state for tax calculation
    state = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
    
    # Apply kingdom tax to gold
    net_gold = gross_gold
    tax_amount = 0
    tax_rate = 0
    
    if gross_gold > 0 and state:
        kingdom_id = state.current_kingdom_id
        if kingdom_id:
            net_gold, tax_amount, tax_rate = apply_kingdom_tax(
                db, kingdom_id, state, float(gross_gold)
            )
            net_gold = int(net_gold)
            tax_amount = int(tax_amount)
        state.gold += net_gold
    
    if blueprint > 0:
        inv = db.query(PlayerInventory).filter(
            PlayerInventory.user_id == player_id,
            PlayerInventory.item_id == "blueprint"
        ).first()
        
        if inv:
            inv.quantity += blueprint
        else:
            inv = PlayerInventory(
                user_id=player_id,
                item_id="blueprint",
                quantity=blueprint
            )
            db.add(inv)
    
    # Update session status
    db_session.status = 'collected'
    db_session.collected_at = datetime.utcnow()
    db_session.final_streak = session.streak
    db_session.gold_earned = net_gold
    db_session.blueprint_earned = blueprint
    db_session.session_data = session.to_db_dict()
    
    # Update player stats
    stats = db.query(ScienceStats).filter(ScienceStats.user_id == player_id).first()
    if not stats:
        stats = ScienceStats(
            user_id=player_id,
            experiments_completed=0,
            total_guesses=0,
            correct_guesses=0,
            best_streak=0,
            perfect_games=0,
            total_gold_earned=0,
            total_blueprints_earned=0
        )
        db.add(stats)
    
    # Count guesses from session
    total_guesses = len([r for r in session.rounds if r.is_revealed])
    correct_guesses = len([r for r in session.rounds if r.is_revealed and r.is_correct])
    
    stats.experiments_completed = (stats.experiments_completed or 0) + 1
    stats.total_guesses = (stats.total_guesses or 0) + total_guesses
    stats.correct_guesses = (stats.correct_guesses or 0) + correct_guesses
    stats.total_gold_earned = (stats.total_gold_earned or 0) + net_gold
    stats.total_blueprints_earned = (stats.total_blueprints_earned or 0) + blueprint
    
    if session.streak > (stats.best_streak or 0):
        stats.best_streak = session.streak
    
    if session.has_won_max:
        stats.perfect_games = (stats.perfect_games or 0) + 1
    
    db.commit()
    
    # Update rewards list to show net gold (after tax)
    rewards = []
    if net_gold > 0:
        from systems.science.config import GOLD_CONFIG
        rewards.append({
            "item": "gold",
            "amount": net_gold,
            "display_name": GOLD_CONFIG["display_name"],
            "icon": GOLD_CONFIG["icon"],
            "color": GOLD_CONFIG["color"],
        })
    if blueprint > 0:
        from systems.science.config import BLUEPRINT_CONFIG
        rewards.append({
            "item": BLUEPRINT_CONFIG["item"],
            "amount": blueprint,
            "display_name": BLUEPRINT_CONFIG["display_name"],
            "icon": BLUEPRINT_CONFIG["icon"],
            "color": BLUEPRINT_CONFIG["color"],
        })
    
    return {
        "success": True,
        "streak": session.streak,
        "rewards": rewards,
        "gold": net_gold,
        "gold_tax": tax_amount,
        "tax_rate": tax_rate,
        "blueprint": blueprint,
        "message": result.get("message", ""),
        "stats": stats.to_dict(),
        "player_gold": state.gold if state else 0,
        "player_blueprints": _get_player_blueprints(db, player_id),
    }


@router.post("/end")
def end_science(
    request: EmptyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """End session without collecting."""
    player_id = user.id
    
    db_session = db.query(ScienceSessionDB).filter(
        ScienceSessionDB.user_id == player_id,
        ScienceSessionDB.status == 'active'
    ).first()
    
    if db_session:
        db_session.status = 'cancelled'
        db.commit()
    
    return {"success": True}

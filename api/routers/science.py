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
from systems.science.science_manager import ScienceManager, ScienceSession
from systems.science.config import SKILL_CONFIG, UI_STRINGS, THEME_CONFIG


router = APIRouter(prefix="/science", tags=["science"])

_manager = ScienceManager()


class EmptyRequest(BaseModel):
    pass


class GuessRequest(BaseModel):
    guess: str  # "high" or "low"


@router.get("/config")
def get_config():
    """Get display config for frontend - ALL UI strings from backend!"""
    return {
        "skill": SKILL_CONFIG,
        "ui": UI_STRINGS,
        "theme": THEME_CONFIG,
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
    
    Returns the first number. Backend has already determined all future numbers.
    """
    player_id = user.id
    
    # Get player's science skill
    state = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
    science_level = state.science if state else 0
    
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
    
    # Return result (includes whether correct, the hidden number, etc.)
    return {
        "success": True,
        **result,
        "session": session.to_dict(),
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
    - 1 correct: 5 gold + science bonus
    - 2 correct: 10 gold + science bonus
    - 3 correct: 1 blueprint!
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
    gold = result.get("gold", 0)
    blueprint = result.get("blueprint", 0)
    
    if gold > 0:
        state = db.query(PlayerState).filter(PlayerState.user_id == player_id).first()
        if state:
            state.gold += gold
    
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
    db_session.gold_earned = gold
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
    stats.total_gold_earned = (stats.total_gold_earned or 0) + gold
    stats.total_blueprints_earned = (stats.total_blueprints_earned or 0) + blueprint
    
    if session.streak > (stats.best_streak or 0):
        stats.best_streak = session.streak
    
    if session.has_won_max:
        stats.perfect_games = (stats.perfect_games or 0) + 1
    
    db.commit()
    
    return {
        "success": True,
        "streak": session.streak,
        "rewards": result.get("rewards", []),
        "gold": gold,
        "blueprint": blueprint,
        "message": result.get("message", ""),
        "stats": stats.to_dict(),
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

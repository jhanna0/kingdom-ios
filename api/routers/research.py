"""
RESEARCH API ENDPOINTS
======================
Simple API - start experiment, get ALL results, frontend animates.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import random

from db.base import get_db
from db.models.user import User
from db.models.player_state import PlayerState
from db.models.player_item import PlayerItem
from routers.auth import get_current_user
from systems.research.config import get_research_config, RESEARCH_GOLD_COST
from systems.research.research_manager import ResearchManager


router = APIRouter(prefix="/research", tags=["research"])


@router.get("/config")
async def get_config():
    """Get research config for frontend."""
    return get_research_config()


@router.post("/experiment")
async def run_experiment(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Run a complete experiment. Returns ALL phase results.
    Frontend animates through them.
    """
    # Get player state
    player = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    
    # Check gold
    if player.gold < RESEARCH_GOLD_COST:
        raise HTTPException(status_code=400, detail=f"Need {RESEARCH_GOLD_COST} gold")
    
    # Deduct gold
    player.gold -= RESEARCH_GOLD_COST
    
    # Get player stats
    science = getattr(player, 'science', 0) or 0
    philosophy = getattr(player, 'philosophy', 0) or 0
    building = getattr(player, 'building_skill', 0) or 0
    
    # Run the experiment
    manager = ResearchManager()
    result = manager.run_experiment(science, philosophy, building)
    
    # Award rewards
    if result.gp > 0:
        player.gold += result.gp
    
    if result.blueprints > 0:
        # Add blueprints to inventory
        for _ in range(result.blueprints):
            blueprint = PlayerItem(
                player_id=player.id,
                item_type="blueprint",
                quantity=1,
            )
            db.add(blueprint)
    
    db.commit()
    
    return {
        "experiment": result.to_dict(),
        "player_stats": {
            "science": science,
            "philosophy": philosophy,
            "building": building,
            "gold": player.gold,
        },
        "config": {
            "fill_animation_ms": 1500,
            "stabilize_animation_ms": 3000,
            "tap_animation_ms": 200,
        },
    }


@router.get("/stats")
async def get_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get player's research-relevant stats."""
    player = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    
    return {
        "science": getattr(player, 'science', 0) or 0,
        "philosophy": getattr(player, 'philosophy', 0) or 0,
        "building": getattr(player, 'building_skill', 0) or 0,
        "gold": player.gold,
    }

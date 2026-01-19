"""
RESEARCH API ENDPOINTS
======================
Simple API - start experiment, get ALL results, frontend animates.
All data persisted to PostgreSQL for Lambda compatibility.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from db.base import get_db
from db.models.user import User
from db.models.player_state import PlayerState
from db.models.player_item import PlayerItem
from db.models.research_session import ResearchSession
from db.models.research_stats import ResearchStats
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
    All data persisted to PostgreSQL.
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
    kingdom_id = player.current_kingdom_id
    
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
    
    # Store experiment session in database
    session = ResearchSession(
        user_id=current_user.id,
        kingdom_id=kingdom_id,
        experiment_data=result.to_dict(),
        success=result.success,
        is_critical=result.is_critical,
        blueprints_earned=result.blueprints,
        gp_earned=result.gp,
        main_tube_fill=int(result.main_tube_fill * 100),
        final_floor=result.final_floor,
        ceiling=result.ceiling,
        landed_tier=result.landed_tier_id,
        science_level=science,
        philosophy_level=philosophy,
        building_level=building,
    )
    db.add(session)
    
    # Update aggregate stats
    if kingdom_id:
        stats = db.query(ResearchStats).filter(
            ResearchStats.user_id == current_user.id,
            ResearchStats.kingdom_id == kingdom_id
        ).first()
        
        if not stats:
            stats = ResearchStats(
                user_id=current_user.id,
                kingdom_id=kingdom_id,
            )
            db.add(stats)
        
        # Update counters
        stats.experiments_completed = (stats.experiments_completed or 0) + 1
        stats.total_gp_earned = (stats.total_gp_earned or 0) + result.gp
        stats.total_blueprints_earned = (stats.total_blueprints_earned or 0) + result.blueprints
        
        if result.success:
            stats.experiments_succeeded = (stats.experiments_succeeded or 0) + 1
            stats.current_success_streak = (stats.current_success_streak or 0) + 1
            if stats.current_success_streak > (stats.best_success_streak or 0):
                stats.best_success_streak = stats.current_success_streak
        else:
            stats.current_success_streak = 0
        
        # Update tier counters
        tier_id = result.landed_tier_id
        if tier_id == "critical":
            stats.critical_hits = (stats.critical_hits or 0) + 1
        elif tier_id == "excellent":
            stats.excellent_hits = (stats.excellent_hits or 0) + 1
        elif tier_id == "good":
            stats.good_hits = (stats.good_hits or 0) + 1
        elif tier_id == "poor":
            stats.poor_hits = (stats.poor_hits or 0) + 1
        else:
            stats.failures = (stats.failures or 0) + 1
        
        # Update highscores
        if result.final_floor > (stats.best_floor or 0):
            stats.best_floor = result.final_floor
        if result.ceiling > (stats.best_ceiling or 0):
            stats.best_ceiling = result.ceiling
        if result.blueprints > (stats.most_blueprints_single or 0):
            stats.most_blueprints_single = result.blueprints
        
        stats.updated_at = datetime.utcnow()
    
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
    """Get player's research-relevant stats and aggregate research stats."""
    player = db.query(PlayerState).filter(PlayerState.user_id == current_user.id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    
    kingdom_id = player.current_kingdom_id
    
    # Get aggregate research stats
    research_stats = None
    if kingdom_id:
        stats = db.query(ResearchStats).filter(
            ResearchStats.user_id == current_user.id,
            ResearchStats.kingdom_id == kingdom_id
        ).first()
        
        if stats:
            research_stats = {
                "experiments_completed": stats.experiments_completed,
                "experiments_succeeded": stats.experiments_succeeded,
                "total_blueprints_earned": stats.total_blueprints_earned,
                "total_gp_earned": stats.total_gp_earned,
                "critical_hits": stats.critical_hits,
                "excellent_hits": stats.excellent_hits,
                "good_hits": stats.good_hits,
                "poor_hits": stats.poor_hits,
                "failures": stats.failures,
                "best_floor": stats.best_floor,
                "best_ceiling": stats.best_ceiling,
                "most_blueprints_single": stats.most_blueprints_single,
                "current_success_streak": stats.current_success_streak,
                "best_success_streak": stats.best_success_streak,
                "success_rate": stats.success_rate,
                "critical_rate": stats.critical_rate,
            }
    
    return {
        "science": getattr(player, 'science', 0) or 0,
        "philosophy": getattr(player, 'philosophy', 0) or 0,
        "building": getattr(player, 'building_skill', 0) or 0,
        "gold": player.gold,
        "research_stats": research_stats,
    }


@router.get("/history")
async def get_history(
    limit: int = 20,
    offset: int = 0,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get player's research experiment history."""
    sessions = db.query(ResearchSession).filter(
        ResearchSession.user_id == current_user.id
    ).order_by(ResearchSession.created_at.desc()).offset(offset).limit(limit).all()
    
    total = db.query(ResearchSession).filter(
        ResearchSession.user_id == current_user.id
    ).count()
    
    return {
        "sessions": [
            {
                "id": s.id,
                "success": s.success,
                "is_critical": s.is_critical,
                "blueprints_earned": s.blueprints_earned,
                "gp_earned": s.gp_earned,
                "main_tube_fill": s.main_tube_fill,
                "final_floor": s.final_floor,
                "ceiling": s.ceiling,
                "landed_tier": s.landed_tier,
                "science_level": s.science_level,
                "philosophy_level": s.philosophy_level,
                "created_at": s.created_at.isoformat() if s.created_at else None,
            }
            for s in sessions
        ],
        "total": total,
        "limit": limit,
        "offset": offset,
    }

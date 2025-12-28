"""
Game endpoints - Players, kingdoms, check-ins
"""
from fastapi import APIRouter, HTTPException
from typing import Dict

from models.schemas import (
    Player,
    PlayerCreate,
    PlayerUpdate,
    Kingdom,
    KingdomUpdate,
    CheckInRequest,
    CheckInResponse,
    CheckInRewards
)


router = APIRouter(tags=["game"])


# Simple in-memory storage (will reset when server restarts)
# TODO: Replace with proper database tables
players_db: Dict[str, Player] = {}
kingdoms_db: Dict[str, Kingdom] = {}


# ===== Player Endpoints =====

@router.post("/players", response_model=Player)
def create_player(player: PlayerCreate):
    """Create a new player"""
    if player.id in players_db:
        raise HTTPException(status_code=400, detail="Player already exists")
    
    new_player = Player(
        id=player.id,
        name=player.name,
        gold=100,  # Starting gold
        level=1
    )
    players_db[player.id] = new_player
    return new_player


@router.get("/players/{player_id}", response_model=Player)
def get_player(player_id: str):
    """Get player by ID"""
    if player_id not in players_db:
        raise HTTPException(status_code=404, detail="Player not found")
    return players_db[player_id]


@router.put("/players/{player_id}", response_model=Player)
def update_player(player_id: str, updates: PlayerUpdate):
    """Update player data"""
    if player_id not in players_db:
        raise HTTPException(status_code=404, detail="Player not found")
    
    player = players_db[player_id]
    if updates.gold is not None:
        player.gold = updates.gold
    if updates.level is not None:
        player.level = updates.level
    
    return player


# ===== Kingdom Endpoints =====

@router.post("/kingdoms", response_model=Kingdom)
def create_kingdom(kingdom: Kingdom):
    """Create a new kingdom"""
    if kingdom.id in kingdoms_db:
        raise HTTPException(status_code=400, detail="Kingdom already exists")
    
    kingdoms_db[kingdom.id] = kingdom
    return kingdom


@router.get("/kingdoms/{kingdom_id}", response_model=Kingdom)
def get_kingdom(kingdom_id: str):
    """Get kingdom by ID"""
    if kingdom_id not in kingdoms_db:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    return kingdoms_db[kingdom_id]


@router.put("/kingdoms/{kingdom_id}", response_model=Kingdom)
def update_kingdom(kingdom_id: str, updates: KingdomUpdate):
    """Update kingdom data"""
    if kingdom_id not in kingdoms_db:
        raise HTTPException(status_code=404, detail="Kingdom not found")
    
    kingdom = kingdoms_db[kingdom_id]
    if updates.ruler_id is not None:
        kingdom.ruler_id = updates.ruler_id
    if updates.ruler_name is not None:
        kingdom.ruler_name = updates.ruler_name
    if updates.treasury is not None:
        kingdom.treasury = updates.treasury
    if updates.population is not None:
        kingdom.population = updates.population
    
    return kingdom


# ===== Check-in Endpoint =====

@router.post("/checkin", response_model=CheckInResponse)
def check_in(request: CheckInRequest):
    """
    Check in to a kingdom
    
    Validates location and rewards player with gold and XP
    """
    # Verify player exists
    if request.player_id not in players_db:
        raise HTTPException(status_code=404, detail="Player not found")
    
    # TODO: Verify kingdom exists
    # TODO: Verify player is actually inside kingdom boundaries
    # TODO: Check cooldown (can't check in too frequently)
    
    # Calculate rewards (simple for now)
    gold_reward = 10
    xp_reward = 5
    
    # Update player
    player = players_db[request.player_id]
    player.gold += gold_reward
    
    return CheckInResponse(
        success=True,
        message=f"Checked in to kingdom!",
        rewards=CheckInRewards(
            gold=gold_reward,
            experience=xp_reward
        )
    )


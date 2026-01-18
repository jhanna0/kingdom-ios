"""
FORAGING MANAGER
================
Pre-calculates EVERYTHING upfront. Frontend just reveals locally.

FLOW:
1. /start - Returns full grid + win/loss result + reward amount
2. Frontend reveals locally (no API calls)
3. /collect - Claims reward if won
"""

import random
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from .config import (
    GRID_SIZE,
    MAX_REVEALS,
    MATCHES_TO_WIN,
    BUSH_TYPES,
    REWARD_CONFIG,
    GRID_CONFIG,
    WIN_RATE_CONFIG,
    TARGET_TYPE,
    get_bush_type_weights,
    calculate_reward,
)


@dataclass
class ForagingSession:
    """
    Pre-calculated foraging session.
    Everything is determined at start - frontend just reveals.
    """
    session_id: str
    player_id: int
    
    # The grid - ALL types known upfront (list of dicts)
    grid: List[dict] = field(default_factory=list)
    
    # Pre-calculated result
    is_winner: bool = False
    winning_positions: List[int] = field(default_factory=list)  # Positions of seeds
    reward_amount: int = 0
    
    # Whether rewards have been collected
    collected: bool = False
    
    def to_dict(self) -> dict:
        return {
            "session_id": self.session_id,
            "grid": self.grid,
            "max_reveals": MAX_REVEALS,
            "matches_to_win": MATCHES_TO_WIN,
            "is_winner": self.is_winner,
            "winning_positions": self.winning_positions,
            "reward_amount": self.reward_amount,
            "reward_config": {
                "item": REWARD_CONFIG["reward_item"],
                "display_name": REWARD_CONFIG["reward_item_display_name"],
                "icon": REWARD_CONFIG["reward_item_icon"],
                "color": REWARD_CONFIG["reward_item_color"],
            },
            "hidden_icon": GRID_CONFIG["bush_hidden_icon"],
            "hidden_color": GRID_CONFIG["bush_hidden_color"],
        }


class ForagingManager:
    """
    Generates pre-calculated foraging sessions.
    """
    
    def __init__(self, seed: Optional[int] = None):
        self.rng = random.Random(seed)
    
    def create_session(self, player_id: int) -> ForagingSession:
        """Create a fully pre-calculated session."""
        session_id = f"forage_{player_id}_{int(time.time() * 1000)}"
        
        # Generate grid
        grid = self._generate_grid()
        
        # Find all seed positions
        seed_positions = [i for i, cell in enumerate(grid) if cell["bush_type"] == TARGET_TYPE]
        
        # Determine if winnable (has at least 3 seeds)
        is_winner = len(seed_positions) >= MATCHES_TO_WIN
        
        # Calculate reward - cap at max reveals since that's max player can find
        seeds_player_can_find = min(len(seed_positions), MAX_REVEALS)
        reward_amount = calculate_reward(seeds_player_can_find) if is_winner else 0
        
        return ForagingSession(
            session_id=session_id,
            player_id=player_id,
            grid=grid,
            is_winner=is_winner,
            winning_positions=seed_positions,
            reward_amount=reward_amount,
        )
    
    def _generate_grid(self) -> List[dict]:
        """Generate grid with all types visible."""
        grid_size = GRID_SIZE * GRID_SIZE
        grid = [None] * grid_size
        
        weights = get_bush_type_weights()
        bush_types = list(weights.keys())
        type_weights = list(weights.values())
        
        # Roll for winnable grid
        should_seed = self.rng.random() < WIN_RATE_CONFIG["cluster_probability"]
        
        if should_seed:
            # Place guaranteed seeds
            seed_positions = self.rng.sample(range(grid_size), WIN_RATE_CONFIG["guaranteed_cluster_size"])
            for pos in seed_positions:
                grid[pos] = self._make_cell(pos, TARGET_TYPE)
        
        # Fill rest randomly
        for i in range(grid_size):
            if grid[i] is None:
                bush_type = self.rng.choices(bush_types, weights=type_weights, k=1)[0]
                grid[i] = self._make_cell(i, bush_type)
        
        return grid
    
    def _make_cell(self, position: int, bush_type: str) -> dict:
        """Create a cell dict with display info."""
        info = BUSH_TYPES.get(bush_type, BUSH_TYPES[TARGET_TYPE])
        return {
            "position": position,
            "bush_type": bush_type,
            "icon": info["icon"],
            "color": info["color"],
            "name": info["name"],
            "is_seed": bush_type == TARGET_TYPE,
        }
    
    def collect_rewards(self, session: ForagingSession) -> dict:
        """Mark rewards as collected."""
        if session.collected:
            raise ValueError("Already collected")
        
        session.collected = True
        
        if session.is_winner:
            return {
                "success": True,
                "is_winner": True,
                "reward_item": REWARD_CONFIG["reward_item"],
                "reward_amount": session.reward_amount,
            }
        else:
            return {
                "success": True,
                "is_winner": False,
                "reward_item": None,
                "reward_amount": 0,
            }


# Singleton
_manager = ForagingManager()

def get_manager() -> ForagingManager:
    return _manager

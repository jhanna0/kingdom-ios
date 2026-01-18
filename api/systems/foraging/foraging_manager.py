"""
FORAGING MANAGER
================
Two-round foraging system with bonus round!

ROUND 1 (Main): Find berries (food) - 10% chance
  - Also has 5% chance to find "seed trail" → triggers bonus round
  
ROUND 2 (Bonus): New grid slides in, 10% chance of seed drop
  - ONLY way to get seeds from foraging!

FLOW:
1. /start - Returns round 1 grid + result, PLUS bonus round if seed trail found
2. Frontend reveals locally (no API calls)
3. If seed trail → animate transition → reveal round 2
4. /collect - Claims ALL rewards (berries from R1 + seeds from R2)
"""

import random
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from .config import (
    GRID_SIZE,
    MAX_REVEALS,
    MATCHES_TO_WIN,  # Still needed for to_dict
    GRID_CONFIG,
    ROUND1_BUSH_TYPES,
    ROUND2_BUSH_TYPES,
    ROUND1_TARGET_TYPE,
    ROUND2_TARGET_TYPE,
    ROUND1_REWARD_CONFIG,
    ROUND2_REWARD_CONFIG,
    ROUND2_RARE_DROP_CONFIG,
    ROUND1_WIN_CONFIG,
    ROUND2_WIN_CONFIG,
    get_bush_type_weights,
    get_round_config,
)


@dataclass
class RoundData:
    """Data for a single round."""
    round_num: int
    grid: List[dict] = field(default_factory=list)
    is_winner: bool = False
    winning_positions: List[int] = field(default_factory=list)
    reward_amount: int = 0
    has_seed_trail: bool = False  # Only for round 1
    seed_trail_position: int = -1  # Where in the grid array (for display)
    has_rare_drop: bool = False  # Round 2 only - rare egg drop!
    
    def to_dict(self, reward_config: dict, hidden_icon: str, hidden_color: str, rare_drop_config: dict = None) -> dict:
        # Build rewards array - frontend just renders this, no special cases
        rewards = []
        if self.is_winner and self.reward_amount > 0:
            rewards.append({
                "item": reward_config["reward_item"],
                "display_name": reward_config["reward_item_display_name"],
                "icon": reward_config["reward_item_icon"],
                "color": reward_config["reward_item_color"],
                "amount": self.reward_amount,
            })
        if self.has_rare_drop and rare_drop_config:
            rewards.append({
                "item": rare_drop_config["reward_item"],
                "display_name": rare_drop_config["reward_item_display_name"],
                "icon": rare_drop_config["reward_item_icon"],
                "color": rare_drop_config["reward_item_color"],
                "amount": 1,
            })
        
        return {
            "round_num": self.round_num,
            "grid": self.grid,
            "max_reveals": MAX_REVEALS,
            "matches_to_win": MATCHES_TO_WIN,
            "is_winner": len(rewards) > 0,  # You won if you got ANY rewards
            "winning_positions": self.winning_positions,
            "rewards": rewards,  # Generic array - add anything here!
            "has_seed_trail": self.has_seed_trail,
            "seed_trail_position": self.seed_trail_position,
            # Legacy fields
            "reward_amount": self.reward_amount,
            "reward_config": {
                "item": reward_config["reward_item"],
                "display_name": reward_config["reward_item_display_name"],
                "icon": reward_config["reward_item_icon"],
                "color": reward_config["reward_item_color"],
            },
            "hidden_icon": hidden_icon,
            "hidden_color": hidden_color,
        }


@dataclass
class ForagingSession:
    """
    Two-round foraging session.
    Everything is determined at start - frontend just reveals.
    """
    session_id: str
    player_id: int
    
    # Round data
    round1: RoundData = field(default_factory=lambda: RoundData(round_num=1))
    round2: Optional[RoundData] = None  # Only if seed trail found
    
    # Whether rewards have been collected
    collected: bool = False
    
    # Legacy compatibility
    @property
    def grid(self) -> List[dict]:
        return self.round1.grid
    
    @property
    def is_winner(self) -> bool:
        return self.round1.is_winner
    
    @property
    def winning_positions(self) -> List[int]:
        return self.round1.winning_positions
    
    @property
    def reward_amount(self) -> int:
        return self.round1.reward_amount
    
    @property
    def has_bonus_round(self) -> bool:
        return self.round2 is not None
    
    def to_dict(self) -> dict:
        r1_config = get_round_config(1)
        result = {
            "session_id": self.session_id,
            "has_bonus_round": self.has_bonus_round,
            # Round 1 data
            "round1": self.round1.to_dict(
                ROUND1_REWARD_CONFIG,
                r1_config["hidden_icon"],
                r1_config["hidden_color"],
            ),
            # Legacy fields for backwards compatibility
            "grid": self.round1.grid,
            "max_reveals": MAX_REVEALS,
            "matches_to_win": MATCHES_TO_WIN,
            "is_winner": self.round1.is_winner,
            "winning_positions": self.round1.winning_positions,
            "reward_amount": self.round1.reward_amount,
            "reward_config": {
                "item": ROUND1_REWARD_CONFIG["reward_item"],
                "display_name": ROUND1_REWARD_CONFIG["reward_item_display_name"],
                "icon": ROUND1_REWARD_CONFIG["reward_item_icon"],
                "color": ROUND1_REWARD_CONFIG["reward_item_color"],
            },
            "hidden_icon": r1_config["hidden_icon"],
            "hidden_color": r1_config["hidden_color"],
        }
        
        # Add round 2 if present
        if self.round2:
            r2_config = get_round_config(2)
            result["round2"] = self.round2.to_dict(
                ROUND2_REWARD_CONFIG,
                r2_config["hidden_icon"],
                r2_config["hidden_color"],
                ROUND2_RARE_DROP_CONFIG,
            )
        
        return result


class ForagingManager:
    """
    Generates pre-calculated two-round foraging sessions.
    """
    
    def __init__(self, seed: Optional[int] = None):
        self.rng = random.Random(seed)
    
    def create_session(self, player_id: int) -> ForagingSession:
        """Create a fully pre-calculated session with potential bonus round."""
        session_id = f"forage_{player_id}_{int(time.time() * 1000)}"
        
        # Generate Round 1 (berries + potential seed trail)
        round1 = self._generate_round1()
        
        # Generate Round 2 only if seed trail found
        round2 = None
        if round1.has_seed_trail:
            round2 = self._generate_round2()
        
        return ForagingSession(
            session_id=session_id,
            player_id=player_id,
            round1=round1,
            round2=round2,
        )
    
    def _generate_round1(self) -> RoundData:
        """
        Generate Round 1 grid - 5 cells, that's it.
        
        ONE ROLL 1-100:
        - 1-5: Seed trail WIN (5%) → 3 trails + 2 filler
        - 6-15: Berries WIN (10%) → 3 berries + 2 filler  
        - 16-35: Seed trail TEASE (20%) → 1-2 trails + filler (can't win)
        - 36-100: Nothing → 5 filler
        """
        weights = get_bush_type_weights(round_num=1)
        bush_types = list(weights.keys())
        type_weights = list(weights.values())
        
        # ONE ROLL - mutually exclusive outcomes
        roll = self.rng.randint(1, 100)
        
        seed_trail_threshold = int(ROUND1_WIN_CONFIG["seed_trail_probability"] * 100)  # 5
        berries_threshold = seed_trail_threshold + int(ROUND1_WIN_CONFIG["cluster_probability"] * 100)  # 15
        tease_threshold = berries_threshold + int(ROUND1_WIN_CONFIG.get("seed_trail_tease_probability", 0) * 100)  # 35
        
        cells = []
        
        if roll <= seed_trail_threshold:
            # SEED TRAIL WIN - place 3 trails
            for _ in range(ROUND1_WIN_CONFIG["seed_trail_cluster_size"]):
                cells.append(self._make_cell(0, "seed_trail", round_num=1))
        elif roll <= berries_threshold:
            # BERRIES WIN - place 3 berries
            for _ in range(ROUND1_WIN_CONFIG["guaranteed_cluster_size"]):
                cells.append(self._make_cell(0, ROUND1_TARGET_TYPE, round_num=1))
        elif roll <= tease_threshold:
            # SEED TRAIL TEASE - place 1-2 trails (not enough to win)
            tease_count = self.rng.randint(1, 2)
            for _ in range(tease_count):
                cells.append(self._make_cell(0, "seed_trail", round_num=1))
        
        # Fill rest with random filler
        while len(cells) < MAX_REVEALS:
            bush_type = self.rng.choices(bush_types, weights=type_weights, k=1)[0]
            cells.append(self._make_cell(0, bush_type, round_num=1))
        
        # Shuffle so wins aren't always first
        self.rng.shuffle(cells)
        
        # Assign positions
        for i, cell in enumerate(cells):
            cell["position"] = i
        
        # Check results
        berry_count = sum(1 for c in cells if c["is_seed"])
        trail_count = sum(1 for c in cells if c.get("is_seed_trail", False))
        
        is_winner = berry_count >= ROUND1_WIN_CONFIG["guaranteed_cluster_size"]
        has_seed_trail = trail_count >= ROUND1_WIN_CONFIG["seed_trail_cluster_size"]
        reward_amount = 1 if is_winner else 0
        
        target_positions = [i for i, c in enumerate(cells) if c["is_seed"]]
        seed_trail_position = next((i for i, c in enumerate(cells) if c.get("is_seed_trail")), -1)
        
        return RoundData(
            round_num=1,
            grid=cells,
            is_winner=is_winner,
            winning_positions=target_positions,
            reward_amount=reward_amount,
            has_seed_trail=has_seed_trail,
            seed_trail_position=seed_trail_position,
        )
    
    def _generate_round2(self) -> RoundData:
        """
        Generate Round 2 (bonus) grid - 5 cells.
        
        ONE ROLL 1-100:
        - 1: Rare Egg WIN (1%)
        - 2-11: Seeds WIN (10%)
        - 12-31: Seed TEASE (20%) - 1-2 seeds, can't win
        - 32-41: Egg TEASE (10%) - 1-2 eggs, no drop
        - 42-100: Nothing
        """
        weights = get_bush_type_weights(round_num=2)
        bush_types = list(weights.keys())
        type_weights = list(weights.values())
        
        # ONE ROLL - no crossover
        roll = self.rng.randint(1, 100)
        rare_threshold = int(ROUND2_RARE_DROP_CONFIG["probability"] * 100)  # 1
        seeds_threshold = rare_threshold + int(ROUND2_WIN_CONFIG["cluster_probability"] * 100)  # 11
        seed_tease_threshold = seeds_threshold + int(ROUND2_WIN_CONFIG["seed_tease_probability"] * 100)  # 31
        egg_tease_threshold = seed_tease_threshold + int(ROUND2_WIN_CONFIG["egg_tease_probability"] * 100)  # 41
        
        cells = []
        has_rare_drop = False
        
        if roll <= rare_threshold:
            # RARE EGG WIN - place 3 eggs (mark as targets so frontend counts them!)
            has_rare_drop = True
            for _ in range(3):
                cell = self._make_cell(0, "rare_egg", round_num=2)
                cell["is_seed"] = True  # Eggs ARE the winning match for this roll!
                cells.append(cell)
        elif roll <= seeds_threshold:
            # SEEDS WIN - place 3 seeds
            for _ in range(ROUND2_WIN_CONFIG["guaranteed_cluster_size"]):
                cells.append(self._make_cell(0, ROUND2_TARGET_TYPE, round_num=2))
        elif roll <= seed_tease_threshold:
            # SEED TEASE - 1-2 seeds, can't win
            tease_count = self.rng.randint(1, 2)
            for _ in range(tease_count):
                cells.append(self._make_cell(0, ROUND2_TARGET_TYPE, round_num=2))
        elif roll <= egg_tease_threshold:
            # EGG TEASE - 1-2 eggs, no drop
            tease_count = self.rng.randint(1, 2)
            for _ in range(tease_count):
                cells.append(self._make_cell(0, "rare_egg", round_num=2))
        
        # Fill rest with random filler
        while len(cells) < MAX_REVEALS:
            bush_type = self.rng.choices(bush_types, weights=type_weights, k=1)[0]
            cells.append(self._make_cell(0, bush_type, round_num=2))
        
        # Shuffle
        self.rng.shuffle(cells)
        
        # Assign positions
        for i, cell in enumerate(cells):
            cell["position"] = i
        
        # Check results - only count actual wheat seeds, not eggs marked as is_seed for UI
        actual_seed_count = sum(1 for c in cells if c["bush_type"] == ROUND2_TARGET_TYPE)
        is_seed_winner = actual_seed_count >= ROUND2_WIN_CONFIG["guaranteed_cluster_size"]
        reward_amount = 1 if is_seed_winner else 0
        
        target_positions = [i for i, c in enumerate(cells) if c["is_seed"]]
        
        return RoundData(
            round_num=2,
            grid=cells,
            is_winner=is_seed_winner,  # Only true for actual seed wins
            winning_positions=target_positions,
            reward_amount=reward_amount,
            has_rare_drop=has_rare_drop,
        )
    
    def _make_cell(self, position: int, bush_type: str, round_num: int) -> dict:
        """Create a cell dict with display info from config."""
        bush_types = ROUND1_BUSH_TYPES if round_num == 1 else ROUND2_BUSH_TYPES
        target_type = ROUND1_TARGET_TYPE if round_num == 1 else ROUND2_TARGET_TYPE
        
        # Seed trail is only in round 1
        if bush_type == "seed_trail":
            info = ROUND1_BUSH_TYPES["seed_trail"]
        else:
            info = bush_types.get(bush_type, bush_types.get(target_type, {}))
        
        return {
            "position": position,
            "bush_type": bush_type,
            "icon": info.get("icon", "questionmark"),
            "color": info.get("color", "inkMedium"),
            "name": info.get("name", bush_type),
            "is_seed": bush_type == target_type,
            "is_seed_trail": bush_type == "seed_trail",
            "label": info.get("label"),  # Read from config, not hardcoded
        }
    
    def collect_rewards(self, session: ForagingSession) -> dict:
        """Collect all rewards from both rounds."""
        if session.collected:
            raise ValueError("Already collected")
        
        session.collected = True
        
        rewards = []
        
        # Round 1 rewards (berries)
        if session.round1.is_winner:
            rewards.append({
                "round": 1,
                "item": ROUND1_REWARD_CONFIG["reward_item"],
                "amount": session.round1.reward_amount,
                "display_name": ROUND1_REWARD_CONFIG["reward_item_display_name"],
            })
        
        # Round 2 rewards (seeds) - only if bonus round exists
        if session.round2 and session.round2.is_winner:
            rewards.append({
                "round": 2,
                "item": ROUND2_REWARD_CONFIG["reward_item"],
                "amount": session.round2.reward_amount,
                "display_name": ROUND2_REWARD_CONFIG["reward_item_display_name"],
            })
        
        # Round 2 RARE DROP (Rare Egg) - independent bonus!
        if session.round2 and session.round2.has_rare_drop:
            rewards.append({
                "round": 2,
                "item": ROUND2_RARE_DROP_CONFIG["reward_item"],
                "amount": 1,
                "display_name": ROUND2_RARE_DROP_CONFIG["reward_item_display_name"],
                "is_rare": True,
            })
        
        # Total for legacy compatibility
        total_rewards = len(rewards)
        primary_reward = rewards[0] if rewards else None
        
        return {
            "success": True,
            "is_winner": total_rewards > 0,
            "rewards": rewards,
            # Legacy fields
            "reward_item": primary_reward["item"] if primary_reward else None,
            "reward_amount": primary_reward["amount"] if primary_reward else 0,
        }


# Singleton
_manager = ForagingManager()

def get_manager() -> ForagingManager:
    return _manager

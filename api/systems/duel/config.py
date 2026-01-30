"""
DUEL CONFIG
===========
Combat formulas for 1v1 PvP Arena duels.

Uses same hit chance formula as battles:
  hit_chance = attack / (enemy_defense * 2)

Push formula adapted for 1v1 (leadership matters!):
  push = DUEL_PUSH_BASE * (1 + leadership * DUEL_LEADERSHIP_BONUS)
  
Higher leadership = harder push per hit.
"""

# Import battle constants for consistency
from systems.coup.config import (
    INJURE_PUSH_MULTIPLIER,
    HIT_MULTIPLIER,
    INJURE_MULTIPLIER,
    calculate_roll_chances,
    calculate_max_rolls,
)

# Re-export as DUEL_ prefixed for consistency
DUEL_HIT_MULTIPLIER = HIT_MULTIPLIER

# ============================================================
# DUEL PUSH FORMULA
# ============================================================

# Base push per hit (before leadership bonus)
DUEL_PUSH_BASE = 8.0  # 8% base push (faster matches)

# Leadership bonus: each level adds this much to the multiplier
# push = BASE * (1 + leadership * BONUS)
# Leadership is 0-5, so with 0.20 bonus per level:
# leadership 0: push = 8.0 * 1.0 = 8.0%
# leadership 1: push = 8.0 * 1.20 = 9.6%
# leadership 2: push = 8.0 * 1.40 = 11.2%
# leadership 3: push = 8.0 * 1.60 = 12.8%
# leadership 4: push = 8.0 * 1.80 = 14.4%
# leadership 5: push = 8.0 * 2.0 = 16.0%
DUEL_LEADERSHIP_BONUS = 0.20  # 20% more push per leadership level

# Critical hits push harder (same multiplier as battles)
DUEL_CRITICAL_PUSH_BONUS = INJURE_PUSH_MULTIPLIER  # 1.5x

# Miss gives no push
DUEL_MISS_PUSH = 0.0

# ============================================================
# HIT CHANCE
# ============================================================

# Hit chance formula: attack / (defense * this)
DUEL_DEFENSE_MULTIPLIER = 2.0

# Min/max hit chance (prevent impossible or guaranteed hits)
DUEL_MIN_HIT_CHANCE = 0.10  # 10% minimum
DUEL_MAX_HIT_CHANCE = 0.90  # 90% maximum

# Critical multiplier (15% of hits are crits)
DUEL_CRITICAL_MULTIPLIER = 0.15

# ============================================================
# TIMING
# ============================================================

DUEL_TURN_TIMEOUT_SECONDS = 30     # 30 seconds per turn (strict enforcement)
DUEL_INVITATION_TIMEOUT_MINUTES = 15  # Invitations expire after 15 min
DUEL_MATCH_TIMEOUT_MINUTES = 30    # Matches expire if inactive for 30 min

# ============================================================
# ROUND SYSTEM (Simultaneous submission)
# ============================================================

# Round submission timeout (shared for both players)
DUEL_ROUND_TIMEOUT_SECONDS = 30

# Cap rolls per round for pacing/UI even if attack is high
DUEL_MAX_ROLLS_PER_ROUND_CAP = 4

# Style selection phase timeout (first 10s of the round)
DUEL_STYLE_LOCK_TIMEOUT_SECONDS = 10

# Swing phase timeout (after styles revealed, players have this long to swing)
DUEL_SWING_TIMEOUT_SECONDS = 30

# Style reveal duration (brief pause to show both styles before swinging)
DUEL_STYLE_REVEAL_DURATION_SECONDS = 2

# ============================================================
# ATTACK STYLES
# ============================================================
# 6 techniques that map directly to existing stats/math.
# All modifiers are intentionally small so stats still matter.

class AttackStyle:
    """Attack style modifiers for dueling."""
    
    # Style names
    BALANCED = "balanced"
    AGGRESSIVE = "aggressive"
    PRECISE = "precise"
    POWER = "power"
    GUARD = "guard"
    FEINT = "feint"
    
    ALL_STYLES = [BALANCED, AGGRESSIVE, PRECISE, POWER, GUARD, FEINT]
    
    # Default style if not selected
    DEFAULT = BALANCED

# Style modifier constants
# MULTIPLIERS (not additive) - fair across all stat levels
# hit_chance_mult: 1.0 = no change, 0.80 = 20% reduction, 1.20 = 20% bonus
STYLE_MODIFIERS = {
    # Balanced - no modifiers, the default
    AttackStyle.BALANCED: {
        "roll_bonus": 0,           # +/- to number of rolls
        "hit_chance_mult": 1.0,    # Multiplier on hit chance (1.0 = no change)
        "crit_rate_mult": 1.0,     # Multiplier on crit rate (1.0 = normal)
        "push_mult_win": 1.0,      # Push multiplier if you win the round
        "push_mult_lose": 1.0,     # Opponent push multiplier if you lose
        "opponent_hit_mult": 1.0,  # Multiplier on opponent's hit chance
        "tie_advantage": False,    # Win ties if True
        "description": "No modifiers",
        "icon": "equal.circle.fill",
    },
    
    # Aggressive - more rolls, less accurate
    AttackStyle.AGGRESSIVE: {
        "roll_bonus": 1,           # +1 roll this round (capped by max)
        "hit_chance_mult": 0.80,   # 20% less accurate (swinging wild)
        "crit_rate_mult": 1.0,
        "push_mult_win": 1.0,
        "push_mult_lose": 1.0,
        "opponent_hit_mult": 1.0,
        "tie_advantage": False,
        "description": "+1 roll, -20% hit chance",
        "icon": "flame.fill",
    },
    
    # Precise - more accurate, fewer crits
    AttackStyle.PRECISE: {
        "roll_bonus": 0,
        "hit_chance_mult": 1.20,   # 20% more accurate (careful aim)
        "crit_rate_mult": 0.50,    # 50% fewer crits (not swinging for fences)
        "push_mult_win": 1.0,
        "push_mult_lose": 1.0,
        "opponent_hit_mult": 1.0,
        "tie_advantage": False,
        "description": "+20% hit chance, -50% crit rate",
        "icon": "scope",
    },
    
    # Power - high risk/reward push multipliers
    AttackStyle.POWER: {
        "roll_bonus": 0,
        "hit_chance_mult": 1.0,
        "crit_rate_mult": 1.0,
        "push_mult_win": 1.25,     # +25% push if you win
        "push_mult_lose": 1.20,    # Opponent gets +20% if you lose (symmetric risk)
        "opponent_hit_mult": 1.0,
        "tie_advantage": False,
        "description": "Win: 1.25x push. Lose: enemy 1.2x push",
        "icon": "bolt.fill",
    },
    
    # Guard - defensive, reduces opponent's chances
    # Note: If -1 roll would drop you to 0, you get 1 but opponent gets +1 bonus
    AttackStyle.GUARD: {
        "roll_bonus": -1,          # -1 roll (risky if you have 1 base roll)
        "hit_chance_mult": 1.0,
        "crit_rate_mult": 1.0,
        "push_mult_win": 1.0,
        "push_mult_lose": 1.0,
        "opponent_hit_mult": 0.80, # Opponent is 20% less accurate
        "tie_advantage": False,
        "description": "-1 roll, opponent -20% hit chance",
        "icon": "shield.fill",
    },
    
    # Feint - wins ties, but risky if you lose
    AttackStyle.FEINT: {
        "roll_bonus": 0,
        "hit_chance_mult": 1.0,
        "crit_rate_mult": 1.0,
        "push_mult_win": 1.0,
        "push_mult_lose": 1.25,    # Opponent pushes 25% harder if you lose
        "opponent_hit_mult": 1.0,
        "tie_advantage": True,     # Wins outcome ties
        "description": "Wins ties (better roll breaks feint vs feint). +25% push if you lose.",
        "icon": "arrow.triangle.branch",
    },
}

def get_style_modifiers(style: str) -> dict:
    """Get modifiers for an attack style."""
    return STYLE_MODIFIERS.get(style, STYLE_MODIFIERS[AttackStyle.BALANCED])

def get_all_styles_config() -> list:
    """Get all styles with their config for frontend display."""
    return [
        {
            "id": style,
            "name": style.replace("_", " ").title(),
            "description": STYLE_MODIFIERS[style]["description"],
            "icon": STYLE_MODIFIERS[style]["icon"],
            # Include key modifiers for UI display
            "roll_bonus": STYLE_MODIFIERS[style]["roll_bonus"],
            # Multipliers shown as percentage change: 0.80 → -20%, 1.20 → +20%
            "hit_chance_mod": int((STYLE_MODIFIERS[style]["hit_chance_mult"] - 1.0) * 100),
            "crit_rate_mod": int((STYLE_MODIFIERS[style]["crit_rate_mult"] - 1.0) * 100),
            "push_mult_win": STYLE_MODIFIERS[style]["push_mult_win"],
            "push_mult_lose": STYLE_MODIFIERS[style]["push_mult_lose"],
            "opponent_hit_mod": int((STYLE_MODIFIERS[style]["opponent_hit_mult"] - 1.0) * 100),
            "wins_ties": STYLE_MODIFIERS[style]["tie_advantage"],
        }
        for style in AttackStyle.ALL_STYLES
    ]

# ============================================================
# OUTCOME DISPLAY CONFIGURATION
# ============================================================
# Labels and icons for roll outcomes - frontend uses these directly

OUTCOME_CONFIG = {
    "miss": {
        "label": "MISS",
        "icon": "xmark.circle.fill",
        "color": "disabled",  # Maps to theme color
    },
    "hit": {
        "label": "HIT",
        "icon": "checkmark.circle.fill",
        "color": "buttonSuccess",
    },
    "critical": {
        "label": "CRIT",
        "icon": "flame.fill",
        "color": "imperialGold",
    },
}

def get_outcome_config() -> dict:
    """Get outcome display configuration for frontend."""
    return OUTCOME_CONFIG

# ============================================================
# MATCH SETTINGS
# ============================================================

DUEL_MAX_WAGER = 1000  # Max gold you can wager
DUEL_MIN_WAGER = 0     # Wager is optional
DUEL_CODE_LENGTH = 6   # e.g., "ABC123"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

def calculate_duel_hit_chance(attack: int, enemy_defense: int) -> float:
    """
    Calculate hit chance for a duel attack.
    Same formula as battles.
    """
    effective_attack = attack + 1
    effective_defense = enemy_defense + 1
    
    hit_chance = effective_attack / (effective_defense * DUEL_DEFENSE_MULTIPLIER)
    return max(DUEL_MIN_HIT_CHANCE, min(DUEL_MAX_HIT_CHANCE, hit_chance))


def calculate_duel_max_rolls(attack: int) -> int:
    """Calculate max rolls for a duel turn. Same as battles: 1 + attack."""
    return calculate_max_rolls(attack)


def calculate_duel_round_rolls(attack: int) -> int:
    """
    Rolls per round in the simultaneous round system.
    Keeps the familiar rule (1 + attack) but caps it for pacing.
    """
    return min(calculate_max_rolls(attack), DUEL_MAX_ROLLS_PER_ROUND_CAP)


def calculate_duel_roll_chances(attack: int, enemy_defense: int) -> tuple:
    """
    Calculate miss/hit/crit probabilities (same as battles).
    Returns: (miss_chance, hit_chance, crit_chance) as integers 0-100
    """
    miss_pct, hit_pct, injure_pct = calculate_roll_chances(attack, enemy_defense)
    return (
        int(round(miss_pct * 100)),
        int(round(hit_pct * 100)),
        int(round(injure_pct * 100)),
    )


def calculate_duel_push(leadership: int, is_critical: bool = False) -> float:
    """
    Calculate push amount for a duel attack.
    
    Formula: DUEL_PUSH_BASE * (1 + leadership * DUEL_LEADERSHIP_BONUS)
    
    Higher leadership = harder push!
    
    Examples (leadership is 0-5):
      leadership 0: hit=8.0%, crit=12.0%
      leadership 3: hit=12.8%, crit=19.2%
      leadership 5: hit=16.0%, crit=24.0%
    """
    multiplier = 1.0 + (leadership * DUEL_LEADERSHIP_BONUS)
    base_push = DUEL_PUSH_BASE * multiplier
    
    if is_critical:
        return base_push * DUEL_CRITICAL_PUSH_BONUS
    return base_push


def calculate_roll_outcome(
    roll_value: float,
    hit_chance: float,
    leadership: int = 0
) -> tuple[str, float]:
    """
    Determine outcome of a duel roll.
    """
    if roll_value > hit_chance:
        return ("miss", DUEL_MISS_PUSH)
    
    # It's a hit - check if critical (only top 15% of hits are crits)
    critical_threshold = hit_chance * DUEL_CRITICAL_MULTIPLIER
    
    if roll_value < critical_threshold:
        return ("critical", calculate_duel_push(leadership, is_critical=True))
    else:
        return ("hit", calculate_duel_push(leadership, is_critical=False))


def generate_match_code() -> str:
    """Generate a random match code (e.g., 'ABC123')"""
    import random
    import string
    
    chars = string.ascii_uppercase + string.digits
    chars = chars.replace('O', '').replace('0', '').replace('I', '').replace('1', '').replace('L', '')
    
    return ''.join(random.choice(chars) for _ in range(DUEL_CODE_LENGTH))


def get_duel_game_config() -> dict:
    """
    Return ALL game config that the frontend needs.
    
    DUMB RENDERER PRINCIPLE:
    - Frontend displays what server tells it
    - NO hardcoded values on frontend
    - Change config here = changes everywhere instantly
    - No app redeployment needed
    """
    return {
        # Mode
        "duel_mode": "swing_by_swing",

        # Timing
        "turn_timeout_seconds": DUEL_TURN_TIMEOUT_SECONDS,
        "round_timeout_seconds": DUEL_ROUND_TIMEOUT_SECONDS,
        "style_lock_timeout_seconds": DUEL_STYLE_LOCK_TIMEOUT_SECONDS,
        "swing_timeout_seconds": DUEL_SWING_TIMEOUT_SECONDS,
        "style_reveal_duration_seconds": DUEL_STYLE_REVEAL_DURATION_SECONDS,
        "invitation_timeout_minutes": DUEL_INVITATION_TIMEOUT_MINUTES,
        
        # Combat multipliers (for display)
        "critical_multiplier": DUEL_CRITICAL_PUSH_BONUS,  # 1.5
        "critical_multiplier_text": f"{DUEL_CRITICAL_PUSH_BONUS}x",
        "push_base_percent": DUEL_PUSH_BASE,  # 4.0
        "leadership_bonus_percent": DUEL_LEADERSHIP_BONUS * 100,  # 20
        
        # Hit chance bounds
        "min_hit_chance_percent": int(DUEL_MIN_HIT_CHANCE * 100),  # 10
        "max_hit_chance_percent": int(DUEL_MAX_HIT_CHANCE * 100),  # 90
        
        # Crit rate (what % of hits become crits)
        "crit_rate_percent": int(DUEL_CRITICAL_MULTIPLIER * 100),  # 15
        
        # Wager limits
        "max_wager_gold": DUEL_MAX_WAGER,
        
        # Animation timing (milliseconds)
        "roll_animation_ms": 400,
        "roll_pause_between_ms": 300,
        "crit_popup_duration_ms": 1500,
        "roll_sweep_step_ms": 15,
        "style_reveal_duration_ms": DUEL_STYLE_REVEAL_DURATION_SECONDS * 1000,

        # Round pacing
        "max_rolls_per_round_cap": DUEL_MAX_ROLLS_PER_ROUND_CAP,
        
        # Attack styles - ALL style definitions come from server
        "attack_styles": get_all_styles_config(),
        "default_style": AttackStyle.DEFAULT,
        
        # Outcome display config - labels, icons, colors for miss/hit/crit
        "outcomes": get_outcome_config(),
    }

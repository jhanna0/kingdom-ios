"""
ROLL SYSTEM CONFIGURATION
=========================
All probability constants and formulas in ONE place.
Tune these values to balance the game - NO magic numbers elsewhere!

The roll system is inspired by RuneScape's skill checks.
Base success chance scales with player stat level (1-10).
"""

# ============================================================
# CORE ROLL FORMULA CONSTANTS
# ============================================================
# Success probability formula: p = clamp(BASE + (SCALING * stat), MIN, MAX)

ROLL_BASE_CHANCE = 0.15          # Base chance at stat level 0
ROLL_SCALING_PER_LEVEL = 0.08   # +8% per stat level
ROLL_MIN_CHANCE = 0.10          # Minimum success chance (even at level 0)
ROLL_MAX_CHANCE = 0.95          # Maximum success chance (can never guarantee)


# ============================================================
# CRITICAL ROLL MODIFIERS
# ============================================================
# Critical success/failure thresholds
CRITICAL_SUCCESS_THRESHOLD = 0.95  # Roll >= this = critical success
CRITICAL_FAILURE_THRESHOLD = 0.05  # Roll <= this = critical failure

CRITICAL_SUCCESS_MULTIPLIER = 1.5  # Bonus multiplier on critical success
CRITICAL_FAILURE_PENALTY = 0.5     # Reduction on critical failure


# ============================================================
# GROUP ROLL MODIFIERS
# ============================================================
# When multiple players roll, how do we combine results?
# Options: "sum" (add successes), "best" (take highest), "average"
GROUP_ROLL_MODE = "sum"

# Group size bonuses (more players = slight bonus to offset harder content)
GROUP_SIZE_BONUS = {
    1: 0.0,    # Solo - no bonus
    2: 0.02,   # Duo - +2% to all rolls
    3: 0.03,   # Trio - +3%
    4: 0.04,   # Quad - +4%
    5: 0.05,   # Full party - +5%
}


# ============================================================
# SKILL CATEGORY WEIGHTS
# ============================================================
# Different activities may weight certain sub-stats differently
# Format: { "activity_type": { "stat_name": weight } }

SKILL_WEIGHTS = {
    "hunting_track": {
        "intelligence": 1.0,  # Primary stat for tracking
    },
    "hunting_approach": {
        "defense": 0.7,
        "intelligence": 0.3,  # Some awareness helps
    },
    "hunting_coordinate": {
        "leadership": 1.0,
    },
    "hunting_strike": {
        "attack_power": 0.8,
        "defense": 0.2,  # Defense helps avoid injury
    },
    "hunting_brace": {
        "defense": 1.0,
    },
    "hunting_blessing": {
        "faith": 1.0,
    },
}


# ============================================================
# PROBABILITY DISPLAY HELPERS
# ============================================================
# For UI: Show player their actual chances

def get_success_chance(stat_level: int, activity: str = None) -> float:
    """
    Calculate success probability for a given stat level.
    
    Args:
        stat_level: Player's stat level (0-10)
        activity: Optional activity type for weighted stats
        
    Returns:
        Probability between ROLL_MIN_CHANCE and ROLL_MAX_CHANCE
    """
    raw_chance = ROLL_BASE_CHANCE + (ROLL_SCALING_PER_LEVEL * stat_level)
    return max(ROLL_MIN_CHANCE, min(ROLL_MAX_CHANCE, raw_chance))


def get_chance_display(stat_level: int) -> dict:
    """
    Get human-readable probability info for UI display.
    Returns dict with percentage and tier description.
    """
    chance = get_success_chance(stat_level)
    percentage = int(chance * 100)
    
    if percentage >= 80:
        tier = "Excellent"
        color = "buttonSuccess"
    elif percentage >= 60:
        tier = "Good"
        color = "gold"
    elif percentage >= 40:
        tier = "Fair"
        color = "inkMedium"
    elif percentage >= 25:
        tier = "Poor"
        color = "buttonWarning"
    else:
        tier = "Unlikely"
        color = "buttonDanger"
    
    return {
        "percentage": percentage,
        "tier": tier,
        "color": color,
        "description": f"{percentage}% chance of success"
    }


# ============================================================
# ROLL CONFIG CLASS (for programmatic access)
# ============================================================

class RollConfig:
    """Programmatic access to roll configuration"""
    
    BASE_CHANCE = ROLL_BASE_CHANCE
    SCALING = ROLL_SCALING_PER_LEVEL
    MIN_CHANCE = ROLL_MIN_CHANCE
    MAX_CHANCE = ROLL_MAX_CHANCE
    
    CRITICAL_SUCCESS = CRITICAL_SUCCESS_THRESHOLD
    CRITICAL_FAILURE = CRITICAL_FAILURE_THRESHOLD
    CRITICAL_SUCCESS_MULT = CRITICAL_SUCCESS_MULTIPLIER
    CRITICAL_FAILURE_MULT = CRITICAL_FAILURE_PENALTY
    
    GROUP_MODE = GROUP_ROLL_MODE
    GROUP_BONUSES = GROUP_SIZE_BONUS
    
    @classmethod
    def get_chance(cls, stat_level: int) -> float:
        return get_success_chance(stat_level)
    
    @classmethod
    def get_display(cls, stat_level: int) -> dict:
        return get_chance_display(stat_level)


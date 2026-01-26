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
DUEL_PUSH_BASE = 4.0  # 4% base push

# Leadership bonus: each level adds this much to the multiplier
# push = BASE * (1 + leadership * BONUS)
# Leadership is 0-5, so with 0.20 bonus per level:
# leadership 0: push = 4.0 * 1.0 = 4.0%
# leadership 1: push = 4.0 * 1.20 = 4.8%
# leadership 2: push = 4.0 * 1.40 = 5.6%
# leadership 3: push = 4.0 * 1.60 = 6.4%
# leadership 4: push = 4.0 * 1.80 = 7.2%
# leadership 5: push = 4.0 * 2.0 = 8.0%
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
      leadership 0: hit=4.0%, crit=6.0%
      leadership 3: hit=6.4%, crit=9.6%
      leadership 5: hit=8.0%, crit=12.0%
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
    
    # It's a hit - check if critical
    critical_threshold = hit_chance * (1 - DUEL_CRITICAL_MULTIPLIER)
    
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

"""
DUEL CONFIG
===========
Combat formulas for 1v1 PvP Arena duels.

Uses same base formula as hunting/battles but tuned for 1v1:
  hit_chance = attack / (enemy_defense * 2)

Differences from battles:
- No territories, just one tug-of-war bar
- Turn-based (alternating turns, not simultaneous)
- Simpler: no injuries, no leadership multipliers
- Faster matches (stronger pushes, quicker resolution)

FORMULAS:
---------
1. HIT CHANCE:
   base_hit = attack / (enemy_defense * 2)
   Capped between 10% and 90%
   
2. CRITICAL CHANCE:
   critical = hit_chance * CRITICAL_MULTIPLIER (0.15 = 15% of hits are crits)
   
3. PUSH PER HIT:
   hit_push = PUSH_BASE (10)
   critical_push = hit_push * CRITICAL_PUSH_BONUS (1.5x)
   
4. BAR:
   Starts at 50 (neutral)
   Challenger pushes toward 0 (wins at 0)
   Opponent pushes toward 100 (wins at 100)
"""

# ============================================================
# COMBAT MECHANICS
# ============================================================

# Hit chance formula: attack / (defense * this)
DUEL_DEFENSE_MULTIPLIER = 2.0

# Min/max hit chance (prevent impossible or guaranteed hits)
DUEL_MIN_HIT_CHANCE = 0.10  # 10% minimum
DUEL_MAX_HIT_CHANCE = 0.90  # 90% maximum

# Multipliers for hits
DUEL_HIT_MULTIPLIER = 1.0    # Normal hit
DUEL_CRITICAL_MULTIPLIER = 0.15  # 15% of successful hits are critical

# Push amounts
DUEL_PUSH_BASE = 10.0           # Base push per successful hit
DUEL_CRITICAL_PUSH_BONUS = 1.5  # Critical hits push 50% more

# Miss gives no push
DUEL_MISS_PUSH = 0.0

# ============================================================
# TIMING
# ============================================================

DUEL_TURN_TIMEOUT_SECONDS = 60     # 60 seconds per turn
DUEL_INVITATION_TIMEOUT_MINUTES = 15  # Invitations expire after 15 min
DUEL_MATCH_TIMEOUT_MINUTES = 30    # Matches expire if inactive for 30 min

# ============================================================
# MATCH SETTINGS
# ============================================================

DUEL_MAX_WAGER = 1000  # Max gold you can wager
DUEL_MIN_WAGER = 0     # Wager is optional

# Match code length
DUEL_CODE_LENGTH = 6   # e.g., "ABC123"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

def calculate_duel_hit_chance(attack: int, enemy_defense: int) -> float:
    """
    Calculate hit chance for a duel attack.
    
    Formula: attack / (defense * 2)
    +1 is added to both to give everyone baseline stats.
    
    Returns: Float 0.10 to 0.90
    """
    # Add 1 to ensure baseline chance
    effective_attack = attack + 1
    effective_defense = enemy_defense + 1
    
    hit_chance = effective_attack / (effective_defense * DUEL_DEFENSE_MULTIPLIER)
    
    # Clamp between min and max
    return max(DUEL_MIN_HIT_CHANCE, min(DUEL_MAX_HIT_CHANCE, hit_chance))


def calculate_duel_push(is_hit: bool, is_critical: bool = False) -> float:
    """
    Calculate push amount for an attack.
    
    Returns:
        0.0 for miss
        PUSH_BASE (10.0) for hit
        PUSH_BASE * 1.5 (15.0) for critical
    """
    if not is_hit:
        return DUEL_MISS_PUSH
    
    push = DUEL_PUSH_BASE
    if is_critical:
        push *= DUEL_CRITICAL_PUSH_BONUS
    
    return push


def calculate_roll_outcome(
    roll_value: float,
    hit_chance: float
) -> tuple[str, float]:
    """
    Determine outcome of a duel roll.
    
    Args:
        roll_value: Random float 0.0-1.0
        hit_chance: Probability of hitting (0.10-0.90)
    
    Returns:
        (outcome, push_amount)
        outcome is 'miss', 'hit', or 'critical'
    """
    if roll_value > hit_chance:
        return ("miss", 0.0)
    
    # It's a hit - check if critical
    # Critical if roll is in the top 15% of the hit range
    critical_threshold = hit_chance * (1 - DUEL_CRITICAL_MULTIPLIER)
    
    if roll_value < critical_threshold:
        return ("critical", DUEL_PUSH_BASE * DUEL_CRITICAL_PUSH_BONUS)
    else:
        return ("hit", DUEL_PUSH_BASE)


def generate_match_code() -> str:
    """Generate a random match code (e.g., 'ABC123')"""
    import random
    import string
    
    # Mix of uppercase letters and digits, easy to read
    chars = string.ascii_uppercase + string.digits
    # Remove confusing characters
    chars = chars.replace('O', '').replace('0', '').replace('I', '').replace('1', '').replace('L', '')
    
    return ''.join(random.choice(chars) for _ in range(DUEL_CODE_LENGTH))

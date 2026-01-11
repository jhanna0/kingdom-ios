"""
COUP BATTLE CONFIG
==================
All combat formulas and constants in one place.
Must match BattleSimulatorView.swift on iOS.

FORMULAS:
---------
1. ROLL BAR (hit chance):
   MISS slots   = enemy_defense × 2
   HIT slots    = attack × HIT_MULTIPLIER (0.9)
   INJURE slots = attack × INJURE_MULTIPLIER (0.1)
   Total        = MISS + HIT + INJURE
   
   P(outcome) = slots / total

2. PUSH PER HIT:
   push = 1 / size^(SIZE_EXPONENT_BASE - leadership × LEADERSHIP_DAMPENING_PER_TIER)
   
   Bigger army = less push per hit (diminishing returns)
   Higher leadership = dampens the size penalty

3. MAX ROLLS:
   max_rolls = 1 + attack_power

4. INJURE BONUS:
   injure_push = base_push × INJURE_PUSH_MULTIPLIER
"""

# ============================================================
# ROLL BAR - Determines hit/miss/injure probability
# ============================================================

# Slot multipliers for roll outcomes
# MISS slots = enemy_defense × 2 (hardcoded)
HIT_MULTIPLIER = 0.9      # HIT slots = attack × 0.9
INJURE_MULTIPLIER = 0.1   # INJURE slots = attack × 0.1

# ============================================================
# PUSH PER HIT - How much the bar moves on a successful hit
# ============================================================

# Formula: push = 1 / size^(BASE - leadership × DAMPENING)
SIZE_EXPONENT_BASE = 0.85           # Base exponent for size penalty
LEADERSHIP_DAMPENING_PER_TIER = 0.02  # How much leadership reduces penalty

# Injury gives bonus push
INJURE_PUSH_MULTIPLIER = 1.5  # 50% bonus for critical hit

# ============================================================
# COOLDOWNS
# ============================================================

BATTLE_ACTION_COOLDOWN_MINUTES = 10  # Time between fights
INJURY_DURATION_MINUTES = 20         # How long injured players sit out

# ============================================================
# TERRITORIES
# ============================================================

TERRITORY_COUPERS = "coupers_territory"
TERRITORY_CROWNS = "crowns_territory"
TERRITORY_THRONE = "throne_room"

# Starting bar values (0 = attackers win, 100 = defenders win)
TERRITORY_STARTING_BARS = {
    TERRITORY_COUPERS: 50.0,
    TERRITORY_CROWNS: 50.0,
    TERRITORY_THRONE: 50.0,
}

TERRITORY_DISPLAY_NAMES = {
    TERRITORY_COUPERS: "Coupers Territory",
    TERRITORY_CROWNS: "Crowns Territory",
    TERRITORY_THRONE: "Throne Room",
}

TERRITORY_ICONS = {
    TERRITORY_COUPERS: "figure.fencing",
    TERRITORY_CROWNS: "crown.fill",
    TERRITORY_THRONE: "building.columns.fill",
}

# ============================================================
# COUP OUTCOME - Rewards and penalties
# ============================================================

# Gold redistribution - take from losers, give to winners
LOSER_GOLD_PERCENT = 0.50  # Losers lose 50% of their gold

# Reputation changes
WINNER_REP_GAIN = 100
LOSER_REP_LOSS = 100

# Skill penalties for losers
LOSER_ATTACK_LOSS = 1
LOSER_DEFENSE_LOSS = 1
LOSER_LEADERSHIP_LOSS = 1

# ============================================================
# HELPER FUNCTIONS
# ============================================================

def calculate_roll_chances(attack: int, enemy_defense: float) -> tuple[float, float, float]:
    """
    Calculate hit/miss/injure probabilities.
    
    +1 is added to both attack and defense to ensure everyone has a baseline chance.
    This prevents 0 attack from having 0% hit chance and 0 defense from being useless.
    
    Returns: (miss_chance, hit_chance, injure_chance) - all 0.0 to 1.0
    """
    miss_slots = (enemy_defense + 1) * 2.0
    hit_slots = (attack + 1) * HIT_MULTIPLIER
    injure_slots = (attack + 1) * INJURE_MULTIPLIER
    total = miss_slots + hit_slots + injure_slots
    
    return (
        miss_slots / total,
        hit_slots / total,
        injure_slots / total,
    )


def calculate_push_per_hit(side_size: int, avg_leadership: float) -> float:
    """
    Calculate how much the bar moves per successful hit.
    
    Bigger armies get less push per hit (diminishing returns).
    Leadership dampens the size penalty.
    """
    exponent = SIZE_EXPONENT_BASE - (avg_leadership * LEADERSHIP_DAMPENING_PER_TIER)
    return 1.0 / pow(max(1, side_size), exponent)


def calculate_max_rolls(attack_power: int) -> int:
    """Calculate max rolls for a fight session."""
    return 1 + attack_power

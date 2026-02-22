"""
BATTLE CONFIG
=============
Unified config for both Coups and Invasions.
Must match iOS BattleSimulatorView.swift (if we build one).

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

5. WALL DEFENSE (Invasions only):
   wall_defense = wall_level × WALL_DEFENSE_PER_LEVEL
   Added to each defender's effective defense
"""

# ============================================================
# ROLL BAR - Determines hit/miss/injure probability
# ============================================================

HIT_MULTIPLIER = 0.9      # HIT slots = attack × 0.9
INJURE_MULTIPLIER = 0.1   # INJURE slots = attack × 0.1

# ============================================================
# PUSH PER HIT - How much the bar moves on a successful hit
# ============================================================

SIZE_EXPONENT_BASE = 0.85           # Base exponent for size penalty
LEADERSHIP_DAMPENING_PER_TIER = 0.02  # How much leadership reduces penalty
INJURE_PUSH_MULTIPLIER = 1.5  # 50% bonus for critical hit

# ============================================================
# COOLDOWNS
# ============================================================

BATTLE_ACTION_COOLDOWN_MINUTES = 10  # Time between fights
INJURY_DURATION_MINUTES = 20         # How long injured players sit out

# ============================================================
# COUP TERRITORIES (3 territories, capture 2 to win)
# ============================================================

TERRITORY_COUPERS = "coupers_territory"
TERRITORY_CROWNS = "crowns_territory"
TERRITORY_THRONE = "throne_room"

COUP_TERRITORIES = [TERRITORY_COUPERS, TERRITORY_CROWNS, TERRITORY_THRONE]
COUP_WIN_THRESHOLD = 2  # Capture 2 of 3 to win

COUP_TERRITORY_STARTING_BARS = {
    TERRITORY_COUPERS: 50.0,
    TERRITORY_CROWNS: 50.0,
    TERRITORY_THRONE: 50.0,
}

COUP_TERRITORY_DISPLAY_NAMES = {
    TERRITORY_COUPERS: "Coupers Territory",
    TERRITORY_CROWNS: "Crowns Territory",
    TERRITORY_THRONE: "Throne Room",
}

COUP_TERRITORY_ICONS = {
    TERRITORY_COUPERS: "figure.fencing",
    TERRITORY_CROWNS: "crown.fill",
    TERRITORY_THRONE: "building.columns.fill",
}

# ============================================================
# INVASION TERRITORIES (5 territories, capture 3 to win)
# ============================================================

TERRITORY_NORTH = "north"
TERRITORY_SOUTH = "south"
TERRITORY_EAST = "east"
TERRITORY_WEST = "west"
TERRITORY_CAPITOL = "capitol"

INVASION_TERRITORIES = [
    TERRITORY_NORTH, 
    TERRITORY_SOUTH, 
    TERRITORY_EAST, 
    TERRITORY_WEST, 
    TERRITORY_CAPITOL
]
INVASION_WIN_THRESHOLD = 3  # Capture 3 of 5 to win

INVASION_TERRITORY_STARTING_BARS = {
    TERRITORY_NORTH: 50.0,
    TERRITORY_SOUTH: 50.0,
    TERRITORY_EAST: 50.0,
    TERRITORY_WEST: 50.0,
    TERRITORY_CAPITOL: 50.0,
}

INVASION_TERRITORY_DISPLAY_NAMES = {
    TERRITORY_NORTH: "Northern Gate",
    TERRITORY_SOUTH: "Southern Gate",
    TERRITORY_EAST: "Eastern Gate",
    TERRITORY_WEST: "Western Gate",
    TERRITORY_CAPITOL: "Capitol",
}

INVASION_TERRITORY_ICONS = {
    TERRITORY_NORTH: "arrow.up.circle.fill",
    TERRITORY_SOUTH: "arrow.down.circle.fill",
    TERRITORY_EAST: "arrow.right.circle.fill",
    TERRITORY_WEST: "arrow.left.circle.fill",
    TERRITORY_CAPITOL: "building.columns.fill",
}

# ============================================================
# WALLS (Invasions only)
# ============================================================

WALL_DEFENSE_PER_LEVEL = 5  # Each wall level adds 5 to total defense

# ============================================================
# TIMING
# ============================================================

COUP_PLEDGE_DURATION_HOURS = 12      # Coup pledge phase (join only during this window)
INVASION_DECLARATION_HOURS = 12      # Invasion warning period before battle starts

# ============================================================
# JOIN RULES
# ============================================================
# 
# COUP:
# - Initiator: T3 leadership + 500 rep, checked into kingdom
# - Phase 1 (12h): Pledge/voting - people pick sides
# - Phase 2: Battle - fight for territories
# - Can join during BOTH phases
# - Join requirement: Have reputation in the kingdom
#
# INVASION:
# - Initiator: Must be a RULER, must be AT the target kingdom
# - Phase 1 (12h): Declaration - warning period  
# - Phase 2: Battle - fight for territories
# - Can join during BOTH phases
# - Join requirement: Have visited the target kingdom at least once
#

# ============================================================
# ELIGIBILITY
# ============================================================

# Coup initiator requirements
COUP_REPUTATION_REQUIREMENT = 500    # Kingdom reputation needed to INITIATE
COUP_LEADERSHIP_REQUIREMENT = 3      # T3 leadership needed to INITIATE

# Coup join requirements  
COUP_JOIN_REPUTATION_REQUIREMENT = 100  # Min rep to JOIN a coup (not initiate)

# Invasion initiator requirements
# - Must rule at least one kingdom
# - Must be present at target kingdom

# ============================================================
# COOLDOWNS
# ============================================================

# Coup cooldowns
COUP_PLAYER_COOLDOWN_DAYS = 30       # Days between coup attempts per player
COUP_KINGDOM_COOLDOWN_DAYS = 7       # Days between coups in same kingdom
COUP_RULER_PROTECTION_DAYS = 7       # New rulers protected from coups for 7 days

# Invasion cooldowns
INVASION_KINGDOM_COOLDOWN_DAYS = 30  # Days before a kingdom can be invaded again
INVASION_AFTER_COUP_COOLDOWN_DAYS = 7  # Days after a coup before kingdom can be invaded

# Universal battle buffer - kingdoms involved in ANY battle get 7 day protection
BATTLE_BUFFER_DAYS = 7  # Applies to kingdoms under coup, invasion, OR actively invading

# ============================================================
# INVASION REQUIREMENTS
# ============================================================
#
# To DECLARE an invasion:
# 1. Must be a ruler (rule at least one kingdom)
# 2. Must be PRESENT at the target kingdom (checked in)
# 3. Target kingdom must have a ruler (can't invade unruled)
# 4. Target kingdom can't already be under attack (no active invasion)
# 5. Target kingdom can't have been invaded recently (30 day cooldown)
# 6. Target kingdom can't have had a recent coup (7 day cooldown)
# 7. Can't invade your own empire
# 8. Can't invade allied kingdoms
#

# ============================================================
# REWARDS/PENALTIES
# ============================================================

LOSER_GOLD_PERCENT = 0.50  # Losers lose 50% of their gold
WINNER_REP_GAIN = 100
LOSER_REP_LOSS = 100

# Skill penalties - ONLY for invasion losses, NOT coups
# Coup losers only lose gold and rep (no skill loss)
LOSER_ATTACK_LOSS = 1
LOSER_DEFENSE_LOSS = 1
LOSER_LEADERSHIP_LOSS = 1

# Invasion-specific penalties (attackers fail)
INVASION_TREASURY_TRANSFER_PERCENT = 0.50  # 50% of attacking kingdom treasury → defending kingdom
INVASION_ATTACKER_GOLD_TO_DEFENDERS_PERCENT = 0.10  # 10% from each attacker's gold → split among defenders

# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_territories_for_type(battle_type: str) -> list:
    """Get territory names based on battle type."""
    if battle_type == "invasion":
        return INVASION_TERRITORIES
    return COUP_TERRITORIES


def get_starting_bars_for_type(battle_type: str) -> dict:
    """Get starting bar values based on battle type."""
    if battle_type == "invasion":
        return INVASION_TERRITORY_STARTING_BARS
    return COUP_TERRITORY_STARTING_BARS


def get_win_threshold_for_type(battle_type: str) -> int:
    """Get number of territories needed to win."""
    if battle_type == "invasion":
        return INVASION_WIN_THRESHOLD
    return COUP_WIN_THRESHOLD


def get_display_names_for_type(battle_type: str) -> dict:
    """Get territory display names based on battle type."""
    if battle_type == "invasion":
        return INVASION_TERRITORY_DISPLAY_NAMES
    return COUP_TERRITORY_DISPLAY_NAMES


def get_icons_for_type(battle_type: str) -> dict:
    """Get territory icons based on battle type."""
    if battle_type == "invasion":
        return INVASION_TERRITORY_ICONS
    return COUP_TERRITORY_ICONS


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


def calculate_wall_defense(wall_level: int) -> int:
    """Calculate defense bonus from walls (invasions only)."""
    return wall_level * WALL_DEFENSE_PER_LEVEL


# ============================================================
# LEGACY COMPATIBILITY - Keep old names working
# ============================================================
# These are used by the old coup code until we migrate it

TERRITORY_STARTING_BARS = COUP_TERRITORY_STARTING_BARS
TERRITORY_DISPLAY_NAMES = COUP_TERRITORY_DISPLAY_NAMES
TERRITORY_ICONS = COUP_TERRITORY_ICONS

# Alias for backward compat
INVASION_PLEDGE_DURATION_HOURS = INVASION_DECLARATION_HOURS

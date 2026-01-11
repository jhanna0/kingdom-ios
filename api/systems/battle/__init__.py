"""
Unified Battle System - Coups and Invasions

Both use the same core mechanics:
- Territory-based tug-of-war combat
- Roll-by-roll fight sessions
- Injuries and cooldowns

Differences:
- Coup: 3 territories, no walls, internal
- Invasion: 5 territories, walls apply, external
"""

from .config import (
    # Roll mechanics
    HIT_MULTIPLIER,
    INJURE_MULTIPLIER,
    SIZE_EXPONENT_BASE,
    LEADERSHIP_DAMPENING_PER_TIER,
    INJURE_PUSH_MULTIPLIER,
    
    # Cooldowns
    BATTLE_ACTION_COOLDOWN_MINUTES,
    INJURY_DURATION_MINUTES,
    
    # Coup territories
    TERRITORY_COUPERS,
    TERRITORY_CROWNS,
    TERRITORY_THRONE,
    COUP_TERRITORIES,
    COUP_WIN_THRESHOLD,
    
    # Invasion territories
    TERRITORY_NORTH,
    TERRITORY_SOUTH,
    TERRITORY_EAST,
    TERRITORY_WEST,
    TERRITORY_CAPITOL,
    INVASION_TERRITORIES,
    INVASION_WIN_THRESHOLD,
    
    # Walls
    WALL_DEFENSE_PER_LEVEL,
    
    # Helper functions
    get_territories_for_type,
    get_starting_bars_for_type,
    get_win_threshold_for_type,
    get_display_names_for_type,
    get_icons_for_type,
    calculate_roll_chances,
    calculate_push_per_hit,
    calculate_max_rolls,
    calculate_wall_defense,
)

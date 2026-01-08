"""
COVERT INCIDENT CONFIGURATION
=============================
All tunable values for the incident system in ONE place.
Adjust these to balance the game - NO magic numbers elsewhere!

HOW IT WORKS:
1. Player uses Infiltrate action in enemy kingdom
2. INITIAL SUCCESS ROLL determines if operation succeeds:
   - Higher intelligence tier = better base success chance
   - More enemy patrols = penalty to success chance
   - Success chances are deliberately LOW (this is hard!)
3. If initial roll SUCCEEDS → incident triggers, tug of war begins
4. Both sides roll to shift the probability bar
5. Master roll picks outcome (prevent vs attacker outcomes)

If initial roll FAILS → operation fails, attacker loses gold/cooldown, gets nothing.
"""

from typing import Dict, Optional


# ============================================================
# INITIAL SUCCESS CONFIGURATION (Intelligence Tier vs Patrols)
# ============================================================
# This is the FIRST check - does the operation even succeed?
# Higher intelligence tier = better base chance
# More enemy patrols = harder to succeed (penalty per patrol)
#
# DESIGN: Success should NOT be very high! This is risky espionage.
#
# Formula: success_chance = BASE_SUCCESS[tier] - (patrols * PATROL_PENALTY)
# Clamped to [MIN_SUCCESS, MAX_SUCCESS]

# Base success chance by intelligence tier (before patrol penalty)
INITIAL_SUCCESS_BY_TIER = {
    1: 0.20,   # T1: 20% base
    2: 0.28,   # T2: 28% base
    3: 0.36,   # T3: 36% base
    4: 0.44,   # T4: 44% base
    5: 0.52,   # T5: 52% base
    6: 0.58,   # T6: 58% base
    7: 0.64,   # T7: 64% base (max tier)
}

# Penalty per active patrol (subtracts from success chance)
PATROL_PENALTY_PER_PATROL = 0.06  # -6% per patrol

# Minimum success chance (even with many patrols, you have SOME chance)
MIN_SUCCESS_CHANCE = 0.05  # 5% floor

# Maximum success chance (cap it so it's never trivial)
MAX_SUCCESS_CHANCE = 0.70  # 70% ceiling

# LEGACY - keeping for backwards compatibility (not used in new flow)
TRIGGER_CHANCE_PER_PATROL = 0.08
BASE_TRIGGER_CHANCE = 0.0


# ============================================================
# TIMING CONFIGURATION
# ============================================================

INCIDENT_DURATION_SECONDS = 300   # 5 minutes for the event to be active
INCIDENT_COOLDOWN_MINUTES = 30    # Cooldown before same attacker->defender pair can trigger again


# ============================================================
# PARTICIPATION LIMITS
# ============================================================

MAX_ROLLS_PER_PLAYER = 3          # How many times one player can roll in an incident
MAX_ROLLS_PER_SIDE = 10           # Total rolls allowed per side (attacker/defender)
MIN_ROLLS_TO_RESOLVE = 1          # At least 1 roll before can resolve


# ============================================================
# DROP TABLE - THE PROBABILITY BAR (Scales with Intelligence Tier!)
# ============================================================
# Slots out of 100. Players shift these with successful rolls.
# "prevent" = defender wins, operation blocked
# Other slots = attacker outcomes
#
# TIER UNLOCKS OUTCOMES:
# - T1: prevent, intel
# - T3: + disruption
# - T5: + contract_sabotage

# Base table for T1 (only prevent and intel)
INCIDENT_DROP_TABLE_T1 = {
    "prevent": 60,              # Defender wins (60%)
    "intel": 40,                # Attacker gets intelligence (40%)
}

# T3 adds disruption
INCIDENT_DROP_TABLE_T3 = {
    "prevent": 50,              # Defender wins (50%)
    "intel": 30,                # Attacker gets intelligence (30%)
    "disruption": 20,           # Attacker causes temp debuff (20%)
}

# T5 adds contract_sabotage AND vault_heist
INCIDENT_DROP_TABLE_T5 = {
    "prevent": 40,              # Defender wins (40%)
    "intel": 22,                # Attacker gets intelligence (22%)
    "disruption": 18,           # Attacker causes temp debuff (18%)
    "contract_sabotage": 12,    # Attacker delays contract (12%)
    "vault_heist": 8,           # Attacker steals gold (8%)
}

# Legacy alias
INCIDENT_DROP_TABLE = INCIDENT_DROP_TABLE_T1


def get_drop_table_for_tier(intelligence_tier: int) -> dict:
    """Get the appropriate drop table based on attacker's intelligence tier"""
    if intelligence_tier >= 5:
        return INCIDENT_DROP_TABLE_T5.copy()
    elif intelligence_tier >= 3:
        return INCIDENT_DROP_TABLE_T3.copy()
    else:
        return INCIDENT_DROP_TABLE_T1.copy()


# ============================================================
# SHIFT AMOUNTS (How rolls move the bar)
# ============================================================
# Positive = more likely, Negative = less likely
# These are applied per successful roll
# Only shifts outcomes that exist in the current tier's table!

# When ATTACKER succeeds: pull from prevent, add to attacker outcomes
ATTACKER_SHIFT = {
    "prevent": -8,              # Less likely to prevent
    "intel": +4,                # More likely intel
    "disruption": +2,           # More likely disruption (if unlocked)
    "contract_sabotage": +1,    # Slightly more likely sabotage (if unlocked)
    "vault_heist": +1,          # Slightly more likely heist (if unlocked)
}

# When DEFENDER succeeds: pull from attacker outcomes, add to prevent
DEFENDER_SHIFT = {
    "prevent": +10,             # More likely to prevent
    "intel": -5,                # Less likely intel
    "disruption": -3,           # Less likely disruption (if unlocked)
    "contract_sabotage": -1,    # Less likely sabotage (if unlocked)
    "vault_heist": -1,          # Less likely heist (if unlocked)
}

# Combined for easy lookup
INCIDENT_SHIFT_PER_SUCCESS = {
    "attacker": ATTACKER_SHIFT,
    "defender": DEFENDER_SHIFT,
}

# Critical success multiplier (same as hunts)
CRITICAL_SHIFT_MULTIPLIER = 2


# ============================================================
# OUTCOME EFFECTS (What happens when each outcome is rolled)
# ============================================================

# Intel outcome: creates/updates KingdomIntelligence
INTEL_EXPIRY_HOURS = 48         # How long intel lasts

# Disruption outcome: temporary debuff
DISRUPTION_DURATION_MINUTES = 30
DISRUPTION_COOLDOWN_PENALTY = 0.10  # +10% cooldown on actions

# Contract sabotage outcome: delays active contract
SABOTAGE_DELAY_PERCENT = 0.05   # Add 5% more actions to contract
SABOTAGE_COOLDOWN_HOURS = 6     # Can only sabotage same kingdom once per 6 hours

# Vault heist outcome: steal gold from kingdom vault (T5 only)
HEIST_PERCENT = 0.10            # Steal 10% of vault
HEIST_MIN_GOLD = 500            # Minimum gold to steal (if vault has enough)


# ============================================================
# REWARDS/COSTS
# ============================================================

# Attacker costs (paid when triggering attempt)
TRIGGER_COST_GOLD = 100

# Defender rewards (if prevent succeeds)
PREVENT_REP_REWARD = 25         # Rep to defenders who participated
PREVENT_GOLD_BOUNTY = 50        # Gold split among defender participants

# Attacker rewards (if they win)
INTEL_REP_REWARD = 30           # Rep to attackers who participated
SABOTAGE_REP_REWARD = 40        # Rep for successful sabotage
HEIST_REP_REWARD = 50           # Rep for successful heist


# ============================================================
# TIER SCALING (Intelligence skill affects roll quality)
# ============================================================
# Higher intelligence tier = better roll outcomes (handled by RollEngine)
# No special scaling here - keep it simple, let the engine handle it


# ============================================================
# CONFIG CLASS (for programmatic access)
# ============================================================

class IncidentConfig:
    """Programmatic access to incident configuration"""
    
    # Initial Success (NEW - the first check!)
    SUCCESS_BY_TIER = INITIAL_SUCCESS_BY_TIER
    PATROL_PENALTY = PATROL_PENALTY_PER_PATROL
    MIN_SUCCESS = MIN_SUCCESS_CHANCE
    MAX_SUCCESS = MAX_SUCCESS_CHANCE
    
    # Legacy trigger (kept for backwards compat, not used in new flow)
    TRIGGER_PER_PATROL = TRIGGER_CHANCE_PER_PATROL
    BASE_TRIGGER = BASE_TRIGGER_CHANCE
    
    # Timing
    DURATION_SECONDS = INCIDENT_DURATION_SECONDS
    COOLDOWN_MINUTES = INCIDENT_COOLDOWN_MINUTES
    
    # Limits
    MAX_ROLLS_PLAYER = MAX_ROLLS_PER_PLAYER
    MAX_ROLLS_SIDE = MAX_ROLLS_PER_SIDE
    MIN_ROLLS = MIN_ROLLS_TO_RESOLVE
    
    # Drop table
    DROP_TABLE = INCIDENT_DROP_TABLE
    SHIFT_PER_SUCCESS = INCIDENT_SHIFT_PER_SUCCESS
    CRITICAL_MULTIPLIER = CRITICAL_SHIFT_MULTIPLIER
    
    # Effects
    INTEL_EXPIRY = INTEL_EXPIRY_HOURS
    DISRUPTION_DURATION = DISRUPTION_DURATION_MINUTES
    DISRUPTION_PENALTY = DISRUPTION_COOLDOWN_PENALTY
    SABOTAGE_DELAY = SABOTAGE_DELAY_PERCENT
    SABOTAGE_COOLDOWN = SABOTAGE_COOLDOWN_HOURS
    HEIST_PERCENT = HEIST_PERCENT
    HEIST_MIN = HEIST_MIN_GOLD
    
    # Economy
    COST = TRIGGER_COST_GOLD
    PREVENT_REP = PREVENT_REP_REWARD
    PREVENT_GOLD = PREVENT_GOLD_BOUNTY
    INTEL_REP = INTEL_REP_REWARD
    SABOTAGE_REP = SABOTAGE_REP_REWARD
    
    @classmethod
    def calculate_initial_success_chance(cls, intelligence_tier: int, active_patrols: int) -> float:
        """
        Calculate initial success probability based on intelligence tier and patrol count.
        
        This is the FIRST check - does the operation even get to the tug-of-war phase?
        
        Formula: success = base_for_tier - (patrols * penalty_per_patrol)
        Clamped to [MIN_SUCCESS, MAX_SUCCESS]
        
        Examples (T3 = 36% base, 6% penalty per patrol):
          0 patrols -> 36% success
          2 patrols -> 36% - 12% = 24% success
          5 patrols -> 36% - 30% = 6% success
          10 patrols -> 36% - 60% = 5% (floor)
        """
        # Get base success for tier (default to T1 if invalid)
        tier = max(1, min(7, intelligence_tier))
        base_success = cls.SUCCESS_BY_TIER.get(tier, cls.SUCCESS_BY_TIER[1])
        
        # Apply patrol penalty
        patrol_penalty = active_patrols * cls.PATROL_PENALTY
        success_chance = base_success - patrol_penalty
        
        # Clamp to bounds
        return max(cls.MIN_SUCCESS, min(cls.MAX_SUCCESS, success_chance))
    
    @classmethod
    def calculate_trigger_chance(cls, active_patrols: int) -> float:
        """
        LEGACY - kept for backwards compatibility.
        Use calculate_initial_success_chance instead.
        """
        if active_patrols <= 0:
            return cls.BASE_TRIGGER
        
        patrol_chance = 1.0 - ((1.0 - cls.TRIGGER_PER_PATROL) ** active_patrols)
        return min(1.0, cls.BASE_TRIGGER + patrol_chance)
    
    @classmethod
    def get_initial_slots(cls, intelligence_tier: int = 1) -> Dict[str, int]:
        """Get drop table based on attacker's intelligence tier"""
        return get_drop_table_for_tier(intelligence_tier)
    
    @classmethod
    def get_shift_for_side(cls, side: str) -> Dict[str, int]:
        """Get shift amounts for attacker or defender"""
        return cls.SHIFT_PER_SUCCESS.get(side, {})

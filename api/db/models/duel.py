"""
Duel Model - 1v1 PvP Arena Combat

SWING-BY-SWING ROUND SYSTEM:
1. Both players pick attack styles (10s)
2. Styles revealed, effects applied to probability bar
3. Each player controls their swings independently:
   - Click SWING → get one result
   - Click SWING again or STOP
   - Best outcome is tracked
4. Both players stop → round resolves
5. Compare best outcomes → winner pushes bar
6. Repeat until bar hits 0 or 100
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey, Float
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List
from enum import Enum

from ..base import Base


def _format_datetime_iso(dt: datetime) -> Optional[str]:
    """Format datetime for iOS compatibility"""
    if dt is None:
        return None
    dt_no_micro = dt.replace(microsecond=0)
    iso_str = dt_no_micro.isoformat()
    if iso_str.endswith('+00:00'):
        return iso_str.replace('+00:00', 'Z')
    elif not iso_str.endswith('Z') and '+' not in iso_str and '-' not in iso_str[-6:]:
        return iso_str + 'Z'
    return iso_str


class DuelStatus(str, Enum):
    """Duel match status"""
    WAITING = "waiting"
    PENDING_ACCEPTANCE = "pending_acceptance"
    READY = "ready"
    FIGHTING = "fighting"
    COMPLETE = "complete"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
    DECLINED = "declined"


class DuelPhase(str, Enum):
    """Round phase within a fighting match"""
    STYLE_SELECTION = "style_selection"  # Players picking styles
    STYLE_REVEAL = "style_reveal"        # Showing both styles before swinging
    SWINGING = "swinging"                # Players controlling their swings
    RESOLVING = "resolving"              # Computing round winner


class DuelOutcome(str, Enum):
    """Possible outcomes for a duel swing"""
    MISS = "miss"
    HIT = "hit"
    CRITICAL = "critical"


# Outcome ranking for comparisons
OUTCOME_RANK = {
    DuelOutcome.MISS.value: 0,
    DuelOutcome.HIT.value: 1,
    DuelOutcome.CRITICAL.value: 2,
    "miss": 0,
    "hit": 1,
    "critical": 2,
}


class DuelMatch(Base):
    """
    A 1v1 duel between two players.
    
    SWING-BY-SWING FLOW:
    1. Match created → WAITING
    2. Opponent accepts → READY
    3. Either player starts → FIGHTING (round 1, style_selection phase)
    4. Both lock styles OR timer expires → style_reveal phase
    5. Brief reveal → swinging phase
    6. Each player swings independently until they stop
    7. Both stopped → resolving phase → round resolved
    8. Winner pushes bar, next round starts
    9. Bar hits 0 or 100 → COMPLETE
    """
    __tablename__ = "duel_matches"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Match identification
    match_code = Column(String(8), unique=True, nullable=False, index=True)
    kingdom_id = Column(String, nullable=False, index=True)
    
    # Players
    challenger_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    challenger_name = Column(String, nullable=False)
    opponent_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    opponent_name = Column(String, nullable=True)
    
    # Match state
    status = Column(String(20), nullable=False, default=DuelStatus.WAITING.value, index=True)
    
    # Combat bar: 0 = challenger wins, 100 = opponent wins
    control_bar = Column(Float, nullable=False, default=50.0)
    
    # ============================================================
    # ROUND SYSTEM
    # ============================================================
    round_number = Column(Integer, nullable=False, default=1)
    round_phase = Column(String(20), nullable=False, default=DuelPhase.STYLE_SELECTION.value)
    round_expires_at = Column(DateTime, nullable=True)  # Overall round timeout
    
    # ============================================================
    # STYLE SELECTION PHASE
    # ============================================================
    style_lock_expires_at = Column(DateTime, nullable=True)
    challenger_style = Column(String(20), nullable=True)
    opponent_style = Column(String(20), nullable=True)
    challenger_style_locked_at = Column(DateTime, nullable=True)
    opponent_style_locked_at = Column(DateTime, nullable=True)
    
    # ============================================================
    # SWING PHASE - CHALLENGER STATE
    # ============================================================
    challenger_swings_used = Column(Integer, default=0)
    challenger_max_swings = Column(Integer, default=1)
    challenger_best_outcome = Column(String(20), nullable=True)
    challenger_best_push = Column(Float, default=0.0)
    challenger_round_rolls = Column(JSONB, nullable=True)  # List of roll results
    challenger_submitted = Column(Boolean, default=False)
    challenger_submitted_at = Column(DateTime, nullable=True)
    
    # ============================================================
    # SWING PHASE - OPPONENT STATE
    # ============================================================
    opponent_swings_used = Column(Integer, default=0)
    opponent_max_swings = Column(Integer, default=1)
    opponent_best_outcome = Column(String(20), nullable=True)
    opponent_best_push = Column(Float, default=0.0)
    opponent_round_rolls = Column(JSONB, nullable=True)
    opponent_submitted = Column(Boolean, default=False)
    opponent_submitted_at = Column(DateTime, nullable=True)
    
    # Swing phase timeout
    swing_phase_expires_at = Column(DateTime, nullable=True)
    
    # ============================================================
    # LEGACY FIELDS (for backwards compat during transition)
    # ============================================================
    current_turn = Column(String(20), nullable=True)  # No longer used in round system
    turn_expires_at = Column(DateTime, nullable=True)
    first_turn_player_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    turn_swings_used = Column(Integer, default=0)
    turn_max_swings = Column(Integer, default=1)
    turn_best_outcome = Column(String(20), nullable=True)
    turn_best_push = Column(Float, default=0.0)
    turn_rolls = Column(JSONB, nullable=True)
    pending_challenger_round_rolls = Column(JSONB, nullable=True)
    pending_opponent_round_rolls = Column(JSONB, nullable=True)
    pending_challenger_round_submitted_at = Column(DateTime, nullable=True)
    pending_opponent_round_submitted_at = Column(DateTime, nullable=True)
    
    # Stats snapshots (frozen at match start)
    challenger_stats = Column(JSONB, nullable=True)
    opponent_stats = Column(JSONB, nullable=True)
    
    # Results
    winner_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    winner_side = Column(String(20), nullable=True)
    
    # Wager
    wager_gold = Column(Integer, default=0)
    winner_gold_earned = Column(Integer, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=True)
    
    # Relationships
    invitations = relationship("DuelInvitation", backref="match", lazy="joined", cascade="all, delete-orphan")
    actions = relationship("DuelAction", backref="match", lazy="dynamic", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<DuelMatch(id={self.id}, code='{self.match_code}', status='{self.status}', phase='{self.round_phase}')>"
    
    # ============================================================
    # STATUS HELPERS
    # ============================================================
    
    @property
    def is_waiting(self) -> bool:
        return self.status == DuelStatus.WAITING.value
    
    @property
    def is_ready(self) -> bool:
        return self.status == DuelStatus.READY.value
    
    @property
    def is_fighting(self) -> bool:
        return self.status == DuelStatus.FIGHTING.value
    
    @property
    def is_complete(self) -> bool:
        return self.status == DuelStatus.COMPLETE.value
    
    @property
    def is_active(self) -> bool:
        return self.status in [DuelStatus.WAITING.value, DuelStatus.READY.value, DuelStatus.FIGHTING.value]
    
    @property
    def can_join(self) -> bool:
        return self.status == DuelStatus.WAITING.value and self.opponent_id is None

    @property
    def is_pending_acceptance(self) -> bool:
        return self.status == DuelStatus.PENDING_ACCEPTANCE.value

    @property
    def is_expired(self) -> bool:
        if self.expires_at:
            now = datetime.utcnow()
            exp = self.expires_at.replace(tzinfo=None) if self.expires_at.tzinfo else self.expires_at
            return now > exp
        return False
    
    # ============================================================
    # PHASE HELPERS
    # ============================================================
    
    @property
    def in_style_selection(self) -> bool:
        return self.round_phase == DuelPhase.STYLE_SELECTION.value
    
    @property
    def in_style_reveal(self) -> bool:
        return self.round_phase == DuelPhase.STYLE_REVEAL.value
    
    @property
    def in_swinging(self) -> bool:
        return self.round_phase == DuelPhase.SWINGING.value
    
    @property
    def in_resolving(self) -> bool:
        return self.round_phase == DuelPhase.RESOLVING.value
    
    def get_player_side(self, player_id: int) -> Optional[str]:
        """Get which side a player is on"""
        if player_id == self.challenger_id:
            return "challenger"
        elif player_id == self.opponent_id:
            return "opponent"
        return None
    
    # ============================================================
    # STYLE HELPERS
    # ============================================================
    
    def get_player_style(self, player_id: int) -> Optional[str]:
        """Get the attack style a player has locked in."""
        if player_id == self.challenger_id:
            return self.challenger_style
        elif player_id == self.opponent_id:
            return self.opponent_style
        return None
    
    def has_player_locked_style(self, player_id: int) -> bool:
        """Check if a player has locked in their style."""
        if player_id == self.challenger_id:
            return self.challenger_style is not None
        elif player_id == self.opponent_id:
            return self.opponent_style is not None
        return False
    
    def both_styles_locked(self) -> bool:
        """Check if both players have locked styles."""
        return self.challenger_style is not None and self.opponent_style is not None
    
    def style_phase_expired(self) -> bool:
        """Check if style selection has timed out."""
        if self.style_lock_expires_at is None:
            return True
        now = datetime.utcnow()
        expires = self.style_lock_expires_at
        if expires.tzinfo is not None:
            expires = expires.replace(tzinfo=None)
        return now > expires
    
    # ============================================================
    # SWING HELPERS
    # ============================================================
    
    def get_player_swings_used(self, player_id: int) -> int:
        """Get swings used by a player this round."""
        if player_id == self.challenger_id:
            return self.challenger_swings_used or 0
        elif player_id == self.opponent_id:
            return self.opponent_swings_used or 0
        return 0
    
    def get_player_max_swings(self, player_id: int) -> int:
        """Get max swings for a player this round."""
        if player_id == self.challenger_id:
            return self.challenger_max_swings or 1
        elif player_id == self.opponent_id:
            return self.opponent_max_swings or 1
        return 1
    
    def get_player_swings_remaining(self, player_id: int) -> int:
        """Get remaining swings for a player."""
        return self.get_player_max_swings(player_id) - self.get_player_swings_used(player_id)
    
    def get_player_best_outcome(self, player_id: int) -> Optional[str]:
        """Get best outcome for a player this round."""
        if player_id == self.challenger_id:
            return self.challenger_best_outcome
        elif player_id == self.opponent_id:
            return self.opponent_best_outcome
        return None
    
    def get_player_rolls(self, player_id: int) -> List[Dict]:
        """Get all rolls for a player this round."""
        if player_id == self.challenger_id:
            return self.challenger_round_rolls or []
        elif player_id == self.opponent_id:
            return self.opponent_round_rolls or []
        return []
    
    def has_player_submitted(self, player_id: int) -> bool:
        """Check if a player has stopped/submitted this round."""
        if player_id == self.challenger_id:
            return self.challenger_submitted or False
        elif player_id == self.opponent_id:
            return self.opponent_submitted or False
        return False
    
    def both_submitted(self) -> bool:
        """Check if both players have submitted."""
        return (self.challenger_submitted or False) and (self.opponent_submitted or False)
    
    def can_player_swing(self, player_id: int) -> bool:
        """Check if a player can still swing."""
        if not self.in_swinging:
            return False
        if self.has_player_submitted(player_id):
            return False
        return self.get_player_swings_remaining(player_id) > 0
    
    def can_player_stop(self, player_id: int) -> bool:
        """Check if a player can stop (must have at least 1 swing)."""
        if not self.in_swinging:
            return False
        if self.has_player_submitted(player_id):
            return False
        return self.get_player_swings_used(player_id) >= 1
    
    # ============================================================
    # STATE MUTATIONS
    # ============================================================
    
    def start_style_phase(self, style_timeout_seconds: int = 10) -> None:
        """Start the style selection phase for a new round."""
        self.round_phase = DuelPhase.STYLE_SELECTION.value
        self.style_lock_expires_at = datetime.utcnow() + timedelta(seconds=style_timeout_seconds)
        # Clear previous round state
        self.challenger_style = None
        self.opponent_style = None
        self.challenger_style_locked_at = None
        self.opponent_style_locked_at = None
        self._reset_swing_state()
    
    def start_swing_phase(self, swing_timeout_seconds: int = 30) -> None:
        """Transition to swing phase (after styles revealed)."""
        self.round_phase = DuelPhase.SWINGING.value
        self.swing_phase_expires_at = datetime.utcnow() + timedelta(seconds=swing_timeout_seconds)
    
    def _reset_swing_state(self) -> None:
        """Reset swing state for a new round."""
        self.challenger_swings_used = 0
        self.challenger_best_outcome = None
        self.challenger_best_push = 0.0
        self.challenger_round_rolls = None
        self.challenger_submitted = False
        self.challenger_submitted_at = None
        
        self.opponent_swings_used = 0
        self.opponent_best_outcome = None
        self.opponent_best_push = 0.0
        self.opponent_round_rolls = None
        self.opponent_submitted = False
        self.opponent_submitted_at = None
    
    def record_swing(
        self,
        player_id: int,
        roll_value: float,
        outcome: str,
        push_amount: float
    ) -> Dict[str, Any]:
        """
        Record a single swing for a player.
        Returns the roll data.
        """
        side = self.get_player_side(player_id)
        if not side:
            raise ValueError("Player not in this match")
        
        # Build roll data
        if side == "challenger":
            swing_number = (self.challenger_swings_used or 0) + 1
            rolls = self.challenger_round_rolls or []
        else:
            swing_number = (self.opponent_swings_used or 0) + 1
            rolls = self.opponent_round_rolls or []
        
        roll_data = {
            "roll_number": swing_number,
            "value": round(roll_value * 100, 1),
            "outcome": outcome,
        }
        rolls.append(roll_data)
        
        # Update state
        if side == "challenger":
            self.challenger_swings_used = swing_number
            self.challenger_round_rolls = rolls
            
            # Track LAST outcome (not best!) - this creates the "press your luck" decision
            # Swinging again REPLACES your current result, so you risk losing a good roll
            self.challenger_best_outcome = outcome
            self.challenger_best_push = push_amount
        else:
            self.opponent_swings_used = swing_number
            self.opponent_round_rolls = rolls
            
            # Track LAST outcome (not best!) - this creates the "press your luck" decision
            self.opponent_best_outcome = outcome
            self.opponent_best_push = push_amount
        
        return roll_data
    
    def submit_player(self, player_id: int) -> None:
        """Mark a player as submitted (stopped swinging)."""
        now = datetime.utcnow()
        side = self.get_player_side(player_id)
        if side == "challenger":
            self.challenger_submitted = True
            self.challenger_submitted_at = now
        elif side == "opponent":
            self.opponent_submitted = True
            self.opponent_submitted_at = now
    
    def apply_push(self, side: str, push_amount: float) -> Optional[str]:
        """
        Apply push to the bar. Returns winner side if match ends.
        
        Challenger pushes toward 0 (wants bar at 0 to win)
        Opponent pushes toward 100 (wants bar at 100 to win)
        """
        if side == "challenger":
            self.control_bar = max(0.0, self.control_bar - push_amount)
        else:
            self.control_bar = min(100.0, self.control_bar + push_amount)
        
        if self.control_bar <= 0:
            self.control_bar = 0.0
            return "challenger"
        elif self.control_bar >= 100:
            self.control_bar = 100.0
            return "opponent"
        return None
    
    def advance_round(self, style_timeout_seconds: int = 10) -> None:
        """Advance to next round."""
        self.round_number = (self.round_number or 1) + 1
        self.start_style_phase(style_timeout_seconds)
    
    def resolve(self, winner_side: str) -> None:
        """Mark match as complete with a winner."""
        self.status = DuelStatus.COMPLETE.value
        self.winner_side = winner_side
        self.winner_id = self.challenger_id if winner_side == "challenger" else self.opponent_id
        self.completed_at = datetime.utcnow()
        
        if self.wager_gold > 0:
            self.winner_gold_earned = self.wager_gold * 2
    
    def cancel(self) -> None:
        self.status = DuelStatus.CANCELLED.value
    
    def expire(self) -> None:
        self.status = DuelStatus.EXPIRED.value
    
    # ============================================================
    # LEGACY COMPATIBILITY
    # ============================================================
    
    def get_current_turn_player_id(self) -> Optional[int]:
        """Legacy: Get current turn player. In round system, not used."""
        if self.current_turn == "challenger":
            return self.challenger_id
        elif self.current_turn == "opponent":
            return self.opponent_id
        return None
    
    def is_players_turn(self, player_id: int) -> bool:
        """Legacy: In round system, both can act during swing phase."""
        return self.get_current_turn_player_id() == player_id
    
    def switch_turn(self) -> None:
        """Legacy: Switch turns."""
        if self.current_turn == "challenger":
            self.current_turn = "opponent"
        else:
            self.current_turn = "challenger"
    
    def clear_styles_for_new_round(self) -> None:
        """Legacy helper."""
        self.challenger_style = None
        self.opponent_style = None
        self.challenger_style_locked_at = None
        self.opponent_style_locked_at = None
        self.style_lock_expires_at = None
    
    # ============================================================
    # SERIALIZATION
    # ============================================================
    
    def to_dict(self, include_actions: bool = False) -> Dict[str, Any]:
        """Generic dict (no player perspective)"""
        from systems.duel.config import DUEL_TURN_TIMEOUT_SECONDS
        
        result = {
            "id": self.id,
            "match_code": self.match_code,
            "kingdom_id": self.kingdom_id,
            "status": self.status,
            "round_number": self.round_number,
            "round_phase": self.round_phase,
            
            "challenger": {
                "id": self.challenger_id,
                "name": self.challenger_name,
                "stats": self.challenger_stats,
            },
            "opponent": {
                "id": self.opponent_id,
                "name": self.opponent_name,
                "stats": self.opponent_stats,
            } if self.opponent_id else None,
            
            "control_bar": round(self.control_bar, 2),
            "wager_gold": self.wager_gold,
            
            "winner": {
                "id": self.winner_id,
                "side": self.winner_side,
                "gold_earned": self.winner_gold_earned,
            } if self.winner_id else None,
            
            "created_at": _format_datetime_iso(self.created_at),
            "started_at": _format_datetime_iso(self.started_at),
            "completed_at": _format_datetime_iso(self.completed_at),
        }
        
        if include_actions:
            result["actions"] = [a.to_dict() for a in self.actions.order_by(DuelAction.performed_at)]
        
        return result
    
    def to_dict_for_player(self, player_id: int, include_actions: bool = False, odds: Dict = None) -> Dict[str, Any]:
        """
        Player-perspective view. Frontend is a DUMB RENDERER.
        All values pre-calculated, all config included.
        """
        from systems.duel.config import (
            DUEL_TURN_TIMEOUT_SECONDS,
            DUEL_SWING_TIMEOUT_SECONDS,
            calculate_duel_roll_chances,
            calculate_duel_round_rolls,
            get_duel_game_config,
            get_style_modifiers,
            AttackStyle,
            DUEL_MAX_ROLLS_PER_ROUND_CAP,
        )
        
        # Determine perspective
        my_side = self.get_player_side(player_id)
        is_challenger = my_side == "challenger"
        
        # Stats for each side
        if is_challenger:
            my_stats = self.challenger_stats or {}
            opp_stats = self.opponent_stats or {}
            my_name = self.challenger_name
            opp_name = self.opponent_name
            opp_id = self.opponent_id
            my_style = self.challenger_style
            opp_style = self.opponent_style
            my_swings_used = self.challenger_swings_used or 0
            my_max_swings = self.challenger_max_swings or 1
            my_best_outcome = self.challenger_best_outcome
            my_rolls = self.challenger_round_rolls or []
            my_submitted = self.challenger_submitted or False
            opp_submitted = self.opponent_submitted or False
        else:
            my_stats = self.opponent_stats or {}
            opp_stats = self.challenger_stats or {}
            my_name = self.opponent_name
            opp_name = self.challenger_name
            opp_id = self.challenger_id
            my_style = self.opponent_style
            opp_style = self.challenger_style
            my_swings_used = self.opponent_swings_used or 0
            my_max_swings = self.opponent_max_swings or 1
            my_best_outcome = self.opponent_best_outcome
            my_rolls = self.opponent_round_rolls or []
            my_submitted = self.opponent_submitted or False
            opp_submitted = self.challenger_submitted or False
        
        # Bar position from player's perspective (100 = you winning)
        if is_challenger:
            your_bar_position = 100.0 - self.control_bar
        else:
            your_bar_position = self.control_bar
        
        # ============================================================
        # PHASE STATE
        # ============================================================
        
        in_style_phase = self.in_style_selection and self.is_fighting
        in_style_reveal = self.in_style_reveal and self.is_fighting
        in_swing_phase = self.in_swinging and self.is_fighting
        
        my_style_locked = my_style is not None
        opp_style_locked = opp_style is not None
        both_styles_locked = self.both_styles_locked()
        
        # Can lock style during style selection if not yet locked
        can_lock_style = in_style_phase and not my_style_locked
        
        # Show opponent's style only after both locked or in reveal/swing phase
        show_opp_style = both_styles_locked or in_style_reveal or in_swing_phase or self.is_complete
        opp_style_display = opp_style if show_opp_style else None
        
        # ============================================================
        # SWING STATE
        # ============================================================
        
        # Calculate max swings based on attack + style modifier
        base_max_swings = min(1 + my_stats.get("attack", 0), DUEL_MAX_ROLLS_PER_ROUND_CAP)
        style_roll_bonus = get_style_modifiers(my_style or AttackStyle.BALANCED).get("roll_bonus", 0)
        calculated_max_swings = max(1, min(DUEL_MAX_ROLLS_PER_ROUND_CAP, base_max_swings + style_roll_bonus))
        
        # Use stored max if in swing phase, else calculated
        if in_swing_phase:
            effective_max_swings = my_max_swings
        else:
            effective_max_swings = calculated_max_swings
        
        swings_remaining = max(0, effective_max_swings - my_swings_used)
        
        # Can swing if in swing phase OR style reveal (which auto-transitions), not submitted, has swings left
        can_swing = (in_swing_phase or in_style_reveal) and not my_submitted and swings_remaining > 0
        
        # Can stop if in swing phase (not reveal), not submitted, has at least 1 swing done
        can_stop = in_swing_phase and not my_submitted and my_swings_used >= 1
        
        # ============================================================
        # ODDS CALCULATION (with style modifiers)
        # ============================================================
        
        # Calculate BASE odds (before style modifiers) for animation
        base_odds = {"miss": 50, "hit": 40, "crit": 10}
        current_odds = {"miss": 50, "hit": 40, "crit": 10}
        
        if odds:
            current_odds = {"miss": odds.get("miss", 50), "hit": odds.get("hit", 40), "crit": odds.get("crit", 10)}
            base_odds = current_odds.copy()
        elif self.is_fighting:
            atk = my_stats.get("attack", 0)
            defense = opp_stats.get("defense", 0)
            
            # Base odds (without style modifiers)
            base_miss_pct, base_hit_pct, base_crit_pct = calculate_duel_roll_chances(atk, defense)
            base_odds = {"miss": base_miss_pct, "hit": base_hit_pct, "crit": base_crit_pct}
            
            miss_pct, hit_pct, crit_pct = base_miss_pct, base_hit_pct, base_crit_pct
            
            # Apply style modifiers if styles are revealed
            if show_opp_style and (my_style or opp_style):
                my_mods = get_style_modifiers(my_style or AttackStyle.BALANCED)
                opp_mods = get_style_modifiers(opp_style or AttackStyle.BALANCED)
                
                # Hit chance modification (my style + opponent's debuff on me)
                hit_mod = my_mods.get("hit_chance_mod", 0) + opp_mods.get("opponent_hit_mod", 0)
                hit_mod_pct = int(hit_mod * 100)
                
                # Crit rate modification
                crit_mult = my_mods.get("crit_rate_mult", 1.0)
                
                # Recalculate
                base_hit = (100 - miss_pct) / 100.0
                modified_hit = max(0.10, min(0.90, base_hit + hit_mod))
                miss_pct = int(round((1.0 - modified_hit) * 100))
                crit_pct = int(round(modified_hit * 0.15 * crit_mult * 100))
                hit_pct = 100 - miss_pct - crit_pct
            
            current_odds = {"miss": miss_pct, "hit": hit_pct, "crit": crit_pct}
        
        # Calculate opponent's base and final swings
        opp_base_swings = min(1 + opp_stats.get("attack", 0), DUEL_MAX_ROLLS_PER_ROUND_CAP)
        opp_style_roll_bonus = get_style_modifiers(opp_style or AttackStyle.BALANCED).get("roll_bonus", 0) if show_opp_style else 0
        opp_final_swings = max(1, min(DUEL_MAX_ROLLS_PER_ROUND_CAP, opp_base_swings + opp_style_roll_bonus))
        
        # ============================================================
        # OPPONENT'S ODDS (when opponent attacks ME)
        # ============================================================
        # This is for the Style Reveal screen to show both probability bars
        
        opponent_base_odds = {"miss": 50, "hit": 40, "crit": 10}
        opponent_current_odds = {"miss": 50, "hit": 40, "crit": 10}
        
        if self.is_fighting:
            # Opponent attacking me: their attack vs my defense
            opp_atk = opp_stats.get("attack", 0)
            my_def = my_stats.get("defense", 0)
            
            # Base odds (without style modifiers)
            opp_base_miss, opp_base_hit, opp_base_crit = calculate_duel_roll_chances(opp_atk, my_def)
            opponent_base_odds = {"miss": opp_base_miss, "hit": opp_base_hit, "crit": opp_base_crit}
            
            opp_miss, opp_hit, opp_crit = opp_base_miss, opp_base_hit, opp_base_crit
            
            # Apply style modifiers if styles are revealed
            if show_opp_style and (my_style or opp_style):
                # Opponent's hit chance modification (their style + my debuff on them)
                opp_mods = get_style_modifiers(opp_style or AttackStyle.BALANCED)
                my_mods = get_style_modifiers(my_style or AttackStyle.BALANCED)
                
                opp_hit_mod = opp_mods.get("hit_chance_mod", 0) + my_mods.get("opponent_hit_mod", 0)
                opp_crit_mult = opp_mods.get("crit_rate_mult", 1.0)
                
                # Recalculate opponent's odds
                opp_base_hit_rate = (100 - opp_miss) / 100.0
                opp_modified_hit = max(0.10, min(0.90, opp_base_hit_rate + opp_hit_mod))
                opp_miss = int(round((1.0 - opp_modified_hit) * 100))
                opp_crit = int(round(opp_modified_hit * 0.15 * opp_crit_mult * 100))
                opp_hit = 100 - opp_miss - opp_crit
            
            opponent_current_odds = {"miss": opp_miss, "hit": opp_hit, "crit": opp_crit}
        
        # ============================================================
        # TIMEOUT CLAIMS
        # ============================================================
        
        def _is_expired(dt):
            if dt is None:
                return False
            now = datetime.utcnow()
            exp = dt.replace(tzinfo=None) if dt.tzinfo else dt
            return now > exp
        
        # Can claim timeout if opponent hasn't submitted and swing phase expired
        can_claim_timeout = (
            in_swing_phase
            and my_submitted
            and not opp_submitted
            and _is_expired(self.swing_phase_expires_at)
        )
        
        # ============================================================
        # WINNER PERSPECTIVE
        # ============================================================
        
        winner_data = None
        if self.winner_id:
            did_i_win = self.winner_id == player_id
            winner_data = {
                "id": self.winner_id,
                "did_i_win": did_i_win,
                "gold_earned": self.winner_gold_earned if did_i_win else 0,
            }
        
        # ============================================================
        # BUILD RESPONSE
        # ============================================================
        
        result = {
            "id": self.id,
            "match_code": self.match_code,
            "kingdom_id": self.kingdom_id,
            "status": self.status,
            
            # === ROUND STATE ===
            "round_number": self.round_number or 1,
            "round_phase": self.round_phase,
            "round_expires_at": _format_datetime_iso(self.round_expires_at),
            
            # === STYLE PHASE ===
            "in_style_phase": in_style_phase,
            "in_style_reveal": in_style_reveal,
            "can_lock_style": can_lock_style,
            "my_style": my_style,
            "my_style_locked": my_style_locked,
            "opponent_style": opp_style_display,
            "opponent_style_locked": opp_style_locked,
            "both_styles_locked": both_styles_locked,
            "style_lock_expires_at": _format_datetime_iso(self.style_lock_expires_at),
            
            # === SWING PHASE ===
            "in_swing_phase": in_swing_phase,
            "can_swing": can_swing,
            "can_stop": can_stop,
            "swings_used": my_swings_used,
            "swings_remaining": swings_remaining,
            "max_swings": effective_max_swings,
            "base_max_swings": base_max_swings,  # Before style modifier
            "swing_delta": effective_max_swings - base_max_swings,  # Style effect
            "opponent_max_swings": opp_final_swings if show_opp_style else opp_base_swings,
            "opponent_base_swings": opp_base_swings,
            "opponent_swing_delta": (opp_final_swings - opp_base_swings) if show_opp_style else 0,
            "best_outcome": my_best_outcome,
            "my_rolls": my_rolls,
            "submitted": my_submitted,
            "opponent_submitted": opp_submitted,
            "swing_phase_expires_at": _format_datetime_iso(self.swing_phase_expires_at),
            
            # === BAR POSITION ===
            "your_bar_position": round(your_bar_position, 2),
            "control_bar": round(self.control_bar, 2),
            
            # === ODDS (your attack vs opponent) ===
            "current_odds": current_odds,
            "base_odds": base_odds,  # Before style modifiers (for animation)
            
            # === OPPONENT'S ODDS (opponent's attack vs you) ===
            "opponent_odds": opponent_current_odds,
            "opponent_base_odds": opponent_base_odds,
            
            # === TIMEOUT ===
            "can_claim_timeout": can_claim_timeout,
            
            # === YOUR INFO ===
            "you": {
                "id": player_id,
                "name": my_name,
                "attack": my_stats.get("attack", 0),
                "defense": my_stats.get("defense", 0),
                "leadership": my_stats.get("leadership", 0),
            },
            
            # === OPPONENT INFO ===
            "opponent": {
                "id": opp_id,
                "name": opp_name,
                "attack": opp_stats.get("attack", 0),
                "defense": opp_stats.get("defense", 0),
            } if opp_id else None,
            
            # === WINNER ===
            "winner": winner_data,
            
            # === METADATA ===
            "wager_gold": self.wager_gold,
            "created_at": _format_datetime_iso(self.created_at),
            "started_at": _format_datetime_iso(self.started_at),
            "completed_at": _format_datetime_iso(self.completed_at),
            
            # === GAME CONFIG ===
            "config": get_duel_game_config(),
            
            # === LEGACY (for backwards compat) ===
            "challenger": {
                "id": self.challenger_id,
                "name": self.challenger_name,
                "stats": self.challenger_stats,
            },
            "is_your_turn": can_swing,  # Legacy
            "can_attack": can_swing,  # Legacy
            "has_submitted_round": my_submitted,  # Legacy
            "opponent_has_submitted_round": opp_submitted,  # Legacy
            "can_submit_round": can_swing,  # Legacy
        }
        
        if include_actions:
            result["actions"] = [a.to_dict() for a in self.actions.order_by(DuelAction.performed_at)]
        
        return result


class DuelInvitation(Base):
    """Invitation sent to a specific friend"""
    __tablename__ = "duel_invitations"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    match_id = Column(Integer, ForeignKey("duel_matches.id", ondelete="CASCADE"), nullable=False, index=True)
    inviter_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    invitee_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    status = Column(String(20), nullable=False, default="pending")
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    responded_at = Column(DateTime, nullable=True)
    
    def __repr__(self):
        return f"<DuelInvitation(match={self.match_id}, invitee={self.invitee_id}, status='{self.status}')>"
    
    def accept(self) -> None:
        self.status = "accepted"
        self.responded_at = datetime.utcnow()
    
    def decline(self) -> None:
        self.status = "declined"
        self.responded_at = datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "match_id": self.match_id,
            "inviter_id": self.inviter_id,
            "invitee_id": self.invitee_id,
            "status": self.status,
            "created_at": _format_datetime_iso(self.created_at),
            "responded_at": _format_datetime_iso(self.responded_at),
        }


class DuelAction(Base):
    """Log of each round resolution during a duel"""
    __tablename__ = "duel_actions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    match_id = Column(Integer, ForeignKey("duel_matches.id", ondelete="CASCADE"), nullable=False, index=True)
    player_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    side = Column(String(20), nullable=False)
    
    roll_value = Column(Float, nullable=False)
    outcome = Column(String(20), nullable=False)
    
    push_amount = Column(Float, nullable=False, default=0.0)
    bar_before = Column(Float, nullable=False)
    bar_after = Column(Float, nullable=False)
    
    performed_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<DuelAction(match={self.match_id}, player={self.player_id}, outcome='{self.outcome}')>"
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "match_id": self.match_id,
            "player_id": self.player_id,
            "side": self.side,
            "roll_value": round(self.roll_value, 4),
            "outcome": self.outcome,
            "push_amount": round(self.push_amount, 4),
            "bar_before": round(self.bar_before, 2),
            "bar_after": round(self.bar_after, 2),
            "performed_at": _format_datetime_iso(self.performed_at),
        }


class DuelPairingHistory(Base):
    """Tracks which player went first in previous duels."""
    __tablename__ = "duel_pairing_history"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    player_a_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    player_b_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    last_first_player_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    last_match_id = Column(Integer, ForeignKey("duel_matches.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    @staticmethod
    def normalize_pair(player_1_id: int, player_2_id: int) -> tuple:
        return (min(player_1_id, player_2_id), max(player_1_id, player_2_id))


class DuelStats(Base):
    """Lifetime duel statistics for a player"""
    __tablename__ = "duel_stats"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    
    wins = Column(Integer, nullable=False, default=0)
    losses = Column(Integer, nullable=False, default=0)
    draws = Column(Integer, nullable=False, default=0)
    
    total_gold_won = Column(Integer, nullable=False, default=0)
    total_gold_lost = Column(Integer, nullable=False, default=0)
    
    win_streak = Column(Integer, nullable=False, default=0)
    best_win_streak = Column(Integer, nullable=False, default=0)
    
    last_duel_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    @property
    def total_matches(self) -> int:
        return self.wins + self.losses + self.draws
    
    @property
    def win_rate(self) -> float:
        if self.total_matches == 0:
            return 0.0
        return self.wins / self.total_matches
    
    def record_win(self, gold_earned: int = 0) -> None:
        self.wins += 1
        self.win_streak += 1
        self.best_win_streak = max(self.best_win_streak, self.win_streak)
        self.total_gold_won += gold_earned
        self.last_duel_at = datetime.utcnow()
    
    def record_loss(self, gold_lost: int = 0) -> None:
        self.losses += 1
        self.win_streak = 0
        self.total_gold_lost += gold_lost
        self.last_duel_at = datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "user_id": self.user_id,
            "wins": self.wins,
            "losses": self.losses,
            "draws": self.draws,
            "total_matches": self.total_matches,
            "win_rate": round(self.win_rate, 3),
            "total_gold_won": self.total_gold_won,
            "total_gold_lost": self.total_gold_lost,
            "win_streak": self.win_streak,
            "best_win_streak": self.best_win_streak,
            "last_duel_at": _format_datetime_iso(self.last_duel_at),
        }

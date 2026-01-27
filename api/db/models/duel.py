"""
Duel Model - 1v1 PvP Arena Combat

Simple duel system for the Town Hall arena:
- Challenger creates a match, invites friends or gets a code
- Opponent accepts, stats are snapshotted
- Turn-based combat with tug-of-war bar
- Winner is whoever pushes bar to their side first

Combat uses same formulas as battles:
  hit_chance = attack / (enemy_defense * 2)
"""
from sqlalchemy import Column, String, Integer, BigInteger, Boolean, DateTime, ForeignKey, Float
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
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
    WAITING = "waiting"                    # Waiting for opponent
    PENDING_ACCEPTANCE = "pending_acceptance"  # Opponent joined, challenger must confirm
    READY = "ready"                        # Both players confirmed, about to start
    FIGHTING = "fighting"                  # Match in progress
    COMPLETE = "complete"                  # Match finished
    CANCELLED = "cancelled"                # Cancelled by challenger
    EXPIRED = "expired"                    # Invitation expired
    DECLINED = "declined"                  # Challenger declined the opponent


class DuelOutcome(str, Enum):
    """Possible outcomes for a duel attack"""
    MISS = "miss"
    HIT = "hit"
    CRITICAL = "critical"


class DuelMatch(Base):
    """
    A 1v1 duel between two players.
    
    Flow:
    1. Challenger creates match → status='waiting', gets match_code
    2. Challenger invites friends OR shares code
    3. Opponent joins via invite/code → status='ready'
    4. Both confirm ready → status='fighting', turn assigned
    5. Players take turns attacking until bar hits 0 or 100
    6. Winner determined → status='complete'
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
    
    # Turn tracking
    current_turn = Column(String(20), nullable=True)  # 'challenger' or 'opponent'
    turn_expires_at = Column(DateTime, nullable=True)
    first_turn_player_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Who went first (for history)
    
    # Multi-swing tracking (within a single turn)
    turn_swings_used = Column(Integer, default=0)  # How many swings used this turn
    turn_max_swings = Column(Integer, default=1)   # Max swings for this turn (1 + attack)
    turn_best_outcome = Column(String(20), nullable=True)  # Best outcome so far: 'miss', 'hit', 'critical'
    turn_best_push = Column(Float, default=0.0)    # Push amount from best outcome
    turn_rolls = Column(JSONB, nullable=True)      # All rolls this turn for display

    # ============================================================
    # Simultaneous round system (no turns; both submit each round)
    # ============================================================
    round_number = Column(Integer, nullable=False, default=1)  # Current round (starts at 1)
    round_expires_at = Column(DateTime, nullable=True)  # Shared timer for round submission

    # Pending submissions for the current round (persist across reconnects)
    pending_challenger_round_rolls = Column(JSONB, nullable=True)
    pending_opponent_round_rolls = Column(JSONB, nullable=True)
    pending_challenger_round_submitted_at = Column(DateTime, nullable=True)
    pending_opponent_round_submitted_at = Column(DateTime, nullable=True)
    
    # ============================================================
    # Attack Style System (locked before rolls each round)
    # ============================================================
    style_lock_expires_at = Column(DateTime, nullable=True)  # When style selection phase ends
    challenger_style = Column(String(20), nullable=True)  # balanced, aggressive, precise, power, guard, feint
    opponent_style = Column(String(20), nullable=True)
    challenger_style_locked_at = Column(DateTime, nullable=True)
    opponent_style_locked_at = Column(DateTime, nullable=True)
    
    # Stats snapshots (frozen at match start for fairness)
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
        return f"<DuelMatch(id={self.id}, code='{self.match_code}', status='{self.status}')>"
    
    # === Status Helpers ===
    
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
        """Match is joinable or in progress"""
        return self.status in [DuelStatus.WAITING.value, DuelStatus.READY.value, DuelStatus.FIGHTING.value]
    
    @property
    def can_join(self) -> bool:
        """Can someone join as opponent?"""
        return self.status == DuelStatus.WAITING.value and self.opponent_id is None

    @property
    def is_pending_acceptance(self) -> bool:
        """Is this match waiting for challenger to confirm opponent?"""
        return self.status == DuelStatus.PENDING_ACCEPTANCE.value

    @property
    def is_expired(self) -> bool:
        """Has the invitation expired?"""
        if self.expires_at and datetime.utcnow() > self.expires_at:
            return True
        return False
    
    # === Turn Helpers ===
    
    def get_current_turn_player_id(self) -> Optional[int]:
        """Get the player ID whose turn it is"""
        if self.current_turn == "challenger":
            return self.challenger_id
        elif self.current_turn == "opponent":
            return self.opponent_id
        return None
    
    def is_players_turn(self, player_id: int) -> bool:
        """Check if it's a specific player's turn"""
        return self.get_current_turn_player_id() == player_id
    
    def get_player_side(self, player_id: int) -> Optional[str]:
        """Get which side a player is on"""
        if player_id == self.challenger_id:
            return "challenger"
        elif player_id == self.opponent_id:
            return "opponent"
        return None
    
    def switch_turn(self) -> None:
        """Switch to the other player's turn"""
        if self.current_turn == "challenger":
            self.current_turn = "opponent"
        else:
            self.current_turn = "challenger"
    
    # === Style Helpers ===
    
    def get_player_style(self, player_id: int) -> Optional[str]:
        """Get the attack style a player has locked in."""
        if player_id == self.challenger_id:
            return self.challenger_style
        elif player_id == self.opponent_id:
            return self.opponent_style
        return None
    
    def has_player_locked_style(self, player_id: int) -> bool:
        """Check if a player has locked in their style for this round."""
        if player_id == self.challenger_id:
            return self.challenger_style is not None
        elif player_id == self.opponent_id:
            return self.opponent_style is not None
        return False
    
    def both_styles_locked(self) -> bool:
        """Check if both players have locked in their styles."""
        return self.challenger_style is not None and self.opponent_style is not None
    
    def style_phase_expired(self) -> bool:
        """Check if the style selection phase has expired."""
        if self.style_lock_expires_at is None:
            return True
        return datetime.utcnow() > self.style_lock_expires_at
    
    def clear_styles_for_new_round(self) -> None:
        """Clear styles for a new round."""
        self.challenger_style = None
        self.opponent_style = None
        self.challenger_style_locked_at = None
        self.opponent_style_locked_at = None
        self.style_lock_expires_at = None
    
    # === Combat ===
    
    def apply_push(self, side: str, push_amount: float) -> Optional[str]:
        """
        Apply push to the bar. Returns winner side if match ends, None otherwise.
        
        Challenger pushes toward 0 (wants bar at 0 to win)
        Opponent pushes toward 100 (wants bar at 100 to win)
        """
        if side == "challenger":
            self.control_bar = max(0.0, self.control_bar - push_amount)
        else:
            self.control_bar = min(100.0, self.control_bar + push_amount)
        
        # Check for winner
        if self.control_bar <= 0:
            self.control_bar = 0.0
            return "challenger"
        elif self.control_bar >= 100:
            self.control_bar = 100.0
            return "opponent"
        
        return None
    
    def resolve(self, winner_side: str) -> None:
        """Mark the match as complete with a winner"""
        self.status = DuelStatus.COMPLETE.value
        self.winner_side = winner_side
        self.winner_id = self.challenger_id if winner_side == "challenger" else self.opponent_id
        self.completed_at = datetime.utcnow()
        
        # Handle wager
        if self.wager_gold > 0:
            self.winner_gold_earned = self.wager_gold * 2  # Winner gets both wagers
    
    def cancel(self) -> None:
        """Cancel the match (only valid if waiting)"""
        self.status = DuelStatus.CANCELLED.value
    
    def expire(self) -> None:
        """Mark as expired"""
        self.status = DuelStatus.EXPIRED.value
    
    # === Serialization ===
    
    def to_dict(self, include_actions: bool = False) -> Dict[str, Any]:
        """Convert to dictionary for API response (generic, no player perspective)"""
        from systems.duel.config import DUEL_TURN_TIMEOUT_SECONDS
        
        result = {
            "id": self.id,
            "match_code": self.match_code,
            "kingdom_id": self.kingdom_id,
            "status": self.status,
            
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
            "current_turn": self.current_turn,
            "current_turn_player_id": self.get_current_turn_player_id(),
            "turn_expires_at": _format_datetime_iso(self.turn_expires_at),
            "turn_timeout_seconds": DUEL_TURN_TIMEOUT_SECONDS,
            "first_turn_player_id": self.first_turn_player_id,
            
            # Multi-swing tracking
            "turn_swings_used": self.turn_swings_used or 0,
            "turn_max_swings": self.turn_max_swings or 1,
            "turn_swings_remaining": (self.turn_max_swings or 1) - (self.turn_swings_used or 0),
            "turn_rolls": self.turn_rolls or [],
            
            "wager_gold": self.wager_gold,
            
            "winner": {
                "id": self.winner_id,
                "side": self.winner_side,
                "gold_earned": self.winner_gold_earned,
            } if self.winner_id else None,
            
            "created_at": _format_datetime_iso(self.created_at),
            "started_at": _format_datetime_iso(self.started_at),
            "completed_at": _format_datetime_iso(self.completed_at),
            "expires_at": _format_datetime_iso(self.expires_at),
        }
        
        if include_actions:
            result["actions"] = [a.to_dict() for a in self.actions.order_by(DuelAction.performed_at)]
        
        return result
    
    def to_dict_for_player(self, player_id: int, include_actions: bool = False, odds: Dict = None) -> Dict[str, Any]:
        """
        Convert to dictionary with player-specific perspective.
        
        SERVER-DRIVEN ARCHITECTURE:
        - Frontend is a dumb renderer
        - All values pre-calculated for this player's perspective
        - No client-side flipping/computing needed
        - ALL config included so frontend has zero hardcoded values
        
        Args:
            player_id: The player requesting the view
            include_actions: Whether to include action history
            odds: Optional dict with miss/hit/crit percentages for current attacker
        """
        from systems.duel.config import (
            DUEL_TURN_TIMEOUT_SECONDS,
            calculate_duel_roll_chances,
            calculate_duel_round_rolls,
            get_duel_game_config,
        )
        
        # Determine perspective
        my_side = self.get_player_side(player_id)
        is_challenger = my_side == "challenger"
        
        # Get stats for each side from this player's perspective
        if is_challenger:
            my_stats = self.challenger_stats or {}
            opponent_stats = self.opponent_stats or {}
            my_name = self.challenger_name
            opponent_name = self.opponent_name
            opponent_id = self.opponent_id
        else:
            my_stats = self.opponent_stats or {}
            opponent_stats = self.challenger_stats or {}
            my_name = self.opponent_name
            opponent_name = self.challenger_name
            opponent_id = self.challenger_id
        
        # Pre-calculate bar position for this player's perspective
        # Higher = better for YOU (100 = you win, 0 = you lose)
        if is_challenger:
            # Challenger wins at bar=0, so invert
            your_bar_position = 100.0 - self.control_bar
        else:
            # Opponent wins at bar=100
            your_bar_position = self.control_bar
        
        # Turn state - pre-calculated booleans
        is_your_turn = self.is_players_turn(player_id)
        can_attack = is_your_turn and self.is_fighting

        # ============================================================
        # Round system state (simultaneous; no turns)
        # ============================================================
        if is_challenger:
            my_pending_round = self.pending_challenger_round_rolls
            opp_pending_round = self.pending_opponent_round_rolls
        else:
            my_pending_round = self.pending_opponent_round_rolls
            opp_pending_round = self.pending_challenger_round_rolls

        has_submitted_round = bool(my_pending_round)
        opponent_has_submitted_round = bool(opp_pending_round)
        can_submit_round = self.is_fighting and (not has_submitted_round)

        # Round timeout claim: you submitted, opponent didn't, and the round expired
        can_claim_round_timeout = (
            self.is_fighting
            and self.round_expires_at is not None
            and datetime.utcnow() > self.round_expires_at
            and has_submitted_round
            and (not opponent_has_submitted_round)
        )
        
        # === STYLE PHASE STATE ===
        if is_challenger:
            my_style = self.challenger_style
            opponent_style_locked = self.opponent_style is not None
            my_style_locked = self.challenger_style is not None
        else:
            my_style = self.opponent_style
            opponent_style_locked = self.challenger_style is not None
            my_style_locked = self.opponent_style is not None
        
        # Style phase is active if: fighting, no pending rolls, and style_lock_expires_at not passed
        both_styles_locked = self.both_styles_locked()
        style_phase_expired = self.style_phase_expired()
        in_style_phase = (
            self.is_fighting 
            and not has_submitted_round 
            and not both_styles_locked 
            and not style_phase_expired
        )
        can_lock_style = in_style_phase and not my_style_locked
        
        # After round resolution, show both styles for the reveal
        # (only reveal opponent's style after both are locked or phase expired)
        show_opponent_style = both_styles_locked or style_phase_expired
        opponent_style_for_display = None
        if show_opponent_style:
            if is_challenger:
                opponent_style_for_display = self.opponent_style
            else:
                opponent_style_for_display = self.challenger_style
        
        # Timeout claim - can claim if it's NOT your turn and the turn has expired
        can_claim_timeout = (
            not is_your_turn and 
            self.is_fighting and 
            self.turn_expires_at is not None and 
            datetime.utcnow() > self.turn_expires_at
        ) or can_claim_round_timeout
        
        # Swings - only relevant when it's your turn
        if is_your_turn:
            your_swings_used = self.turn_swings_used or 0
            # If no swings yet, calculate from your attack (turn_max_swings might be stale from opponent's turn)
            if your_swings_used == 0:
                your_max_swings = 1 + my_stats.get("attack", 0)
            else:
                your_max_swings = self.turn_max_swings or (1 + my_stats.get("attack", 0))
            your_swings_remaining = your_max_swings - your_swings_used
        else:
            # When not your turn, show your potential swings (1 + attack)
            your_swings_used = 0
            your_max_swings = 1 + my_stats.get("attack", 0)
            your_swings_remaining = your_max_swings
        
        # Current odds (for probability bar display)
        if odds:
            current_odds = {
                "miss": odds.get("miss", 50),
                "hit": odds.get("hit", 40),
                "crit": odds.get("crit", 10),
            }
        elif self.is_fighting:
            # Round system: each player always sees THEIR odds
            atk = my_stats.get("attack", 0)
            defense = opponent_stats.get("defense", 0)
            miss_pct, hit_pct, crit_pct = calculate_duel_roll_chances(atk, defense)
            current_odds = {"miss": miss_pct, "hit": hit_pct, "crit": crit_pct}
        else:
            current_odds = {"miss": 50, "hit": 40, "crit": 10}
        
        # Turn rolls with attacker name (no isMe flag needed)
        turn_rolls_display = []
        current_attacker_name = None
        if self.is_fighting:
            current_attacker_id = self.get_current_turn_player_id()
            if current_attacker_id == self.challenger_id:
                current_attacker_name = self.challenger_name
            else:
                current_attacker_name = self.opponent_name
        
        for roll in (self.turn_rolls or []):
            turn_rolls_display.append({
                "roll_number": roll.get("roll_number", 1),
                "value": roll.get("value", 50),
                "outcome": roll.get("outcome", "miss"),
                "attacker_name": current_attacker_name or "Unknown",
            })
        
        # Winner from this player's perspective
        winner_data = None
        if self.winner_id:
            did_i_win = self.winner_id == player_id
            winner_data = {
                "id": self.winner_id,
                "did_i_win": did_i_win,
                "gold_earned": self.winner_gold_earned if did_i_win else 0,
            }
        
        result = {
            "id": self.id,
            "match_code": self.match_code,
            "kingdom_id": self.kingdom_id,
            "status": self.status,
            
            # === PLAYER PERSPECTIVE (the good stuff) ===
            "is_your_turn": is_your_turn,
            "can_attack": can_attack,
            "can_claim_timeout": can_claim_timeout,
            "your_bar_position": round(your_bar_position, 2),

            # === ROUND SYSTEM (new) ===
            "round_number": self.round_number or 1,
            "round_expires_at": _format_datetime_iso(self.round_expires_at),
            "can_submit_round": can_submit_round,
            "has_submitted_round": has_submitted_round,
            "opponent_has_submitted_round": opponent_has_submitted_round,
            "your_round_rolls_count": calculate_duel_round_rolls(my_stats.get("attack", 0)),
            
            # === ATTACK STYLE SYSTEM ===
            "in_style_phase": in_style_phase,
            "can_lock_style": can_lock_style,
            "my_style": my_style,  # Your locked style (or None)
            "my_style_locked": my_style_locked,
            "opponent_style_locked": opponent_style_locked,
            "opponent_style": opponent_style_for_display,  # Only shown after both locked
            "style_lock_expires_at": _format_datetime_iso(self.style_lock_expires_at),
            "both_styles_locked": both_styles_locked,
            
            "your_swings_used": your_swings_used,
            "your_swings_remaining": your_swings_remaining,
            "your_max_swings": your_max_swings,
            
            # Your info
            "you": {
                "id": player_id,
                "name": my_name,
                "attack": my_stats.get("attack", 0),
                "defense": my_stats.get("defense", 0),
                "leadership": my_stats.get("leadership", 0),
            },
            
            # Opponent info
            "opponent": {
                "id": opponent_id,
                "name": opponent_name,
                "attack": opponent_stats.get("attack", 0),
                "defense": opponent_stats.get("defense", 0),
            } if opponent_id else None,
            
            # Current attacker's odds (for probability bar)
            "current_odds": current_odds,
            
            # Rolls this turn (generic - no isMe needed)
            "turn_rolls": turn_rolls_display,
            
            # Winner
            "winner": winner_data,
            
            # === METADATA ===
            "wager_gold": self.wager_gold,
            "turn_expires_at": _format_datetime_iso(self.turn_expires_at),
            
            "created_at": _format_datetime_iso(self.created_at),
            "started_at": _format_datetime_iso(self.started_at),
            "completed_at": _format_datetime_iso(self.completed_at),
            
            # === GAME CONFIG (frontend has ZERO hardcoded values) ===
            "config": get_duel_game_config(),
            
            # === LEGACY (for backwards compat during transition) ===
            "challenger": {
                "id": self.challenger_id,
                "name": self.challenger_name,
                "stats": self.challenger_stats,
            },
            "opponent_legacy": {
                "id": self.opponent_id,
                "name": self.opponent_name,
                "stats": self.opponent_stats,
            } if self.opponent_id else None,
            "control_bar": round(self.control_bar, 2),
            "current_turn": self.current_turn,
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
    
    status = Column(String(20), nullable=False, default="pending")  # pending, accepted, declined, expired
    
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
    """Log of each attack during a duel"""
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
    """
    Tracks which player went first in previous duels between the same pair.
    Used to alternate who starts when the same two players duel again.
    
    player_a_id is always the smaller ID (for consistent lookups).
    """
    __tablename__ = "duel_pairing_history"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Always store with player_a_id < player_b_id for consistent lookups
    player_a_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    player_b_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Who went first in the last match
    last_first_player_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Reference to the match
    last_match_id = Column(Integer, ForeignKey("duel_matches.id", ondelete="SET NULL"), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<DuelPairingHistory(a={self.player_a_id}, b={self.player_b_id}, last_first={self.last_first_player_id})>"
    
    @staticmethod
    def normalize_pair(player_1_id: int, player_2_id: int) -> tuple:
        """Return (smaller_id, larger_id) for consistent lookups"""
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
    
    def __repr__(self):
        return f"<DuelStats(user={self.user_id}, wins={self.wins}, losses={self.losses})>"
    
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

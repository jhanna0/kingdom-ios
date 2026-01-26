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
        """Convert to dictionary for API response"""
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

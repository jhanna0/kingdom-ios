"""
DUEL MANAGER
============
Orchestrates 1v1 PvP duels in the Town Hall arena.

ARCHITECTURE PRINCIPLE: Backend is authoritative.
- Backend determines who goes first (based on pairing history)
- Backend enforces turn order (can't attack if not your turn)
- Backend manages turn timer (30s)
- Backend broadcasts turn results to BOTH players
- Frontend just renders what backend tells it

Flow:
1. Challenger picks a friend and creates challenge -> opponent gets notification
2. Opponent accepts/declines
3. Backend starts match, determines first player from pairing history
4. Players take turns (30s each), backend broadcasts results
5. If turn expires, opponent can claim timeout win

Handles:
- Challenge creation (match + invitation atomically)
- Opponent accepting/declining
- Turn order history (alternating who goes first)
- Turn-based combat execution with strict enforcement
- Real-time WebSocket broadcasts to both players
- Match resolution and rewards
"""
import random
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Tuple, Any
from sqlalchemy.orm import Session

from db.models import User, PlayerState, DuelMatch, DuelInvitation, DuelAction, DuelStats, DuelStatus, Friend, DuelPairingHistory
from .config import (
    DUEL_TURN_TIMEOUT_SECONDS,
    DUEL_INVITATION_TIMEOUT_MINUTES,
    DUEL_MAX_WAGER,
    calculate_duel_hit_chance,
    calculate_roll_outcome,
    generate_match_code,
)


class DuelManager:
    """
    Manager for PvP duel matches.
    
    Backend is authoritative - prevents all cheating:
    - Turn order enforced server-side
    - Turn timer enforced server-side
    - All state changes happen on backend, then broadcast to clients
    
    Usage:
        manager = DuelManager()
        match, invitation = manager.create_challenge(db, challenger_id, opponent_id, kingdom_id)
        # opponent receives notification, accepts:
        match = manager.join_by_invitation(db, invitation.id, opponent_id)
        # either player starts:
        match = manager.start_match(db, match.id, player_id)
        result = manager.execute_attack(db, match.id, player_id)
    """
    
    def __init__(self):
        self.rng = random.Random()
    
    # ===== Turn Order History =====
    
    def determine_first_player(self, db: Session, player_1_id: int, player_2_id: int) -> int:
        """
        Determine who should go first based on pairing history.
        
        If these players have dueled before, the OTHER player goes first this time.
        If no history, player_1 (challenger) goes first.
        
        Args:
            db: Database session
            player_1_id: One player (typically challenger)
            player_2_id: Other player (typically opponent)
        
        Returns:
            ID of player who should go first
        """
        # Normalize the pair for consistent lookup
        a_id, b_id = DuelPairingHistory.normalize_pair(player_1_id, player_2_id)
        
        history = db.query(DuelPairingHistory).filter(
            DuelPairingHistory.player_a_id == a_id,
            DuelPairingHistory.player_b_id == b_id
        ).first()
        
        if not history:
            # No history - challenger goes first
            return player_1_id
        
        # Alternate: whoever went first last time does NOT go first now
        if history.last_first_player_id == player_1_id:
            return player_2_id
        else:
            return player_1_id
    
    def _update_pairing_history(
        self, 
        db: Session, 
        player_1_id: int, 
        player_2_id: int, 
        first_player_id: int,
        match_id: int
    ) -> None:
        """
        Record who went first in this match for future alternation.
        """
        a_id, b_id = DuelPairingHistory.normalize_pair(player_1_id, player_2_id)
        
        history = db.query(DuelPairingHistory).filter(
            DuelPairingHistory.player_a_id == a_id,
            DuelPairingHistory.player_b_id == b_id
        ).first()
        
        if history:
            history.last_first_player_id = first_player_id
            history.last_match_id = match_id
            history.updated_at = datetime.utcnow()
        else:
            history = DuelPairingHistory(
                player_a_id=a_id,
                player_b_id=b_id,
                last_first_player_id=first_player_id,
                last_match_id=match_id
            )
            db.add(history)
    
    # ===== Challenge Creation =====
    
    def create_challenge(
        self,
        db: Session,
        challenger_id: int,
        opponent_id: int,
        kingdom_id: str,
        wager_gold: int = 0
    ) -> Tuple[DuelMatch, DuelInvitation]:
        """
        Create a duel challenge to a specific friend.
        
        Like trades: creates match + invitation atomically.
        The opponent will receive a notification and can accept/decline.
        
        Args:
            db: Database session
            challenger_id: ID of player creating the challenge
            opponent_id: ID of the friend being challenged
            kingdom_id: Town Hall location
            wager_gold: Optional gold wager (both players must match)
        
        Returns:
            Tuple of (DuelMatch, DuelInvitation)
        """
        # Get challenger info
        challenger = db.query(User).filter(User.id == challenger_id).first()
        if not challenger:
            raise ValueError("Challenger not found")
        
        # Get opponent info
        opponent = db.query(User).filter(User.id == opponent_id).first()
        if not opponent:
            raise ValueError("Opponent not found")
        
        # Validate wager
        wager_gold = min(max(0, wager_gold), DUEL_MAX_WAGER)
        
        # Check if challenger can afford wager
        if wager_gold > 0:
            state = db.query(PlayerState).filter(PlayerState.user_id == challenger_id).first()
            if not state or state.gold < wager_gold:
                raise ValueError(f"Insufficient gold for wager (need {wager_gold})")
        
        # Generate unique match code (kept for internal reference)
        max_attempts = 10
        for _ in range(max_attempts):
            code = generate_match_code()
            existing = db.query(DuelMatch).filter(DuelMatch.match_code == code).first()
            if not existing:
                break
        else:
            raise ValueError("Could not generate unique match code")
        
        # Get both players' stats
        challenger_stats = self._get_player_stats(db, challenger_id)
        opponent_stats = self._get_player_stats(db, opponent_id)
        
        # Create match with opponent already set (waiting for their acceptance)
        match = DuelMatch(
            match_code=code,
            kingdom_id=kingdom_id,
            challenger_id=challenger_id,
            challenger_name=challenger.display_name or f"Player {challenger_id}",
            challenger_stats=challenger_stats,
            opponent_id=opponent_id,
            opponent_name=opponent.display_name or f"Player {opponent_id}",
            opponent_stats=opponent_stats,
            wager_gold=wager_gold,
            status=DuelStatus.WAITING.value,
            expires_at=datetime.utcnow() + timedelta(minutes=DUEL_INVITATION_TIMEOUT_MINUTES),
        )
        
        db.add(match)
        db.flush()  # Get match ID
        
        # Create invitation for the opponent
        invitation = DuelInvitation(
            match_id=match.id,
            inviter_id=challenger_id,
            invitee_id=opponent_id,
            status="pending",
        )
        
        db.add(invitation)
        db.commit()
        db.refresh(match)
        db.refresh(invitation)
        
        return match, invitation
    
    def _get_player_stats(self, db: Session, user_id: int) -> Dict[str, int]:
        """Get player stats for duel combat including equipment bonuses"""
        from db.models import PlayerItem
        
        state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
        if not state:
            return {
                "attack": 0, "defense": 0, "level": 1,
                "base_attack": 0, "base_defense": 0,
                "weapon_bonus": 0, "armor_bonus": 0,
            }
        
        base_attack = state.attack_power or 0
        base_defense = state.defense_power or 0
        
        # Get equipped items and their bonuses
        equipped_items = db.query(PlayerItem).filter(
            PlayerItem.user_id == user_id,
            PlayerItem.is_equipped == True
        ).all()
        
        weapon_bonus = 0
        armor_bonus = 0
        
        for item in equipped_items:
            if item.type == "weapon":
                weapon_bonus += item.attack_bonus or 0
            elif item.type == "armor":
                armor_bonus += item.defense_bonus or 0
        
        return {
            "attack": base_attack + weapon_bonus,
            "defense": base_defense + armor_bonus,
            "level": state.level or 1,
            "leadership": state.leadership or 0,
            "base_attack": base_attack,
            "base_defense": base_defense,
            "weapon_bonus": weapon_bonus,
            "armor_bonus": armor_bonus,
        }
    
    # ===== Invitations =====
    
    def get_pending_invitations(self, db: Session, user_id: int) -> List[Dict]:
        """Get all pending duel challenges for a user"""
        invitations = db.query(DuelInvitation).filter(
            DuelInvitation.invitee_id == user_id,
            DuelInvitation.status == "pending"
        ).all()
        
        result = []
        for inv in invitations:
            match = db.query(DuelMatch).filter(DuelMatch.id == inv.match_id).first()
            if match and match.status == DuelStatus.WAITING.value:
                inviter = db.query(User).filter(User.id == inv.inviter_id).first()
                result.append({
                    "invitation_id": inv.id,
                    "match_id": match.id,
                    "inviter_id": inv.inviter_id,
                    "inviter_name": inviter.display_name if inviter else "Unknown",
                    "wager_gold": match.wager_gold,
                    "kingdom_id": match.kingdom_id,
                    "challenger_stats": match.challenger_stats,
                    "created_at": inv.created_at.isoformat() + "Z" if inv.created_at else None,
                })
        
        return result
    
    # ===== Accepting/Declining Challenges =====
    
    def join_by_invitation(
        self,
        db: Session,
        invitation_id: int,
        opponent_id: int
    ) -> DuelMatch:
        """
        Accept a duel challenge and join the match.
        
        With direct invites, accepting goes straight to READY status
        (no need for challenger to confirm since they initiated).
        
        Args:
            db: Database session
            invitation_id: The invitation ID
            opponent_id: ID of the player accepting
        
        Returns:
            The updated DuelMatch (now in READY state)
        """
        invitation = db.query(DuelInvitation).filter(
            DuelInvitation.id == invitation_id
        ).first()
        
        if not invitation:
            raise ValueError("Challenge not found")
        
        if invitation.invitee_id != opponent_id:
            raise ValueError("This challenge is not for you")
        
        if invitation.status != "pending":
            raise ValueError(f"Challenge already {invitation.status}")
        
        match = db.query(DuelMatch).filter(DuelMatch.id == invitation.match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if match.status != DuelStatus.WAITING.value:
            raise ValueError("Match is no longer available")
        
        if match.is_expired:
            match.expire()
            invitation.status = "expired"
            db.commit()
            raise ValueError("Challenge has expired")
        
        # Check wager affordability
        if match.wager_gold > 0:
            state = db.query(PlayerState).filter(PlayerState.user_id == opponent_id).first()
            if not state or state.gold < match.wager_gold:
                raise ValueError(f"Insufficient gold for wager (need {match.wager_gold})")
        
        # Mark invitation as accepted
        invitation.accept()
        
        # With direct invites, go straight to READY (challenger already chose this opponent)
        match.status = DuelStatus.READY.value
        
        db.commit()
        db.refresh(match)
        
        return match
    
    def decline_invitation(self, db: Session, invitation_id: int, user_id: int) -> Optional[DuelMatch]:
        """
        Decline a duel challenge - also cancels the associated match.
        
        Returns the cancelled match so the challenger can be notified.
        """
        invitation = db.query(DuelInvitation).filter(
            DuelInvitation.id == invitation_id
        ).first()
        
        if not invitation:
            raise ValueError("Challenge not found")
        
        if invitation.invitee_id != user_id:
            raise ValueError("This challenge is not for you")
        
        if invitation.status != "pending":
            raise ValueError(f"Challenge already {invitation.status}")
        
        # Get the match to cancel it
        match = db.query(DuelMatch).filter(DuelMatch.id == invitation.match_id).first()
        
        # Decline the invitation
        invitation.decline()
        
        # Cancel the associated match
        if match and match.status == DuelStatus.WAITING.value:
            match.status = DuelStatus.DECLINED.value
            match.completed_at = datetime.utcnow()
        
        db.commit()
        
        if match:
            db.refresh(match)
        
        return match
    
    # ===== Match Start =====
    
    def start_match(self, db: Session, match_id: int, player_id: int) -> DuelMatch:
        """
        Start the duel - determines who goes first based on pairing history.
        
        The first player is determined by alternating from previous duels:
        - If these players never dueled: challenger goes first
        - If they dueled before: the OTHER player goes first this time
        
        Returns the match with turn info set.
        """
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if match.status != DuelStatus.READY.value:
            raise ValueError(f"Match is {match.status}, cannot start")
        
        if player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        # Deduct wagers
        if match.wager_gold > 0:
            for pid in [match.challenger_id, match.opponent_id]:
                state = db.query(PlayerState).filter(PlayerState.user_id == pid).first()
                if state:
                    state.gold = max(0, state.gold - match.wager_gold)
        
        # Determine who goes first based on pairing history (alternates)
        first_player_id = self.determine_first_player(
            db, match.challenger_id, match.opponent_id
        )
        
        # Set first turn
        if first_player_id == match.challenger_id:
            match.current_turn = "challenger"
        else:
            match.current_turn = "opponent"
        
        # Record who went first for history
        match.first_turn_player_id = first_player_id
        
        # Start the match with turn timer
        match.status = DuelStatus.FIGHTING.value
        match.started_at = datetime.utcnow()
        match.turn_expires_at = datetime.utcnow() + timedelta(seconds=DUEL_TURN_TIMEOUT_SECONDS)
        
        # Update pairing history for next time
        self._update_pairing_history(
            db, 
            match.challenger_id, 
            match.opponent_id, 
            first_player_id,
            match.id
        )
        
        db.commit()
        db.refresh(match)
        
        return match
    
    # ===== Turn Management =====
    
    def _switch_turn(self, match: DuelMatch) -> None:
        """
        Switch to the other player's turn and reset timer.
        Called internally after a successful attack.
        """
        match.switch_turn()
        match.turn_expires_at = datetime.utcnow() + timedelta(seconds=DUEL_TURN_TIMEOUT_SECONDS)
    
    def check_turn_timeout(self, db: Session, match_id: int) -> Optional[Dict]:
        """
        Check if the current turn has timed out.
        
        Returns None if turn is still valid, or timeout info if expired.
        This can be called by a background job or the claim-timeout endpoint.
        """
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match or match.status != DuelStatus.FIGHTING.value:
            return None
        
        if match.turn_expires_at and datetime.utcnow() > match.turn_expires_at:
            # Turn has expired
            return {
                "expired": True,
                "timed_out_player_id": match.get_current_turn_player_id(),
                "current_turn": match.current_turn,
                "expired_at": match.turn_expires_at
            }
        
        return None
    
    def forfeit_by_timeout(self, db: Session, match_id: int, claiming_player_id: int) -> DuelMatch:
        """
        Award victory to claiming player because opponent timed out.
        
        Validates that:
        1. It's NOT the claiming player's turn
        2. The turn has actually expired
        
        Returns the completed match.
        """
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if match.status != DuelStatus.FIGHTING.value:
            raise ValueError("Match is not in progress")
        
        if claiming_player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        # Can only claim if it's NOT your turn
        if match.get_current_turn_player_id() == claiming_player_id:
            raise ValueError("It's your turn - you can't claim timeout")
        
        # Check if turn actually expired
        if not match.turn_expires_at or datetime.utcnow() < match.turn_expires_at:
            remaining = (match.turn_expires_at - datetime.utcnow()).seconds if match.turn_expires_at else 0
            raise ValueError(f"Turn hasn't expired yet ({remaining}s remaining)")
        
        # Award victory to claiming player (opponent timed out)
        winner_side = "challenger" if claiming_player_id == match.challenger_id else "opponent"
        self._resolve_match(db, match, winner_side)
        
        db.commit()
        db.refresh(match)
        
        return match
    
    # ===== Combat =====
    
    def execute_attack(
        self,
        db: Session,
        match_id: int,
        player_id: int
    ) -> Dict[str, Any]:
        """
        Execute a SINGLE SWING in the duel.
        
        Multi-swing system:
        - Each API call = one swing
        - Player can have multiple swings per turn (1 + attack stat)
        - Best outcome is tracked across all swings
        - Turn only switches after all swings are used
        - Bar is pushed after final swing using best outcome
        
        Args:
            db: Database session
            match_id: The duel match ID
            player_id: ID of the attacking player
        
        Returns:
            Single swing result with roll, current best, swings remaining.
        """
        from .config import calculate_duel_max_rolls, calculate_duel_roll_chances
        
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if not match.is_fighting:
            raise ValueError(f"Match is {match.status}, not fighting")
        
        # STRICT TURN ENFORCEMENT
        if not match.is_players_turn(player_id):
            current_turn_player = match.get_current_turn_player_id()
            raise ValueError(f"Not your turn. Current turn: player {current_turn_player}")
        
        # Get player's side and stats
        side = match.get_player_side(player_id)
        attacker_stats = match.challenger_stats if side == "challenger" else match.opponent_stats
        defender_stats = match.opponent_stats if side == "challenger" else match.challenger_stats
        
        attack = attacker_stats.get("attack", 0)
        defense = defender_stats.get("defense", 0)
        leadership = attacker_stats.get("leadership", 0)
        
        hit_chance = calculate_duel_hit_chance(attack, defense)
        miss_pct, hit_pct, crit_pct = calculate_duel_roll_chances(attack, defense)
        
        # Initialize turn swing tracking if this is first swing of turn
        if match.turn_swings_used == 0 or match.turn_swings_used is None:
            max_swings = calculate_duel_max_rolls(attack)
            match.turn_max_swings = max_swings
            match.turn_swings_used = 0
            match.turn_best_outcome = "miss"
            match.turn_best_push = 0.0
            match.turn_rolls = []
        
        # Check if player still has swings
        if match.turn_swings_used >= match.turn_max_swings:
            raise ValueError("No swings remaining this turn")
        
        # === DO ONE SWING ===
        roll_value = self.rng.random()
        outcome, push_amount = calculate_roll_outcome(roll_value, hit_chance, leadership)
        
        swing_number = match.turn_swings_used + 1
        roll_data = {
            "roll_number": swing_number,
            "value": round(roll_value * 100, 1),
            "outcome": outcome,
        }
        
        # Add to turn rolls
        turn_rolls = match.turn_rolls or []
        turn_rolls.append(roll_data)
        match.turn_rolls = turn_rolls
        
        # Track best outcome
        outcome_rank = {"miss": 0, "hit": 1, "critical": 2}
        current_best = match.turn_best_outcome or "miss"
        if outcome_rank[outcome] > outcome_rank[current_best]:
            match.turn_best_outcome = outcome
            match.turn_best_push = push_amount
        elif outcome_rank[outcome] == outcome_rank[current_best] and push_amount > (match.turn_best_push or 0):
            match.turn_best_push = push_amount
        
        match.turn_swings_used = swing_number
        swings_remaining = match.turn_max_swings - swing_number
        is_last_swing = swings_remaining == 0
        
        print(f"🎯 SWING {swing_number}/{match.turn_max_swings}: player={player_id}, outcome={outcome}, best={match.turn_best_outcome}")
        
        # Build result for this swing
        result = {
            "success": True,
            "roll": roll_data,
            "swing_number": swing_number,
            "swings_remaining": swings_remaining,
            "max_swings": match.turn_max_swings,
            "current_best_outcome": match.turn_best_outcome,
            "current_best_push": round(match.turn_best_push or 0, 2),
            "all_rolls": turn_rolls,
            "miss_chance": miss_pct,
            "hit_chance_pct": hit_pct,
            "crit_chance": crit_pct,
            "is_last_swing": is_last_swing,
            "turn_complete": is_last_swing,
            "match": None,
            "action": None,
            "winner": None,
            "game_over": False,
        }
        
        # If last swing, apply the best outcome and switch turns
        if is_last_swing:
            bar_before = match.control_bar
            best_push = match.turn_best_push or 0
            best_outcome = match.turn_best_outcome or "miss"
            
            winner_side = match.apply_push(side, best_push)
            
            print(f"🎯 TURN COMPLETE: best={best_outcome}, push={best_push:.2f}, bar={bar_before:.2f}->{match.control_bar:.2f}")
            
            # Record action
            action = DuelAction(
                match_id=match_id,
                player_id=player_id,
                side=side,
                roll_value=roll_value,  # Last roll value
                outcome=best_outcome,
                push_amount=best_push,
                bar_before=bar_before,
                bar_after=match.control_bar,
            )
            db.add(action)
            
            result["action"] = {
                "player_id": player_id,
                "side": side,
                "outcome": best_outcome,
                "push_amount": round(best_push, 2),
                "bar_before": round(bar_before, 2),
                "bar_after": round(match.control_bar, 2),
            }
            
            # Check for winner
            if winner_side:
                self._resolve_match(db, match, winner_side)
                result["winner"] = {
                    "side": winner_side,
                    "player_id": match.winner_id,
                    "gold_earned": match.winner_gold_earned,
                }
                result["game_over"] = True
            else:
                # Switch turns and reset swing tracking
                self._switch_turn(match)
                match.turn_swings_used = 0
                match.turn_best_outcome = None
                match.turn_best_push = 0.0
                match.turn_rolls = []
                
                result["next_turn"] = {
                    "player_id": match.get_current_turn_player_id(),
                    "side": match.current_turn,
                    "expires_at": match.turn_expires_at.isoformat() + "Z" if match.turn_expires_at else None,
                    "timeout_seconds": DUEL_TURN_TIMEOUT_SECONDS,
                }
        
        db.commit()
        db.refresh(match)
        
        result["match"] = match.to_dict(include_actions=True)
        
        return result
    
    def _resolve_match(self, db: Session, match: DuelMatch, winner_side: str) -> None:
        """Resolve the match with a winner"""
        match.resolve(winner_side)
        
        loser_id = match.opponent_id if winner_side == "challenger" else match.challenger_id
        
        # Update duel stats
        self._update_stats(db, match.winner_id, won=True, gold=match.winner_gold_earned or 0)
        self._update_stats(db, loser_id, won=False, gold=match.wager_gold)
        
        # Award gold to winner
        if match.winner_gold_earned and match.winner_gold_earned > 0:
            winner_state = db.query(PlayerState).filter(PlayerState.user_id == match.winner_id).first()
            if winner_state:
                winner_state.gold += match.winner_gold_earned
    
    def _update_stats(self, db: Session, user_id: int, won: bool, gold: int) -> None:
        """Update player's duel stats"""
        stats = db.query(DuelStats).filter(DuelStats.user_id == user_id).first()
        
        if not stats:
            stats = DuelStats(
                user_id=user_id,
                wins=0,
                losses=0,
                draws=0,
                total_gold_won=0,
                total_gold_lost=0,
                win_streak=0,
                best_win_streak=0,
            )
            db.add(stats)
            db.flush()  # Apply defaults before modifying
        
        if won:
            stats.record_win(gold)
        else:
            stats.record_loss(gold)
    
    # ===== Match Management =====
    
    def get_match(self, db: Session, match_id: int) -> Optional[DuelMatch]:
        """Get a match by ID"""
        return db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
    
    def get_active_match_for_player(self, db: Session, player_id: int) -> Optional[DuelMatch]:
        """Get a player's active match (if any)"""
        return db.query(DuelMatch).filter(
            DuelMatch.status.in_([
                DuelStatus.WAITING.value,
                DuelStatus.PENDING_ACCEPTANCE.value,
                DuelStatus.READY.value,
                DuelStatus.FIGHTING.value
            ]),
            (DuelMatch.challenger_id == player_id) | (DuelMatch.opponent_id == player_id)
        ).first()
    
    def cancel_match(self, db: Session, match_id: int, player_id: int) -> DuelMatch:
        """Cancel a match (only valid if waiting)"""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if match.challenger_id != player_id:
            raise ValueError("Only the challenger can cancel")
        
        if match.status != DuelStatus.WAITING.value:
            raise ValueError("Can only cancel matches that haven't started")
        
        match.cancel()
        db.commit()
        db.refresh(match)
        
        return match
    
    def forfeit_match(self, db: Session, match_id: int, player_id: int) -> DuelMatch:
        """Forfeit an in-progress match"""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        if not match.is_fighting:
            raise ValueError("Can only forfeit active matches")
        
        # The other player wins
        winner_side = "opponent" if player_id == match.challenger_id else "challenger"
        self._resolve_match(db, match, winner_side)
        
        db.commit()
        db.refresh(match)
        
        return match
    
    def get_player_stats(self, db: Session, user_id: int) -> Optional[DuelStats]:
        """Get a player's duel stats"""
        return db.query(DuelStats).filter(DuelStats.user_id == user_id).first()
    
    def get_leaderboard(self, db: Session, limit: int = 10) -> List[Dict]:
        """Get top duelists by wins"""
        stats_list = db.query(DuelStats).order_by(
            DuelStats.wins.desc()
        ).limit(limit).all()
        
        result = []
        for stats in stats_list:
            user = db.query(User).filter(User.id == stats.user_id).first()
            result.append({
                "user_id": stats.user_id,
                "display_name": user.display_name if user else f"Player {stats.user_id}",
                **stats.to_dict()
            })
        
        return result
    
    def get_recent_matches(self, db: Session, kingdom_id: str, limit: int = 10) -> List[Dict]:
        """Get recent completed matches in a kingdom"""
        matches = db.query(DuelMatch).filter(
            DuelMatch.kingdom_id == kingdom_id,
            DuelMatch.status == DuelStatus.COMPLETE.value
        ).order_by(DuelMatch.completed_at.desc()).limit(limit).all()
        
        return [m.to_dict() for m in matches]

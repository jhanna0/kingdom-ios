"""
DUEL MANAGER - Swing-by-Swing PvP Combat
=========================================

ARCHITECTURE:
- Backend is 100% authoritative
- Frontend is a DUMB RENDERER
- All game logic, calculations, and outcomes computed server-side

ROUND FLOW:
1. STYLE SELECTION (10s)
   - Both players pick attack styles
   - Timer expires OR both lock → styles revealed

2. STYLE REVEAL (2s)
   - Both styles shown with visual effects
   - Probability bar updates with combined modifiers

3. SWING PHASE (30s)
   - Each player controls their swings INDEPENDENTLY
   - Click SWING → POST /duels/{id}/swing → get ONE result
   - See result, decide: swing again OR stop
   - Best outcome tracked automatically
   - Click STOP (or use all swings) → POST /duels/{id}/stop

4. RESOLUTION
   - Both players stopped → compare best outcomes
   - Winner pushes bar (with style multipliers)
   - Feint wins ties
   - Next round starts OR match ends
"""
import random
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Tuple, Any
from sqlalchemy.orm import Session

from db.models import User, PlayerState, DuelMatch, DuelInvitation, DuelAction, DuelStats, DuelStatus, Friend, DuelPairingHistory
from db.models.duel import DuelPhase, OUTCOME_RANK
from .config import (
    DUEL_TURN_TIMEOUT_SECONDS,
    DUEL_INVITATION_TIMEOUT_MINUTES,
    DUEL_MAX_WAGER,
    DUEL_STYLE_LOCK_TIMEOUT_SECONDS,
    DUEL_SWING_TIMEOUT_SECONDS,
    DUEL_STYLE_REVEAL_DURATION_SECONDS,
    DUEL_MAX_ROLLS_PER_ROUND_CAP,
    DUEL_MIN_HIT_CHANCE,
    DUEL_MAX_HIT_CHANCE,
    DUEL_CRITICAL_MULTIPLIER,
    calculate_duel_hit_chance,
    calculate_duel_push,
    generate_match_code,
    AttackStyle,
    get_style_modifiers,
)


class DuelManager:
    """
    Orchestrates 1v1 PvP duels with swing-by-swing control.
    
    Each player controls their own swings independently.
    Round resolves when both have stopped.
    """
    
    def __init__(self):
        self.rng = random.Random()
    
    # =========================================================================
    # CHALLENGE CREATION & ACCEPTANCE
    # =========================================================================
    
    def create_challenge(
        self,
        db: Session,
        challenger_id: int,
        opponent_id: int,
        kingdom_id: str,
        wager_gold: int = 0
    ) -> Tuple[DuelMatch, DuelInvitation]:
        """Create a duel challenge to a friend."""
        challenger = db.query(User).filter(User.id == challenger_id).first()
        if not challenger:
            raise ValueError("Challenger not found")
        
        opponent = db.query(User).filter(User.id == opponent_id).first()
        if not opponent:
            raise ValueError("Opponent not found")
        
        wager_gold = min(max(0, wager_gold), DUEL_MAX_WAGER)
        
        if wager_gold > 0:
            state = db.query(PlayerState).filter(PlayerState.user_id == challenger_id).first()
            if not state or state.gold < wager_gold:
                raise ValueError(f"Insufficient gold for wager (need {wager_gold})")
        
        # Generate unique match code
        for _ in range(10):
            code = generate_match_code()
            if not db.query(DuelMatch).filter(DuelMatch.match_code == code).first():
                break
        else:
            raise ValueError("Could not generate unique match code")
        
        challenger_stats = self._get_player_stats(db, challenger_id)
        opponent_stats = self._get_player_stats(db, opponent_id)
        
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
            round_phase=DuelPhase.STYLE_SELECTION.value,
            expires_at=datetime.utcnow() + timedelta(minutes=DUEL_INVITATION_TIMEOUT_MINUTES),
        )
        
        db.add(match)
        db.flush()
        
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
        """Get player stats including equipment bonuses."""
        from db.models import PlayerItem
        
        state = db.query(PlayerState).filter(PlayerState.user_id == user_id).first()
        if not state:
            return {"attack": 0, "defense": 0, "level": 1, "leadership": 0}
        
        base_attack = state.attack_power or 0
        base_defense = state.defense_power or 0
        
        equipped = db.query(PlayerItem).filter(
            PlayerItem.user_id == user_id,
            PlayerItem.is_equipped == True
        ).all()
        
        weapon_bonus = sum(i.attack_bonus or 0 for i in equipped if i.type == "weapon")
        armor_bonus = sum(i.defense_bonus or 0 for i in equipped if i.type == "armor")
        
        return {
            "attack": base_attack + weapon_bonus,
            "defense": base_defense + armor_bonus,
            "level": state.level or 1,
            "leadership": state.leadership or 0,
        }
    
    def get_pending_invitations(self, db: Session, user_id: int) -> List[Dict]:
        """Get pending duel invitations for a user."""
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
    
    def join_by_invitation(self, db: Session, invitation_id: int, opponent_id: int) -> DuelMatch:
        """Accept a duel invitation."""
        invitation = db.query(DuelInvitation).filter(DuelInvitation.id == invitation_id).first()
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
        
        if match.wager_gold > 0:
            state = db.query(PlayerState).filter(PlayerState.user_id == opponent_id).first()
            if not state or state.gold < match.wager_gold:
                raise ValueError(f"Insufficient gold for wager (need {match.wager_gold})")
        
        invitation.accept()
        match.status = DuelStatus.READY.value
        
        db.commit()
        db.refresh(match)
        
        return match
    
    def decline_invitation(self, db: Session, invitation_id: int, user_id: int) -> Optional[DuelMatch]:
        """Decline a duel invitation."""
        invitation = db.query(DuelInvitation).filter(DuelInvitation.id == invitation_id).first()
        if not invitation:
            raise ValueError("Challenge not found")
        
        if invitation.invitee_id != user_id:
            raise ValueError("This challenge is not for you")
        
        if invitation.status != "pending":
            raise ValueError(f"Challenge already {invitation.status}")
        
        match = db.query(DuelMatch).filter(DuelMatch.id == invitation.match_id).first()
        invitation.decline()
        
        if match and match.status == DuelStatus.WAITING.value:
            match.status = DuelStatus.DECLINED.value
            match.completed_at = datetime.utcnow()
        
        db.commit()
        if match:
            db.refresh(match)
        
        return match
    
    # =========================================================================
    # MATCH START
    # =========================================================================
    
    def start_match(self, db: Session, match_id: int, player_id: int) -> DuelMatch:
        """Start the duel - begins round 1 style selection."""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        if match.status != DuelStatus.READY.value:
            raise ValueError(f"Match is {match.status}, cannot start")
        
        # Deduct wagers
        if match.wager_gold > 0:
            for pid in [match.challenger_id, match.opponent_id]:
                state = db.query(PlayerState).filter(PlayerState.user_id == pid).first()
                if state:
                    state.gold = max(0, state.gold - match.wager_gold)
        
        # Start match
        match.status = DuelStatus.FIGHTING.value
        match.started_at = datetime.utcnow()
        match.round_number = 1
        
        # Initialize max swings for each player
        ch_attack = (match.challenger_stats or {}).get("attack", 0)
        op_attack = (match.opponent_stats or {}).get("attack", 0)
        match.challenger_max_swings = min(1 + ch_attack, DUEL_MAX_ROLLS_PER_ROUND_CAP)
        match.opponent_max_swings = min(1 + op_attack, DUEL_MAX_ROLLS_PER_ROUND_CAP)
        
        # Start style selection phase
        match.start_style_phase(DUEL_STYLE_LOCK_TIMEOUT_SECONDS)
        
        db.commit()
        db.refresh(match)
        
        return match
    
    # =========================================================================
    # STYLE SELECTION
    # =========================================================================
    
    def lock_style(
        self,
        db: Session,
        match_id: int,
        player_id: int,
        style: str
    ) -> Dict[str, Any]:
        """Lock in an attack style for the current round."""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if not match.is_fighting:
            raise ValueError(f"Match is {match.status}, not fighting")
        
        if player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        if style not in AttackStyle.ALL_STYLES:
            raise ValueError(f"Invalid style: {style}")
        
        if match.has_player_locked_style(player_id):
            current = match.get_player_style(player_id)
            raise ValueError(f"Already locked in {current}")
        
        # Lock the style
        now = datetime.utcnow()
        side = match.get_player_side(player_id)
        
        if side == "challenger":
            match.challenger_style = style
            match.challenger_style_locked_at = now
        else:
            match.opponent_style = style
            match.opponent_style_locked_at = now
        
        db.commit()
        db.refresh(match)
        
        # Check AFTER commit if both are locked - handles race condition
        # where both players lock simultaneously
        both_locked = match.both_styles_locked()
        
        if both_locked and match.in_style_selection:
            self._transition_to_swing_phase(match)
            db.commit()
            db.refresh(match)
        
        return {
            "success": True,
            "style": style,
            "both_styles_locked": both_locked,
            "match": match,
        }
    
    def check_style_phase_timeout(self, db: Session, match_id: int) -> Optional[DuelMatch]:
        """Check if style phase timed out and apply defaults."""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match or not match.is_fighting:
            return None
        
        if not match.in_style_selection:
            return None
        
        if not match.style_phase_expired():
            return None
        
        # Apply default styles where needed
        if not match.challenger_style:
            match.challenger_style = AttackStyle.DEFAULT
            match.challenger_style_locked_at = datetime.utcnow()
        
        if not match.opponent_style:
            match.opponent_style = AttackStyle.DEFAULT
            match.opponent_style_locked_at = datetime.utcnow()
        
        # Transition to swing phase
        self._transition_to_swing_phase(match)
        
        db.commit()
        db.refresh(match)
        
        return match
    
    def _transition_to_swing_phase(self, match: DuelMatch) -> None:
        """
        Transition from style selection to STYLE REVEAL phase.
        
        The frontend will show the reveal animation for style_reveal_duration_ms,
        then call swing() which will auto-transition to SWINGING phase.
        """
        # Apply style modifiers to max swings
        ch_mods = get_style_modifiers(match.challenger_style or AttackStyle.BALANCED)
        op_mods = get_style_modifiers(match.opponent_style or AttackStyle.BALANCED)
        
        ch_base = min(1 + (match.challenger_stats or {}).get("attack", 0), DUEL_MAX_ROLLS_PER_ROUND_CAP)
        op_base = min(1 + (match.opponent_stats or {}).get("attack", 0), DUEL_MAX_ROLLS_PER_ROUND_CAP)
        
        ch_raw = ch_base + ch_mods["roll_bonus"]
        op_raw = op_base + op_mods["roll_bonus"]
        
        # Handle edge case: if style would drop to 0 rolls, give them 1 but opponent gets +1
        ch_bonus_to_opponent = 0
        op_bonus_to_challenger = 0
        
        if ch_raw < 1:
            ch_raw = 1
            ch_bonus_to_opponent = 1
        
        if op_raw < 1:
            op_raw = 1
            op_bonus_to_challenger = 1
        
        match.challenger_max_swings = min(DUEL_MAX_ROLLS_PER_ROUND_CAP, ch_raw + op_bonus_to_challenger)
        match.opponent_max_swings = min(DUEL_MAX_ROLLS_PER_ROUND_CAP, op_raw + ch_bonus_to_opponent)
        
        # Set to STYLE REVEAL phase - frontend will show animation
        match.round_phase = DuelPhase.STYLE_REVEAL.value
        
        # START THE SWING TIMEOUT NOW - even if no one swings, timeout should work
        # Frontend shows reveal animation, then players can swing
        # If opponent never swings, you can still claim timeout
        match.swing_phase_expires_at = datetime.utcnow() + timedelta(seconds=DUEL_SWING_TIMEOUT_SECONDS)
    
    # =========================================================================
    # SWING PHASE - THE CORE MECHANIC
    # =========================================================================
    
    def swing(
        self,
        db: Session,
        match_id: int,
        player_id: int
    ) -> Dict[str, Any]:
        """
        Execute a SINGLE SWING.
        
        This is the core mechanic - player controls each swing individually.
        Returns the roll result. Player can then swing again or stop.
        """
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if not match.is_fighting:
            raise ValueError(f"Match is {match.status}, not fighting")
        
        if player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        # Check style phase timeout first
        if match.in_style_selection and match.style_phase_expired():
            self.check_style_phase_timeout(db, match_id)
            db.refresh(match)
        
        # Recovery: if both styles locked but still in style_selection (race condition aftermath)
        if match.in_style_selection and match.both_styles_locked():
            self._transition_to_swing_phase(match)
            db.commit()
            db.refresh(match)
        
        # Must be in swing phase (or style reveal which auto-transitions)
        if match.in_style_reveal:
            # Auto-transition to swing phase
            match.start_swing_phase(DUEL_SWING_TIMEOUT_SECONDS)
        
        if not match.in_swinging:
            raise ValueError(f"Not in swing phase (phase: {match.round_phase})")
        
        if not match.can_player_swing(player_id):
            if match.has_player_submitted(player_id):
                raise ValueError("Already submitted this round")
            raise ValueError("No swings remaining")
        
        # Get player stats
        side = match.get_player_side(player_id)
        if side == "challenger":
            my_stats = match.challenger_stats or {}
            opp_stats = match.opponent_stats or {}
            my_style = match.challenger_style
            opp_style = match.opponent_style
        else:
            my_stats = match.opponent_stats or {}
            opp_stats = match.challenger_stats or {}
            my_style = match.opponent_style
            opp_style = match.challenger_style
        
        attack = my_stats.get("attack", 0)
        defense = opp_stats.get("defense", 0)
        leadership = my_stats.get("leadership", 0)
        
        # Calculate hit chance with style modifiers
        base_hit_chance = calculate_duel_hit_chance(attack, defense)
        hit_chance = self._apply_style_hit_modifiers(base_hit_chance, my_style, opp_style)
        
        # Calculate crit rate with style modifier
        crit_mult = self._get_style_crit_multiplier(my_style)
        
        # Roll!
        roll_value = self.rng.random()
        outcome = self._calculate_outcome(roll_value, hit_chance, crit_mult)
        push_amount = calculate_duel_push(leadership, is_critical=(outcome == "critical"))
        
        # Record the swing
        roll_data = match.record_swing(player_id, roll_value, outcome, push_amount)
        
        # Calculate display odds
        miss_pct = int(round((1.0 - hit_chance) * 100))
        crit_pct = int(round(hit_chance * DUEL_CRITICAL_MULTIPLIER * crit_mult * 100))
        hit_pct = 100 - miss_pct - crit_pct
        
        swings_used = match.get_player_swings_used(player_id)
        swings_remaining = match.get_player_swings_remaining(player_id)
        max_swings = match.get_player_max_swings(player_id)
        best_outcome = match.get_player_best_outcome(player_id)
        
        # NO auto-submit - player must always click SUBMIT themselves
        # Even when out of swings, let them see the result and decide
        
        db.commit()
        db.refresh(match)
        
        return {
            "success": True,
            "roll": roll_data,
            "outcome": outcome,
            "swing_number": swings_used,
            "swings_remaining": swings_remaining,
            "max_swings": max_swings,
            "best_outcome": best_outcome,
            "can_swing": swings_remaining > 0,
            "can_stop": swings_used >= 1,  # Can always stop after at least 1 swing
            "auto_submitted": False,
            "round_resolved": False,
            "resolution": None,
            "match": match,
            "miss_chance": miss_pct,
            "hit_chance_pct": hit_pct,
            "crit_chance": crit_pct,
        }
    
    def stop(
        self,
        db: Session,
        match_id: int,
        player_id: int
    ) -> Dict[str, Any]:
        """
        Stop swinging and lock in current best roll.
        
        Player chooses to stop early (after at least 1 swing).
        If both players have stopped, round resolves.
        """
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if not match.is_fighting:
            raise ValueError(f"Match is {match.status}, not fighting")
        
        if player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        if not match.can_player_stop(player_id):
            if match.has_player_submitted(player_id):
                raise ValueError("Already submitted this round")
            if match.get_player_swings_used(player_id) < 1:
                raise ValueError("Must swing at least once before stopping")
            raise ValueError("Cannot stop right now")
        
        print(f"DUEL_DEBUG stop() BEFORE: ch_best={match.challenger_best_outcome!r}, op_best={match.opponent_best_outcome!r}")
        
        # Submit
        match.submit_player(player_id)
        
        best_outcome = match.get_player_best_outcome(player_id)
        both = match.both_submitted()
        
        print(f"DUEL_DEBUG stop() AFTER submit: both={both}, ch_best={match.challenger_best_outcome!r}, op_best={match.opponent_best_outcome!r}")
        
        db.commit()
        db.refresh(match)
        
        print(f"DUEL_DEBUG stop() AFTER REFRESH: ch_best={match.challenger_best_outcome!r}, op_best={match.opponent_best_outcome!r}")
        print(f"DUEL_DEBUG stop() AFTER REFRESH: ch_rolls={match.challenger_round_rolls}")
        print(f"DUEL_DEBUG stop() AFTER REFRESH: op_rolls={match.opponent_round_rolls}")
        
        # DEFENSIVE: If outcomes were lost in refresh (missing DB columns?), recover from rolls
        if match.challenger_best_outcome is None and match.challenger_round_rolls:
            last_roll = match.challenger_round_rolls[-1] if match.challenger_round_rolls else None
            if last_roll:
                match.challenger_best_outcome = last_roll.get("outcome", "miss")
                print(f"DUEL_DEBUG   RECOVERED challenger_best_outcome from rolls: {match.challenger_best_outcome!r}")
        if match.opponent_best_outcome is None and match.opponent_round_rolls:
            last_roll = match.opponent_round_rolls[-1] if match.opponent_round_rolls else None
            if last_roll:
                match.opponent_best_outcome = last_roll.get("outcome", "miss")
                print(f"DUEL_DEBUG   RECOVERED opponent_best_outcome from rolls: {match.opponent_best_outcome!r}")
        
        # Check if round should resolve
        round_resolved = False
        resolution = None
        if match.both_submitted():
            resolution = self._resolve_round(db, match)
            round_resolved = True
        
        return {
            "success": True,
            "submitted": True,
            "best_outcome": best_outcome,
            "waiting_for_opponent": not round_resolved,
            "round_resolved": round_resolved,
            "resolution": resolution,
            "match": match,
        }
    
    # =========================================================================
    # ROUND RESOLUTION
    # =========================================================================
    
    def _resolve_round(self, db: Session, match: DuelMatch) -> Dict[str, Any]:
        """
        Resolve the round after both players have submitted.
        
        Compare best outcomes, apply feint tiebreaker, push bar.
        """
        match.round_phase = DuelPhase.RESOLVING.value
        
        # Get best outcomes
        ch_best = match.challenger_best_outcome or "miss"
        op_best = match.opponent_best_outcome or "miss"
        ch_push = match.challenger_best_push or 0.0
        op_push = match.opponent_best_push or 0.0
        
        # Get styles for multipliers
        ch_style = match.challenger_style or AttackStyle.BALANCED
        op_style = match.opponent_style or AttackStyle.BALANCED
        
        # Compare outcomes
        ch_rank = OUTCOME_RANK.get(ch_best, 0)
        op_rank = OUTCOME_RANK.get(op_best, 0)
        
        # DUEL_DEBUG: Print all values for debugging
        print(f"DUEL_DEBUG _resolve_round match_id={match.id}")
        print(f"DUEL_DEBUG   challenger_id={match.challenger_id}, opponent_id={match.opponent_id}")
        print(f"DUEL_DEBUG   challenger_best_outcome (raw)={match.challenger_best_outcome!r}")
        print(f"DUEL_DEBUG   opponent_best_outcome (raw)={match.opponent_best_outcome!r}")
        print(f"DUEL_DEBUG   ch_best={ch_best!r}, op_best={op_best!r}")
        print(f"DUEL_DEBUG   ch_rank={ch_rank}, op_rank={op_rank}")
        print(f"DUEL_DEBUG   ch_push={ch_push}, op_push={op_push}")
        
        winner_side = None
        push_amount = 0.0
        decisive_outcome = None
        feint_winner = None
        tiebreaker_data = None
        is_parried = False
        
        if ch_rank > op_rank:
            winner_side = "challenger"
            decisive_outcome = ch_best
            push_amount = ch_push
            print(f"DUEL_DEBUG   DECISION: ch_rank({ch_rank}) > op_rank({op_rank}) -> challenger wins")
        elif op_rank > ch_rank:
            winner_side = "opponent"
            decisive_outcome = op_best
            push_amount = op_push
            print(f"DUEL_DEBUG   DECISION: op_rank({op_rank}) > ch_rank({ch_rank}) -> opponent wins")
        else:
            # Tie - check feint
            print(f"DUEL_DEBUG   DECISION: TIE ch_rank={ch_rank} == op_rank={op_rank}, checking feint")
            ch_rolls = match.challenger_round_rolls or []
            op_rolls = match.opponent_round_rolls or []
            feint_winner, tiebreaker_data = self._check_feint_tiebreaker(ch_style, op_style, ch_rolls, op_rolls)
            print(f"DUEL_DEBUG   feint_winner={feint_winner}, tiebreaker_data={tiebreaker_data}, ch_style={ch_style}, op_style={op_style}")
            if feint_winner == "challenger":
                winner_side = "challenger"
                decisive_outcome = ch_best
                push_amount = ch_push
            elif feint_winner == "opponent":
                winner_side = "opponent"
                decisive_outcome = op_best
                push_amount = op_push
            else:
                # True tie - parried, no push
                is_parried = True
                print(f"DUEL_DEBUG   PARRIED - true tie, no feint advantage")
        
        # Apply style push multipliers
        if winner_side and push_amount > 0:
            winner_style = ch_style if winner_side == "challenger" else op_style
            loser_style = op_style if winner_side == "challenger" else ch_style
            
            win_mult, lose_penalty = self._get_style_push_multipliers(winner_style, loser_style)
            push_amount = push_amount * win_mult * lose_penalty
        
        # Apply push
        bar_before = match.control_bar
        match_winner = None
        
        if winner_side and push_amount > 0:
            match_winner = match.apply_push(winner_side, push_amount)
            
            # Record action for history
            winner_id = match.challenger_id if winner_side == "challenger" else match.opponent_id
            action = DuelAction(
                match_id=match.id,
                player_id=winner_id,
                side=winner_side,
                roll_value=0.0,  # Round-based
                outcome=decisive_outcome or "miss",
                push_amount=push_amount,
                bar_before=bar_before,
                bar_after=match.control_bar,
            )
            db.add(action)
        
        # Build resolution data
        # Include explicit challenger_won/opponent_won so iOS doesn't calculate
        resolution = {
            "round_number": match.round_number,
            "challenger_best": ch_best,
            "opponent_best": op_best,
            "challenger_rolls": match.challenger_round_rolls or [],
            "opponent_rolls": match.opponent_round_rolls or [],
            "challenger_style": ch_style,
            "opponent_style": op_style,
            "winner_side": winner_side,
            "decisive_outcome": decisive_outcome,
            "feint_winner": feint_winner,
            "tiebreaker": tiebreaker_data,  # Includes roll values for tiebreaker animation
            "parried": is_parried,
            "push_amount": round(push_amount, 2),
            "bar_before": round(bar_before, 2),
            "bar_after": round(match.control_bar, 2),
            # EXPLICIT booleans - iOS should use these, NOT calculate
            "challenger_won": winner_side == "challenger",
            "opponent_won": winner_side == "opponent",
        }
        
        print(f"DUEL_DEBUG   FINAL RESOLUTION: winner_side={winner_side!r}, parried={is_parried}, push={push_amount}")
        print(f"DUEL_DEBUG   challenger_won={winner_side == 'challenger'}, opponent_won={winner_side == 'opponent'}")
        print(f"DUEL_DEBUG   challenger_best={ch_best!r}, opponent_best={op_best!r}")
        print(f"DUEL_DEBUG   challenger_rolls={match.challenger_round_rolls}")
        print(f"DUEL_DEBUG   opponent_rolls={match.opponent_round_rolls}")
        
        # Check for match winner
        if match_winner:
            self._complete_match(db, match, match_winner)
            resolution["match_winner"] = match_winner
            resolution["game_over"] = True
        else:
            # Advance to next round
            match.advance_round(DUEL_STYLE_LOCK_TIMEOUT_SECONDS)
            resolution["game_over"] = False
        
        db.commit()
        
        return resolution
    
    def _complete_match(self, db: Session, match: DuelMatch, winner_side: str) -> None:
        """Complete the match with a winner."""
        match.resolve(winner_side)
        
        loser_id = match.opponent_id if winner_side == "challenger" else match.challenger_id
        
        # Update stats
        self._update_duel_stats(db, match.winner_id, won=True, gold=match.winner_gold_earned or 0)
        self._update_duel_stats(db, loser_id, won=False, gold=match.wager_gold)
        
        # Award gold
        if match.winner_gold_earned and match.winner_gold_earned > 0:
            winner_state = db.query(PlayerState).filter(PlayerState.user_id == match.winner_id).first()
            if winner_state:
                winner_state.gold += match.winner_gold_earned
    
    def _update_duel_stats(self, db: Session, user_id: int, won: bool, gold: int) -> None:
        """Update players duel statistics."""
        stats = db.query(DuelStats).filter(DuelStats.user_id == user_id).first()
        
        if not stats:
            stats = DuelStats(
                user_id=user_id,
                wins=0, losses=0, draws=0,
                total_gold_won=0, total_gold_lost=0,
                win_streak=0, best_win_streak=0,
            )
            db.add(stats)
            db.flush()
        
        if won:
            stats.record_win(gold)
        else:
            stats.record_loss(gold)
    
    # =========================================================================
    # STYLE MODIFIERS
    # =========================================================================
    
    def _apply_style_hit_modifiers(
        self,
        base_hit_chance: float,
        attacker_style: str,
        defender_style: str
    ) -> float:
        """
        Apply style modifiers to hit chance.
        
        Uses MULTIPLICATIVE modifiers for fairness across all stat levels.
        A 20% penalty costs the same relative amount whether you have 30% or 70% hit.
        """
        atk_mods = get_style_modifiers(attacker_style or AttackStyle.BALANCED)
        def_mods = get_style_modifiers(defender_style or AttackStyle.BALANCED)
        
        # Multiplicative: base * attacker_mult * defender_mult
        modified = base_hit_chance * atk_mods["hit_chance_mult"] * def_mods["opponent_hit_mult"]
        return max(DUEL_MIN_HIT_CHANCE, min(DUEL_MAX_HIT_CHANCE, modified))
    
    def _get_style_crit_multiplier(self, style: str) -> float:
        """Get crit rate multiplier from style."""
        mods = get_style_modifiers(style or AttackStyle.BALANCED)
        return mods["crit_rate_mult"]
    
    def _get_style_push_multipliers(self, winner_style: str, loser_style: str) -> Tuple[float, float]:
        """Get push multipliers (winner_mult, loser_penalty)."""
        winner_mods = get_style_modifiers(winner_style or AttackStyle.BALANCED)
        loser_mods = get_style_modifiers(loser_style or AttackStyle.BALANCED)
        return (winner_mods["push_mult_win"], loser_mods["push_mult_lose"])
    
    def _check_feint_tiebreaker(
        self, 
        ch_style: str, 
        op_style: str,
        ch_rolls: list = None,
        op_rolls: list = None
    ) -> Tuple[Optional[str], Optional[Dict[str, Any]]]:
        """
        Check if feint wins a tie.
        
        Returns: (winning_side, tiebreaker_data)
            - winning_side: "challenger", "opponent", or None
            - tiebreaker_data: dict with roll values for animation, or None if no tiebreaker
        """
        ch_mods = get_style_modifiers(ch_style or AttackStyle.BALANCED)
        op_mods = get_style_modifiers(op_style or AttackStyle.BALANCED)
        
        ch_feint = ch_mods["tie_advantage"]
        op_feint = op_mods["tie_advantage"]
        
        if ch_feint and op_feint:
            # Both have feint - LOWER roll wins (lower is always better in our system)
            # Note: roll["value"] is already 0-100 scale (multiplied in record_swing)
            ch_roll = ch_rolls[-1]["value"] if ch_rolls else 0
            op_roll = op_rolls[-1]["value"] if op_rolls else 0
            print(f"DUEL_DEBUG   Both feint: ch_roll={ch_roll}, op_roll={op_roll}")
            
            # Tiebreaker data for frontend animation (values already 0-100, round to int for display)
            tiebreaker_data = {
                "type": "feint_vs_feint",
                "challenger_roll": round(ch_roll),
                "opponent_roll": round(op_roll),
            }
            
            # LOWER roll wins the tiebreaker
            if ch_roll < op_roll:
                tiebreaker_data["winner"] = "challenger"
                return "challenger", tiebreaker_data
            elif op_roll < ch_roll:
                tiebreaker_data["winner"] = "opponent"
                return "opponent", tiebreaker_data
            # Exact same roll = true tie (rare)
            tiebreaker_data["winner"] = None
            return None, tiebreaker_data
        
        if ch_feint:
            # Challenger has feint, wins the tie
            tiebreaker_data = {
                "type": "feint_wins",
                "feint_side": "challenger",
                "winner": "challenger",
            }
            return "challenger", tiebreaker_data
        
        if op_feint:
            # Opponent has feint, wins the tie
            tiebreaker_data = {
                "type": "feint_wins",
                "feint_side": "opponent",
                "winner": "opponent",
            }
            return "opponent", tiebreaker_data
        
        return None, None
    
    def _calculate_outcome(
        self,
        roll_value: float,
        hit_chance: float,
        crit_mult: float
    ) -> str:
        """Calculate roll outcome."""
        if roll_value > hit_chance:
            return "miss"
        
        crit_threshold = hit_chance * DUEL_CRITICAL_MULTIPLIER * crit_mult
        if roll_value < crit_threshold:
            return "critical"
        return "hit"
    
    # =========================================================================
    # TIMEOUT HANDLING
    # =========================================================================
    
    def claim_swing_timeout(
        self,
        db: Session,
        match_id: int,
        player_id: int
    ) -> DuelMatch:
        """Claim victory due to opponent not finishing swings in time."""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if not match.is_fighting:
            raise ValueError("Match is not in progress")
        
        if player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        # Must have submitted yourself
        if not match.has_player_submitted(player_id):
            raise ValueError("You must submit before claiming timeout")
        
        # Opponent must not have submitted
        opponent_id = match.opponent_id if player_id == match.challenger_id else match.challenger_id
        if match.has_player_submitted(opponent_id):
            raise ValueError("Opponent already submitted")
        
        # Check if swing phase actually expired
        if match.swing_phase_expires_at:
            now = datetime.utcnow()
            exp = match.swing_phase_expires_at.replace(tzinfo=None) if match.swing_phase_expires_at.tzinfo else match.swing_phase_expires_at
            if now < exp:
                remaining = int((exp - now).total_seconds())
                raise ValueError(f"Swing phase hasn't expired ({remaining}s remaining)")
        else:
            raise ValueError("No swing phase timeout set")
        
        # Award victory
        winner_side = "challenger" if player_id == match.challenger_id else "opponent"
        self._complete_match(db, match, winner_side)
        
        db.commit()
        db.refresh(match)
        
        return match
    
    # =========================================================================
    # FORFEIT / CANCEL
    # =========================================================================
    
    def forfeit_match(self, db: Session, match_id: int, player_id: int) -> DuelMatch:
        """Forfeit the match - opponent wins."""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if player_id not in [match.challenger_id, match.opponent_id]:
            raise ValueError("You are not in this match")
        
        if not match.is_fighting:
            raise ValueError("Can only forfeit active matches")
        
        winner_side = "opponent" if player_id == match.challenger_id else "challenger"
        self._complete_match(db, match, winner_side)
        
        db.commit()
        db.refresh(match)
        
        return match
    
    def cancel_match(self, db: Session, match_id: int, player_id: int) -> DuelMatch:
        """Cancel a waiting match."""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        if match.challenger_id != player_id:
            raise ValueError("Only the challenger can cancel")
        
        if match.status != DuelStatus.WAITING.value:
            raise ValueError("Can only cancel waiting matches")
        
        match.cancel()
        db.commit()
        db.refresh(match)
        
        return match
    
    # =========================================================================
    # QUERIES
    # =========================================================================
    
    def get_match(self, db: Session, match_id: int, auto_fix: bool = True) -> Optional[DuelMatch]:
        """Get a match by ID. Optionally auto-fix stuck states."""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        
        # Auto-fix stuck state: both styles locked but still in style_selection
        if auto_fix and match and match.is_fighting and match.in_style_selection and match.both_styles_locked():
            self._transition_to_swing_phase(match)
            db.commit()
            db.refresh(match)
        
        return match
    
    def get_active_match_for_player(self, db: Session, player_id: int) -> Optional[DuelMatch]:
        """Get player's active match."""
        match = db.query(DuelMatch).filter(
            DuelMatch.status.in_([
                DuelStatus.WAITING.value,
                DuelStatus.PENDING_ACCEPTANCE.value,
                DuelStatus.READY.value,
                DuelStatus.FIGHTING.value
            ]),
            (DuelMatch.challenger_id == player_id) | (DuelMatch.opponent_id == player_id)
        ).first()
        
        # Auto-fix stuck state: both styles locked but still in style_selection
        if match and match.is_fighting and match.in_style_selection and match.both_styles_locked():
            self._transition_to_swing_phase(match)
            db.commit()
            db.refresh(match)
        
        return match
    
    def get_player_stats(self, db: Session, user_id: int) -> Optional[DuelStats]:
        """Get player's duel stats."""
        return db.query(DuelStats).filter(DuelStats.user_id == user_id).first()
    
    def get_leaderboard(self, db: Session, limit: int = 10) -> List[Dict]:
        """Get top duelists."""
        stats_list = db.query(DuelStats).order_by(DuelStats.wins.desc()).limit(limit).all()
        
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
        """Get recent completed matches."""
        matches = db.query(DuelMatch).filter(
            DuelMatch.kingdom_id == kingdom_id,
            DuelMatch.status == DuelStatus.COMPLETE.value
        ).order_by(DuelMatch.completed_at.desc()).limit(limit).all()
        
        return [m.to_dict() for m in matches]
    
    # =========================================================================
    # LEGACY COMPATIBILITY
    # =========================================================================
    
    def forfeit_by_timeout(self, db: Session, match_id: int, claiming_player_id: int) -> DuelMatch:
        """Legacy: Claim timeout victory."""
        return self.claim_swing_timeout(db, match_id, claiming_player_id)
    
    def execute_attack(self, db: Session, match_id: int, player_id: int) -> Dict[str, Any]:
        """Legacy: Map to swing()."""
        return self.swing(db, match_id, player_id)
    
    def submit_round_swing(self, db: Session, match_id: int, player_id: int) -> Dict[str, Any]:
        """Legacy: Auto-swing all remaining and stop."""
        match = db.query(DuelMatch).filter(DuelMatch.id == match_id).first()
        if not match:
            raise ValueError("Match not found")
        
        # Swing all remaining
        last_result = None
        while match.can_player_swing(player_id):
            last_result = self.swing(db, match_id, player_id)
            db.refresh(match)
            if last_result.get("round_resolved"):
                break
        
        # If not auto-submitted and can stop, stop
        if not match.has_player_submitted(player_id) and match.can_player_stop(player_id):
            last_result = self.stop(db, match_id, player_id)
        
        return last_result or {"success": False, "message": "Could not submit"}

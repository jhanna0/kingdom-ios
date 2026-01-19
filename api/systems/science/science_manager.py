"""
SCIENCE MANAGER
===============
High/Low guessing game logic.

CRITICAL: Backend PRE-CALCULATES ALL NUMBERS upfront!
Frontend is DUMB - just displays and sends guesses.

FLOW:
1. /start - Pre-generate ALL 4 numbers (start + 3 rounds), store in DB
2. /guess - Player submits HIGH or LOW, backend checks against pre-calc'd number
   - If correct: reveal next number, streak++
   - If wrong: game over, get rewards for current streak
3. /collect - Claim rewards

All game logic is server-side. Frontend calculates NOTHING!
"""

import random
import time
from dataclasses import dataclass, field
from typing import Optional, List

from .config import (
    MIN_NUMBER,
    MAX_NUMBER,
    MAX_GUESSES,
    REWARD_CONFIG,
    BLUEPRINT_CONFIG,
    GOLD_CONFIG,
    calculate_gold_reward,
)


@dataclass
class ScienceRound:
    """Data for a single round/guess - PRE-CALCULATED!"""
    round_num: int
    shown_number: int          # The number shown to player BEFORE guessing
    hidden_number: int         # The next number (pre-calculated, hidden until guess)
    correct_answer: str        # "high" or "low" - what would be correct
    guess: Optional[str] = None  # Player's guess (filled in when they guess)
    is_correct: Optional[bool] = None  # Result (filled in when they guess)
    is_revealed: bool = False  # Has this round been played?
    
    def to_dict(self, hide_answer: bool = True) -> dict:
        """Convert to dict. hide_answer=True hides the pre-calc'd answer."""
        result = {
            "round_num": self.round_num,
            "shown_number": self.shown_number,
            "is_revealed": self.is_revealed,
        }
        
        # Only show these after the round is played
        if self.is_revealed:
            result["hidden_number"] = self.hidden_number
            result["guess"] = self.guess
            result["is_correct"] = self.is_correct
        
        # Never expose correct_answer to frontend (anti-cheat)
        
        return result


@dataclass 
class ScienceSession:
    """
    Science minigame session.
    
    ALL numbers are pre-calculated at session start!
    Stored in DB so Lambda can validate guesses.
    """
    session_id: str
    player_id: int
    science_level: int = 0
    
    # PRE-CALCULATED ROUNDS - generated at start, stored in DB!
    # rounds[0] = first guess, rounds[1] = second guess, rounds[2] = third guess
    rounds: List[ScienceRound] = field(default_factory=list)
    
    # Current game state
    current_round: int = 0     # Which round we're on (0, 1, 2)
    streak: int = 0            # Correct guesses in a row
    is_game_over: bool = False
    is_collected: bool = False
    
    @property
    def current_number(self) -> int:
        """The number currently shown to the player."""
        if self.current_round < len(self.rounds):
            return self.rounds[self.current_round].shown_number
        # After all rounds, show the last hidden number
        if self.rounds:
            return self.rounds[-1].hidden_number
        return 5  # Fallback
    
    @property
    def can_guess(self) -> bool:
        """Can the player make another guess?"""
        return not self.is_game_over and self.current_round < MAX_GUESSES
    
    @property
    def can_collect(self) -> bool:
        """Can the player collect rewards?"""
        return not self.is_collected and self.streak > 0
    
    @property
    def has_won_max(self) -> bool:
        """Did the player hit max streak?"""
        return self.streak >= MAX_GUESSES
    
    def get_potential_rewards(self) -> dict:
        """Get rewards the player would get if they collect now."""
        if self.streak == 0:
            return {"gold": 0, "blueprint": 0, "rewards": []}
        
        gold = calculate_gold_reward(self.streak, self.science_level)
        blueprint = REWARD_CONFIG.get(self.streak, {}).get("blueprint", 0)
        
        rewards = []
        if gold > 0:
            rewards.append({
                "item": "gold",
                "amount": gold,
                "display_name": GOLD_CONFIG["display_name"],
                "icon": GOLD_CONFIG["icon"],
                "color": GOLD_CONFIG["color"],
            })
        if blueprint > 0:
            rewards.append({
                "item": BLUEPRINT_CONFIG["item"],
                "amount": blueprint,
                "display_name": BLUEPRINT_CONFIG["display_name"],
                "icon": BLUEPRINT_CONFIG["icon"],
                "color": BLUEPRINT_CONFIG["color"],
            })
        
        return {
            "gold": gold,
            "blueprint": blueprint,
            "rewards": rewards,
            "message": REWARD_CONFIG.get(self.streak, {}).get("message", ""),
        }
    
    def to_dict(self) -> dict:
        """Convert to dict for API response - HIDES pre-calculated answers!"""
        potential = self.get_potential_rewards()
        
        return {
            "session_id": self.session_id,
            "current_number": self.current_number,
            "current_round": self.current_round,
            "streak": self.streak,
            "max_streak": MAX_GUESSES,
            "is_game_over": self.is_game_over,
            "can_guess": self.can_guess,
            "can_collect": self.can_collect,
            "has_won_max": self.has_won_max,
            "potential_rewards": potential,
            # Only show rounds that have been played (hide future answers!)
            "rounds": [r.to_dict(hide_answer=True) for r in self.rounds if r.is_revealed],
            "min_number": MIN_NUMBER,
            "max_number": MAX_NUMBER,
        }
    
    def to_db_dict(self) -> dict:
        """Convert to dict for DB storage - includes ALL pre-calc'd data!"""
        return {
            "session_id": self.session_id,
            "player_id": self.player_id,
            "science_level": self.science_level,
            "current_round": self.current_round,
            "streak": self.streak,
            "is_game_over": self.is_game_over,
            "is_collected": self.is_collected,
            # Store ALL round data including hidden answers
            "rounds": [
                {
                    "round_num": r.round_num,
                    "shown_number": r.shown_number,
                    "hidden_number": r.hidden_number,
                    "correct_answer": r.correct_answer,
                    "guess": r.guess,
                    "is_correct": r.is_correct,
                    "is_revealed": r.is_revealed,
                }
                for r in self.rounds
            ],
        }
    
    @classmethod
    def from_db_dict(cls, data: dict) -> "ScienceSession":
        """Reconstruct session from DB data."""
        rounds = [
            ScienceRound(
                round_num=r["round_num"],
                shown_number=r["shown_number"],
                hidden_number=r["hidden_number"],
                correct_answer=r["correct_answer"],
                guess=r.get("guess"),
                is_correct=r.get("is_correct"),
                is_revealed=r.get("is_revealed", False),
            )
            for r in data.get("rounds", [])
        ]
        
        return cls(
            session_id=data["session_id"],
            player_id=data["player_id"],
            science_level=data.get("science_level", 0),
            rounds=rounds,
            current_round=data.get("current_round", 0),
            streak=data.get("streak", 0),
            is_game_over=data.get("is_game_over", False),
            is_collected=data.get("is_collected", False),
        )


class ScienceManager:
    """
    Manages science minigame sessions.
    
    CRITICAL: All numbers are pre-calculated at session start!
    Sessions are stored in PostgreSQL so they survive Lambda restarts.
    """
    
    def __init__(self, seed: Optional[int] = None):
        self.rng = random.Random(seed)
    
    def create_session(self, player_id: int, science_level: int = 0) -> ScienceSession:
        """
        Create a new science session with ALL numbers pre-calculated!
        
        Args:
            player_id: The player's ID
            science_level: Player's science skill level
            
        Returns:
            Session with 3 rounds pre-calculated
        """
        session_id = f"science_{player_id}_{int(time.time() * 1000)}"
        
        # PRE-CALCULATE ALL 4 NUMBERS!
        # Start in tight middle range - harder to guess near 50
        numbers = [self.rng.randint(45, 65)]  # Starting number (tight middle)
        
        # Generate 3 more numbers for the 3 rounds
        for _ in range(MAX_GUESSES):
            numbers.append(self.rng.randint(MIN_NUMBER, MAX_NUMBER))
        
        # Create rounds with pre-calculated answers
        rounds = []
        for i in range(MAX_GUESSES):
            shown = numbers[i]
            hidden = numbers[i + 1]
            
            # Determine correct answer
            if hidden > shown:
                correct = "high"
            elif hidden < shown:
                correct = "low"
            else:
                # Tie - loss (neither high nor low is correct)
                correct = "tie"
            
            rounds.append(ScienceRound(
                round_num=i + 1,
                shown_number=shown,
                hidden_number=hidden,
                correct_answer=correct,
            ))
        
        return ScienceSession(
            session_id=session_id,
            player_id=player_id,
            science_level=science_level,
            rounds=rounds,
        )
    
    def make_guess(self, session: ScienceSession, guess: str) -> dict:
        """
        Process a player's guess against pre-calculated answer.
        
        Args:
            session: The current session (loaded from DB)
            guess: "high" or "low"
        
        Returns:
            Result dict - backend tells frontend if correct!
        """
        if not session.can_guess:
            return {
                "success": False,
                "error": "Cannot make guess - game is over or max streak reached",
            }
        
        guess = guess.lower().strip()
        if guess not in ("high", "low"):
            return {
                "success": False,
                "error": "Guess must be 'high' or 'low'",
            }
        
        # Get the current round (pre-calculated!)
        round_data = session.rounds[session.current_round]
        
        # Check against pre-calculated answer
        correct_answer = round_data.correct_answer
        is_correct = (guess == correct_answer)  # "tie" never matches "high" or "low"
        
        # Update the round
        round_data.guess = guess
        round_data.is_correct = is_correct
        round_data.is_revealed = True
        
        # Update session state
        if is_correct:
            session.streak += 1
            session.current_round += 1
            
            # Check for max streak (auto game-over on win)
            if session.streak >= MAX_GUESSES:
                session.is_game_over = True
        else:
            session.is_game_over = True
        
        return {
            "success": True,
            "is_correct": is_correct,
            "guess": guess,
            "shown_number": round_data.shown_number,
            "hidden_number": round_data.hidden_number,  # NOW revealed!
            "correct_answer": correct_answer,  # Tell them what was right
            "streak": session.streak,
            "current_round": session.current_round,
            "is_game_over": session.is_game_over,
            "has_won_max": session.has_won_max,
            "potential_rewards": session.get_potential_rewards(),
            # Next number to show (if game continues)
            "next_number": session.current_number if not session.is_game_over else None,
            "round": round_data.to_dict(hide_answer=False),
        }
    
    def collect_rewards(self, session: ScienceSession) -> dict:
        """
        Collect rewards and end the session.
        """
        if session.is_collected:
            return {
                "success": False,
                "error": "Already collected",
            }
        
        if session.streak == 0:
            return {
                "success": False, 
                "error": "No rewards to collect",
            }
        
        # Mark as collected
        session.is_collected = True
        session.is_game_over = True
        
        rewards = session.get_potential_rewards()
        
        return {
            "success": True,
            "streak": session.streak,
            "gold": rewards["gold"],
            "blueprint": rewards["blueprint"],
            "rewards": rewards["rewards"],
            "message": rewards["message"],
        }


# Singleton
_manager = ScienceManager()


def get_manager() -> ScienceManager:
    return _manager

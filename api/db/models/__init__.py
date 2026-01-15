"""
SQLAlchemy models
"""
from .user import User
from .player_state import PlayerState
from .kingdom import Kingdom, UserKingdom
from .kingdom_building import KingdomBuilding
from .contract import Contract
from .property import Property
from .city_boundary import CityBoundary
from .check_in import CheckInHistory
from .kingdom_intelligence import KingdomIntelligence
# Legacy coup imports - keeping for backward compat during migration
from .coup import CoupEvent, CoupTerritory, CoupBattleAction, CoupInjury, CoupFightSession, CoupParticipant, RollOutcome
from systems.coup.config import (
    SIZE_EXPONENT_BASE, LEADERSHIP_DAMPENING_PER_TIER,
    HIT_MULTIPLIER, INJURE_MULTIPLIER, INJURE_PUSH_MULTIPLIER,
    BATTLE_ACTION_COOLDOWN_MINUTES, INJURY_DURATION_MINUTES,
    TERRITORY_COUPERS, TERRITORY_CROWNS, TERRITORY_THRONE,
    TERRITORY_STARTING_BARS, TERRITORY_DISPLAY_NAMES, TERRITORY_ICONS,
    calculate_roll_chances, calculate_push_per_hit, calculate_max_rolls,
)
from .invasion import InvasionEvent

# NEW: Unified Battle system (replaces CoupEvent + InvasionEvent)
from .battle import (
    Battle, BattleType, BattleParticipant, BattleTerritory,
    BattleAction, BattleInjury, FightSession,
    RollOutcome as BattleRollOutcome,
)
from .kingdom_history import KingdomHistory
from .alliance import Alliance
from .friend import Friend
from .activity_log import PlayerActivityLog
from .market_order import MarketOrder, MarketTransaction, OrderType, OrderStatus
from .kingdom_event import KingdomEvent

# New unified models
from .unified_contract import UnifiedContract, ContractContribution
from .player_item import PlayerItem
from .action_cooldown import ActionCooldown
from .inventory import PlayerInventory
from .item import Item
from .hunt_session import HuntSession
from .hunt_stats import HuntStats
from .trade_offer import TradeOffer, TradeOfferStatus

# PvP Arena Duels
from .duel import DuelMatch, DuelInvitation, DuelAction, DuelStats, DuelStatus, DuelOutcome

__all__ = [
    "User",
    "PlayerState",
    "Kingdom",
    "UserKingdom",
    "KingdomBuilding",
    "Contract",
    "Property",
    "CityBoundary",
    "CheckInHistory",
    "KingdomIntelligence",
    # Legacy coup (keeping for backward compat)
    "CoupEvent",
    "CoupTerritory",
    "CoupBattleAction",
    "CoupInjury",
    "CoupFightSession",
    "CoupParticipant",
    "RollOutcome",
    "SIZE_EXPONENT_BASE",
    "LEADERSHIP_DAMPENING_PER_TIER",
    "HIT_MULTIPLIER",
    "INJURE_MULTIPLIER",
    "INJURE_PUSH_MULTIPLIER",
    "BATTLE_ACTION_COOLDOWN_MINUTES",
    "INJURY_DURATION_MINUTES",
    "TERRITORY_COUPERS",
    "TERRITORY_CROWNS",
    "TERRITORY_THRONE",
    "TERRITORY_STARTING_BARS",
    "TERRITORY_DISPLAY_NAMES",
    "TERRITORY_ICONS",
    "calculate_roll_chances",
    "calculate_push_per_hit",
    "calculate_max_rolls",
    "InvasionEvent",
    # NEW: Unified Battle system
    "Battle",
    "BattleType",
    "BattleParticipant",
    "BattleTerritory",
    "BattleAction",
    "BattleInjury",
    "FightSession",
    "BattleRollOutcome",
    # Other models
    "KingdomHistory",
    "Alliance",
    "Friend",
    "PlayerActivityLog",
    "MarketOrder",
    "MarketTransaction",
    "OrderType",
    "OrderStatus",
    "KingdomEvent",
    # New unified models
    "UnifiedContract",
    "ContractContribution",
    "PlayerItem",
    "ActionCooldown",
    "PlayerInventory",
    "Item",
    "HuntSession",
    "HuntStats",
    # Player Trading
    "TradeOffer",
    "TradeOfferStatus",
    # PvP Arena Duels
    "DuelMatch",
    "DuelInvitation",
    "DuelAction",
    "DuelStats",
    "DuelStatus",
    "DuelOutcome",
]


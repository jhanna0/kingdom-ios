"""
Database package - SQLAlchemy configuration and models
"""
from .base import engine, SessionLocal, Base, get_db, init_db
from .models import (
    User,
    PlayerState,
    Kingdom,
    UserKingdom,
    Contract,
    Property,
    CityBoundary,
    CheckInHistory,
    KingdomIntelligence,
    # Legacy (keeping for backward compat)
    CoupEvent,
    InvasionEvent,
    # NEW: Unified Battle system
    Battle,
    BattleType,
    BattleParticipant,
    BattleTerritory,
    BattleAction,
    BattleInjury,
    FightSession,
    # Other models
    KingdomHistory,
    Alliance,
    PlayerActivityLog,
    MarketOrder,
    MarketTransaction,
    OrderType,
    OrderStatus,
    # New unified models
    UnifiedContract,
    ContractContribution,
    PlayerItem,
    ActionCooldown,
    PlayerInventory,
    Item,
    HuntSession,
)

__all__ = [
    "engine",
    "SessionLocal",
    "Base",
    "get_db",
    "init_db",
    "User",
    "PlayerState",
    "Kingdom",
    "UserKingdom",
    "Contract",
    "Property",
    "CityBoundary",
    "CheckInHistory",
    "KingdomIntelligence",
    # Legacy (keeping for backward compat)
    "CoupEvent",
    "InvasionEvent",
    # NEW: Unified Battle system
    "Battle",
    "BattleType",
    "BattleParticipant",
    "BattleTerritory",
    "BattleAction",
    "BattleInjury",
    "FightSession",
    # Other models
    "KingdomHistory",
    "Alliance",
    "PlayerActivityLog",
    "MarketOrder",
    "MarketTransaction",
    "OrderType",
    "OrderStatus",
    # New unified models
    "UnifiedContract",
    "ContractContribution",
    "PlayerItem",
    "ActionCooldown",
    "PlayerInventory",
    "Item",
    "HuntSession",
]


"""
Pydantic schemas for request/response validation
"""
from .user import (
    PlayerState,
    PlayerStateUpdate,
    SyncRequest,
    SyncResponse,
    Player,
    PlayerCreate,
    PlayerUpdate,
)
from .kingdom import (
    Kingdom,
    KingdomState,
    KingdomUpdate,
)
from .equipment import (
    EquipmentItem,
    PropertyItem,
)
from .contract import (
    ContractCreate,
    ContractResponse,
)
from .common import (
    CheckInRequest,
    CheckInRewards,
    CheckInResponse,
    CityBoundaryResponse,
)

__all__ = [
    # User/Player
    "PlayerState",
    "PlayerStateUpdate",
    "SyncRequest",
    "SyncResponse",
    "Player",
    "PlayerCreate",
    "PlayerUpdate",
    # Kingdom
    "Kingdom",
    "KingdomState",
    "KingdomUpdate",
    # Equipment
    "EquipmentItem",
    "PropertyItem",
    # Contract
    "ContractCreate",
    "ContractResponse",
    # Common
    "CheckInRequest",
    "CheckInRewards",
    "CheckInResponse",
    "CityBoundaryResponse",
]


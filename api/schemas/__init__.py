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
    KingdomData,
)
from .coup import (
    CoupInitiateRequest,
    CoupInitiateResponse,
    CoupJoinRequest,
    CoupJoinResponse,
    CoupEventResponse,
    CoupResolveResponse,
    CoupParticipant,
    ActiveCoupsResponse,
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
    "KingdomData",
    # Coup
    "CoupInitiateRequest",
    "CoupInitiateResponse",
    "CoupJoinRequest",
    "CoupJoinResponse",
    "CoupEventResponse",
    "CoupResolveResponse",
    "CoupParticipant",
    "ActiveCoupsResponse",
]


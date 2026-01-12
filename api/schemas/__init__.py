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
    CityQuickResponse,
    BoundaryResponse,
    KingdomData,
    BuildingData,
    BuildingClickAction,
    BuildingUpgradeCost,
    BuildingTierInfo,
    BUILDING_COLORS,
    AllianceInfo,
    ActiveCoupData,
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
from .invasion import (
    InvasionDeclareRequest,
    InvasionDeclareResponse,
    InvasionJoinRequest,
    InvasionJoinResponse,
    InvasionEventResponse,
    InvasionResolveResponse,
    InvasionParticipant,
    ActiveInvasionsResponse,
)
from .alliance import (
    AllianceProposeRequest,
    AllianceProposeResponse,
    AllianceAcceptResponse,
    AllianceDeclineResponse,
    AllianceResponse,
    AllianceListResponse,
    PendingAlliancesResponse,
)
from .player import (
    PlayerActivity,
    PlayerEquipment,
    PlayerPublicProfile,
    PlayerInKingdom,
    PlayersInKingdomResponse,
    ActivePlayersResponse,
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
    "CityQuickResponse",
    "BoundaryResponse",
    "KingdomData",
    "BuildingData",
    "BuildingClickAction",
    "BuildingUpgradeCost",
    "BuildingTierInfo",
    "BUILDING_COLORS",
    # Coup
    "CoupInitiateRequest",
    "CoupInitiateResponse",
    "CoupJoinRequest",
    "CoupJoinResponse",
    "CoupEventResponse",
    "CoupResolveResponse",
    "CoupParticipant",
    "ActiveCoupsResponse",
    # Invasion
    "InvasionDeclareRequest",
    "InvasionDeclareResponse",
    "InvasionJoinRequest",
    "InvasionJoinResponse",
    "InvasionEventResponse",
    "InvasionResolveResponse",
    "InvasionParticipant",
    "ActiveInvasionsResponse",
    # Alliance
    "AllianceProposeRequest",
    "AllianceProposeResponse",
    "AllianceAcceptResponse",
    "AllianceDeclineResponse",
    "AllianceResponse",
    "AllianceListResponse",
    "PendingAlliancesResponse",
    # Player Discovery
    "PlayerActivity",
    "PlayerEquipment",
    "PlayerPublicProfile",
    "PlayerInKingdom",
    "PlayersInKingdomResponse",
    "ActivePlayersResponse",
]


"""
Empire schemas - Request/Response models for empire management

SERVER-DRIVEN UI: All display metadata comes from backend.
Frontend renders dynamically based on these configs.
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


# ===== UI Configuration Models =====

class StatConfig(BaseModel):
    """Configuration for a stat display item"""
    id: str
    label: str
    icon: str
    color: str
    color_inactive: Optional[str] = None
    format: str = "number"
    suffix: Optional[str] = None


class TreasuryActionConfig(BaseModel):
    """Configuration for a treasury action button"""
    id: str
    label: str
    icon: str
    description: str
    source: str
    target: str
    requires_multiple_kingdoms: bool = False


class TreasuryLocationOption(BaseModel):
    """A FROM/TO option in treasury management - fully populated by backend"""
    id: str  # "personal" or kingdom ID
    type: str  # "personal", "current_kingdom", "other_kingdom"
    label: str
    icon: str
    balance: int


class SectionConfig(BaseModel):
    """Configuration for a UI section"""
    title: str
    icon: str
    color: str
    empty_message: Optional[str] = None


class KingdomActionConfig(BaseModel):
    """Configuration for kingdom card action buttons"""
    id: str
    label: str
    icon: str
    color: str


class EmpireUIConfig(BaseModel):
    """Full UI configuration for empire views - sent from server"""
    # Header
    header_icon: str
    header_icon_color: str
    subtitle_template: str
    
    # Stats
    stats: List[StatConfig]
    
    # Sections
    wars_section: SectionConfig
    wars_attacking_icon: str
    wars_defending_icon: str
    wars_attacking_color: str
    wars_defending_color: str
    
    alliances_section: SectionConfig
    alliances_ally_icon: str
    alliances_days_label: str
    alliances_kingdoms_label: str
    
    kingdoms_section: SectionConfig
    kingdoms_capital_badge: str
    kingdoms_capital_icon: str
    kingdoms_capital_color: str
    
    # Kingdom card
    kingdom_stats: List[StatConfig]
    kingdom_actions: List[KingdomActionConfig]
    
    # Treasury management
    treasury_actions: List[TreasuryActionConfig]
    quick_amounts: List[int]
    quick_max_label: str
    
    # Messages
    no_empire_title: str
    no_empire_subtitle: str
    no_empire_icon: str
    loading_message: str
    error_title: str
    error_retry: str
    transfer_no_kingdoms_message: str


# ===== Nested Data Models =====

class ActiveContractSummary(BaseModel):
    """Summary of an active building contract"""
    id: int
    building_type: str
    building_display_name: str
    building_icon: str
    target_level: int
    actions_completed: int
    actions_required: int
    
    @property
    def progress_percent(self) -> int:
        if self.actions_required <= 0:
            return 100
        return min(100, int((self.actions_completed / self.actions_required) * 100))


class EmpireKingdomSummary(BaseModel):
    """Summary of a kingdom within the empire"""
    id: str
    name: str
    treasury_gold: int
    tax_rate: int  # 0-100
    travel_fee: int
    checked_in_players: int  # Active citizens (hometown residents, last 7 days)
    wall_level: int
    vault_level: int
    is_capital: bool  # True if this is the empire capital (original kingdom)
    ruler_started_at: Optional[datetime] = None
    
    # Active building contract (if any)
    active_contract: Optional[ActiveContractSummary] = None
    
    # Treasury management options - backend decides what's available
    treasury_from_options: List[TreasuryLocationOption] = []
    treasury_to_options: List[TreasuryLocationOption] = []


class ActiveWarSummary(BaseModel):
    """Summary of an active war (invasion)"""
    battle_id: int
    type: str  # "attacking" or "defending"
    target_kingdom_id: str
    target_kingdom_name: str
    attacking_from_kingdom_id: Optional[str] = None
    attacking_from_kingdom_name: Optional[str] = None
    initiator_name: str
    pledge_end_time: datetime
    phase: str  # "pledge" or "battle"
    attacker_count: int
    defender_count: int


class AllianceSummary(BaseModel):
    """Summary of an active alliance"""
    alliance_id: int
    allied_empire_id: str
    allied_empire_name: str
    allied_kingdom_count: int
    expires_at: datetime
    days_remaining: int


# ===== Request Schemas =====

class TransferFundsRequest(BaseModel):
    """Request to transfer funds between kingdoms"""
    source_kingdom_id: str
    target_kingdom_id: str
    amount: int = Field(..., gt=0, description="Amount of gold to transfer (must be positive)")


class TreasuryWithdrawRequest(BaseModel):
    """Request to withdraw gold from kingdom treasury to personal wallet"""
    amount: int = Field(..., gt=0, description="Amount of gold to withdraw (must be positive)")


class TreasuryDepositRequest(BaseModel):
    """Request to deposit personal gold into kingdom treasury"""
    amount: int = Field(..., gt=0, description="Amount of gold to deposit (must be positive)")


# ===== Response Schemas =====

class EmpireOverviewResponse(BaseModel):
    """Full empire overview for the ruler - includes server-driven UI config"""
    # Empire identity
    empire_id: str
    empire_name: str  # Name of capital kingdom
    
    # Aggregated stats
    total_treasury: int  # Sum of all kingdom treasuries
    total_subjects: int  # Sum of all active citizens (hometown residents, last 7 days)
    kingdom_count: int
    
    # Personal
    personal_gold: int  # Player's own gold
    
    # Kingdoms in empire
    kingdoms: List[EmpireKingdomSummary]
    
    # Active conflicts
    active_wars: List[ActiveWarSummary]
    wars_attacking: int
    wars_defending: int
    
    # Alliances
    alliances: List[AllianceSummary]
    alliance_count: int
    
    # SERVER-DRIVEN UI CONFIG - Frontend renders based on this!
    ui_config: EmpireUIConfig


class TransferFundsResponse(BaseModel):
    """Response after transferring funds"""
    success: bool
    message: str
    amount_transferred: int
    source_kingdom_id: str
    source_kingdom_name: str
    source_treasury_remaining: int
    target_kingdom_id: str
    target_kingdom_name: str
    target_treasury_new: int


class TreasuryWithdrawResponse(BaseModel):
    """Response after withdrawing from treasury"""
    success: bool
    message: str
    amount_withdrawn: int
    kingdom_id: str
    kingdom_name: str
    treasury_remaining: int
    personal_gold_new: int


class TreasuryDepositResponse(BaseModel):
    """Response after depositing to treasury"""
    success: bool
    message: str
    amount_deposited: int
    kingdom_id: str
    kingdom_name: str
    treasury_new: int
    personal_gold_remaining: int


# ===== Managed Kingdom (for Empire Management) =====

class BuildingUpgradeCost(BaseModel):
    """Cost to upgrade a building"""
    actions_required: int
    construction_cost: int
    can_afford: bool


class BuildingTierInfo(BaseModel):
    """Info for a single building tier"""
    tier: int
    name: str
    benefit: str
    description: str
    per_action_costs: List[Dict[str, Any]] = []


class BuildingClickAction(BaseModel):
    """Click action for a building"""
    type: str
    resource: Optional[str] = None
    exhausted: bool = False
    exhausted_message: Optional[str] = None
    daily_limit: Optional[int] = None
    gathered_today: Optional[int] = None
    remaining_today: Optional[int] = None


class BuildingCatchupInfo(BaseModel):
    """Catch-up info for players who joined after building was constructed"""
    needs_catchup: bool
    can_use: bool
    actions_required: int
    actions_completed: int
    actions_remaining: int


class BuildingPermitInfo(BaseModel):
    """Permit info for visitors accessing buildings in foreign kingdoms"""
    can_access: bool
    reason: str
    is_hometown: bool
    is_allied: bool
    needs_permit: bool
    has_valid_permit: bool
    permit_expires_at: Optional[str] = None
    permit_minutes_remaining: int
    hometown_has_building: bool
    hometown_building_level: int
    has_active_catchup: bool
    can_buy_permit: bool
    permit_cost: int
    permit_duration_minutes: int


class ManagedKingdomBuilding(BaseModel):
    """Full building data for kingdom management"""
    type: str
    display_name: str
    icon: str
    color: str
    category: str
    description: str
    level: int
    max_level: int
    sort_order: int
    upgrade_cost: Optional[BuildingUpgradeCost] = None
    click_action: Optional[BuildingClickAction] = None
    catchup: Optional[BuildingCatchupInfo] = None
    permit: Optional[BuildingPermitInfo] = None
    tier_name: str
    tier_benefit: str
    all_tiers: List[BuildingTierInfo] = []


class ManagedKingdomResponse(BaseModel):
    """Full kingdom data for empire management - works from anywhere"""
    id: str
    name: str
    ruler_id: int
    ruler_name: str
    treasury_gold: int
    tax_rate: int
    travel_fee: int
    active_citizens: int
    checked_in_players: int
    buildings: List[ManagedKingdomBuilding]
    is_capital: bool

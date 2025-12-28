"""
Building System - Construction and upgrades for towns
"""
from typing import Dict, Set, Optional
from datetime import datetime, timedelta
from enum import Enum


class BuildingType(Enum):
    """Available building types"""
    WALLS = "walls"
    VAULT = "vault"


class BuildingDefinition:
    """Definition of a building type with costs and benefits"""
    
    def __init__(self, building_type: BuildingType, name: str, description: str,
                 base_cost: int, base_time_hours: float, max_level: int = 5):
        self.type = building_type
        self.name = name
        self.description = description
        self.base_cost = base_cost
        self.base_time_hours = base_time_hours
        self.max_level = max_level
    
    def get_cost(self, level: int) -> int:
        """Cost scales exponentially"""
        return int(self.base_cost * (1.5 ** (level - 1)))
    
    def get_build_time_hours(self, level: int) -> float:
        """Build time scales with level"""
        return self.base_time_hours * (1.3 ** (level - 1))
    
    def get_benefit_description(self, level: int) -> str:
        """Description of what this level provides"""
        if self.type == BuildingType.WALLS:
            defenders = level * 2
            return f"Adds {defenders} defenders to coup calculations"
        elif self.type == BuildingType.VAULT:
            protection = level * 20
            return f"Protects {protection}% of treasury from looting"
        return "Unknown benefit"


class Building:
    """An actual building in a town"""
    
    def __init__(self, building_type: BuildingType, definition: BuildingDefinition):
        self.type = building_type
        self.definition = definition
        self.level = 0  # 0 = not built yet
        self.built_time: Optional[datetime] = None
    
    def is_built(self) -> bool:
        return self.level > 0
    
    def can_upgrade(self) -> bool:
        return self.level < self.definition.max_level
    
    def upgrade(self):
        """Upgrade to next level"""
        if self.can_upgrade():
            self.level += 1
            self.built_time = datetime.now()


class ConstructionContract:
    """A contract for building construction - EVE style"""
    
    def __init__(self, building_type: BuildingType, target_level: int, 
                 build_cost: int, worker_payment: int, base_hours: float, 
                 contractor_id: str, town_name: str):
        self.building_type = building_type
        self.target_level = target_level
        self.build_cost = build_cost  # Cost of materials
        self.worker_payment = worker_payment  # Payment to workers (held in escrow)
        self.base_hours = base_hours
        self.contractor_id = contractor_id  # Who posted the contract
        self.town_name = town_name
        
        self.start_time = datetime.now()
        self.workers: Set[str] = set()  # Player IDs working on this (NOT including contractor)
        self.completed = False
        self.cancelled = False
        self.payment_distributed = False
    
    def add_worker(self, player_id: str):
        """Accept the contract and start working"""
        if player_id != self.contractor_id:  # Contractor doesn't work on it
            self.workers.add(player_id)
    
    def remove_worker(self, player_id: str):
        """Stop working on the contract"""
        self.workers.discard(player_id)
    
    def get_worker_count(self) -> int:
        """Number of workers (not including contractor)"""
        return len(self.workers)
    
    def get_payment_per_worker(self) -> int:
        """Calculate payment each worker gets"""
        if self.get_worker_count() == 0:
            return 0
        return self.worker_payment // self.get_worker_count()
    
    def calculate_completion_time(self) -> Optional[datetime]:
        """
        Calculate when construction will finish based on number of workers
        More workers = faster construction (diminishing returns)
        Returns None if no workers have accepted the contract
        """
        worker_count = self.get_worker_count()
        
        if worker_count == 0:
            return None  # No workers = never completes
        
        # Diminishing returns formula: time / (1 + log2(workers))
        # 1 worker = 100% time
        # 2 workers = 50% time
        # 4 workers = 33% time
        # 8 workers = 25% time
        import math
        time_multiplier = 1.0 / (1 + math.log2(worker_count))
        
        actual_hours = self.base_hours * time_multiplier
        return self.start_time + timedelta(hours=actual_hours)
    
    def is_complete(self) -> bool:
        """Check if construction is finished"""
        if self.completed or self.cancelled:
            return self.completed
        
        completion_time = self.calculate_completion_time()
        if completion_time is None:
            return False  # No workers, can't complete
        
        if datetime.now() >= completion_time:
            self.completed = True
        
        return self.completed
    
    def get_progress_percent(self) -> float:
        """Get construction progress as percentage"""
        if self.completed:
            return 100.0
        if self.cancelled:
            return 0.0
        
        completion_time = self.calculate_completion_time()
        if completion_time is None:
            return 0.0  # No workers = no progress
        
        total_duration = (completion_time - self.start_time).total_seconds()
        elapsed = (datetime.now() - self.start_time).total_seconds()
        
        if total_duration <= 0:
            return 100.0
        
        return min(100.0, (elapsed / total_duration) * 100)
    
    def get_time_remaining(self) -> Optional[timedelta]:
        """Get time remaining until completion (None if no workers)"""
        if self.completed:
            return timedelta(0)
        
        completion_time = self.calculate_completion_time()
        if completion_time is None:
            return None  # No workers = infinite time
        
        remaining = completion_time - datetime.now()
        
        return max(timedelta(0), remaining)


# Building definitions
BUILDING_DEFS = {
    BuildingType.WALLS: BuildingDefinition(
        BuildingType.WALLS,
        "Walls",
        "Fortifications that add defenders to your side during coups",
        base_cost=200,
        base_time_hours=2.0,
        max_level=5
    ),
    BuildingType.VAULT: BuildingDefinition(
        BuildingType.VAULT,
        "Vault",
        "Protect your treasury from being fully looted",
        base_cost=250,
        base_time_hours=2.5,
        max_level=5
    ),
}


def get_building_definition(building_type: BuildingType) -> BuildingDefinition:
    """Get the definition for a building type"""
    return BUILDING_DEFS[building_type]


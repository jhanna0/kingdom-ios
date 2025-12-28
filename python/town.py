"""
Simplified Town class - focus on social spaces, not economics
"""
from typing import Dict, List, Set, Optional
from datetime import datetime, timedelta
from buildings import Building, ConstructionContract, BuildingType, get_building_definition


class Room:
    """A room/location within a town where players gather"""
    
    def __init__(self, name: str, description: str = ""):
        self.name = name
        self.description = description
        self.players: Set[str] = set()  # Set of player_ids currently here
        self.messages: List[Dict] = []  # Chat history
        
    def add_player(self, player_id: str):
        """Add a player to this room"""
        self.players.add(player_id)
        
    def remove_player(self, player_id: str):
        """Remove a player from this room"""
        self.players.discard(player_id)
        
    def add_message(self, player_name: str, message: str):
        """Add a chat message to this room"""
        self.messages.append({
            'player': player_name,
            'message': message,
            'timestamp': datetime.now()
        })


class Town:
    """A physical location that can be ruled"""
    
    def __init__(self, name: str, latitude: float = None, longitude: float = None):
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        
        # Ruler
        self.ruler_id: Optional[str] = None
        
        # People present (checked in)
        self.population: Set[str] = set()  # player_ids currently checked in
        
        # Social spaces
        self.rooms: Dict[str, Room] = {}
        self._create_default_rooms()
        
        # Events log (public feed)
        self.public_events: List[Dict] = []
        
        # Simple economy
        self.treasury = 1000  # Gold available for the taking (coup reward)
        
        # Buildings
        self.buildings: Dict[BuildingType, Building] = {}
        self._initialize_buildings()
        self.active_contract: Optional[ConstructionContract] = None
        
        # Feudal relationships
        self.liege_lord_id = None  # If this town is a vassal to another ruler
        
        # Metadata
        self.founded_date = datetime.now()
        self.founder_id = None
        
    def _create_default_rooms(self):
        """Create the default rooms where players can gather"""
        default_rooms = [
            ("town_square", "The central meeting place where all gather"),
            ("tavern", "A rowdy place for drinks and conspiracies"),
            ("throne_room", "The seat of power, where the ruler holds court"),
            ("dungeon", "A dark place where the condemned await their fate"),
        ]
        
        for room_name, description in default_rooms:
            self.rooms[room_name] = Room(room_name, description)
    
    def _initialize_buildings(self):
        """Initialize all building types (unbuilt)"""
        for building_type in BuildingType:
            definition = get_building_definition(building_type)
            self.buildings[building_type] = Building(building_type, definition)
    
    def add_player(self, player_id: str, room: str = "town_square"):
        """Player checks into this town"""
        self.population.add(player_id)
        if room in self.rooms:
            self.rooms[room].add_player(player_id)
    
    def remove_player(self, player_id: str):
        """Player leaves this town"""
        self.population.discard(player_id)
        # Remove from all rooms
        for room in self.rooms.values():
            room.remove_player(player_id)
    
    def set_ruler(self, player_id: str, player_name: str, reason: str = "coup"):
        """Set a new ruler"""
        old_ruler = self.ruler_id
        self.ruler_id = player_id
        
        # Broadcast the event
        self.broadcast_event({
            'type': 'ruler_change',
            'new_ruler_id': player_id,
            'new_ruler_name': player_name,
            'old_ruler_id': old_ruler,
            'reason': reason,
            'timestamp': datetime.now()
        })
    
    def broadcast_event(self, event: Dict):
        """Add an event to the public feed"""
        self.public_events.append(event)
    
    def broadcast_execution(self, victim_name: str, reason: str):
        """Announce an execution"""
        self.broadcast_event({
            'type': 'execution',
            'victim': victim_name,
            'reason': reason,
            'timestamp': datetime.now()
        })
    
    def broadcast_decree(self, ruler_name: str, decree: str):
        """Ruler makes a public announcement"""
        self.broadcast_event({
            'type': 'decree',
            'ruler': ruler_name,
            'message': decree,
            'timestamp': datetime.now()
        })
    
    def get_room(self, room_name: str) -> Optional[Room]:
        """Get a room by name"""
        return self.rooms.get(room_name)
    
    def get_recent_events(self, limit: int = 10) -> List[Dict]:
        """Get the most recent public events"""
        return self.public_events[-limit:]
    
    def get_checked_in_players(self) -> Set[str]:
        """Get all players currently checked in to this town"""
        return self.population.copy()
    
    def get_building(self, building_type: BuildingType) -> Optional[Building]:
        """Get a building by type"""
        return self.buildings.get(building_type)
    
    def get_building_level(self, building_type: BuildingType) -> int:
        """Get the current level of a building (0 = not built)"""
        building = self.buildings.get(building_type)
        return building.level if building else 0
    
    def post_contract(self, contract: ConstructionContract):
        """Post a construction contract"""
        self.active_contract = contract
        self.broadcast_event({
            'type': 'contract_posted',
            'building': contract.building_type.value,
            'level': contract.target_level,
            'contractor': contract.contractor_id,
            'payment': contract.worker_payment,
            'timestamp': datetime.now()
        })
    
    def complete_contract(self) -> Dict[str, int]:
        """
        Complete the active contract and return payment distribution
        Returns dict of {player_id: payment_amount}
        """
        if not self.active_contract or not self.active_contract.is_complete():
            return {}
        
        building_type = self.active_contract.building_type
        target_level = self.active_contract.target_level
        
        building = self.buildings[building_type]
        building.level = target_level
        building.built_time = datetime.now()
        
        # Calculate payments
        payment_per_worker = self.active_contract.get_payment_per_worker()
        payments = {worker_id: payment_per_worker for worker_id in self.active_contract.workers}
        
        self.broadcast_event({
            'type': 'contract_completed',
            'building': building_type.value,
            'level': target_level,
            'workers': len(self.active_contract.workers),
            'payment_per_worker': payment_per_worker,
            'timestamp': datetime.now()
        })
        
        self.active_contract = None
        
        return payments
    
    def get_wall_defenders(self) -> int:
        """Get number of virtual defenders from walls"""
        walls_level = self.get_building_level(BuildingType.WALLS)
        # Each wall level adds 2 virtual defenders
        return walls_level * 2
    
    def get_vault_protection(self) -> float:
        """Get % of treasury protected from looting"""
        vault_level = self.get_building_level(BuildingType.VAULT)
        return min(0.80, vault_level * 0.20)  # Max 80% protection
    
    def __repr__(self):
        ruler_status = f"Ruler: {self.ruler_id}" if self.ruler_id else "No Ruler"
        return f"Town({self.name}, {ruler_status}, {len(self.population)} present)"

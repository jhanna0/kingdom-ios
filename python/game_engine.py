"""
Simplified Game Engine - focus on live social interactions, not automation
"""
from typing import Dict, List, Optional, Tuple, Set
from datetime import datetime, timedelta
import random
import math

from player import Player
from town import Town
from buildings import BuildingType, ConstructionContract, get_building_definition


class CoupConspiracy:
    """A SECRET coup conspiracy - players plotting to overthrow a ruler"""
    
    def __init__(self, leader_id: str, town_name: str):
        self.leader_id = leader_id
        self.town_name = town_name
        self.initiated_time = datetime.now()
        self.conspirators: Set[str] = {leader_id}  # Player IDs in the conspiracy
        self.invited: Set[str] = set()  # Invited but not responded
        self.executed = False
        self.discovered = False
        
    def invite_player(self, player_id: str):
        """Invite a player to join"""
        if player_id not in self.conspirators:
            self.invited.add(player_id)
    
    def accept_invitation(self, player_id: str):
        """Player joins the conspiracy"""
        if player_id in self.invited:
            self.invited.remove(player_id)
            self.conspirators.add(player_id)
    
    def reject_invitation(self, player_id: str):
        """Player rejects (might snitch!)"""
        if player_id in self.invited:
            self.invited.remove(player_id)
    
    def get_size(self) -> int:
        return len(self.conspirators)
    
    def is_member(self, player_id: str) -> bool:
        return player_id in self.conspirators


class GameEngine:
    """Core game mechanics - simplified for social gameplay"""
    
    def __init__(self):
        self.players: Dict[str, Player] = {}
        self.towns: Dict[str, Town] = {}
        self.active_conspiracies: Dict[str, CoupConspiracy] = {}  # town_name -> conspiracy
        
        # Game settings
        self.checkin_valid_hours = 4  # Check-ins expire after 4 hours
        self.checkin_radius_meters = 100  # Must be within 100m to check in
        self.coup_initiation_cost = 50
        self.coup_cooldown_hours = 24
        self.min_conspirators = 2  # Need at least 2 people total
        
    # ===== PLAYER & TOWN MANAGEMENT =====
    
    def create_player(self, player_id: str, name: str) -> Player:
        """Create a new player"""
        if player_id in self.players:
            raise ValueError(f"Player {player_id} already exists")
        player = Player(player_id, name)
        self.players[player_id] = player
        return player
    
    def create_town(self, name: str, latitude: float, longitude: float) -> Town:
        """Create a new town at a GPS location"""
        if name in self.towns:
            raise ValueError(f"Town {name} already exists")
        town = Town(name, latitude, longitude)
        self.towns[name] = town
        return town
    
    # ===== CHECK-IN SYSTEM (CORE GEO MECHANIC) =====
    
    def check_in(self, player_id: str, town_name: str, lat: float, lon: float) -> Tuple[bool, str]:
        """
        Player checks in to a town (MUST be physically present)
        This is the ONLY way to enter a town
        """
        player = self.players.get(player_id)
        town = self.towns.get(town_name)
        
        if not player or not town:
            return False, "Player or town not found"
        
        if not player.is_alive:
            return False, "Dead players cannot check in"
        
        # Verify GPS proximity
        if town.latitude and town.longitude:
            distance = self._calculate_distance(lat, lon, town.latitude, town.longitude)
            if distance * 1000 > self.checkin_radius_meters:  # Convert km to meters
                return False, f"Too far away (must be within {self.checkin_radius_meters}m)"
        
        # Remove from old town
        if player.current_town and player.current_town in self.towns:
            old_town = self.towns[player.current_town]
            old_town.remove_player(player_id)
        
        # Check in to new town
        player.check_in(town_name, lat, lon)
        town.add_player(player_id)
        
        return True, f"{player.name} checked in to {town_name}"
    
    def _calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Calculate distance between GPS coordinates in kilometers (Haversine)"""
        R = 6371.0  # Earth radius in km
        
        lat1_rad = math.radians(lat1)
        lon1_rad = math.radians(lon1)
        lat2_rad = math.radians(lat2)
        lon2_rad = math.radians(lon2)
        
        dlat = lat2_rad - lat1_rad
        dlon = lon2_rad - lon1_rad
        
        a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        
        return R * c
    
    # ===== ROOM & CHAT SYSTEM =====
    
    def move_to_room(self, player_id: str, room_name: str) -> Tuple[bool, str]:
        """Move to a different room in current town"""
        player = self.players.get(player_id)
        
        if not player or not player.is_alive:
            return False, "Cannot move"
        
        if not player.current_town:
            return False, "Not checked in anywhere"
        
        town = self.towns[player.current_town]
        if room_name not in town.rooms:
            return False, f"Room {room_name} not found"
        
        # Remove from old room
        if player.current_room:
            old_room = town.get_room(player.current_room)
            if old_room:
                old_room.remove_player(player_id)
        
        # Add to new room
        new_room = town.get_room(room_name)
        new_room.add_player(player_id)
        player.move_to_room(room_name)
        
        return True, f"Moved to {room_name}"
    
    def chat_in_room(self, player_id: str, message: str) -> Tuple[bool, str, List[str]]:
        """
        Send a message in current room
        Returns (success, message, list of player_ids who saw it)
        """
        player = self.players.get(player_id)
        
        if not player or not player.is_alive:
            return False, "Cannot chat", []
        
        if not player.current_town or not player.current_room:
            return False, "Not in a room", []
        
        town = self.towns[player.current_town]
        room = town.get_room(player.current_room)
        
        if not room:
            return False, "Room not found", []
        
        room.add_message(player.name, message)
        
        return True, "Message sent", list(room.players)
    
    # ===== COUP SYSTEM (LIVE COORDINATION REQUIRED) =====
    
    def initiate_coup(self, player_id: str) -> Tuple[bool, str]:
        """
        Start a SECRET coup conspiracy
        Must be checked in to the town
        """
        player = self.players.get(player_id)
        
        if not player or not player.is_alive:
            return False, "Cannot initiate coup"
        
        if not player.is_checked_in(self.checkin_valid_hours):
            return False, "Must be checked in to initiate coup"
        
        town_name = player.current_town
        town = self.towns.get(town_name)
        
        if not town:
            return False, "Town not found"
        
        # If no ruler, just seize power
        if not town.ruler_id:
            town.set_ruler(player_id, player.name, "seized vacant throne")
            player.add_fief(town_name)
            town.treasury = max(0, town.treasury // 2)  # Take half the treasury
            player.gold += town.treasury
            return True, f"Seized power in {town_name}! Looted {town.treasury} gold!"
        
        if town.ruler_id == player_id:
            return False, "You're already the ruler"
        
        if town_name in self.active_conspiracies:
            return False, "There's already an active conspiracy here"
        
        if not player.can_attempt_coup(self.coup_cooldown_hours):
            return False, f"Coup cooldown active ({self.coup_cooldown_hours}h)"
        
        if player.gold < self.coup_initiation_cost:
            return False, f"Need {self.coup_initiation_cost} gold to initiate coup"
        
        # Start conspiracy
        player.gold -= self.coup_initiation_cost
        player.last_coup_attempt = datetime.now()
        
        conspiracy = CoupConspiracy(player_id, town_name)
        self.active_conspiracies[town_name] = conspiracy
        
        return True, f"Secret coup initiated. Invite others before executing!"
    
    def invite_to_coup(self, inviter_id: str, target_id: str) -> Tuple[bool, str]:
        """Invite another player to join your conspiracy"""
        inviter = self.players.get(inviter_id)
        target = self.players.get(target_id)
        
        if not inviter or not target:
            return False, "Player not found"
        
        if not inviter.is_alive or not target.is_alive:
            return False, "Dead players cannot conspire"
        
        if inviter.current_town != target.current_town:
            return False, "Must be in same town"
        
        town_name = inviter.current_town
        if town_name not in self.active_conspiracies:
            return False, "No active conspiracy"
        
        conspiracy = self.active_conspiracies[town_name]
        
        if not conspiracy.is_member(inviter_id):
            return False, "You're not part of the conspiracy"
        
        if target_id in conspiracy.conspirators:
            return False, "Already a conspirator"
        
        if target_id in conspiracy.invited:
            return False, "Already invited"
        
        town = self.towns[town_name]
        if target_id == town.ruler_id:
            return False, "Cannot invite the ruler to a coup against themselves!"
        
        conspiracy.invite_player(target_id)
        
        return True, f"Invited {target.name} to the conspiracy"
    
    def respond_to_coup_invitation(self, player_id: str, accept: bool, snitch: bool = False) -> Tuple[bool, str]:
        """Accept or reject a coup invitation (and optionally snitch)"""
        player = self.players.get(player_id)
        
        if not player or not player.is_alive:
            return False, "Cannot respond"
        
        town_name = player.current_town
        if not town_name or town_name not in self.active_conspiracies:
            return False, "No active conspiracy"
        
        conspiracy = self.active_conspiracies[town_name]
        
        if player_id not in conspiracy.invited:
            return False, "You haven't been invited"
        
        town = self.towns[town_name]
        
        if accept:
            conspiracy.accept_invitation(player_id)
            return True, f"Joined the conspiracy! ({conspiracy.get_size()} conspirators)"
        else:
            conspiracy.reject_invitation(player_id)
            
            # PLAYER chooses to snitch or not
            if snitch:
                conspiracy.discovered = True
                player.record_betrayal()
                
                leader = self.players[conspiracy.leader_id]
                town.broadcast_event({
                    'type': 'conspiracy_discovered',
                    'informant': player.name,
                    'leader': leader.name,
                    'timestamp': datetime.now()
                })
                
                return True, f"You rejected and SNITCHED! The conspiracy is exposed!"
            else:
                return True, "You rejected the invitation and kept quiet"
    
    def execute_coup(self, player_id: str) -> Tuple[bool, str]:
        """
        Execute the coup - ALL conspirators must be checked in!
        LIVE coordination required
        """
        player = self.players.get(player_id)
        
        if not player or not player.is_alive:
            return False, "Cannot execute coup"
        
        town_name = player.current_town
        if not town_name or town_name not in self.active_conspiracies:
            return False, "No active conspiracy"
        
        conspiracy = self.active_conspiracies[town_name]
        town = self.towns[town_name]
        
        if conspiracy.leader_id != player_id:
            return False, "Only the conspiracy leader can execute"
        
        if conspiracy.executed:
            return False, "Already executed"
        
        if conspiracy.discovered:
            return False, "Conspiracy was discovered - too late!"
        
        # CRITICAL: All conspirators must be checked in RIGHT NOW
        checked_in_conspirators = []
        for c_id in conspiracy.conspirators:
            conspirator = self.players[c_id]
            if conspirator.is_checked_in(self.checkin_valid_hours) and conspirator.current_town == town_name:
                checked_in_conspirators.append(c_id)
        
        if len(checked_in_conspirators) < self.min_conspirators:
            return False, f"Need {self.min_conspirators} conspirators PRESENT. Only {len(checked_in_conspirators)} checked in!"
        
        conspiracy.executed = True
        
        # Get all checked-in players (potential supporters/defenders)
        checked_in_population = [p for p in self.players.values()
                                if p.is_checked_in(self.checkin_valid_hours) 
                                and p.current_town == town_name 
                                and p.is_alive]
        
        total_present = len(checked_in_population)
        conspirator_count = len(checked_in_conspirators)
        
        # Add wall defenders to defender side
        wall_defenders = town.get_wall_defenders()
        defender_count = (total_present - conspirator_count) + wall_defenders
        
        # Success: need more conspirators than defenders (including walls)
        success = conspirator_count > defender_count
        
        if success:
            # Coup succeeds!
            old_ruler = self.players.get(town.ruler_id)
            if old_ruler:
                old_ruler.remove_fief(town_name)
            
            town.set_ruler(player_id, player.name, f"coup with {conspirator_count} conspirators")
            player.add_fief(town_name)
            player.record_coup_won()
            
            # Loot the treasury (vault protects some of it)
            vault_protection = town.get_vault_protection()
            lootable = int(town.treasury * (1.0 - vault_protection))
            protected = town.treasury - lootable
            
            player.gold += lootable
            town.treasury = protected
            
            del self.active_conspiracies[town_name]
            
            vault_msg = f" (vault protected {protected} gold)" if protected > 0 else ""
            return True, f"🎉 COUP SUCCESS! {player.name} seized power! Looted {lootable} gold{vault_msg}!"
        else:
            # Coup fails!
            town.broadcast_event({
                'type': 'coup_failed',
                'leader': player.name,
                'conspirators': conspirator_count,
                'timestamp': datetime.now()
            })
            
            player.record_coup_failed()
            del self.active_conspiracies[town_name]
            
            return False, f"💀 COUP FAILED! All {conspirator_count} conspirators exposed!"
    
    # ===== RULER POWERS =====
    
    def execute_player(self, ruler_id: str, target_id: str, reason: str = "treason") -> Tuple[bool, str]:
        """Ruler executes a player (PERMANENT DEATH)"""
        ruler = self.players.get(ruler_id)
        target = self.players.get(target_id)
        
        if not ruler or not target:
            return False, "Player not found"
        
        if not ruler.is_alive or not target.is_alive:
            return False, "Invalid execution"
        
        if ruler.current_town != target.current_town:
            return False, "Must be in same town"
        
        town = self.towns[ruler.current_town]
        
        if town.ruler_id != ruler_id:
            return False, "Only the ruler can execute"
        
        # Execute
        target.execute()
        ruler.record_execution_ordered()
        town.broadcast_execution(target.name, reason)
        
        # If target was a ruler, handle succession
        for fief_name in list(target.fiefs_ruled):
            self._handle_succession(target_id, fief_name)
        
        return True, f"{ruler.name} executed {target.name} for {reason}"
    
    def make_decree(self, ruler_id: str, decree: str) -> Tuple[bool, str]:
        """Ruler makes a public announcement"""
        ruler = self.players.get(ruler_id)
        
        if not ruler or not ruler.is_alive:
            return False, "Cannot make decree"
        
        if not ruler.current_town:
            return False, "Must be in a town"
        
        town = self.towns[ruler.current_town]
        
        if town.ruler_id != ruler_id:
            return False, "Only the ruler can make decrees"
        
        town.broadcast_decree(ruler.name, decree)
        return True, f"Decree issued: {decree}"
    
    def demand_payment(self, ruler_id: str, target_id: str, amount: int, reason: str = "") -> Tuple[bool, str]:
        """
        Ruler demands payment from a subject (manual taxation/tribute)
        Target chooses: pay, refuse (risk execution), or flee
        """
        ruler = self.players.get(ruler_id)
        target = self.players.get(target_id)
        
        if not ruler or not target:
            return False, "Player not found"
        
        town = self.towns[ruler.current_town]
        if town.ruler_id != ruler_id:
            return False, "Only the ruler can demand payment"
        
        if target.current_town != ruler.current_town:
            return False, "Target must be in your town"
        
        if amount <= 0:
            return False, "Invalid amount"
        
        # This creates a demand - target responds with pay_demand()
        town.broadcast_event({
            'type': 'payment_demanded',
            'ruler': ruler.name,
            'target': target.name,
            'amount': amount,
            'reason': reason,
            'timestamp': datetime.now()
        })
        
        return True, f"Demanded {amount} gold from {target.name}"
    
    def transfer_gold(self, from_id: str, to_id: str, amount: int, reason: str = "") -> Tuple[bool, str]:
        """Transfer gold between players (payments, bribes, gifts)"""
        from_player = self.players.get(from_id)
        to_player = self.players.get(to_id)
        
        if not from_player or not to_player:
            return False, "Player not found"
        
        if not from_player.is_alive or not to_player.is_alive:
            return False, "Dead players cannot transfer gold"
        
        if from_player.gold < amount:
            return False, f"Insufficient gold (have {from_player.gold})"
        
        if amount <= 0:
            return False, "Invalid amount"
        
        from_player.gold -= amount
        to_player.gold += amount
        
        reason_str = f" ({reason})" if reason else ""
        return True, f"Transferred {amount} gold to {to_player.name}{reason_str}"
    
    # ===== BUILDING SYSTEM =====
    
    def post_construction_contract(self, player_id: str, building_type: BuildingType, 
                                   worker_payment: int) -> Tuple[bool, str]:
        """
        Post a contract for building construction (EVE style)
        Ruler pays materials cost + worker payment upfront (held in escrow)
        Workers accept and complete it, then get paid
        """
        player = self.players.get(player_id)
        
        if not player or not player.is_alive:
            return False, "Cannot post contract"
        
        if not player.current_town:
            return False, "Must be in a town"
        
        town = self.towns[player.current_town]
        
        if town.ruler_id != player_id:
            return False, "Only the ruler can post construction contracts"
        
        if town.active_contract:
            return False, f"Already have active contract for {town.active_contract.building_type.value}"
        
        # Check if building exists and can be upgraded
        building = town.get_building(building_type)
        if not building:
            return False, "Building type not found"
        
        if not building.can_upgrade():
            return False, f"{building.definition.name} already at max level"
        
        target_level = building.level + 1
        definition = building.definition
        materials_cost = definition.get_cost(target_level)
        build_time = definition.get_build_time_hours(target_level)
        
        total_cost = materials_cost + worker_payment
        
        if player.gold < total_cost:
            return False, f"Need {total_cost} gold (materials: {materials_cost}, workers: {worker_payment}). Have: {player.gold}"
        
        if worker_payment <= 0:
            return False, "Worker payment must be > 0"
        
        # Deduct total cost (held in escrow)
        player.gold -= total_cost
        
        contract = ConstructionContract(
            building_type, target_level, materials_cost, worker_payment, build_time,
            player_id, town.name
        )
        
        town.post_contract(contract)
        
        return True, f"Contract posted: {building.definition.name} lvl {target_level}. Payment: {worker_payment}g to workers. Base time: {build_time:.1f}h"
    
    def accept_construction_contract(self, player_id: str) -> Tuple[bool, str]:
        """Accept a construction contract and start working on it"""
        player = self.players.get(player_id)
        
        if not player or not player.is_alive:
            return False, "Cannot accept contract"
        
        if not player.current_town:
            return False, "Must be in a town"
        
        town = self.towns[player.current_town]
        
        if not town.active_contract:
            return False, "No active contract"
        
        if town.active_contract.completed:
            return False, "Contract already complete"
        
        if player_id == town.active_contract.contractor_id:
            return False, "Cannot work on your own contract"
        
        if player_id in town.active_contract.workers:
            return False, "Already working on this contract"
        
        town.active_contract.add_worker(player_id)
        
        time_remaining = town.active_contract.get_time_remaining()
        if time_remaining:
            hours = time_remaining.total_seconds() / 3600
            time_str = f"Time remaining: {hours:.1f}h"
        else:
            time_str = "Waiting for workers"
        
        payment_per_worker = town.active_contract.get_payment_per_worker()
        
        return True, f"Contract accepted! ({town.active_contract.get_worker_count()} workers). Payment: {payment_per_worker}g. {time_str}"
    
    def leave_construction_contract(self, player_id: str) -> Tuple[bool, str]:
        """Stop working on a construction contract"""
        player = self.players.get(player_id)
        
        if not player or not player.current_town:
            return False, "Not in a town"
        
        town = self.towns[player.current_town]
        
        if not town.active_contract:
            return False, "No active contract"
        
        if player_id not in town.active_contract.workers:
            return False, "Not working on this contract"
        
        town.active_contract.remove_worker(player_id)
        
        return True, f"Left contract ({town.active_contract.get_worker_count()} workers remaining)"
    
    def check_and_complete_contract(self, town_name: str) -> Tuple[bool, str]:
        """Check if contract is complete and finalize it, distributing payments"""
        town = self.towns.get(town_name)
        
        if not town or not town.active_contract:
            return False, "No active contract"
        
        if not town.active_contract.is_complete():
            progress = town.active_contract.get_progress_percent()
            time_remaining = town.active_contract.get_time_remaining()
            if time_remaining:
                hours = time_remaining.total_seconds() / 3600
                return False, f"Contract {progress:.0f}% complete. {hours:.1f}h remaining"
            else:
                return False, f"Contract waiting for workers to accept it"
        
        # Complete the contract
        building_type = town.active_contract.building_type
        level = town.active_contract.target_level
        
        # Distribute payments to workers
        payments = town.complete_contract()
        
        for worker_id, amount in payments.items():
            worker = self.players.get(worker_id)
            if worker:
                worker.gold += amount
        
        total_paid = sum(payments.values())
        
        return True, f"{building_type.value} upgraded to level {level}! {len(payments)} workers paid {total_paid}g total"
    
    # ===== FEUDAL SYSTEM =====
    
    def swear_vassalage(self, vassal_id: str, liege_id: str) -> Tuple[bool, str]:
        """Ruler becomes vassal of another ruler (social agreement)"""
        vassal = self.players.get(vassal_id)
        liege = self.players.get(liege_id)
        
        if not vassal or not liege:
            return False, "Player not found"
        
        if not vassal.is_ruler:
            return False, "Must be a ruler to swear vassalage"
        
        if vassal_id == liege_id:
            return False, "Cannot swear vassalage to yourself"
        
        if vassal.liege_lord_id:
            return False, "Already a vassal"
        
        vassal.swear_vassalage(liege_id)
        liege.add_vassal(vassal_id)
        
        return True, f"{vassal.name} swore vassalage to {liege.name}"
    
    def break_vassalage(self, vassal_id: str) -> Tuple[bool, str]:
        """Declare independence"""
        vassal = self.players.get(vassal_id)
        
        if not vassal or not vassal.liege_lord_id:
            return False, "Not a vassal"
        
        liege_id = vassal.liege_lord_id
        liege = self.players.get(liege_id)
        
        vassal.break_vassalage()
        if liege:
            liege.remove_vassal(vassal_id)
        
        return True, f"{vassal.name} declared independence!"
    
    def designate_heir(self, ruler_id: str, heir_id: str) -> Tuple[bool, str]:
        """Designate an heir for succession"""
        ruler = self.players.get(ruler_id)
        heir = self.players.get(heir_id)
        
        if not ruler or not heir:
            return False, "Player not found"
        
        if not ruler.is_ruler:
            return False, "Must be a ruler"
        
        if not heir.is_alive:
            return False, "Heir must be alive"
        
        ruler.heir = heir_id
        return True, f"{heir.name} designated as heir"
    
    def _handle_succession(self, deceased_id: str, town_name: str):
        """Handle what happens when a ruler dies"""
        deceased = self.players.get(deceased_id)
        town = self.towns.get(town_name)
        
        if not town:
            return
        
        # Check for heir
        if deceased and deceased.heir:
            heir = self.players.get(deceased.heir)
            if heir and heir.is_alive:
                town.set_ruler(heir.player_id, heir.name, f"inherited from {deceased.name}")
                heir.add_fief(town_name)
                return
        
        # No heir - power vacuum!
        town.ruler_id = None
        town.broadcast_event({
            'type': 'power_vacuum',
            'former_ruler': deceased.name if deceased else "Unknown",
            'message': f"{town_name} is leaderless - anyone can seize power!",
            'timestamp': datetime.now()
        })
    
    # ===== STATUS & INFO =====
    
    def get_player_status(self, player_id: str) -> Dict:
        """Get player info"""
        player = self.players.get(player_id)
        if not player:
            return {}
        
        return {
            'name': player.name,
            'is_alive': player.is_alive,
            'is_ruler': player.is_ruler,
            'current_town': player.current_town,
            'current_room': player.current_room,
            'checked_in': player.is_checked_in(self.checkin_valid_hours),
            'gold': player.gold,
            'fiefs_ruled': list(player.fiefs_ruled),
            'liege_lord': self.players[player.liege_lord_id].name if player.liege_lord_id else None,
            'vassals': len(player.vassals),
            'heir': self.players[player.heir].name if player.heir else None,
            'coups_won': player.coups_won,
            'times_executed': player.times_executed,
            'can_coup': player.can_attempt_coup(self.coup_cooldown_hours)
        }
    
    def get_town_status(self, town_name: str) -> Dict:
        """Get town info"""
        town = self.towns.get(town_name)
        if not town:
            return {}
        
        ruler = self.players.get(town.ruler_id) if town.ruler_id else None
        
        return {
            'name': town.name,
            'ruler': ruler.name if ruler else "None",
            'checked_in': len(town.population),
            'treasury': town.treasury,
            'rooms': list(town.rooms.keys()),
            'recent_events': town.get_recent_events(5)
        }
    
    def get_conspiracy_status(self, player_id: str) -> Optional[Dict]:
        """Get conspiracy info (only for members)"""
        player = self.players.get(player_id)
        if not player or not player.current_town:
            return None
        
        if player.current_town not in self.active_conspiracies:
            return None
        
        conspiracy = self.active_conspiracies[player.current_town]
        
        if not conspiracy.is_member(player_id):
            return None
        
        leader = self.players[conspiracy.leader_id]
        
        return {
            'leader': leader.name,
            'conspirators': conspiracy.get_size(),
            'invited_pending': len(conspiracy.invited),
            'can_execute': conspiracy.get_size() >= self.min_conspirators,
            'discovered': conspiracy.discovered
        }

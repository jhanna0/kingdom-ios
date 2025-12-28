"""
Player class - represents a player in the game
"""
from typing import Optional, Set
from datetime import datetime, timedelta


class Player:
    """A player who can check in to towns, participate in coups, and rule territory"""
    
    def __init__(self, player_id: str, name: str):
        self.player_id = player_id
        self.name = name
        
        # Status
        self.is_alive = True
        self.gold = 100  # Starting gold
        
        # Progression (Gold + Reputation system)
        self.reputation = 0  # Global reputation (permanent, public)
        self.level = 1
        self.experience = 0
        self.skill_points = 0
        
        # Combat stats (for coups)
        self.attack_power = 1
        self.defense_power = 1
        self.leadership = 1  # Vote weight bonus
        
        # Kingdom-specific reputation
        self.kingdom_reputation = {}  # town_name -> reputation
        
        # Location
        self.current_town: Optional[str] = None
        self.current_room: Optional[str] = None
        self.last_checkin: Optional[datetime] = None
        self.last_checkin_lat: Optional[float] = None
        self.last_checkin_lon: Optional[float] = None
        
        # Power
        self.fiefs_ruled: Set[str] = set()  # Towns this player rules
        self.is_ruler = False
        
        # Feudal system
        self.liege_lord_id: Optional[str] = None  # Who this player serves
        self.vassals: Set[str] = set()  # Players who serve this player
        self.heir: Optional[str] = None  # Designated heir
        
        # Stats
        self.coups_won = 0
        self.coups_failed = 0
        self.times_executed = 0
        self.executions_ordered = 0
        self.betrayals = 0
        
        # Cooldowns
        self.last_coup_attempt: Optional[datetime] = None
    
    def check_in(self, town_name: str, lat: float, lon: float):
        """Check in to a town"""
        self.current_town = town_name
        self.last_checkin = datetime.now()
        self.last_checkin_lat = lat
        self.last_checkin_lon = lon
    
    def is_checked_in(self, valid_hours: float = 4) -> bool:
        """Check if player has a valid check-in"""
        if not self.last_checkin:
            return False
        
        elapsed = datetime.now() - self.last_checkin
        return elapsed < timedelta(hours=valid_hours)
    
    def move_to_room(self, room_name: str):
        """Move to a different room in current town"""
        self.current_room = room_name
    
    def add_fief(self, town_name: str):
        """Gain control of a town"""
        self.fiefs_ruled.add(town_name)
        self.is_ruler = True
    
    def remove_fief(self, town_name: str):
        """Lose control of a town"""
        self.fiefs_ruled.discard(town_name)
        if len(self.fiefs_ruled) == 0:
            self.is_ruler = False
    
    def can_attempt_coup(self, cooldown_hours: float) -> bool:
        """Check if player can attempt a coup (cooldown expired)"""
        if not self.last_coup_attempt:
            return True
        
        elapsed = datetime.now() - self.last_coup_attempt
        return elapsed >= timedelta(hours=cooldown_hours)
    
    def record_coup_won(self):
        """Record a successful coup"""
        self.coups_won += 1
    
    def record_coup_failed(self):
        """Record a failed coup"""
        self.coups_failed += 1
    
    def record_execution_ordered(self):
        """Record ordering an execution"""
        self.executions_ordered += 1
    
    def record_betrayal(self):
        """Record betraying a conspiracy"""
        self.betrayals += 1
    
    def execute(self):
        """Execute this player (permanent death)"""
        self.is_alive = False
        self.gold = 0
        self.times_executed += 1
    
    def swear_vassalage(self, liege_id: str):
        """Become a vassal of another ruler"""
        self.liege_lord_id = liege_id
    
    def break_vassalage(self):
        """Declare independence"""
        self.liege_lord_id = None
    
    def add_vassal(self, vassal_id: str):
        """Add a vassal"""
        self.vassals.add(vassal_id)
    
    def remove_vassal(self, vassal_id: str):
        """Remove a vassal"""
        self.vassals.discard(vassal_id)
    
    # MARK: - Reputation System (like Eve Online)
    
    def get_reputation_tier(self, reputation: int = None) -> str:
        """Get reputation tier name"""
        rep = reputation if reputation is not None else self.reputation
        if rep >= 1000: return "Legendary"
        if rep >= 500: return "Champion"
        if rep >= 300: return "Notable"
        if rep >= 150: return "Citizen"
        if rep >= 50: return "Resident"
        return "Stranger"
    
    def get_kingdom_reputation(self, town_name: str) -> int:
        """Get reputation in specific kingdom"""
        return self.kingdom_reputation.get(town_name, 0)
    
    def add_reputation(self, amount: int, town_name: str = None):
        """Add reputation (PERMANENT - like Eve standings)"""
        self.reputation += amount
        if town_name:
            current = self.kingdom_reputation.get(town_name, 0)
            self.kingdom_reputation[town_name] = current + amount
    
    def can_vote_on_coup(self, town_name: str) -> bool:
        """Check if can vote (150+ rep in kingdom)"""
        return self.get_kingdom_reputation(town_name) >= 150
    
    def can_propose_coup(self, town_name: str) -> bool:
        """Check if can propose coup (300+ rep in kingdom)"""
        return self.get_kingdom_reputation(town_name) >= 300
    
    def get_vote_weight(self, town_name: str) -> int:
        """Get vote weight (tier multiplier + leadership)"""
        rep = self.get_kingdom_reputation(town_name)
        tier_weight = 3 if rep >= 1000 else 2 if rep >= 500 else 1
        return tier_weight + self.leadership
    
    # MARK: - Leveling & XP
    
    def get_xp_for_next_level(self) -> int:
        """XP needed for next level"""
        return 100 * (2 ** (self.level - 1))
    
    def add_experience(self, amount: int):
        """Add XP and check for level up"""
        self.experience += amount
        while self.experience >= self.get_xp_for_next_level():
            self.level_up()
    
    def level_up(self):
        """Level up! Gain skill points"""
        xp_needed = self.get_xp_for_next_level()
        self.experience -= xp_needed
        self.level += 1
        self.skill_points += 3
        self.gold += 50  # Bonus gold
        print(f"🎉 {self.name} leveled up to {self.level}!")
    
    # MARK: - Training (Spend Gold)
    
    def purchase_xp(self, amount: int) -> bool:
        """Buy XP with gold (10g per XP)"""
        cost = amount * 10
        if self.gold < cost:
            return False
        self.gold -= cost
        self.add_experience(amount)
        return True
    
    def train_attack(self) -> bool:
        """Train attack power"""
        cost = int(100 * (self.attack_power ** 1.5))
        if self.gold < cost:
            return False
        self.gold -= cost
        self.attack_power += 1
        return True
    
    def train_defense(self) -> bool:
        """Train defense power"""
        cost = int(100 * (self.defense_power ** 1.5))
        if self.gold < cost:
            return False
        self.gold -= cost
        self.defense_power += 1
        return True
    
    def train_leadership(self) -> bool:
        """Train leadership"""
        cost = int(100 * (self.leadership ** 1.5))
        if self.gold < cost:
            return False
        self.gold -= cost
        self.leadership += 1
        return True
    
    def use_skill_point(self, stat: str) -> bool:
        """Use skill point to increase stat (free)"""
        if self.skill_points <= 0:
            return False
        
        self.skill_points -= 1
        if stat == "attack":
            self.attack_power += 1
        elif stat == "defense":
            self.defense_power += 1
        elif stat == "leadership":
            self.leadership += 1
        else:
            return False
        return True
    
    # MARK: - Rewards (Gold + Reputation ONLY)
    
    def reward_contract_completion(self, gold_amount: int, town_name: str = None):
        """Reward for completing contract"""
        self.gold += gold_amount
        self.add_reputation(10, town_name)
        print(f"💰 {self.name} earned {gold_amount}g and +10 rep")
    
    def reward_daily_checkin(self, town_name: str = None):
        """Reward for daily check-in"""
        self.gold += 50
        self.add_reputation(5, town_name)
        print(f"📅 {self.name} daily bonus: +50g, +5 rep")
    
    def reward_coup_success(self, town_name: str = None):
        """Reward for successful coup"""
        self.gold += 1000
        self.add_reputation(50, town_name)
        print(f"👑 {self.name} coup success: +1000g, +50 rep!")
    
    def reward_coup_defense(self, town_name: str = None):
        """Reward for defending against coup"""
        self.gold += 200
        self.add_reputation(25, town_name)
        print(f"🛡️ {self.name} defended coup: +200g, +25 rep")
    
    def __repr__(self):
        status = "💀" if not self.is_alive else "👑" if self.is_ruler else "⚔️"
        tier = self.get_reputation_tier()
        return f"Player({status} {self.name}, Lv{self.level}, {self.gold}g, {tier}, {len(self.fiefs_ruled)} fiefs)"

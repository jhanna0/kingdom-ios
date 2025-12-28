"""
Simplified Demo - showing the geo-based social coup game
"""
from game_engine import GameEngine
from buildings import BuildingType
from datetime import datetime
import time


def print_separator(title=""):
    """Print a visual separator"""
    if title:
        print(f"\n{'='*60}")
        print(f"  {title}")
        print(f"{'='*60}\n")
    else:
        print(f"{'='*60}\n")


def print_event(event):
    """Pretty print a public event"""
    event_type = event['type']
    timestamp = event['timestamp'].strftime("%H:%M:%S")
    
    if event_type == 'ruler_change':
        print(f"[{timestamp}] 👑 {event['new_ruler_name']} became ruler! ({event['reason']})")
    elif event_type == 'decree':
        print(f"[{timestamp}] 📜 DECREE from {event['ruler']}: {event['message']}")
    elif event_type == 'execution':
        print(f"[{timestamp}] ⚔️  {event['victim']} executed for {event['reason']}")
    elif event_type == 'conspiracy_discovered':
        print(f"[{timestamp}] 🚨 {event['informant']} exposed {event['leader']}'s plot!")
    elif event_type == 'power_vacuum':
        print(f"[{timestamp}] 💀 {event['message']}")


def main():
    print_separator("KINGDOM: Geo-Based Social Power Game")
    
    # Initialize game
    game = GameEngine()
    
    # Create a bar in NYC (real GPS coordinates)
    print("🍺 Creating 'The Dead Rabbit' bar in NYC...")
    bar_lat, bar_lon = 40.7034, -74.0115  # Real bar in lower Manhattan
    bar = game.create_town("The Dead Rabbit", bar_lat, bar_lon)
    print(f"   Location: {bar_lat}, {bar_lon}")
    print(f"   Rooms: {', '.join(bar.rooms.keys())}\n")
    
    # Create players
    print("👥 Creating players...")
    alice = game.create_player("alice", "Alice")
    bob = game.create_player("bob", "Bob")
    charlie = game.create_player("charlie", "Charlie")
    diana = game.create_player("diana", "Diana")
    print(f"   Created 4 players\n")
    
    print_separator("SCENARIO 1: CHECKING IN (Physical Presence Required)")
    
    # Players check in (simulating GPS)
    print("Alice arrives at the bar and checks in...")
    success, msg = game.check_in("alice", "The Dead Rabbit", bar_lat, bar_lon)
    print(f"   {msg}")
    print(f"   Alice is checked in: {alice.is_checked_in()}\n")
    
    print("Bob tries to check in from too far away...")
    fake_lat, fake_lon = 40.8000, -74.0000  # ~10km away
    success, msg = game.check_in("bob", "The Dead Rabbit", fake_lat, fake_lon)
    print(f"   {msg}")
    print(f"   (Bob must actually be at the bar!)\n")
    
    print("Bob arrives at the bar and checks in properly...")
    success, msg = game.check_in("bob", "The Dead Rabbit", bar_lat, bar_lon)
    print(f"   {msg}\n")
    
    print("Charlie and Diana also arrive...")
    game.check_in("charlie", "The Dead Rabbit", bar_lat, bar_lon)
    game.check_in("diana", "The Dead Rabbit", bar_lat, bar_lon)
    print(f"   4 people now at the bar\n")
    
    print_separator("SCENARIO 2: SEIZING AN UNCLAIMED LOCATION")
    
    print("Alice notices no one rules this bar yet...")
    print(f"   Current ruler: {bar.ruler_id}")
    print(f"   Treasury: {bar.treasury} gold\n")
    
    print("Alice initiates a coup (really just claiming it)...")
    success, msg = game.initiate_coup("alice")
    print(f"   {msg}")
    print(f"   Alice now rules: {list(alice.fiefs_ruled)}")
    print(f"   Alice's gold: {alice.gold}\n")
    
    print_separator("SCENARIO 3: RULER MAKES DEMANDS")
    
    print("Alice, now ruler, makes a decree...")
    success, msg = game.make_decree("alice", "Everyone drinks on my tab tonight!")
    print(f"   {msg}\n")
    
    print("Alice demands payment from Bob...")
    success, msg = game.demand_payment("alice", "bob", 30, "entry fee")
    print(f"   {msg}\n")
    
    print("Bob decides to pay...")
    success, msg = game.transfer_gold("bob", "alice", 30, "paying entry fee")
    print(f"   {msg}")
    print(f"   Bob's gold: {bob.gold}")
    print(f"   Alice's gold: {alice.gold}\n")
    
    print_separator("SCENARIO 4: ALICE POSTS A CONSTRUCTION CONTRACT")
    
    print("Alice wants to fortify her new territory...")
    print(f"   Alice's gold: {alice.gold}")
    print(f"   Current walls: Level {bar.get_building_level(BuildingType.WALLS)}\n")
    
    print("Alice posts a contract for walls (Level 1)...")
    print("   Materials cost: 200g, Worker payment: 100g")
    success, msg = game.post_construction_contract("alice", BuildingType.WALLS, 100)
    print(f"   {msg}")
    print(f"   Alice's gold: {alice.gold} (300g held in escrow)\n")
    
    print("Diana sees the contract and accepts it for the payment...")
    success, msg = game.accept_construction_contract("diana")
    print(f"   {msg}\n")
    
    print("Charlie also accepts the contract...")
    success, msg = game.accept_construction_contract("charlie")
    print(f"   {msg}")
    print(f"   With 2 workers, payment splits: {bar.active_contract.get_payment_per_worker()}g each\n")
    
    print("With 2 workers, construction is faster!")
    print("   (In real game, time would pass. For demo, we'll fast-forward)\n")
    
    # Simulate time passing by marking as complete
    bar.active_contract.completed = True
    success, msg = game.check_and_complete_contract("The Dead Rabbit")
    print(f"   {msg}")
    print(f"   Diana's gold: {diana.gold}")
    print(f"   Charlie's gold: {charlie.gold}")
    print(f"   Walls level: {bar.get_building_level(BuildingType.WALLS)}")
    print(f"   Defense: +{bar.get_wall_defenders()} virtual defenders\n")
    
    print_separator("SCENARIO 5: CONSPIRACY IN THE TAVERN")
    
    print("Bob and Charlie move to the tavern room to plot...")
    game.move_to_room("bob", "tavern")
    game.move_to_room("charlie", "tavern")
    print(f"   Bob in: {bob.current_room}")
    print(f"   Charlie in: {charlie.current_room}\n")
    
    print("Private conversation:")
    success, msg, visible_to = game.chat_in_room("bob", "Alice is charging too much!")
    print(f"   Bob: 'Alice is charging too much!'")
    print(f"   (Visible to {len(visible_to)} people)")
    
    success, msg, visible_to = game.chat_in_room("charlie", "Let's overthrow her!")
    print(f"   Charlie: 'Let's overthrow her!'")
    print(f"   (Alice and Diana in other rooms can't hear)\n")
    
    print_separator("SCENARIO 6: SECRET COUP BEGINS")
    
    print("Bob secretly initiates a coup conspiracy...")
    print(f"   Cost: {game.coup_initiation_cost} gold")
    print(f"   Bob's gold: {bob.gold}\n")
    
    success, msg = game.initiate_coup("bob")
    print(f"   {msg}")
    print(f"   Bob's gold: {bob.gold}\n")
    
    # Check conspiracy (only Bob can see)
    conspiracy = game.get_conspiracy_status("bob")
    if conspiracy:
        print("🤫 Conspiracy Status (secret):")
        print(f"   Leader: {conspiracy['leader']}")
        print(f"   Conspirators: {conspiracy['conspirators']}")
        print(f"   Can execute: {conspiracy['can_execute']}\n")
    
    print_separator("SCENARIO 7: RECRUITING ALLIES")
    
    print("Bob invites Charlie to the conspiracy...")
    success, msg = game.invite_to_coup("bob", "charlie")
    print(f"   {msg}\n")
    
    print("Charlie accepts...")
    success, msg = game.respond_to_coup_invitation("charlie", accept=True, snitch=False)
    print(f"   {msg}\n")
    
    conspiracy = game.get_conspiracy_status("bob")
    print(f"Updated conspiracy size: {conspiracy['conspirators']}")
    print(f"Ready to execute: {conspiracy['can_execute']}\n")
    
    print_separator("SCENARIO 8: THE COUP ATTEMPT (WITH WALLS)")
    
    print("Current situation:")
    print(f"   People at bar: 4 (Alice, Bob, Charlie, Diana)")
    print(f"   Conspirators: 2 (Bob, Charlie)")
    print(f"   Non-conspirators: 2 (Alice, Diana)")
    print(f"   Wall defenders: {bar.get_wall_defenders()}")
    print(f"   Total defenders: {2 + bar.get_wall_defenders()}")
    print(f"   Conspirators need MORE than defenders to win\n")
    
    print("Bob executes the coup!")
    success, msg = game.execute_coup("bob")
    print(f"   {msg}\n")
    
    if success:
        print("🎉 BOB WON!")
        print(f"   Bob now rules: {list(bob.fiefs_ruled)}")
        print(f"   Bob is ruler: {bob.is_ruler}")
        print(f"   Alice lost control: {list(alice.fiefs_ruled)}\n")
        
        print_separator("SCENARIO 9: NEW RULER'S REIGN")
        
        print("Bob makes his first decree...")
        success, msg = game.make_decree("bob", "No more entry fees! Free bar for all!")
        print(f"   {msg}\n")
        
        print("Bob executes Alice to prevent counter-coup...")
        success, msg = game.execute_player("bob", "alice", "deposed ruler")
        print(f"   {msg}")
        print(f"   Alice is alive: {alice.is_alive}")
        print(f"   Alice's gold is gone: {alice.gold}\n")
        
    else:
        print("💀 COUP FAILED!")
        print(f"   Alice remains ruler")
        print(f"   Bob and Charlie are exposed!\n")
        
        print_separator("SCENARIO 9: SWIFT JUSTICE")
        
        print("Alice executes the conspirators...")
        success, msg = game.execute_player("alice", "bob", "attempted coup")
        print(f"   {msg}")
        
        success, msg = game.execute_player("alice", "charlie", "conspiracy")
        print(f"   {msg}\n")
        
        print("Alice makes a decree...")
        success, msg = game.make_decree("alice", "Let this be a lesson to all traitors!")
        print(f"   {msg}\n")
    
    print_separator("FINAL STATUS")
    
    town_status = game.get_town_status("The Dead Rabbit")
    print(f"Bar: {town_status['name']}")
    print(f"Ruler: {town_status['ruler']}")
    print(f"People checked in: {town_status['checked_in']}")
    print(f"Treasury: {town_status['treasury']}\n")
    
    print("Players:")
    for pid in game.players.keys():
        p = game.get_player_status(pid)
        status = "💀" if not p['is_alive'] else "✓"
        ruler = "👑" if p['is_ruler'] else "  "
        print(f"   {status} {ruler} {p['name']}: {p['gold']} gold, {p['coups_won']} coups won")
    
    print("\n" + "="*60)
    print("Demo complete! In the real game, players would actually")
    print("need to be at physical locations to coup and rule them.")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()

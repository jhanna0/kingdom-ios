# Kingdom Game - API Reference

## GameEngine Methods

### Player Management

#### `create_player(player_id: str, name: str) -> Player`
Create a new player.

```python
player = game.create_player("alice_123", "Alice")
```

#### `get_player_status(player_id: str) -> Dict`
Get detailed status of a player.

Returns:
```python
{
    'name': str,
    'rank': str,  # PEASANT, NOBLE, GOVERNOR, KING
    'is_alive': bool,
    'town': str,
    'current_room': str,
    'gold': int,
    'land': int,
    'can_coup': bool
}
```

### Town Management

#### `create_town(name: str, latitude: float = None, longitude: float = None) -> Town`
Create a new town (optionally with real-world coordinates).

```python
town = game.create_town("Boston", latitude=42.3601, longitude=-71.0589)
```

#### `join_town(player_id: str, town_name: str)`
Player joins a town.

```python
game.join_town("alice_123", "Boston")
```

#### `get_town_status(town_name: str) -> Dict`
Get detailed status of a town.

Returns:
```python
{
    'name': str,
    'ruler': str,
    'population': int,
    'rooms': List[str],
    'recent_events': List[Dict]
}
```

### Movement & Chat

#### `move_to_room(player_id: str, room_name: str)`
Move player to a different room in their town.

Default rooms: `"town_square"`, `"tavern"`, `"market"`, `"palace"`, `"dungeon"`

```python
game.move_to_room("alice_123", "tavern")
```

#### `chat_in_room(player_id: str, message: str) -> List[str]`
Send a message in current room. Returns list of player_ids who can see it.

```python
visible_to = game.chat_in_room("alice_123", "The king is a tyrant!")
# Only players in the same room will see this
```

### Coup System (SECRET)

#### `initiate_coup(player_id: str) -> Tuple[bool, str]`
Secretly start a coup conspiracy. **This is private - no one else knows!**

Cost: 50 gold (configurable)
Cooldown: 24 hours after last attempt

```python
success, msg = game.initiate_coup("bob_456")
# "You have secretly initiated a coup conspiracy..."
```

#### `invite_to_coup(inviter_id: str, target_id: str) -> Tuple[bool, str]`
Privately invite someone to join your conspiracy.

**Risk**: If they reject, they might snitch (30% chance)!

```python
success, msg = game.invite_to_coup("bob_456", "charlie_789")
# "You have secretly invited Charlie to join the conspiracy"
```

#### `check_coup_invitation(player_id: str) -> Optional[Dict]`
Check if you have a pending invitation.

Returns:
```python
{
    'leader': str,
    'town': str,
    'message': str
}
# or None if no invitation
```

#### `respond_to_coup_invitation(player_id: str, accept: bool) -> Tuple[bool, str]`
Accept or reject a coup invitation.

**Warning**: Rejecting has a 30% chance of snitching to the king!

```python
# Accept
success, msg = game.respond_to_coup_invitation("charlie_789", accept=True)
# "You have joined the conspiracy! Conspirators: 3"

# Reject (might snitch!)
success, msg = game.respond_to_coup_invitation("charlie_789", accept=False)
# Either: "You rejected and kept silent"
# Or: "You rejected and INFORMED the king! The conspiracy has been exposed!"
```

#### `execute_coup(player_id: str) -> Tuple[bool, str]`
Execute the coup! **This makes it public** - either succeed or all conspirators are exposed.

Requirements:
- Must be conspiracy leader
- Must have minimum conspirators (default: 3)
- Conspiracy not discovered

Success chance:
- Base: 30%
- +15% per extra conspirator
- Max: 95%

```python
success, msg = game.execute_coup("bob_456")
# Success: "🎉 COUP SUCCESS! Bob has seized power..."
# Failure: "💀 COUP FAILED! Bob's conspiracy has been crushed!"
```

#### `get_conspiracy_status(player_id: str) -> Optional[Dict]`
Get status of your conspiracy. **Only visible to conspirators!**

Returns:
```python
{
    'leader': str,
    'conspirators': int,
    'invited_pending': int,
    'min_required': int,
    'can_execute': bool,
    'discovered': bool,
    'executed': bool
}
# or None if not part of any conspiracy
```

### Royal Powers

#### `make_decree(ruler_id: str, decree: str) -> Tuple[bool, str]`
Ruler makes a public decree visible to entire town.

**Restriction**: Only the current ruler can make decrees.

```python
success, msg = game.make_decree("alice_123", "All citizens must pay 10 gold in taxes!")
# Creates public event visible to all
```

#### `execute_player(ruler_id: str, target_id: str, reason: str = "treason") -> Tuple[bool, str]`
Ruler executes a player.

**Restriction**: Only ruler can execute, only in their own town.

```python
success, msg = game.execute_player("alice_123", "bob_456", "leading a conspiracy")
# "Alice has executed Bob for leading a conspiracy!"
# Bob.is_alive = False
# Creates public execution event
```

### Loyalty & Influence

#### `pledge_loyalty(player_id: str, target_id: str) -> Tuple[bool, str]`
Pledge loyalty to another player.

```python
success, msg = game.pledge_loyalty("charlie_789", "bob_456")
# "Charlie pledged loyalty to Bob"
```

**Note**: In the current system, you can also directly modify player influence:

```python
player.add_influence("target_id", amount)
influence_score = player.get_influence_over("target_id")
```

## Public Events

All major actions create public events visible to everyone in the town:

### Event Types

```python
# Ruler change
{
    'type': 'ruler_change',
    'new_ruler': str,
    'new_ruler_id': str,
    'old_ruler_id': str,
    'reason': str,
    'timestamp': datetime
}

# Royal decree
{
    'type': 'decree',
    'ruler': str,
    'message': str,
    'timestamp': datetime
}

# Execution
{
    'type': 'execution',
    'victim': str,
    'reason': str,
    'timestamp': datetime
}

# Conspiracy discovered (snitch!)
{
    'type': 'conspiracy_discovered',
    'informant': str,
    'leader': str,
    'timestamp': datetime
}

# Coup success
{
    'type': 'coup_success',
    'new_ruler': str,
    'conspirators': int,
    'population': int,
    'timestamp': datetime
}

# Coup failure
{
    'type': 'coup_failed',
    'leader': str,
    'conspirators': int,
    'timestamp': datetime
}
```

### Accessing Events

```python
# Get recent events from a town
events = town.get_recent_events(limit=10)

# Or via game engine
status = game.get_town_status("Boston")
recent_events = status['recent_events']
```

## Room System

Every town has these default rooms:

- `town_square` - Public gathering place
- `tavern` - Perfect for secret meetings
- `market` - Trade and gossip
- `palace` - Where the ruler resides
- `dungeon` - For the condemned

**Key Feature**: Chat is room-scoped. Only players in the same room can see messages!

```python
# Bob and Charlie meet in tavern
game.move_to_room("bob_456", "tavern")
game.move_to_room("charlie_789", "tavern")

# They plot in private
game.chat_in_room("bob_456", "Let's overthrow Alice!")
# Only Charlie can see this (not Alice or others in town_square)
```

## Configuration

Customize game balance by modifying `GameEngine` attributes:

```python
game = GameEngine()

# Coup settings
game.coup_cooldown_hours = 24          # Time between coup attempts
game.coup_initiation_cost = 50         # Gold cost to start conspiracy
game.min_conspirators = 3              # Minimum people needed
game.snitch_chance = 0.3               # 30% chance reject = snitch
```

## Example: Complete Coup Flow

```python
# Setup
game = GameEngine()
boston = game.create_town("Boston")

alice = game.create_player("alice_1", "Alice")
bob = game.create_player("bob_1", "Bob")
charlie = game.create_player("charlie_1", "Charlie")

game.join_town("alice_1", "Boston")
game.join_town("bob_1", "Boston")
game.join_town("charlie_1", "Boston")

# Alice seizes power
game.initiate_coup("alice_1")  # No ruler, automatic success

# Bob plots revenge
game.initiate_coup("bob_1")
# "You have secretly initiated a coup conspiracy..."

# Bob recruits Charlie
game.invite_to_coup("bob_1", "charlie_1")
# "You have secretly invited Charlie..."

# Charlie accepts
invitation = game.check_coup_invitation("charlie_1")
# {'leader': 'Bob', ...}

game.respond_to_coup_invitation("charlie_1", accept=True)
# "You have joined the conspiracy! Conspirators: 2"

# Bob needs more support... (recruit one more to reach min 3)
# ... then:

# Execute the coup!
success, msg = game.execute_coup("bob_1")
if success:
    # Bob is now KING!
    game.make_decree("bob_1", "A new era begins!")
    game.execute_player("bob_1", "alice_1", "deposed ruler")
else:
    # All conspirators exposed
    # Alice can execute them all
    game.execute_player("alice_1", "bob_1", "failed coup leader")
    game.execute_player("alice_1", "charlie_1", "conspiracy")
```

## Return Value Patterns

Most action methods return `Tuple[bool, str]`:
- First value: Success (True/False)
- Second value: Human-readable message

```python
success, message = game.execute_coup("bob_1")
if success:
    print(f"Success! {message}")
else:
    print(f"Failed: {message}")
```

Status methods return `Dict` or `None`:
```python
status = game.get_conspiracy_status("bob_1")
if status:
    print(f"Conspirators: {status['conspirators']}")
else:
    print("Not part of any conspiracy")
```

---

## Next Steps

See [COUP_MECHANICS.md](COUP_MECHANICS.md) for detailed strategy guide and mechanics breakdown.

See [README.md](README.md) for game overview and future plans.



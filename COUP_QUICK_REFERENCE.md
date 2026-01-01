# Coup System - Quick Reference Card 🎯

## API Endpoints

### Initiate Coup
```bash
POST /coups/initiate
Body: {"kingdom_id": "ashford"}
Auth: Required
Cost: 50g | Req: 300+ rep | Cooldown: 24h
```

### Join Coup
```bash
POST /coups/{coup_id}/join
Body: {"side": "attackers" | "defenders"}
Auth: Required
Req: Checked in to kingdom
```

### Get Active Coups
```bash
GET /coups/active?kingdom_id=ashford
Auth: Required
```

### Get Coup Details
```bash
GET /coups/{coup_id}
Auth: Required
```

### Resolve Coup
```bash
POST /coups/{coup_id}/resolve
Auth: Required
Note: Auto-resolves after 2 hours
```

---

## Combat Formula

```
Attack Strength = Σ(attacker.attack_power)
Defense Strength = Σ(defender.defense_power)

Victory if: Attack > Defense × 1.25
(No walls for coups - internal rebellion)
```

---

## Rewards

### Attackers Win
- **Initiator**: Becomes ruler, +1000g, +50 rep
- **Old ruler**: Loses kingdom
- **Defenders**: Nothing

### Attackers Lose (HARSH)
- **All attackers**: Lose ALL gold, -100 rep, attack=1, defense=1
- **Ruler**: Gets all seized gold, +50 rep
- **Defenders**: +200g each, +30 rep

---

## Game Constants

```python
COUP_COST = 50                      # Gold to initiate
COUP_REPUTATION_REQUIREMENT = 300   # Min rep needed
COUP_COOLDOWN_HOURS = 24           # Cooldown between attempts
COUP_VOTING_DURATION_HOURS = 2     # Time to pick sides
ATTACKER_ADVANTAGE_REQUIRED = 1.25 # 25% more power needed
```

Edit these in: `/api/routers/coups.py`

---

## Testing

```bash
# Quick test
./test_coup_api.sh YOUR_TOKEN YOUR_KINGDOM_ID

# Manual test
curl -X POST http://localhost:8000/coups/initiate \
  -H "Authorization: Bearer TOKEN" \
  -d '{"kingdom_id": "ashford"}'
```

---

## Database

```sql
-- View active coups
SELECT * FROM coup_events WHERE status = 'voting';

-- View coup history
SELECT * FROM coup_events WHERE status = 'resolved' ORDER BY resolved_at DESC;

-- Check player coup stats
SELECT coups_won, coups_failed, last_coup_attempt FROM player_state WHERE user_id = 1;
```

---

## Status Codes

- `200` - Success
- `400` - Invalid request (not enough gold/rep, cooldown active, etc.)
- `401` - Unauthorized (bad token)
- `404` - Coup or kingdom not found

---

## Next: Build iOS UI

1. Create `CoupAPI.swift` service
2. Add coup list view
3. Add "Initiate Coup" button
4. Show countdown timer
5. Display results

See: `COUP_SYSTEM_IMPLEMENTATION.md` for full details




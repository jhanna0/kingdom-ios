# Alliance System

## Overview

Alliances are **formal pacts between empires** that provide mutual benefits and protections. A ruler proposes an alliance, and the target ruler must accept it.

---

## Core Mechanics

### Alliance Lifecycle

```
PENDING ─────accept()────→ ACTIVE ─────30 days────→ EXPIRED
    │                          
    │                          
 decline()                   
    │                          
    ▼                          
 DECLINED                      
```

- **Pending**: Proposal sent, awaiting response (7 days to respond)
- **Active**: Alliance in effect, benefits active (lasts 30 days)
- **Expired**: Alliance naturally ended
- **Declined**: Target rejected the proposal

---

## Alliance Benefits

| Benefit | Description |
|---------|-------------|
| 🛡️ **No Invasions** | Cannot declare invasion on allied empire cities |
| 🔒 **No Espionage** | Cannot gather intelligence on allied kingdoms |
| 🚫 **No Sabotage** | Cannot sabotage allied kingdom contracts |
| 🎫 **No Travel Fee** | Free entry to allied kingdom cities |
| ⚔️ **Defensive Aid** | Can join as defenders in ally's invasions |

---

## Requirements

### To Propose Alliance:
- Must be a **ruler** of at least one city
- Cannot propose to your **own empire**
- Cannot have existing pending/active alliance with target
- Max **3 active alliances** per empire
- Costs **500g** (diplomatic investment)

### To Accept Alliance:
- Must be a **ruler** in target empire
- Free to accept
- Has 7 days to respond before proposal expires

---

## API Endpoints

### Propose Alliance
```
POST /alliances/propose
Body: { "target_empire_id": "los-angeles" }

Response:
{
  "success": true,
  "alliance_id": 42,
  "message": "Alliance proposed to Los Angeles! They have 7 days to accept.",
  "cost_paid": 500,
  "proposal_expires_at": "2025-01-05T00:00:00Z"
}
```

### Accept Alliance
```
POST /alliances/{alliance_id}/accept

Response:
{
  "success": true,
  "message": "Alliance with San Francisco is now active!",
  "alliance_id": 42,
  "expires_at": "2025-01-28T00:00:00Z",
  "benefits": [
    "🛡️ Cannot attack each other",
    "🔒 Cannot spy on each other",
    "🚫 Cannot sabotage each other",
    "🎫 No travel fees in allied cities",
    "⚔️ Can help defend against invasions"
  ]
}
```

### Decline Alliance
```
POST /alliances/{alliance_id}/decline

Response:
{
  "success": true,
  "message": "Alliance proposal from San Francisco declined."
}
```

### Get Active Alliances
```
GET /alliances/active

Response:
{
  "alliances": [...],
  "count": 2
}
```

### Get Pending Alliances
```
GET /alliances/pending

Response:
{
  "sent": [...],
  "received": [...],
  "sent_count": 1,
  "received_count": 2
}
```

### Get Alliance Details
```
GET /alliances/{alliance_id}

Response:
{
  "id": 42,
  "initiator_empire_id": "san-francisco",
  "target_empire_id": "los-angeles",
  "status": "active",
  "days_remaining": 25,
  "is_active": true,
  ...
}
```

---

## Defensive Aid

The most powerful benefit - allied players can defend your cities from invasion!

### Scenario: Kingdom A (your ally) is being invaded

**Without Alliance**: Only citizens of Kingdom A can join as defenders

**With Alliance**: Citizens from your empire (allied to A) can ALSO join as defenders

**Requirements**:
- Must be physically checked into the target city
- Must be from: target kingdom, same empire, OR allied empire

---

## Strategic Implications

### Why Form Alliances?

1. **Defensive Pact**: Allies can help defend your cities from invasion
2. **Trade Routes**: Free movement between allied cities
3. **Deterrence**: Attackers must consider combined strength of allies
4. **Trust**: No need to worry about espionage from allies

### Alliance Limitations

- **Max 3 alliances** prevents one mega-alliance dominating
- **30-day duration** forces periodic renewal/renegotiation
- **No breaking early** - commit to your word!
- **500g cost** shows diplomatic commitment

---

## Database Setup

Run the migration:

```bash
cd api
psql -U your_username -d kingdom_db -f db/add_alliance_system.sql
```

---

## Example Flow

1. **Alice** (ruler of San Francisco) proposes alliance to **Bob** (ruler of Los Angeles)
   - Alice pays 500g
   - Bob receives notification of pending proposal

2. **Bob** accepts within 7 days
   - Alliance becomes active
   - Both empires gain all benefits

3. For the next **30 days**:
   - Neither can attack the other
   - Neither can spy/sabotage
   - Free travel between cities
   - Can help defend each other from invasions

4. After 30 days:
   - Alliance expires naturally
   - Can propose a new alliance if desired


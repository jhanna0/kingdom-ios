# Property API

## Overview

Properties are a **5-tier progression system** where players:
1. Buy **land (T1)** in a kingdom
2. Upgrade through tiers to unlock benefits
3. Can own **ONE property per kingdom**

## Tier System

| Tier | Name | Benefits |
|------|------|----------|
| T1 | Land | 50% travel cost, instant travel to kingdom |
| T2 | House | Personal residence (TBD) |
| T3 | Workshop | Can craft weapons/armor, 15% faster crafting |
| T4 | Beautiful Property | Tax exemption in kingdom |
| T5 | Estate | 50% survive conquest |

## Endpoints

### GET /properties

Get all properties owned by the current player.

**Response:**
```json
[
  {
    "id": "uuid",
    "kingdom_id": "kingdom-id",
    "kingdom_name": "Ashford",
    "owner_id": 123,
    "owner_name": "Player Name",
    "tier": 3,
    "purchased_at": "2024-01-01T00:00:00",
    "last_upgraded": "2024-01-02T00:00:00"
  }
]
```

### POST /properties/purchase

Purchase land (T1) in a kingdom.

**Requirements:**
- 50+ reputation
- Enough gold (price scales with kingdom population)
- Cannot already own property in that kingdom

**Request:**
```json
{
  "kingdom_id": "kingdom-id",
  "kingdom_name": "Ashford"
}
```

**Response:** PropertyResponse (201 Created)

**Pricing:**
- Base: 500 gold
- Formula: `500 × (1 + population / 50)`
- Example: Kingdom with 20 citizens = 700 gold

### POST /properties/{property_id}/upgrade

Upgrade property to next tier.

**Requirements:**
- Own the property
- Enough gold for upgrade
- Not already at T5

**Response:** PropertyResponse

**Upgrade Costs:**
- T1 → T2: 500 gold
- T2 → T3: 1,000 gold
- T3 → T4: 2,000 gold
- T4 → T5: 4,000 gold

Formula: `500 × 2^(next_tier - 2)`

### GET /properties/{property_id}

Get single property details.

**Response:** PropertyResponse

## Errors

- `400 BAD_REQUEST`: Insufficient gold, already owns property, or max tier
- `404 NOT_FOUND`: Property or kingdom not found
- `403 FORBIDDEN`: Not authenticated

## One Property Per Kingdom Rule

The API enforces that players can only own **ONE property per kingdom**. 

Attempting to purchase land in a kingdom where you already own property will result in:
```json
{
  "detail": "You already own property in Ashford (Tier 3)"
}
```

Players can own properties in multiple kingdoms, but only one per kingdom.


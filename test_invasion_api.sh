#!/bin/bash
# Invasion System API Test Script
# Tests the full invasion flow from declaration to resolution
#
# Usage: ./test_invasion_api.sh ATTACKER_TOKEN ATTACKING_KINGDOM_ID TARGET_KINGDOM_ID [DEFENDER_TOKEN]
#
# Requirements:
# - Attacker must rule ATTACKING_KINGDOM_ID
# - Attacker must be checked in to TARGET_KINGDOM_ID
# - Attacker needs 500g to declare invasion
# - Optional: DEFENDER_TOKEN for a second player to test defending

set -e

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: ./test_invasion_api.sh ATTACKER_TOKEN ATTACKING_KINGDOM_ID TARGET_KINGDOM_ID [DEFENDER_TOKEN]"
    echo ""
    echo "Example: ./test_invasion_api.sh eyJhbGc... boston cambridge eyJdefender..."
    echo ""
    echo "Requirements:"
    echo "  - You must RULE the attacking kingdom"
    echo "  - You must be CHECKED IN to the target kingdom"
    echo "  - You need 500g to declare invasion"
    echo "  - Target kingdom must not have an active invasion"
    exit 1
fi

ATTACKER_TOKEN="$1"
ATTACKING_KINGDOM="$2"
TARGET_KINGDOM="$3"
DEFENDER_TOKEN="$4"
API_URL="${API_URL:-http://localhost:8000}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "   Invasion System API Tests"
echo "========================================"
echo ""
echo "API URL: $API_URL"
echo "Attacking Kingdom: $ATTACKING_KINGDOM"
echo "Target Kingdom: $TARGET_KINGDOM"
echo "Defender Token: ${DEFENDER_TOKEN:+provided}"
echo ""

# Helper function to pretty print JSON
pretty_json() {
    python3 -m json.tool 2>/dev/null || cat
}

# Helper function to extract field from JSON
json_field() {
    python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('$1', '') if isinstance(data, dict) else '')" 2>/dev/null
}

#===========================================
# Test 1: Get current player state
#===========================================
echo -e "${BLUE}Test 1: Get attacker's current state${NC}"
echo "----------------------------------------"
PLAYER_STATE=$(curl -s -X GET "$API_URL/player/state" \
  -H "Authorization: Bearer $ATTACKER_TOKEN" \
  -H "Content-Type: application/json")

echo "$PLAYER_STATE" | pretty_json

CURRENT_KINGDOM=$(echo "$PLAYER_STATE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_kingdom_id', ''))" 2>/dev/null)
GOLD=$(echo "$PLAYER_STATE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('gold', 0))" 2>/dev/null)
FIEFS=$(echo "$PLAYER_STATE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('fiefs_ruled', []))" 2>/dev/null)

echo ""
echo "Current Kingdom: $CURRENT_KINGDOM"
echo "Gold: $GOLD"
echo "Fiefs Ruled: $FIEFS"
echo ""

#===========================================
# Test 2: Check for active invasions on target
#===========================================
echo -e "${BLUE}Test 2: Check for active invasions on target kingdom${NC}"
echo "----------------------------------------"
ACTIVE_INVASIONS=$(curl -s -X GET "$API_URL/invasions/active?kingdom_id=$TARGET_KINGDOM" \
  -H "Authorization: Bearer $ATTACKER_TOKEN" \
  -H "Content-Type: application/json")

echo "$ACTIVE_INVASIONS" | pretty_json
echo ""

ACTIVE_COUNT=$(echo "$ACTIVE_INVASIONS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))" 2>/dev/null)
echo "Active invasions: $ACTIVE_COUNT"
echo ""

#===========================================
# Test 3: Declare invasion
#===========================================
echo -e "${YELLOW}Test 3: Declare invasion from $ATTACKING_KINGDOM to $TARGET_KINGDOM${NC}"
echo "----------------------------------------"

DECLARE_RESPONSE=$(curl -s -X POST "$API_URL/invasions/declare" \
  -H "Authorization: Bearer $ATTACKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"attacking_from_kingdom_id\": \"$ATTACKING_KINGDOM\",
    \"target_kingdom_id\": \"$TARGET_KINGDOM\"
  }")

echo "$DECLARE_RESPONSE" | pretty_json

INVASION_ID=$(echo "$DECLARE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('invasion_id', ''))" 2>/dev/null)
SUCCESS=$(echo "$DECLARE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null)
echo ""

if [ "$SUCCESS" = "True" ] && [ -n "$INVASION_ID" ]; then
    echo -e "${GREEN}Invasion declared successfully! ID: $INVASION_ID${NC}"
    echo ""
    
    #===========================================
    # Test 4: Get invasion details
    #===========================================
    echo -e "${BLUE}Test 4: Get invasion details${NC}"
    echo "----------------------------------------"
    
    INVASION_DETAILS=$(curl -s -X GET "$API_URL/invasions/$INVASION_ID" \
      -H "Authorization: Bearer $ATTACKER_TOKEN" \
      -H "Content-Type: application/json")
    
    echo "$INVASION_DETAILS" | pretty_json
    echo ""
    
    BATTLE_TIME=$(echo "$INVASION_DETAILS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('battle_time', ''))" 2>/dev/null)
    TIME_REMAINING=$(echo "$INVASION_DETAILS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('time_remaining_seconds', 0))" 2>/dev/null)
    
    echo "Battle Time: $BATTLE_TIME"
    echo "Time Remaining: ${TIME_REMAINING}s"
    echo ""
    
    #===========================================
    # Test 5: Try to join as attacker (should fail - already joined)
    #===========================================
    echo -e "${BLUE}Test 5: Try to join as attacker (should fail - already joined)${NC}"
    echo "----------------------------------------"
    
    JOIN_ATTACKER=$(curl -s -X POST "$API_URL/invasions/$INVASION_ID/join" \
      -H "Authorization: Bearer $ATTACKER_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"side": "attackers"}')
    
    echo "$JOIN_ATTACKER" | pretty_json
    echo ""
    
    #===========================================
    # Test 6: Join as defender (if defender token provided)
    #===========================================
    if [ -n "$DEFENDER_TOKEN" ]; then
        echo -e "${BLUE}Test 6: Join as defender with second player${NC}"
        echo "----------------------------------------"
        
        # First check defender's state
        DEFENDER_STATE=$(curl -s -X GET "$API_URL/player/state" \
          -H "Authorization: Bearer $DEFENDER_TOKEN" \
          -H "Content-Type: application/json")
        
        DEFENDER_KINGDOM=$(echo "$DEFENDER_STATE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_kingdom_id', ''))" 2>/dev/null)
        echo "Defender's current kingdom: $DEFENDER_KINGDOM"
        
        if [ "$DEFENDER_KINGDOM" = "$TARGET_KINGDOM" ]; then
            JOIN_DEFENDER=$(curl -s -X POST "$API_URL/invasions/$INVASION_ID/join" \
              -H "Authorization: Bearer $DEFENDER_TOKEN" \
              -H "Content-Type: application/json" \
              -d '{"side": "defenders"}')
            
            echo "$JOIN_DEFENDER" | pretty_json
        else
            echo -e "${RED}Defender must be checked in to target kingdom ($TARGET_KINGDOM) to defend${NC}"
        fi
        echo ""
    else
        echo -e "${YELLOW}Test 6: Skipped (no defender token provided)${NC}"
        echo ""
    fi
    
    #===========================================
    # Test 7: Try to resolve (should fail - too early)
    #===========================================
    echo -e "${BLUE}Test 7: Try to resolve invasion (should fail - battle not ready)${NC}"
    echo "----------------------------------------"
    
    EARLY_RESOLVE=$(curl -s -X POST "$API_URL/invasions/$INVASION_ID/resolve" \
      -H "Authorization: Bearer $ATTACKER_TOKEN" \
      -H "Content-Type: application/json")
    
    echo "$EARLY_RESOLVE" | pretty_json
    echo ""
    
    #===========================================
    # Test 8: Get updated invasion status
    #===========================================
    echo -e "${BLUE}Test 8: Get updated invasion status${NC}"
    echo "----------------------------------------"
    
    UPDATED_INVASION=$(curl -s -X GET "$API_URL/invasions/$INVASION_ID" \
      -H "Authorization: Bearer $ATTACKER_TOKEN" \
      -H "Content-Type: application/json")
    
    echo "$UPDATED_INVASION" | pretty_json
    
    ATTACKER_COUNT=$(echo "$UPDATED_INVASION" | python3 -c "import sys, json; print(json.load(sys.stdin).get('attacker_count', 0))" 2>/dev/null)
    DEFENDER_COUNT=$(echo "$UPDATED_INVASION" | python3 -c "import sys, json; print(json.load(sys.stdin).get('defender_count', 0))" 2>/dev/null)
    
    echo ""
    echo "Current participants: $ATTACKER_COUNT attackers, $DEFENDER_COUNT defenders"
    echo ""
    
    #===========================================
    # Summary and next steps
    #===========================================
    echo "========================================"
    echo -e "${GREEN}   Invasion Created Successfully!${NC}"
    echo "========================================"
    echo ""
    echo "Invasion ID: $INVASION_ID"
    echo "Battle Time: $BATTLE_TIME"
    echo "Time Remaining: ${TIME_REMAINING}s (~$((TIME_REMAINING / 60)) minutes)"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Have other players join as attackers (must be at target city):"
    echo "   curl -X POST $API_URL/invasions/$INVASION_ID/join \\"
    echo "     -H 'Authorization: Bearer OTHER_TOKEN' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"side\": \"attackers\"}'"
    echo ""
    echo "2. Have defenders join (must be at target city + from target/allied empire):"
    echo "   curl -X POST $API_URL/invasions/$INVASION_ID/join \\"
    echo "     -H 'Authorization: Bearer DEFENDER_TOKEN' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"side\": \"defenders\"}'"
    echo ""
    echo "3. Wait for battle time, then resolve:"
    echo "   curl -X POST $API_URL/invasions/$INVASION_ID/resolve \\"
    echo "     -H 'Authorization: Bearer $ATTACKER_TOKEN'"
    echo ""
    echo "4. Or use auto-resolve (for background jobs):"
    echo "   curl -X POST $API_URL/invasions/auto-resolve"
    echo ""
    
else
    echo -e "${RED}Failed to declare invasion${NC}"
    echo ""
    echo "Common issues:"
    echo "  - Not enough gold (need 500g)"
    echo "  - You don't rule the attacking kingdom"
    echo "  - Not checked in to target kingdom (must be AT target city)"
    echo "  - Already an active invasion on target"
    echo "  - Cannot invade your own empire"
    echo "  - Cannot invade allied empire"
    echo ""
    
    ERROR=$(echo "$DECLARE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('detail', ''))" 2>/dev/null)
    if [ -n "$ERROR" ]; then
        echo "Error detail: $ERROR"
    fi
fi

echo ""
echo "========================================"
echo "   Documentation"
echo "========================================"
echo ""
echo "Full docs: INVASION_DESIGN_QUESTIONS.md"
echo ""
echo "Key differences from Coups:"
echo "  - Invasions are EXTERNAL (city vs city)"
echo "  - Coups are INTERNAL (within same city)"
echo "  - Invasions have 2-hour warning period"
echo "  - Walls add defense (+5 per level)"
echo "  - Must rule attacking city"
echo "  - Must be AT target city"
echo "  - Cost: 500g per attacker (only initiator pays to declare)"
echo ""
echo "Combat formula:"
echo "  attacker_strength > (defender_strength + wall_defense) * 1.25"
echo ""
echo "Victory outcome:"
echo "  - Initiator becomes ruler of conquered city"
echo "  - City joins attacker's empire"
echo "  - Loot distributed (vault protects some)"
echo "  - Walls damaged (-2 levels)"
echo ""
echo "Failure outcome:"
echo "  - 50% of attacking kingdom treasury transferred to defenders"
echo "  - Attackers lose 10% gold + 100 rep + 1 atk/def/leadership"
echo "  - Defenders gain gold share + 100 rep"
echo ""

#!/bin/bash
# Coup System API Test Script
# Usage: ./test_coup_api.sh YOUR_AUTH_TOKEN YOUR_KINGDOM_ID

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./test_coup_api.sh YOUR_AUTH_TOKEN YOUR_KINGDOM_ID"
    echo ""
    echo "Example: ./test_coup_api.sh eyJhbGc... ashford"
    exit 1
fi

TOKEN="$1"
KINGDOM_ID="$2"
API_URL="http://localhost:8000"

echo "========================================"
echo "🧪 Coup System API Tests"
echo "========================================"
echo ""

# Test 1: Get active coups
echo "📋 Test 1: Get active coups in kingdom $KINGDOM_ID"
echo "----------------------------------------"
curl -s -X GET "$API_URL/coups/active?kingdom_id=$KINGDOM_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | python3 -m json.tool
echo ""
echo ""

# Test 2: Initiate a coup
echo "⚔️  Test 2: Initiate a coup in kingdom $KINGDOM_ID"
echo "----------------------------------------"
INITIATE_RESPONSE=$(curl -s -X POST "$API_URL/coups/initiate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"kingdom_id\": \"$KINGDOM_ID\"}")

echo "$INITIATE_RESPONSE" | python3 -m json.tool

# Extract coup_id from response
COUP_ID=$(echo "$INITIATE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('coup_id', ''))" 2>/dev/null)

echo ""
echo ""

if [ -n "$COUP_ID" ]; then
    # Test 3: Get coup details
    echo "🔍 Test 3: Get details for coup $COUP_ID"
    echo "----------------------------------------"
    curl -s -X GET "$API_URL/coups/$COUP_ID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" | python3 -m json.tool
    echo ""
    echo ""
    
    # Test 4: Try to join (should fail since initiator already joined)
    echo "👥 Test 4: Try to join coup (should fail - already joined)"
    echo "----------------------------------------"
    curl -s -X POST "$API_URL/coups/$COUP_ID/join" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"side\": \"attackers\"}" | python3 -m json.tool
    echo ""
    echo ""
    
    echo "✅ Coup created successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Use another user to join: curl -X POST $API_URL/coups/$COUP_ID/join -H 'Authorization: Bearer OTHER_TOKEN' -d '{\"side\": \"defenders\"}'"
    echo "2. Wait 2 hours or force resolve: curl -X POST $API_URL/coups/$COUP_ID/resolve -H 'Authorization: Bearer $TOKEN'"
    echo ""
else
    echo "❌ Failed to create coup. Check the error message above."
    echo ""
    echo "Common issues:"
    echo "- Not enough reputation (need 300+)"
    echo "- Not enough gold (need 50)"
    echo "- Not checked in to kingdom"
    echo "- Already a ruler of this kingdom"
    echo "- Coup cooldown active (24h)"
    echo ""
fi

echo "========================================"
echo "📚 Documentation: COUP_SYSTEM_IMPLEMENTATION.md"
echo "========================================"


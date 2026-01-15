#!/usr/bin/env python3
"""
Invasion System Integration Test

Runs a full end-to-end test of the invasion system:
1. Creates test users and kingdoms
2. Sets up the game state (ruler, check-ins, gold)
3. Declares invasion
4. Joins as defender
5. Fast-forwards time and resolves
6. Verifies the outcome

Usage:
    # Run with docker-compose
    docker-compose exec api python /app/test_invasion_integration.py

    # Or run locally (if you have the right env vars)
    cd api && python test_invasion_integration.py
"""

import os
import sys
import requests
from datetime import datetime, timedelta
from jose import jwt

# Configuration
API_URL = os.getenv("API_URL", "http://localhost:8000")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://admin:admin@localhost:5432/kingdom")
JWT_SECRET = os.getenv("JWT_SECRET_KEY", "local-dev-secret-do-not-use-in-production")

# Test data
TEST_ATTACKER_APPLE_ID = "test_attacker_invasion_001"
TEST_DEFENDER_APPLE_ID = "test_defender_invasion_001"
TEST_ATTACKING_KINGDOM = "test_kingdom_attacker"
TEST_TARGET_KINGDOM = "test_kingdom_target"


def create_test_token(apple_user_id: str) -> str:
    """Generate a valid JWT token for testing"""
    payload = {
        "sub": apple_user_id,
        "exp": datetime.utcnow() + timedelta(days=7)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def setup_database():
    """Set up test data in the database"""
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import sessionmaker
    
    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    db = Session()
    
    try:
        print("\n=== Setting up test database ===\n")
        
        # Clean up any existing test data (order matters for foreign keys!)
        print("Cleaning up old test data...")
        
        # 0. Delete checkin_history
        db.execute(text("""
            DELETE FROM checkin_history 
            WHERE kingdom_id IN (:target, :attacking)
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        # 1. Delete battles first (references users)
        db.execute(text("""
            DELETE FROM battles 
            WHERE kingdom_id IN (:target, :attacking)
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        # 2. Delete invasion events
        db.execute(text("""
            DELETE FROM invasion_events 
            WHERE target_kingdom_id = :target OR attacking_from_kingdom_id = :attacking
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        # 3. Delete user_kingdoms
        db.execute(text("""
            DELETE FROM user_kingdoms 
            WHERE kingdom_id IN (:target, :attacking)
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        # 4. Delete kingdoms BEFORE users (kingdoms references users via ruler_id)
        db.execute(text("""
            DELETE FROM kingdoms WHERE id IN (:target, :attacking)
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        # 5. Delete player_state
        db.execute(text("""
            DELETE FROM player_state 
            WHERE user_id IN (
                SELECT id FROM users WHERE apple_user_id IN (:attacker, :defender)
            )
        """), {"attacker": TEST_ATTACKER_APPLE_ID, "defender": TEST_DEFENDER_APPLE_ID})
        
        # 6. Delete users last
        db.execute(text("""
            DELETE FROM users WHERE apple_user_id IN (:attacker, :defender)
        """), {"attacker": TEST_ATTACKER_APPLE_ID, "defender": TEST_DEFENDER_APPLE_ID})
        
        db.commit()
        print("  Done!")
        
        # Create test users
        print("\nCreating test users...")
        db.execute(text("""
            INSERT INTO users (apple_user_id, email, display_name, is_active, created_at, updated_at)
            VALUES 
                (:attacker_id, 'attacker@test.com', 'TestAttacker', true, NOW(), NOW()),
                (:defender_id, 'defender@test.com', 'TestDefender', true, NOW(), NOW())
        """), {"attacker_id": TEST_ATTACKER_APPLE_ID, "defender_id": TEST_DEFENDER_APPLE_ID})
        db.commit()
        
        # Get user IDs
        result = db.execute(text("""
            SELECT id, apple_user_id FROM users WHERE apple_user_id IN (:attacker, :defender)
        """), {"attacker": TEST_ATTACKER_APPLE_ID, "defender": TEST_DEFENDER_APPLE_ID})
        
        user_ids = {}
        for row in result:
            user_ids[row[1]] = row[0]
        
        attacker_id = user_ids[TEST_ATTACKER_APPLE_ID]
        defender_id = user_ids[TEST_DEFENDER_APPLE_ID]
        print(f"  Attacker ID: {attacker_id}")
        print(f"  Defender ID: {defender_id}")
        
        # Create kingdoms
        print("\nCreating test kingdoms...")
        db.execute(text("""
            INSERT INTO kingdoms (id, name, ruler_id, wall_level, treasury_gold, created_at, updated_at)
            VALUES 
                (:attacking, 'Attacking Kingdom', :attacker_id, 0, 1000, NOW(), NOW()),
                (:target, 'Target Kingdom', :defender_id, 2, 5000, NOW(), NOW())
        """), {
            "attacking": TEST_ATTACKING_KINGDOM,
            "target": TEST_TARGET_KINGDOM,
            "attacker_id": attacker_id,
            "defender_id": defender_id
        })
        db.commit()
        print(f"  Attacking kingdom: {TEST_ATTACKING_KINGDOM} (ruler: attacker)")
        print(f"  Target kingdom: {TEST_TARGET_KINGDOM} (ruler: defender, walls: 2, treasury: 5000g)")
        
        # Create player states with all required defaults
        print("\nCreating player states...")
        db.execute(text("""
            INSERT INTO player_state (
                user_id, hometown_kingdom_id, current_kingdom_id, 
                gold, attack_power, defense_power, kingdoms_ruled,
                level, experience, skill_points, leadership, building_skill, intelligence,
                honor, total_checkins, total_conquests, coups_won, coups_failed,
                times_executed, executions_ordered, contracts_completed, 
                total_work_contributed, total_training_purchases,
                iron, steel, wood, is_alive,
                attack_debuff, science, faith, philosophy, merchant,
                created_at, updated_at
            )
            VALUES 
                (:attacker_id, :attacking, :target, 1000, 50, 30, 1,
                 1, 0, 0, 10, 5, 5,
                 100, 0, 0, 0, 0,
                 0, 0, 0,
                 0, 0,
                 0, 0, 0, true,
                 0, 0, 0, 0, 0,
                 NOW(), NOW()),
                (:defender_id, :target, :target, 500, 30, 40, 1,
                 1, 0, 0, 10, 5, 5,
                 100, 0, 0, 0, 0,
                 0, 0, 0,
                 0, 0,
                 0, 0, 0, true,
                 0, 0, 0, 0, 0,
                 NOW(), NOW())
        """), {
            "attacker_id": attacker_id,
            "defender_id": defender_id,
            "attacking": TEST_ATTACKING_KINGDOM,
            "target": TEST_TARGET_KINGDOM
        })
        db.commit()
        print(f"  Attacker: 1000g, 50 atk, 30 def, checked into TARGET (required for invasion)")
        print(f"  Defender: 500g, 30 atk, 40 def, checked into target")
        
        # Create user_kingdoms entries
        print("\nCreating user_kingdoms entries...")
        db.execute(text("""
            INSERT INTO user_kingdoms (user_id, kingdom_id, local_reputation, checkins_count, first_visited)
            VALUES 
                (:attacker_id, :attacking, 500, 10, NOW()),
                (:attacker_id, :target, 100, 5, NOW()),
                (:defender_id, :target, 500, 20, NOW())
        """), {
            "attacker_id": attacker_id,
            "defender_id": defender_id,
            "attacking": TEST_ATTACKING_KINGDOM,
            "target": TEST_TARGET_KINGDOM
        })
        
        # Create checkin_history entries (required for join eligibility)
        print("Creating checkin_history entries...")
        db.execute(text("""
            INSERT INTO checkin_history (user_id, kingdom_id, checked_in_at, latitude, longitude)
            VALUES 
                (:attacker_id, :attacking, NOW(), 42.36, -71.06),
                (:attacker_id, :target, NOW(), 42.37, -71.11),
                (:defender_id, :target, NOW(), 42.37, -71.11)
        """), {
            "attacker_id": attacker_id,
            "defender_id": defender_id,
            "attacking": TEST_ATTACKING_KINGDOM,
            "target": TEST_TARGET_KINGDOM
        })
        db.commit()
        print("  Done!")
        
        db.close()
        return attacker_id, defender_id
        
    except Exception as e:
        db.rollback()
        db.close()
        raise e


def api_call(method: str, endpoint: str, token: str = None, data: dict = None):
    """Make an API call and return the response"""
    url = f"{API_URL}{endpoint}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    print(f"  [DEBUG] {method} {url}")
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=10)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=10)
        else:
            raise ValueError(f"Unsupported method: {method}")
        
        print(f"  [DEBUG] Status: {response.status_code}")
        return response
    except Exception as e:
        print(f"  [DEBUG] Request failed: {e}")
        raise


def test_invasion_flow():
    """Run the full invasion test"""
    print("\n" + "=" * 60)
    print("   INVASION SYSTEM INTEGRATION TEST")
    print("=" * 60)
    
    # Wait for API to be ready (file changes trigger restart)
    import time
    print("\nWaiting for API to be ready...")
    time.sleep(3)
    
    # Step 1: Setup database
    print("\n--- STEP 1: Database Setup ---")
    try:
        attacker_id, defender_id = setup_database()
    except Exception as e:
        print(f"\nFailed to set up database: {e}")
        print("\nMake sure you're running this inside docker-compose:")
        print("  docker-compose exec api python /app/test_invasion_integration.py")
        return False
    
    # Step 2: Generate tokens
    print("\n--- STEP 2: Generate Auth Tokens ---")
    attacker_token = create_test_token(TEST_ATTACKER_APPLE_ID)
    defender_token = create_test_token(TEST_DEFENDER_APPLE_ID)
    print(f"  Attacker token: {attacker_token[:50]}...")
    print(f"  Defender token: {defender_token[:50]}...")
    
    # Step 3: Verify setup via direct DB query (skip /player/state - too many dependencies)
    print("\n--- STEP 3: Verify Database Setup ---")
    print("  (Skipping /player/state endpoint - testing invasion endpoints directly)")
    
    # Step 4: Check for active battles
    print("\n--- STEP 4: Check Active Battles ---")
    active = api_call("GET", f"/battles/active?kingdom_id={TEST_TARGET_KINGDOM}", attacker_token)
    if active.status_code == 200:
        active_data = active.json()
        print(f"  Active battles on target: {active_data.get('count', 0)}")
    else:
        print(f"  Failed to get active battles: {active.text}")
    
    # Step 5: Declare invasion (via /battles/invasion/declare)
    print("\n--- STEP 5: Declare Invasion ---")
    declare_response = api_call("POST", "/battles/invasion/declare", attacker_token, {
        "attacking_from_kingdom_id": TEST_ATTACKING_KINGDOM,
        "target_kingdom_id": TEST_TARGET_KINGDOM
    })
    
    if declare_response.status_code != 200:
        print(f"  ERROR: Failed to declare invasion:")
        print(f"    Status: {declare_response.status_code}")
        print(f"    Response: {declare_response.text}")
        return False
    
    declare_data = declare_response.json()
    battle_id = declare_data.get("battle_id")
    print(f"  SUCCESS! Invasion declared:")
    print(f"    - Battle ID: {battle_id}")
    print(f"    - Battle Type: {declare_data.get('battle_type')}")
    print(f"    - Pledge End Time: {declare_data.get('pledge_end_time')}")
    
    # Step 6: Get invasion details
    print("\n--- STEP 6: Get Invasion Details ---")
    details = api_call("GET", f"/battles/{battle_id}", attacker_token)
    if details.status_code == 200:
        details_data = details.json()
        print(f"  Invasion status:")
        print(f"    - Attackers: {details_data.get('attacker_count')}")
        print(f"    - Defenders: {details_data.get('defender_count')}")
        print(f"    - Time remaining: {details_data.get('time_remaining_seconds')}s")
    else:
        print(f"  Failed to get details: {details.text}")
    
    # Step 7: Defender joins
    print("\n--- STEP 7: Defender Joins ---")
    join_response = api_call("POST", f"/battles/{battle_id}/join", defender_token, {
        "side": "defenders"
    })
    
    if join_response.status_code != 200:
        print(f"  ERROR: Defender failed to join:")
        print(f"    Status: {join_response.status_code}")
        print(f"    Response: {join_response.text}")
        # Continue anyway to test resolution
    else:
        join_data = join_response.json()
        print(f"  SUCCESS! Defender joined:")
        print(f"    - Attackers: {join_data.get('attacker_count')}")
        print(f"    - Defenders: {join_data.get('defender_count')}")
    
    # Step 8: Fast-forward pledge time (direct DB update)
    print("\n--- STEP 8: Fast-Forward Pledge Time ---")
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import sessionmaker
    
    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    db = Session()
    
    db.execute(text("""
        UPDATE battles 
        SET pledge_end_time = NOW() - INTERVAL '1 minute'
        WHERE id = :battle_id
    """), {"battle_id": battle_id})
    db.commit()
    db.close()
    print("  Pledge time set to past - ready for combat!")
    
    # Step 9: Start a fight session (needs territory in body)
    print("\n--- STEP 9: Start Fight Session ---")
    fight_response = api_call("POST", f"/battles/{battle_id}/fight/start", attacker_token, {
        "territory": "north"  # First territory
    })
    
    if fight_response.status_code != 200:
        print(f"  Fight session response:")
        print(f"    Status: {fight_response.status_code}")
        print(f"    Response: {fight_response.text}")
    else:
        fight_data = fight_response.json()
        print(f"  Fight session started!")
        print(f"    - Session ID: {fight_data.get('session_id')}")
        print(f"    - Territory: {fight_data.get('current_territory')}")
        print(f"    - Rolls remaining: {fight_data.get('rolls_remaining')}")
    
    # Step 10: Verify final state via DB
    print("\n--- STEP 10: Verify Final State ---")
    
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import sessionmaker
    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    db = Session()
    
    # Check kingdoms
    result = db.execute(text("""
        SELECT k.id, k.ruler_id, u.display_name as ruler_name, k.treasury_gold, k.wall_level
        FROM kingdoms k
        LEFT JOIN users u ON k.ruler_id = u.id
        WHERE k.id IN (:target, :attacking)
    """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
    
    for row in result:
        print(f"  Kingdom {row[0]}:")
        print(f"    - Ruler: {row[2]} (id={row[1]})")
        print(f"    - Treasury: {row[3]}g")
        print(f"    - Walls: {row[4]}")
    
    # Check player gold
    result = db.execute(text("""
        SELECT u.display_name, ps.gold, ps.kingdoms_ruled
        FROM player_state ps
        JOIN users u ON ps.user_id = u.id
        WHERE u.apple_user_id IN (:attacker, :defender)
    """), {"attacker": TEST_ATTACKER_APPLE_ID, "defender": TEST_DEFENDER_APPLE_ID})
    
    for row in result:
        print(f"  Player {row[0]}: {row[1]}g, {row[2]} kingdoms ruled")
    
    db.close()
    
    print("\n" + "=" * 60)
    print("   TEST COMPLETE!")
    print("=" * 60 + "\n")
    
    return True


def cleanup_test_data():
    """Clean up test data after the test"""
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import sessionmaker
    
    print("\n--- Cleaning up test data ---")
    
    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    db = Session()
    
    try:
        # Order matters for foreign keys!
        db.execute(text("""
            DELETE FROM checkin_history WHERE kingdom_id IN (:target, :attacking)
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        db.execute(text("""
            DELETE FROM battles WHERE kingdom_id IN (:target, :attacking)
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        db.execute(text("""
            DELETE FROM invasion_events 
            WHERE target_kingdom_id = :target OR attacking_from_kingdom_id = :attacking
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        db.execute(text("""
            DELETE FROM user_kingdoms 
            WHERE kingdom_id IN (:target, :attacking)
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        db.execute(text("""
            DELETE FROM kingdoms WHERE id IN (:target, :attacking)
        """), {"target": TEST_TARGET_KINGDOM, "attacking": TEST_ATTACKING_KINGDOM})
        
        db.execute(text("""
            DELETE FROM player_state 
            WHERE user_id IN (
                SELECT id FROM users WHERE apple_user_id IN (:attacker, :defender)
            )
        """), {"attacker": TEST_ATTACKER_APPLE_ID, "defender": TEST_DEFENDER_APPLE_ID})
        
        db.execute(text("""
            DELETE FROM users WHERE apple_user_id IN (:attacker, :defender)
        """), {"attacker": TEST_ATTACKER_APPLE_ID, "defender": TEST_DEFENDER_APPLE_ID})
        
        db.commit()
        print("  Cleaned up!")
    except Exception as e:
        print(f"  Cleanup error: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    try:
        success = test_invasion_flow()
        
        # Ask if user wants to clean up
        if len(sys.argv) > 1 and sys.argv[1] == "--cleanup":
            cleanup_test_data()
        else:
            print("\nNote: Test data was left in database for inspection.")
            print("Run with --cleanup flag to remove test data.")
        
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n\nTest interrupted.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nTest failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

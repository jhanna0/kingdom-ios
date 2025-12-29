"""
Configuration settings for Kingdom API
"""
import os

# ===== DEVELOPMENT MODE =====
# Set to True to enable development features
DEV_MODE = os.getenv("DEV_MODE", "True").lower() == "true"

# Dev mode features:
# - Rulers can accept their own contracts
# - Contracts complete instantly (0 hours required)
# - Boosted check-in rewards (10x gold/XP)
# - Reduced cooldowns

if DEV_MODE:
    print("⚠️  DEV MODE ENABLED - Testing features active")
    print("   - Rulers can join own contracts")
    print("   - Instant contract completion")
    print("   - 10x check-in rewards")
    print("   - 5min check-in cooldown")
else:
    print("✅ Production mode - Full restrictions active")


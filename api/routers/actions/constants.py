"""
Central configuration for action cooldowns and constants
"""

# Action cooldowns (in minutes)
WORK_BASE_COOLDOWN = 120  # 2 hours
PATROL_COOLDOWN = 10  # 10 minutes
SABOTAGE_COOLDOWN = 120  # 2 hours
SCOUT_COOLDOWN = 120  # 2 hours
TRAINING_COOLDOWN = 120  # 2 hours
CRAFTING_BASE_COOLDOWN = 120  # 2 hours (same as work)

# Vault heist configuration
VAULT_HEIST_COOLDOWN = 10080  # 7 days in minutes
VAULT_HEIST_COOLDOWN_HOURS = 168  # Once per week (7 days)
MIN_INTELLIGENCE_REQUIRED = 5  # Must have Intelligence T5 to attempt
HEIST_COST = 1000  # Gold cost to attempt heist
HEIST_PERCENT = 0.10  # Steal 10% of vault
MIN_HEIST_AMOUNT = 500  # Minimum vault size to target
BASE_HEIST_DETECTION = 0.3  # 30% base detection chance
VAULT_LEVEL_BONUS = 0.05  # +5% detection per vault level
INTELLIGENCE_REDUCTION = 0.04  # -4% detection per intelligence above 5
PATROL_BONUS = 0.02  # +2% detection per active patrol
HEIST_REP_LOSS = 500  # Reputation lost in target kingdom when caught
HEIST_BAN = True  # Whether to ban from kingdom when caught

# Action rewards
SCOUT_GOLD_REWARD = 10
PATROL_GOLD_REWARD = 5
PATROL_REPUTATION_REWARD = 10

# Patrol duration
PATROL_DURATION_MINUTES = 10


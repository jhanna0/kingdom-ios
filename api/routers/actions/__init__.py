"""
Actions Router - Combines all action endpoints into a single router

This module organizes action endpoints into logical groupings:
- status: Get cooldown status for all actions
- contracts: Work on building contracts
- patrol: Start patrols to guard kingdoms
- scouting: Scout enemy kingdoms for intelligence
- training: Purchase and complete stat training
- crafting: Purchase and craft weapons/armor
- sabotage: Sabotage enemy kingdom contracts
- vault_heist: Steal from enemy kingdom vaults (Intelligence T5)
"""
from fastapi import APIRouter

from . import status, contracts, patrol, scouting, training, crafting, sabotage, vault_heist

# Main actions router
router = APIRouter(prefix="/actions", tags=["actions"])

# Include all sub-routers
router.include_router(status.router)
router.include_router(contracts.router)
router.include_router(patrol.router)
router.include_router(scouting.router)
router.include_router(training.router)
router.include_router(crafting.router)
router.include_router(sabotage.router)
router.include_router(vault_heist.router)


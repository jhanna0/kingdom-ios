"""
Actions Router - Combines all action endpoints into a single router

This module organizes action endpoints into logical groupings:
- status: Get cooldown status for all actions
- contracts: Work on building contracts
- patrol: Start patrols to guard kingdoms
- farming: Farm to generate gold (always available)
- training: Purchase and complete stat training
- crafting: Purchase and craft weapons/armor
- gathering: Click-to-gather resources (wood/iron) with roll system

HOSTILE INTEL OPERATIONS (sabotage, vault_heist) are now OUTCOMES of the
incident system at /incidents. One button "Covert Operation" - outcomes
scale with Intelligence tier (T1: intel, T3: +disruption, T5: +sabotage/heist)
"""
from fastapi import APIRouter

from . import status, contracts, patrol, farming, training, crafting, gathering, catchup

# Main actions router
router = APIRouter(prefix="/actions", tags=["actions"])

# Include all sub-routers
router.include_router(status.router)
router.include_router(contracts.router)
router.include_router(patrol.router)
router.include_router(farming.router)
router.include_router(training.router)
router.include_router(crafting.router)
router.include_router(gathering.router)
router.include_router(catchup.router)

# NOTE: sabotage and vault_heist removed - now incident outcomes at /incidents


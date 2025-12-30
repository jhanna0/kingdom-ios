"""
Centralized tax collection system

When citizens earn money from actions, a portion goes to the kingdom treasury based on tax rate.
Tax is applied AFTER any perks or bonuses (e.g., building skill bonuses).
"""
from sqlalchemy.orm import Session
from db import Kingdom, PlayerState
from typing import Tuple


def apply_kingdom_tax(
    db: Session,
    kingdom_id: str,
    player_state: PlayerState,
    gross_income: int
) -> Tuple[int, int, int]:
    """
    Apply kingdom tax to player's income.
    
    Args:
        db: Database session
        kingdom_id: Kingdom where income was earned
        player_state: Player earning the income
        gross_income: Total income AFTER perks/bonuses
    
    Returns:
        Tuple of (net_income, tax_amount, tax_rate):
        - net_income: Amount player receives after tax
        - tax_amount: Amount sent to kingdom treasury
        - tax_rate: Tax rate percentage that was applied
    
    Notes:
        - Rulers are exempt from taxes in their own kingdom
        - Tax is rounded down (int division)
        - Tax is added to kingdom treasury automatically
    """
    if gross_income <= 0:
        return (gross_income, 0, 0)
    
    # Get kingdom
    kingdom = db.query(Kingdom).filter(Kingdom.id == kingdom_id).first()
    if not kingdom:
        # Kingdom not found, no tax
        return (gross_income, 0, 0)
    
    # Check if player is the ruler (rulers don't pay tax in their own kingdom)
    if kingdom.ruler_id and kingdom.ruler_id == player_state.user_id:
        return (gross_income, 0, 0)
    
    # Calculate tax
    tax_rate = kingdom.tax_rate
    tax_amount = int(gross_income * tax_rate / 100)
    net_income = gross_income - tax_amount
    
    # Add tax to kingdom treasury
    if tax_amount > 0:
        kingdom.treasury_gold += tax_amount
    
    return (net_income, tax_amount, tax_rate)


def apply_kingdom_tax_with_bonus(
    db: Session,
    kingdom_id: str,
    player_state: PlayerState,
    base_income: int,
    bonus_multiplier: float = 1.0
) -> Tuple[int, int, int, int]:
    """
    Apply kingdom tax to player's income, accounting for bonuses.
    
    This is a helper that applies bonuses BEFORE tax, then taxes the result.
    Use this when you have a base income and want to apply perks first.
    
    Args:
        db: Database session
        kingdom_id: Kingdom where income was earned
        player_state: Player earning the income
        base_income: Base income before any perks
        bonus_multiplier: Multiplier for perks (e.g., 1.1 for +10%)
    
    Returns:
        Tuple of (net_income, tax_amount, tax_rate, gross_income):
        - net_income: Amount player receives after tax
        - tax_amount: Amount sent to kingdom treasury
        - tax_rate: Tax rate percentage that was applied
        - gross_income: Income after bonus but before tax
    """
    # Apply bonus first
    gross_income = int(base_income * bonus_multiplier)
    
    # Then apply tax
    net_income, tax_amount, tax_rate = apply_kingdom_tax(
        db, kingdom_id, player_state, gross_income
    )
    
    return (net_income, tax_amount, tax_rate, gross_income)


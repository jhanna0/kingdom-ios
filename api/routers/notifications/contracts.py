"""
Contract updates and notifications
"""
from sqlalchemy.orm import Session
from typing import Dict, Any, List
from db import User, Contract, Kingdom


def build_contract_updates(db: Session, user: User) -> Dict[str, List[Dict[str, Any]]]:
    """Build contract updates (ready to complete and in progress)"""
    
    user_id_str = str(user.id)
    
    # Get all contracts and filter by user contributions
    all_contracts = db.query(Contract).all()
    
    # Ready to complete - contracts user contributed to that are now completed
    ready_contracts_list = []
    for contract in all_contracts:
        if (contract.status == 'completed' and 
            contract.action_contributions and 
            user_id_str in contract.action_contributions):
            
            kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
            
            # Calculate user's reward based on contribution
            user_contribution = contract.action_contributions.get(user_id_str, 0)
            user_reward = int((user_contribution / contract.actions_completed) * contract.reward_pool) if contract.actions_completed > 0 else 0
            
            ready_contracts_list.append({
                "id": contract.id,
                "kingdom_name": kingdom.name if kingdom else "Unknown",
                "building_type": contract.building_type,
                "building_level": contract.building_level,
                "reward": user_reward
            })
    
    # In progress - contracts user is currently contributing to
    in_progress_list = []
    for contract in all_contracts:
        if (contract.status == 'in_progress' and 
            contract.action_contributions and 
            user_id_str in contract.action_contributions):
            
            kingdom = db.query(Kingdom).filter(Kingdom.id == contract.kingdom_id).first()
            progress = contract.actions_completed / contract.total_actions_required if contract.total_actions_required > 0 else 0
            user_contribution = contract.action_contributions.get(user_id_str, 0)
            
            in_progress_list.append({
                "id": contract.id,
                "kingdom_name": kingdom.name if kingdom else "Unknown",
                "building_type": contract.building_type,
                "progress": progress,
                "actions_remaining": contract.total_actions_required - contract.actions_completed,
                "actions_completed": contract.actions_completed,
                "total_actions_required": contract.total_actions_required
            })
    
    return {
        "ready_to_complete": ready_contracts_list,
        "in_progress": in_progress_list
    }


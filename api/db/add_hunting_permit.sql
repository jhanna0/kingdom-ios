-- Add hunting permit columns for visitor hunting
-- Allows players to hunt in kingdoms other than their hometown

ALTER TABLE player_state
ADD COLUMN IF NOT EXISTS hunting_permit_kingdom_id VARCHAR(255) DEFAULT NULL;

ALTER TABLE player_state
ADD COLUMN IF NOT EXISTS hunting_permit_expires_at TIMESTAMP DEFAULT NULL;

-- Add comments for documentation
COMMENT ON COLUMN player_state.hunting_permit_kingdom_id IS 'Kingdom ID where hunting permit is valid';
COMMENT ON COLUMN player_state.hunting_permit_expires_at IS 'When the hunting permit expires (10 minutes from purchase)';

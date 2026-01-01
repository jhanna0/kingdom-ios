-- Add travel fee system to kingdoms
-- Players must pay this fee when entering a kingdom (unless they rule it)
-- Fee goes to the kingdom's treasury

ALTER TABLE kingdoms 
ADD COLUMN IF NOT EXISTS travel_fee INTEGER DEFAULT 10;

-- Update existing kingdoms to have a default travel fee
UPDATE kingdoms 
SET travel_fee = 10 
WHERE travel_fee IS NULL;




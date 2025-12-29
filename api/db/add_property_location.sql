-- Add location field to properties table
-- Allows players to choose which side of the kingdom their property is on

ALTER TABLE properties 
ADD COLUMN IF NOT EXISTS location VARCHAR(10);


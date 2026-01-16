-- Set all cities to market level 1
UPDATE kingdoms
SET market_level = 1
WHERE market_level != 1;

-- Verify the update
SELECT COUNT(*) as cities_with_market_1 FROM kingdoms WHERE market_level = 1;
SELECT COUNT(*) as total_cities FROM kingdoms;

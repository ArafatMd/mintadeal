-- A product a shop delivers anywhere in Bengaluru, even when the shop's own city-wide delivery is off.
-- With the shop's city-wide delivery on, every product is delivered city-wide anyway.
ALTER TABLE listing ADD COLUMN citywide BOOLEAN NOT NULL DEFAULT FALSE;

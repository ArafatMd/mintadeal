-- Whether the shop placed its own pin (GPS or map), rather than the centre of its area.
ALTER TABLE vendor ADD COLUMN location_pinned BOOLEAN NOT NULL DEFAULT FALSE;

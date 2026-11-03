-- How customers reacted to a stall: opening its page, and tapping Call, WhatsApp or Directions.
-- Only admins see these; they share a report with the seller on request.
ALTER TABLE popup ADD COLUMN view_count       INTEGER NOT NULL DEFAULT 0;
ALTER TABLE popup ADD COLUMN call_count       INTEGER NOT NULL DEFAULT 0;
ALTER TABLE popup ADD COLUMN whatsapp_count   INTEGER NOT NULL DEFAULT 0;
ALTER TABLE popup ADD COLUMN directions_count INTEGER NOT NULL DEFAULT 0;

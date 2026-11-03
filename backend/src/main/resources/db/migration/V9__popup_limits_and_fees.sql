-- How many stalls a seller may run at once and what a stall costs, for shops and for other sellers.
-- One row; admins change it in the admin website.
CREATE TABLE popup_settings (
    id                       INTEGER PRIMARY KEY CHECK (id = 1),
    shop_max_live            INTEGER     NOT NULL,
    shop_fee_per_day_minor   BIGINT      NOT NULL,
    seller_max_live          INTEGER     NOT NULL,
    seller_fee_per_day_minor BIGINT      NOT NULL,
    updated_at               TIMESTAMPTZ NOT NULL,
    version                  BIGINT      NOT NULL
);
INSERT INTO popup_settings VALUES (1, 1, 0, 1, 0, now(), 0);

-- An admin's choice for one seller; null uses the defaults above.
ALTER TABLE popup_seller ADD COLUMN max_live INTEGER;
ALTER TABLE popup_seller ADD COLUMN fee_per_day_minor BIGINT;

-- A stall run by an approved shop, shown with the shop's name and a link to it.
ALTER TABLE popup ADD COLUMN vendor_id UUID REFERENCES vendor (id);
ALTER TABLE popup ADD COLUMN vendor_name VARCHAR(120);
-- The listing fee: charged to the shop's balance, or paid online by other sellers before the stall goes live.
ALTER TABLE popup ADD COLUMN fee_minor BIGINT NOT NULL DEFAULT 0;
ALTER TABLE popup ADD COLUMN payment_provider VARCHAR(20);
ALTER TABLE popup ADD COLUMN payment_reference VARCHAR(80);
ALTER TABLE popup ADD COLUMN payment_url VARCHAR(500);
ALTER TABLE popup ADD COLUMN payment_id VARCHAR(80);
ALTER TABLE popup ADD COLUMN payment_deadline TIMESTAMPTZ;
ALTER TABLE popup ADD COLUMN paid_at TIMESTAMPTZ;
CREATE INDEX idx_popup_payment ON popup (payment_reference);

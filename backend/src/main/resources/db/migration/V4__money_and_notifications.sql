-- Stage 5: commission rules. A row with no category is the default rate.
CREATE TABLE commission_rule (
    id         UUID PRIMARY KEY,
    category   VARCHAR(30) UNIQUE,
    rate_bps   INT         NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMPTZ NOT NULL,
    version    BIGINT      NOT NULL
);
CREATE UNIQUE INDEX uq_commission_default ON commission_rule ((category IS NULL)) WHERE category IS NULL;

-- The rate is fixed when the order is placed; the amount is taken when it completes.
ALTER TABLE shop_order ADD COLUMN commission_bps INT NOT NULL DEFAULT 0;
ALTER TABLE shop_order ADD COLUMN commission_minor BIGINT;

-- Double-entry ledger: every journal's entries sum to zero. Debits are positive, credits negative.
CREATE TABLE ledger_journal (
    id          UUID PRIMARY KEY,
    journal_type VARCHAR(30)  NOT NULL,
    reference_id UUID         NOT NULL,
    description  VARCHAR(300) NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL
);
CREATE UNIQUE INDEX uq_journal_type_reference ON ledger_journal (journal_type, reference_id);

CREATE TABLE ledger_entry (
    id           UUID PRIMARY KEY,
    journal_id   UUID        NOT NULL REFERENCES ledger_journal (id),
    account      VARCHAR(40) NOT NULL,
    vendor_id    UUID REFERENCES vendor (id),
    amount_minor BIGINT      NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_ledger_entry_account ON ledger_entry (account, vendor_id);
CREATE INDEX idx_ledger_entry_journal ON ledger_entry (journal_id);

-- Payouts to shops, created in batches by an admin.
CREATE TABLE payout_batch (
    id           UUID PRIMARY KEY,
    created_by   UUID         NOT NULL,
    payout_count INT          NOT NULL,
    total_minor  BIGINT       NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL
);

CREATE TABLE payout (
    id                 UUID PRIMARY KEY,
    batch_id           UUID         NOT NULL REFERENCES payout_batch (id),
    vendor_id          UUID         NOT NULL REFERENCES vendor (id),
    vendor_name        VARCHAR(120) NOT NULL,
    amount_minor       BIGINT       NOT NULL,
    status             VARCHAR(20)  NOT NULL,
    method             VARCHAR(20),
    destination        VARCHAR(120) NOT NULL,
    provider_payout_id VARCHAR(100),
    utr                VARCHAR(60),
    failure_reason     VARCHAR(500),
    created_at         TIMESTAMPTZ  NOT NULL,
    sent_at            TIMESTAMPTZ,
    paid_at            TIMESTAMPTZ,
    version            BIGINT       NOT NULL
);
CREATE INDEX idx_payout_vendor ON payout (vendor_id, created_at DESC);
CREATE INDEX idx_payout_status ON payout (status);
CREATE INDEX idx_payout_provider ON payout (provider_payout_id);

-- Every WhatsApp/SMS message we tried to send.
CREATE TABLE notification (
    id          UUID PRIMARY KEY,
    event       VARCHAR(40)  NOT NULL,
    channel     VARCHAR(20)  NOT NULL,
    recipient   VARCHAR(20)  NOT NULL,
    order_id    UUID,
    status      VARCHAR(20)  NOT NULL,
    provider_id VARCHAR(120),
    error       VARCHAR(500),
    created_at  TIMESTAMPTZ  NOT NULL
);
CREATE INDEX idx_notification_created ON notification (created_at DESC);

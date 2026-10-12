-- Admin-managed integration settings (Razorpay, 2Factor). Secrets are AES-GCM encrypted by the application.
CREATE TABLE integration_setting (
    provider      VARCHAR(30) PRIMARY KEY,
    enabled       BOOLEAN      NOT NULL,
    config_json   TEXT         NOT NULL,
    secret_cipher TEXT,
    updated_by    UUID,
    updated_at    TIMESTAMPTZ  NOT NULL,
    version       BIGINT       NOT NULL
);

-- Stage 3: one checkout per customer purchase, split into one shop order per vendor.
CREATE TABLE checkout (
    id                   UUID PRIMARY KEY,
    code                 VARCHAR(20)  NOT NULL UNIQUE,
    customer_id          UUID         NOT NULL REFERENCES app_user (id),
    client_request_id    VARCHAR(64)  NOT NULL,
    payment_method       VARCHAR(20)  NOT NULL,
    payment_status       VARCHAR(20)  NOT NULL,
    payment_provider     VARCHAR(20),
    payment_reference    VARCHAR(100),
    payment_url          VARCHAR(500),
    provider_payment_id  VARCHAR(100),
    payment_deadline     TIMESTAMPTZ,
    paid_at              TIMESTAMPTZ,
    items_total_minor    BIGINT       NOT NULL,
    delivery_total_minor BIGINT       NOT NULL,
    grand_total_minor    BIGINT       NOT NULL,
    contact_name         VARCHAR(120),
    contact_phone        VARCHAR(20)  NOT NULL,
    address_line         VARCHAR(300),
    address_area         VARCHAR(120),
    address_landmark     VARCHAR(200),
    address_latitude     DOUBLE PRECISION,
    address_longitude    DOUBLE PRECISION,
    note                 VARCHAR(500),
    created_at           TIMESTAMPTZ  NOT NULL,
    updated_at           TIMESTAMPTZ  NOT NULL,
    version              BIGINT       NOT NULL
);
CREATE UNIQUE INDEX uq_checkout_client_request ON checkout (customer_id, client_request_id);
CREATE INDEX idx_checkout_payment ON checkout (payment_status, payment_deadline);
CREATE INDEX idx_checkout_reference ON checkout (payment_reference);

CREATE TABLE shop_order (
    id                 UUID PRIMARY KEY,
    checkout_id        UUID         NOT NULL REFERENCES checkout (id),
    code               VARCHAR(24)  NOT NULL UNIQUE,
    vendor_id          UUID         NOT NULL REFERENCES vendor (id),
    vendor_name        VARCHAR(120) NOT NULL,
    customer_id        UUID         NOT NULL REFERENCES app_user (id),
    status             VARCHAR(30)  NOT NULL,
    fulfilment_mode    VARCHAR(30)  NOT NULL,
    items_total_minor  BIGINT       NOT NULL,
    delivery_fee_minor BIGINT       NOT NULL,
    total_minor        BIGINT       NOT NULL,
    accept_deadline    TIMESTAMPTZ,
    accepted_at        TIMESTAMPTZ,
    ready_at           TIMESTAMPTZ,
    completed_at       TIMESTAMPTZ,
    cancelled_at       TIMESTAMPTZ,
    cancelled_by       VARCHAR(20),
    cancel_reason      VARCHAR(500),
    created_at         TIMESTAMPTZ  NOT NULL,
    updated_at         TIMESTAMPTZ  NOT NULL,
    version            BIGINT       NOT NULL
);
CREATE INDEX idx_shop_order_vendor ON shop_order (vendor_id, status, created_at DESC);
CREATE INDEX idx_shop_order_customer ON shop_order (customer_id, created_at DESC);
CREATE INDEX idx_shop_order_checkout ON shop_order (checkout_id);
CREATE INDEX idx_shop_order_deadline ON shop_order (status, accept_deadline);

CREATE TABLE order_line (
    id                   UUID PRIMARY KEY,
    shop_order_id        UUID         NOT NULL REFERENCES shop_order (id) ON DELETE CASCADE,
    position             INT          NOT NULL,
    listing_id           UUID         NOT NULL REFERENCES listing (id),
    listing_type         VARCHAR(20)  NOT NULL,
    title                VARCHAR(160) NOT NULL,
    image_url            VARCHAR(500),
    unit_price_minor     BIGINT       NOT NULL,
    original_price_minor BIGINT       NOT NULL,
    quantity             INT          NOT NULL,
    line_total_minor     BIGINT       NOT NULL
);
CREATE INDEX idx_order_line_order ON order_line (shop_order_id);

-- Append-only history of every status change.
CREATE TABLE order_event (
    id            UUID PRIMARY KEY,
    shop_order_id UUID         NOT NULL REFERENCES shop_order (id) ON DELETE CASCADE,
    status        VARCHAR(30)  NOT NULL,
    actor_type    VARCHAR(20)  NOT NULL,
    actor_id      UUID,
    note          VARCHAR(500),
    created_at    TIMESTAMPTZ  NOT NULL
);
CREATE INDEX idx_order_event_order ON order_event (shop_order_id, created_at);

CREATE TABLE refund (
    id                 UUID PRIMARY KEY,
    checkout_id        UUID         NOT NULL REFERENCES checkout (id),
    shop_order_id      UUID         NOT NULL REFERENCES shop_order (id),
    amount_minor       BIGINT       NOT NULL,
    status             VARCHAR(20)  NOT NULL,
    provider_refund_id VARCHAR(100),
    error              VARCHAR(500),
    created_at         TIMESTAMPTZ  NOT NULL,
    updated_at         TIMESTAMPTZ  NOT NULL,
    version            BIGINT       NOT NULL
);
CREATE UNIQUE INDEX uq_refund_shop_order ON refund (shop_order_id);

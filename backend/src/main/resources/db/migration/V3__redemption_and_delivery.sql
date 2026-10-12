-- Stage 4: single-use QR codes for venue offers.
CREATE TABLE redemption (
    id            UUID PRIMARY KEY,
    shop_order_id UUID         NOT NULL UNIQUE REFERENCES shop_order (id),
    vendor_id     UUID         NOT NULL REFERENCES vendor (id),
    token         VARCHAR(64)  NOT NULL UNIQUE,
    quantity      INT          NOT NULL,
    valid_from    TIMESTAMPTZ,
    valid_to      TIMESTAMPTZ,
    used_at       TIMESTAMPTZ,
    used_by       UUID,
    created_at    TIMESTAMPTZ  NOT NULL,
    version       BIGINT       NOT NULL
);

-- Stage 4: Mintadeal delivery partner jobs, one active job per shop order.
CREATE TABLE delivery_job (
    id                    UUID PRIMARY KEY,
    shop_order_id         UUID          NOT NULL REFERENCES shop_order (id),
    order_code            VARCHAR(24)   NOT NULL,
    vendor_id             UUID          NOT NULL REFERENCES vendor (id),
    status                VARCHAR(20)   NOT NULL,
    agent_id              UUID REFERENCES app_user (id),
    cost_minor            BIGINT        NOT NULL,
    distance_km           NUMERIC(6, 2) NOT NULL,
    cash_to_collect_minor BIGINT        NOT NULL,
    pickup_name           VARCHAR(120)  NOT NULL,
    pickup_phone          VARCHAR(20)   NOT NULL,
    pickup_address        VARCHAR(400)  NOT NULL,
    pickup_area           VARCHAR(120)  NOT NULL,
    pickup_latitude       DOUBLE PRECISION NOT NULL,
    pickup_longitude      DOUBLE PRECISION NOT NULL,
    drop_name             VARCHAR(120),
    drop_phone            VARCHAR(20)   NOT NULL,
    drop_address          VARCHAR(400)  NOT NULL,
    drop_area             VARCHAR(120)  NOT NULL,
    drop_latitude         DOUBLE PRECISION NOT NULL,
    drop_longitude        DOUBLE PRECISION NOT NULL,
    drop_code             VARCHAR(6)    NOT NULL,
    drop_code_attempts    INT           NOT NULL,
    item_count            INT           NOT NULL,
    failure_reason        VARCHAR(500),
    requested_at          TIMESTAMPTZ   NOT NULL,
    assigned_at           TIMESTAMPTZ,
    picked_up_at          TIMESTAMPTZ,
    delivered_at          TIMESTAMPTZ,
    closed_at             TIMESTAMPTZ,
    version               BIGINT        NOT NULL
);
CREATE INDEX idx_delivery_job_status ON delivery_job (status, requested_at);
CREATE INDEX idx_delivery_job_agent ON delivery_job (agent_id, status);
CREATE INDEX idx_delivery_job_order ON delivery_job (shop_order_id);

-- Money a shop owes Mintadeal, recovered from payouts in Stage 5.
CREATE TABLE vendor_charge (
    id              UUID PRIMARY KEY,
    vendor_id       UUID         NOT NULL REFERENCES vendor (id),
    shop_order_id   UUID         NOT NULL REFERENCES shop_order (id),
    delivery_job_id UUID         REFERENCES delivery_job (id),
    charge_type     VARCHAR(30)  NOT NULL,
    amount_minor    BIGINT       NOT NULL,
    description     VARCHAR(300) NOT NULL,
    status          VARCHAR(20)  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL,
    version         BIGINT       NOT NULL
);
CREATE UNIQUE INDEX uq_vendor_charge_job ON vendor_charge (delivery_job_id);
CREATE INDEX idx_vendor_charge_vendor ON vendor_charge (vendor_id, status);

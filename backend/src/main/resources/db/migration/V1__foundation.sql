-- Stage 1: identity
CREATE TABLE app_user (
    id          UUID PRIMARY KEY,
    phone       VARCHAR(20)  NOT NULL UNIQUE,
    name        VARCHAR(120),
    email       VARCHAR(200),
    created_at  TIMESTAMPTZ  NOT NULL,
    version     BIGINT       NOT NULL
);

CREATE TABLE user_role (
    user_id UUID        NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    role    VARCHAR(30) NOT NULL,
    PRIMARY KEY (user_id, role)
);

CREATE TABLE otp_challenge (
    id          UUID PRIMARY KEY,
    phone       VARCHAR(20)  NOT NULL,
    code_hash   VARCHAR(100) NOT NULL,
    expires_at  TIMESTAMPTZ  NOT NULL,
    attempts    INT          NOT NULL,
    consumed    BOOLEAN      NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL
);
CREATE INDEX idx_otp_phone_created ON otp_challenge (phone, created_at DESC);

-- Stage 2: vendors
CREATE TABLE vendor (
    id                    UUID PRIMARY KEY,
    owner_user_id         UUID          NOT NULL REFERENCES app_user (id),
    display_name          VARCHAR(120)  NOT NULL,
    legal_name            VARCHAR(200),
    category              VARCHAR(30)   NOT NULL,
    vendor_type           VARCHAR(20)   NOT NULL,
    status                VARCHAR(20)   NOT NULL,
    phone                 VARCHAR(20)   NOT NULL,
    description           VARCHAR(1000),
    address_line          VARCHAR(300)  NOT NULL,
    area                  VARCHAR(120)  NOT NULL,
    city                  VARCHAR(60)   NOT NULL,
    pincode               VARCHAR(10)   NOT NULL,
    latitude              DOUBLE PRECISION NOT NULL,
    longitude             DOUBLE PRECISION NOT NULL,
    gst_number            VARCHAR(20),
    opening_hours         VARCHAR(200),
    logo_url              VARCHAR(500),
    payout_upi_id         VARCHAR(100),
    payout_account_number VARCHAR(30),
    payout_ifsc           VARCHAR(15),
    self_delivery         BOOLEAN NOT NULL,
    partner_delivery      BOOLEAN NOT NULL,
    pickup                BOOLEAN NOT NULL,
    citywide_delivery     BOOLEAN NOT NULL,
    delivery_radius_km    NUMERIC(5, 2) NOT NULL,
    delivery_fee_minor    BIGINT NOT NULL,
    min_order_minor       BIGINT NOT NULL,
    review_note           VARCHAR(500),
    created_at            TIMESTAMPTZ NOT NULL,
    updated_at            TIMESTAMPTZ NOT NULL,
    version               BIGINT      NOT NULL
);
CREATE UNIQUE INDEX uq_vendor_owner ON vendor (owner_user_id);
CREATE INDEX idx_vendor_status ON vendor (status);
CREATE INDEX idx_vendor_location ON vendor (latitude, longitude);

-- Stage 2: catalogue
CREATE TABLE listing (
    id                 UUID PRIMARY KEY,
    vendor_id          UUID          NOT NULL REFERENCES vendor (id),
    listing_type       VARCHAR(20)   NOT NULL,
    title              VARCHAR(160)  NOT NULL,
    description        VARCHAR(2000),
    category           VARCHAR(30)   NOT NULL,
    image_url          VARCHAR(500),
    price_minor        BIGINT        NOT NULL,
    offer_price_minor  BIGINT,
    stock              INT,
    capacity_per_slot  INT,
    terms              VARCHAR(2000),
    valid_from         TIMESTAMPTZ,
    valid_to           TIMESTAMPTZ,
    status             VARCHAR(20)   NOT NULL,
    removed_reason     VARCHAR(500),
    created_at         TIMESTAMPTZ   NOT NULL,
    updated_at         TIMESTAMPTZ   NOT NULL,
    version            BIGINT        NOT NULL
);
CREATE INDEX idx_listing_vendor ON listing (vendor_id);
CREATE INDEX idx_listing_status ON listing (status);

CREATE TABLE listing_fulfilment_mode (
    listing_id UUID        NOT NULL REFERENCES listing (id) ON DELETE CASCADE,
    mode       VARCHAR(30) NOT NULL,
    PRIMARY KEY (listing_id, mode)
);

-- Stage 2: customers follow shops
CREATE TABLE vendor_follow (
    customer_id UUID        NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    vendor_id   UUID        NOT NULL REFERENCES vendor (id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (customer_id, vendor_id)
);

-- Admin audit trail
CREATE TABLE audit_event (
    id          UUID PRIMARY KEY,
    actor_id    UUID         NOT NULL,
    action      VARCHAR(60)  NOT NULL,
    entity_type VARCHAR(40)  NOT NULL,
    entity_id   UUID         NOT NULL,
    detail      VARCHAR(1000),
    created_at  TIMESTAMPTZ  NOT NULL
);
CREATE INDEX idx_audit_entity ON audit_event (entity_type, entity_id);

-- Accounts deleted at the person's request: personal details are removed and the phone is freed,
-- the row stays so orders and payments (which the law requires us to keep) still point at it.
ALTER TABLE app_user ADD COLUMN deleted_at TIMESTAMPTZ;

-- Pop-up stalls: hawkers, street sellers and event stalls who sell from one spot for a few days.
CREATE TABLE popup_seller (
    user_id        UUID PRIMARY KEY REFERENCES app_user (id),
    name           VARCHAR(80)  NOT NULL,
    blocked        BOOLEAN      NOT NULL,
    blocked_reason VARCHAR(300),
    created_at     TIMESTAMPTZ  NOT NULL,
    version        BIGINT       NOT NULL
);

-- One stall session at one place. Never deleted: once it ends customers stop seeing it, admins keep the history.
CREATE TABLE popup (
    id             UUID PRIMARY KEY,
    seller_id      UUID             NOT NULL REFERENCES popup_seller (user_id),
    seller_name    VARCHAR(80)      NOT NULL,
    latitude       DOUBLE PRECISION NOT NULL,
    longitude      DOUBLE PRECISION NOT NULL,
    days           INTEGER          NOT NULL,
    starts_at      TIMESTAMPTZ      NOT NULL,
    ends_at        TIMESTAMPTZ      NOT NULL,
    stopped_at     TIMESTAMPTZ,
    removed_at     TIMESTAMPTZ,
    removed_reason VARCHAR(300),
    moved_at       TIMESTAMPTZ,
    created_at     TIMESTAMPTZ      NOT NULL,
    version        BIGINT           NOT NULL
);
CREATE INDEX idx_popup_seller ON popup (seller_id, created_at DESC);
CREATE INDEX idx_popup_live ON popup (ends_at) WHERE stopped_at IS NULL AND removed_at IS NULL;

CREATE TABLE popup_item (
    popup_id    UUID         NOT NULL REFERENCES popup (id) ON DELETE CASCADE,
    position    INTEGER      NOT NULL,
    image_url   VARCHAR(500) NOT NULL,
    title       VARCHAR(60),
    price_minor BIGINT,
    PRIMARY KEY (popup_id, position)
);

CREATE TABLE popup_report (
    id          UUID PRIMARY KEY,
    popup_id    UUID         NOT NULL REFERENCES popup (id),
    reporter_id UUID         NOT NULL REFERENCES app_user (id),
    reason      VARCHAR(30)  NOT NULL,
    note        VARCHAR(300),
    created_at  TIMESTAMPTZ  NOT NULL,
    UNIQUE (popup_id, reporter_id)
);

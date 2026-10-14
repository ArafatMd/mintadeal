-- A shop's own cover photo, shown on its card and storefront instead of a deal photo.
ALTER TABLE vendor ADD COLUMN cover_url VARCHAR(500);

-- Profile photos for everyone: shop owners, riders, customers and staff.
ALTER TABLE app_user ADD COLUMN avatar_url VARCHAR(500);

-- Banners an admin puts on the customer home screen.
CREATE TABLE home_banner (
    id              UUID PRIMARY KEY,
    title           VARCHAR(60)  NOT NULL,
    subtitle        VARCHAR(100),
    kicker          VARCHAR(40),
    image_url       VARCHAR(500) NOT NULL,
    target_type     VARCHAR(20)  NOT NULL,
    target_category VARCHAR(30),
    target_id       UUID,
    scope           VARCHAR(20)  NOT NULL,
    starts_at       TIMESTAMPTZ,
    ends_at         TIMESTAMPTZ,
    position        INT          NOT NULL,
    active          BOOLEAN      NOT NULL,
    created_by      UUID         NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL,
    updated_at      TIMESTAMPTZ  NOT NULL,
    version         BIGINT       NOT NULL
);
CREATE INDEX idx_home_banner_position ON home_banner (active, position);

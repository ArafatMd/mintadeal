-- Stage 6: customers rate completed orders; the shop can reply and admins can hide abusive reviews.
CREATE TABLE vendor_review (
    id            UUID PRIMARY KEY,
    shop_order_id UUID         NOT NULL UNIQUE REFERENCES shop_order (id),
    vendor_id     UUID         NOT NULL REFERENCES vendor (id),
    customer_id   UUID         NOT NULL REFERENCES app_user (id),
    rating        SMALLINT     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment       VARCHAR(500),
    reply         VARCHAR(500),
    replied_at    TIMESTAMPTZ,
    hidden        BOOLEAN      NOT NULL,
    hidden_reason VARCHAR(300),
    created_at    TIMESTAMPTZ  NOT NULL,
    updated_at    TIMESTAMPTZ  NOT NULL,
    version       BIGINT       NOT NULL
);
CREATE INDEX idx_review_vendor ON vendor_review (vendor_id, hidden, created_at DESC);

-- Stage 6: help requests from customers, shops and riders, answered by Mintadeal staff.
CREATE TABLE support_ticket (
    id              UUID PRIMARY KEY,
    code            VARCHAR(20)  NOT NULL UNIQUE,
    opened_by       UUID         NOT NULL REFERENCES app_user (id),
    opener_role     VARCHAR(30)  NOT NULL,
    shop_order_id   UUID REFERENCES shop_order (id),
    order_code      VARCHAR(24),
    topic           VARCHAR(30)  NOT NULL,
    subject         VARCHAR(120) NOT NULL,
    status          VARCHAR(20)  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL,
    last_message_at TIMESTAMPTZ  NOT NULL,
    version         BIGINT       NOT NULL
);
CREATE INDEX idx_ticket_opener ON support_ticket (opened_by, opener_role, last_message_at DESC);
CREATE INDEX idx_ticket_status ON support_ticket (status, last_message_at DESC);

CREATE TABLE support_message (
    id         UUID PRIMARY KEY,
    ticket_id  UUID          NOT NULL REFERENCES support_ticket (id) ON DELETE CASCADE,
    author_id  UUID          NOT NULL REFERENCES app_user (id),
    staff      BOOLEAN       NOT NULL,
    body       VARCHAR(2000) NOT NULL,
    created_at TIMESTAMPTZ   NOT NULL
);
CREATE INDEX idx_support_message_ticket ON support_message (ticket_id, created_at);

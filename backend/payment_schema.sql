-- ============================================
-- RAZORPAY PAYMENT & ESCROW TABLES
-- ============================================

USE campus_mart;

-- Payment orders table (holds all payment information)
CREATE TABLE IF NOT EXISTS payment_orders (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    razorpay_order_id VARCHAR(100) NOT NULL UNIQUE,
    razorpay_payment_id VARCHAR(100) DEFAULT NULL,
    razorpay_signature  VARCHAR(300) DEFAULT NULL,
    buyer_id        BIGINT NOT NULL,
    seller_id       BIGINT NOT NULL,
    item_id         BIGINT NOT NULL,
    amount          DECIMAL(10,2) NOT NULL,
    currency        VARCHAR(10) DEFAULT 'INR',
    status          ENUM('CREATED','PAID','FAILED',
                         'REFUNDED','ESCROW_HOLD',
                         'RELEASED','DISPUTED','CANCELLED')
                    DEFAULT 'CREATED',
    payment_method  VARCHAR(50) DEFAULT NULL,
    notes           TEXT DEFAULT NULL,
    escrow_released BOOLEAN DEFAULT FALSE,
    release_deadline TIMESTAMP NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id)  REFERENCES students(id),
    FOREIGN KEY (seller_id) REFERENCES students(id),
    FOREIGN KEY (item_id)   REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Escrow timeline (tracks all events for each order)
CREATE TABLE IF NOT EXISTS escrow_events (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id       BIGINT NOT NULL,
    event_type     ENUM('ORDER_CREATED','PAYMENT_RECEIVED',
                        'DELIVERY_CONFIRMED','ESCROW_RELEASED',
                        'DISPUTE_RAISED','DISPUTE_RESOLVED',
                        'REFUND_INITIATED','REFUND_DONE')
                   NOT NULL,
    triggered_by   BIGINT DEFAULT NULL,
    description    TEXT,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id)     REFERENCES payment_orders(id) ON DELETE CASCADE,
    FOREIGN KEY (triggered_by) REFERENCES students(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Indexes for performance
CREATE INDEX idx_orders_buyer   ON payment_orders(buyer_id);
CREATE INDEX idx_orders_seller  ON payment_orders(seller_id);
CREATE INDEX idx_orders_item    ON payment_orders(item_id);
CREATE INDEX idx_orders_status  ON payment_orders(status);
CREATE INDEX idx_orders_razorpay ON payment_orders(razorpay_order_id);
CREATE INDEX idx_events_order   ON escrow_events(order_id);
CREATE INDEX idx_events_type    ON escrow_events(event_type);

-- Verify tables created
SHOW TABLES LIKE 'payment%';
SHOW TABLES LIKE 'escrow%';
DESCRIBE payment_orders;
DESCRIBE escrow_events;

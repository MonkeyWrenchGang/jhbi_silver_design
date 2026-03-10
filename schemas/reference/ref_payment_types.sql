-- Ref Payment Types Table Definition
-- Reference/Lookup Table

CREATE TABLE ref_payment_types (
    payment_type_code VARCHAR(20) NOT NULL,
    payment_type_name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP,
    PRIMARY KEY (payment_type_code)
);

COMMENT ON TABLE ref_payment_types IS 'Reference table for payment types (ACH, Wire, Card, etc.)';


-- Ref Transaction Directions Table Definition
-- Reference/Lookup Table

CREATE TABLE ref_transaction_directions (
    direction_code VARCHAR(10) NOT NULL,
    direction_name VARCHAR(50) NOT NULL,
    description VARCHAR(200),
    PRIMARY KEY (direction_code)
);

COMMENT ON TABLE ref_transaction_directions IS 'Transaction direction reference (INBOUND, OUTBOUND)';


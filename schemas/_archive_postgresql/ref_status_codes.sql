-- Ref Status Codes Table Definition
-- Reference/Lookup Table

CREATE TABLE ref_status_codes (
    status_code VARCHAR(20) NOT NULL,
    status_name VARCHAR(100) NOT NULL,
    status_category VARCHAR(50),
    description VARCHAR(500),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (status_code)
);

COMMENT ON TABLE ref_status_codes IS 'Reference table for transaction status codes';


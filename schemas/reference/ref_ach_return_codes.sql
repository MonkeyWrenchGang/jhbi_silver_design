-- Ref Ach Return Codes Table Definition
-- Reference/Lookup Table

CREATE TABLE ref_ach_return_codes (
    return_code VARCHAR(10) NOT NULL,
    return_description VARCHAR(500) NOT NULL,
    category VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (return_code)
);

COMMENT ON TABLE ref_ach_return_codes IS 'NACHA ACH return reason codes (R01-R85)';


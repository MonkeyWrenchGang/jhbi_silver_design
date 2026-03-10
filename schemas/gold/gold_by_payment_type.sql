-- Gold_ByPaymentType Table Definition
-- Aggregated analytical data by payment type
-- Generated from JHBI Data Catalog

CREATE TABLE gold_bypaymenttype (
    payment_type VARCHAR(50) NOT NULL COMMENT 'Payment type (ACH, Wire, Card, etc.)',
    aggregation_date DATE NOT NULL COMMENT 'Date of aggregation',
    transaction_count BIGINT NOT NULL COMMENT 'Total number of transactions',
    total_amount NUMERIC(18,2) NULL COMMENT 'Total transaction amount'
);

COMMENT ON TABLE gold_bypaymenttype IS 'Gold layer aggregated data by payment type';

-- Raw_Check_RDC Table Definition
-- Generated from JHBI Data Catalog

CREATE TABLE raw_check_rdc (
    check_transaction_id VARCHAR(255) NOT NULL COMMENT 'Unique check/deposit transaction ID',
    check_number VARCHAR(255) NULL COMMENT 'Check number from MICR line',
    check_type VARCHAR(255) NOT NULL COMMENT 'Type of check transaction',
    deposit_type VARCHAR(255) NOT NULL COMMENT 'How the check was deposited',
    transaction_type VARCHAR(255) NOT NULL COMMENT 'DEPOSIT or PRESENTED_CHECK',
    amount NUMERIC(18,2) NOT NULL COMMENT 'Check amount',
    payer_routing_number VARCHAR(255) NULL COMMENT 'Payor bank routing number (MICR)',
    payer_account_number VARCHAR(255) NULL COMMENT 'Payor account number (tokenized)',
    payer_name VARCHAR(255) NULL COMMENT 'Name of check writer',
    payee_name VARCHAR(255) NULL COMMENT 'Name of check recipient',
    payee_account_token VARCHAR(255) NULL COMMENT 'Deposit account (tokenized)',
    image_reference_id VARCHAR(255) NULL COMMENT 'Reference to check image (front/back)',
    icl_sequence_number VARCHAR(255) NULL COMMENT 'Image Cash Letter sequence number',
    hold_type VARCHAR(255) NULL COMMENT 'Funds hold type applied',
    hold_amount NUMERIC(18,2) NULL COMMENT 'Amount placed on hold',
    funds_availability_date DATE NULL COMMENT 'When funds become available',
    risk_score NUMERIC(5,2) NULL COMMENT 'Ensenta/fraud risk score',
    positive_pay_status VARCHAR(255) NULL COMMENT 'Positive Pay match result',
    ach_conversion_flag BOOLEAN NULL COMMENT 'Whether check was converted to ACH',
    return_reason_code VARCHAR(255) NULL COMMENT 'Check return reason',
    status VARCHAR(255) NOT NULL COMMENT 'Transaction status',
    deposit_timestamp TIMESTAMP NOT NULL COMMENT 'When deposit was made',
    cleared_timestamp TIMESTAMP NULL COMMENT 'When check cleared',
    source_product VARCHAR(255) NOT NULL COMMENT 'JH product: EPS, ENSENTA, SMARTPAY_MRDC',
    channel VARCHAR(255) NULL COMMENT 'Deposit channel',
    _cdc_sequence_id VARCHAR(255) NOT NULL COMMENT 'CDC sequence number for ordering',
    _cdc_operation VARCHAR(255) NOT NULL COMMENT 'CDC operation type: I(nsert), U(pdate), D(elete)',
    _cdc_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when change was captured at source',
    _cdc_source_system VARCHAR(255) NOT NULL COMMENT 'Source application identifier',
    _cdc_load_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when record landed in BigQuery raw zone',
    _tenant_id VARCHAR(255) NOT NULL COMMENT 'Financial institution identifier for multi-tenant isolation'
,
    PRIMARY KEY (check_transaction_id)
);

COMMENT ON TABLE raw_check_rdc IS 'Raw Check Rdc transaction data from source systems';

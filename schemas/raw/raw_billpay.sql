-- Raw_BillPay Table Definition
-- Generated from JHBI Data Catalog

CREATE TABLE raw_billpay (
    bill_pay_transaction_id VARCHAR(255) NOT NULL COMMENT 'Unique bill pay transaction ID',
    payment_type VARCHAR(255) NOT NULL COMMENT 'CONSUMER, BUSINESS, CARD_FUNDED, DONATION, GIFT_CHECK',
    payment_method VARCHAR(255) NOT NULL COMMENT 'How payment is funded',
    amount NUMERIC(18,2) NOT NULL COMMENT 'Payment amount',
    fee_amount NUMERIC(12,4) NULL COMMENT 'Expedite or convenience fee',
    payer_name VARCHAR(255) NULL COMMENT 'Accountholder/payer name',
    payer_account_token VARCHAR(255) NULL COMMENT 'Funding account (tokenized)',
    payer_card_token VARCHAR(255) NULL COMMENT 'Funding card (tokenized, for CardPay)',
    biller_name VARCHAR(255) NULL COMMENT 'Biller/payee name',
    biller_id VARCHAR(255) NULL COMMENT 'Biller identifier in iPay network',
    biller_account_number VARCHAR(255) NULL COMMENT 'Customer account number at biller',
    is_recurring BOOLEAN NULL COMMENT 'Whether this is a recurring payment',
    recurrence_frequency VARCHAR(255) NULL COMMENT 'Frequency for recurring payments',
    is_expedited BOOLEAN NULL COMMENT 'Whether payment is expedited',
    delivery_method VARCHAR(255) NULL COMMENT 'How payment is delivered to biller',
    scheduled_date DATE NULL COMMENT 'Scheduled payment date',
    delivery_date DATE NULL COMMENT 'Expected delivery date to biller',
    confirmation_number VARCHAR(255) NULL COMMENT 'Payment confirmation number',
    status VARCHAR(255) NOT NULL COMMENT 'Transaction status',
    failure_reason VARCHAR(255) NULL COMMENT 'Reason for failure if applicable',
    created_timestamp TIMESTAMP NOT NULL COMMENT 'When payment was created',
    processed_timestamp TIMESTAMP NULL COMMENT 'When payment was processed',
    delivered_timestamp TIMESTAMP NULL COMMENT 'When payment was delivered',
    source_product VARCHAR(255) NOT NULL COMMENT 'JH product: IPAY_CONSUMER, IPAY_BUSINESS, IPAY_CARDPAY, PAYRAILZ_BILLPAY',
    channel VARCHAR(255) NULL COMMENT 'Origination channel',
    _cdc_sequence_id VARCHAR(255) NOT NULL COMMENT 'CDC sequence number for ordering',
    _cdc_operation VARCHAR(255) NOT NULL COMMENT 'CDC operation type: I(nsert), U(pdate), D(elete)',
    _cdc_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when change was captured at source',
    _cdc_source_system VARCHAR(255) NOT NULL COMMENT 'Source application identifier',
    _cdc_load_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when record landed in BigQuery raw zone',
    _tenant_id VARCHAR(255) NOT NULL COMMENT 'Financial institution identifier for multi-tenant isolation'
,
    PRIMARY KEY (bill_pay_transaction_id)
);

COMMENT ON TABLE raw_billpay IS 'Raw Billpay transaction data from source systems';

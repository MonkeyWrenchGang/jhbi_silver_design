-- Unified_Silver Table Definition
-- Unified view combining all payment types
-- Generated from JHBI Data Catalog

CREATE TABLE unified_silver (
    unified_payment_id VARCHAR(255) NOT NULL COMMENT 'Globally unique payment ID (UUID v4)',
    source_transaction_id VARCHAR(255) NOT NULL COMMENT 'Original transaction ID from source system',
    source_system VARCHAR(255) NOT NULL COMMENT 'Source application identifier',
    tenant_id VARCHAR(255) NOT NULL COMMENT 'Financial institution identifier',
    payment_rail VARCHAR(255) NOT NULL COMMENT 'Payment network/rail used',
    payment_category VARCHAR(255) NOT NULL COMMENT 'High-level payment category',
    payment_type VARCHAR(255) NOT NULL COMMENT 'Specific payment type',
    payment_subtype VARCHAR(255) NULL COMMENT 'Further classification within type',
    direction VARCHAR(255) NOT NULL COMMENT 'Payment direction from FI perspective',
    amount NUMERIC(18,2) NOT NULL COMMENT 'Transaction amount in original currency',
    currency_code VARCHAR(255) NOT NULL COMMENT 'ISO 4217 currency code',
    usd_amount NUMERIC(18,2) NOT NULL COMMENT 'Amount in USD (converted for intl)',
    fee_amount NUMERIC(12,4) NULL COMMENT 'Any fee associated with payment',
    originator_name VARCHAR(255) NULL COMMENT 'Sender/originator/debtor name',
    originator_account_token VARCHAR(255) NULL COMMENT 'Sender account (tokenized)',
    originator_routing_number VARCHAR(255) NULL COMMENT 'Sender FI routing number',
    originator_fi_id VARCHAR(255) NULL COMMENT 'Sender FI identifier',
    beneficiary_name VARCHAR(255) NULL COMMENT 'Receiver/beneficiary/creditor name',
    beneficiary_account_token VARCHAR(255) NULL COMMENT 'Receiver account (tokenized)',
    beneficiary_routing_number VARCHAR(255) NULL COMMENT 'Receiver FI routing number',
    beneficiary_fi_id VARCHAR(255) NULL COMMENT 'Receiver FI identifier',
    beneficiary_country VARCHAR(255) NULL COMMENT 'Receiver country (intl payments)',
    card_type VARCHAR(255) NULL COMMENT 'Card type if card payment',
    card_brand VARCHAR(255) NULL COMMENT 'Card network brand',
    card_entry_mode VARCHAR(255) NULL COMMENT 'Card entry mode',
    merchant_category_code VARCHAR(255) NULL COMMENT 'MCC for card transactions',
    initiated_timestamp TIMESTAMP NOT NULL COMMENT 'When payment was initiated/created',
    settled_timestamp TIMESTAMP NULL COMMENT 'When payment settled/completed',
    posted_timestamp TIMESTAMP NULL COMMENT 'When posted to account',
    effective_date DATE NULL COMMENT 'Effective/value date',
    status VARCHAR(255) NOT NULL COMMENT 'Normalized transaction status',
    status_reason_code VARCHAR(255) NULL COMMENT 'Reason code for returns/failures/disputes',
    channel VARCHAR(255) NULL COMMENT 'Origination channel',
    is_recurring BOOLEAN NULL COMMENT 'Recurring payment indicator',
    memo VARCHAR(255) NULL COMMENT 'Payment memo/description/remittance info',
    fraud_score NUMERIC(5,2) NULL COMMENT 'Fraud/risk score if available',
    silver_load_timestamp TIMESTAMP NOT NULL COMMENT 'When record was loaded into silver/unified',
    silver_batch_id VARCHAR(255) NOT NULL COMMENT 'Silver layer processing batch identifier',
    raw_cdc_sequence_id VARCHAR(255) NOT NULL COMMENT 'Original CDC sequence from raw',
    data_quality_flags VARCHAR(255) NULL COMMENT 'JSON array of data quality issues found'
,
    PRIMARY KEY (unified_payment_id)
);

COMMENT ON TABLE unified_silver IS 'Unified payment transaction table combining all payment types (Silver layer)';

-- Raw_Zelle Table Definition
-- Generated from JHBI Data Catalog

CREATE TABLE raw_zelle (
    zelle_transaction_id VARCHAR(255) NOT NULL COMMENT 'Unique Zelle transaction ID',
    zelle_network_ref VARCHAR(255) NULL COMMENT 'Zelle network reference number',
    transaction_type VARCHAR(255) NOT NULL COMMENT 'SEND or RECEIVE',
    payment_type VARCHAR(255) NOT NULL COMMENT 'P2P_CONSUMER or P2P_COMMERCIAL',
    amount NUMERIC(18,2) NOT NULL COMMENT 'Payment amount in USD',
    sender_token VARCHAR(255) NULL COMMENT 'Sender Zelle token (email or phone)',
    sender_name VARCHAR(255) NULL COMMENT 'Sender name',
    sender_fi_id VARCHAR(255) NULL COMMENT 'Sender financial institution ID',
    sender_account_token VARCHAR(255) NULL COMMENT 'Sender account (tokenized)',
    receiver_token VARCHAR(255) NULL COMMENT 'Receiver Zelle token (email or phone)',
    receiver_name VARCHAR(255) NULL COMMENT 'Receiver name',
    receiver_fi_id VARCHAR(255) NULL COMMENT 'Receiver financial institution ID',
    receiver_account_token VARCHAR(255) NULL COMMENT 'Receiver account (tokenized)',
    memo VARCHAR(255) NULL COMMENT 'Payment memo/note from sender',
    is_enrolled_recipient BOOLEAN NULL COMMENT 'Whether recipient was enrolled at time of payment',
    token_validation_status VARCHAR(255) NULL COMMENT 'JH Token Validation result',
    fraud_score NUMERIC(5,2) NULL COMMENT 'Real-time fraud risk score',
    status VARCHAR(255) NOT NULL COMMENT 'Transaction status',
    initiated_timestamp TIMESTAMP NOT NULL COMMENT 'When payment was initiated',
    completed_timestamp TIMESTAMP NULL COMMENT 'When funds were available to recipient',
    source_product VARCHAR(255) NOT NULL COMMENT 'Always: JHA_PAYCENTER_ZELLE',
    channel VARCHAR(255) NULL COMMENT 'Origination channel',
    _cdc_sequence_id VARCHAR(255) NOT NULL COMMENT 'CDC sequence number for ordering',
    _cdc_operation VARCHAR(255) NOT NULL COMMENT 'CDC operation type: I(nsert), U(pdate), D(elete)',
    _cdc_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when change was captured at source',
    _cdc_source_system VARCHAR(255) NOT NULL COMMENT 'Source application identifier',
    _cdc_load_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when record landed in BigQuery raw zone',
    _tenant_id VARCHAR(255) NOT NULL COMMENT 'Financial institution identifier for multi-tenant isolation'
,
    PRIMARY KEY (zelle_transaction_id)
);

COMMENT ON TABLE raw_zelle IS 'Raw Zelle transaction data from source systems';

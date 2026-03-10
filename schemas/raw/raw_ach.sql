-- Raw_ACH Table Definition
-- Generated from JHBI Data Catalog

CREATE TABLE raw_ach (
    ach_transaction_id VARCHAR(255) NOT NULL COMMENT 'Unique transaction identifier from source',
    trace_number VARCHAR(255) NOT NULL COMMENT 'ACH trace number (15 digits)',
    batch_number VARCHAR(255) NULL COMMENT 'ACH batch number',
    file_id VARCHAR(255) NULL COMMENT 'ACH file identifier',
    transaction_code VARCHAR(255) NOT NULL COMMENT 'NACHA standard entry class code (SEC)',
    entry_class_code VARCHAR(255) NOT NULL COMMENT 'Standard Entry Class code',
    transaction_type VARCHAR(255) NOT NULL COMMENT 'Credit or Debit',
    amount NUMERIC(18,2) NOT NULL COMMENT 'Transaction amount in USD',
    effective_entry_date DATE NOT NULL COMMENT 'Intended settlement date',
    settlement_date DATE NULL COMMENT 'Actual settlement date',
    same_day_flag BOOLEAN NOT NULL COMMENT 'Whether this is a same-day ACH transaction',
    direction VARCHAR(255) NOT NULL COMMENT 'INBOUND or OUTBOUND',
    originator_name VARCHAR(255) NULL COMMENT 'Name of the originating party',
    originator_id VARCHAR(255) NULL COMMENT 'Originator identification number',
    originator_routing_number VARCHAR(255) NULL COMMENT 'Originating DFI routing/transit number',
    originator_account_number VARCHAR(255) NULL COMMENT 'Originator account number (tokenized)',
    receiver_name VARCHAR(255) NULL COMMENT 'Name of the receiving party',
    receiver_routing_number VARCHAR(255) NULL COMMENT 'Receiving DFI routing/transit number',
    receiver_account_number VARCHAR(255) NULL COMMENT 'Receiver account number (tokenized)',
    receiver_account_type VARCHAR(255) NULL COMMENT 'Checking, Savings, Loan, GL',
    company_entry_description VARCHAR(255) NULL COMMENT 'Company entry description (10 chars)',
    addenda_record_indicator BOOLEAN NULL COMMENT 'Whether addenda records are present',
    addenda_information VARCHAR(255) NULL COMMENT 'Addenda record content (payment details)',
    return_reason_code VARCHAR(255) NULL COMMENT 'ACH return reason code if returned',
    return_date DATE NULL COMMENT 'Date the return was processed',
    noc_code VARCHAR(255) NULL COMMENT 'Notification of Change code',
    status VARCHAR(255) NOT NULL COMMENT 'Transaction lifecycle status',
    source_product VARCHAR(255) NOT NULL COMMENT 'Source JH product (iPay, EPS, Payrailz, BPS)',
    channel VARCHAR(255) NULL COMMENT 'Origination channel',
    created_timestamp TIMESTAMP NOT NULL COMMENT 'When transaction was created in source',
    updated_timestamp TIMESTAMP NULL COMMENT 'Last update timestamp',
    _cdc_sequence_id VARCHAR(255) NOT NULL COMMENT 'CDC sequence number for ordering',
    _cdc_operation VARCHAR(255) NOT NULL COMMENT 'CDC operation type: I(nsert), U(pdate), D(elete)',
    _cdc_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when change was captured at source',
    _cdc_source_system VARCHAR(255) NOT NULL COMMENT 'Source application identifier',
    _cdc_load_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when record landed in BigQuery raw zone',
    _tenant_id VARCHAR(255) NOT NULL COMMENT 'Financial institution identifier for multi-tenant isolation'
,
    PRIMARY KEY (ach_transaction_id)
);

COMMENT ON TABLE raw_ach IS 'Raw Ach transaction data from source systems';

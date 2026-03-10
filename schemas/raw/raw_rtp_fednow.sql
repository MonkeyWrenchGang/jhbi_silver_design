-- Raw_RTP_FedNow Table Definition
-- Generated from JHBI Data Catalog

CREATE TABLE raw_rtp_fednow (
    instant_payment_id VARCHAR(255) NOT NULL COMMENT 'Unique instant payment identifier',
    network_reference_id VARCHAR(255) NULL COMMENT 'Network-assigned reference (TCH or Fed)',
    payment_rail VARCHAR(255) NOT NULL COMMENT 'RTP or FEDNOW',
    message_type VARCHAR(255) NOT NULL COMMENT 'ISO 20022 message type',
    transaction_type VARCHAR(255) NOT NULL COMMENT 'CREDIT_TRANSFER, REQUEST_FOR_PAYMENT, RETURN, RFP_RESPONSE',
    direction VARCHAR(255) NOT NULL COMMENT 'SEND or RECEIVE',
    amount NUMERIC(18,2) NOT NULL COMMENT 'Payment amount in USD',
    sender_name VARCHAR(255) NULL COMMENT 'Debtor/sender name',
    sender_routing_number VARCHAR(255) NULL COMMENT 'Sender FI routing number',
    sender_account_token VARCHAR(255) NULL COMMENT 'Sender account (tokenized)',
    receiver_name VARCHAR(255) NULL COMMENT 'Creditor/receiver name',
    receiver_routing_number VARCHAR(255) NULL COMMENT 'Receiver FI routing number',
    receiver_account_token VARCHAR(255) NULL COMMENT 'Receiver account (tokenized)',
    end_to_end_id VARCHAR(255) NULL COMMENT 'End-to-end identification (ISO 20022)',
    remittance_info VARCHAR(255) NULL COMMENT 'Structured or unstructured remittance info',
    rfp_expiry_timestamp TIMESTAMP NULL COMMENT 'Request for Payment expiration',
    rfp_original_ref VARCHAR(255) NULL COMMENT 'Original RfP reference (for RfP responses)',
    return_reason_code VARCHAR(255) NULL COMMENT 'Return reason code',
    acceptance_timestamp TIMESTAMP NULL COMMENT 'When receiving FI accepted/posted',
    status VARCHAR(255) NOT NULL COMMENT 'Transaction status',
    rejection_reason VARCHAR(255) NULL COMMENT 'Rejection reason from receiving FI',
    rail_finder_selected BOOLEAN NULL COMMENT 'Whether PayCenter Rail Finder auto-selected this rail',
    initiated_timestamp TIMESTAMP NOT NULL COMMENT 'When payment was initiated',
    settled_timestamp TIMESTAMP NULL COMMENT 'When payment settled (seconds for instant)',
    source_product VARCHAR(255) NOT NULL COMMENT 'JH product: JHA_PAYCENTER_RTP, JHA_PAYCENTER_FEDNOW',
    channel VARCHAR(255) NULL COMMENT 'Origination channel',
    _cdc_sequence_id VARCHAR(255) NOT NULL COMMENT 'CDC sequence number for ordering',
    _cdc_operation VARCHAR(255) NOT NULL COMMENT 'CDC operation type: I(nsert), U(pdate), D(elete)',
    _cdc_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when change was captured at source',
    _cdc_source_system VARCHAR(255) NOT NULL COMMENT 'Source application identifier',
    _cdc_load_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when record landed in BigQuery raw zone',
    _tenant_id VARCHAR(255) NOT NULL COMMENT 'Financial institution identifier for multi-tenant isolation'
,
    PRIMARY KEY (instant_payment_id)
);

COMMENT ON TABLE raw_rtp_fednow IS 'Raw Rtp Fednow transaction data from source systems';

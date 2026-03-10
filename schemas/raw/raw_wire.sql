-- Raw_Wire Table Definition
-- Generated from JHBI Data Catalog

CREATE TABLE raw_wire (
    wire_transaction_id VARCHAR(255) NOT NULL COMMENT 'Unique wire transfer identifier',
    imad VARCHAR(255) NULL COMMENT 'Input Message Accountability Data (FedWire)',
    omad VARCHAR(255) NULL COMMENT 'Output Message Accountability Data (FedWire)',
    wire_type VARCHAR(255) NOT NULL COMMENT 'DOMESTIC or INTERNATIONAL',
    direction VARCHAR(255) NOT NULL COMMENT 'INBOUND or OUTBOUND',
    amount NUMERIC(18,2) NOT NULL COMMENT 'Wire amount in originating currency',
    currency_code VARCHAR(255) NOT NULL COMMENT 'ISO 4217 currency code',
    fx_rate NUMERIC(12,6) NULL COMMENT 'Foreign exchange rate (intl wires only)',
    usd_equivalent_amount NUMERIC(18,2) NULL COMMENT 'USD equivalent for international wires',
    sender_name VARCHAR(255) NULL COMMENT 'Originator/sender name',
    sender_routing_number VARCHAR(255) NULL COMMENT 'Sender FI routing number',
    sender_account_number VARCHAR(255) NULL COMMENT 'Sender account (tokenized)',
    sender_address VARCHAR(255) NULL COMMENT 'Sender address (structured)',
    beneficiary_name VARCHAR(255) NULL COMMENT 'Beneficiary/receiver name',
    beneficiary_routing_number VARCHAR(255) NULL COMMENT 'Beneficiary FI routing number or BIC/SWIFT',
    beneficiary_account_number VARCHAR(255) NULL COMMENT 'Beneficiary account (tokenized)',
    beneficiary_address VARCHAR(255) NULL COMMENT 'Beneficiary address',
    beneficiary_country VARCHAR(255) NULL COMMENT 'ISO 3166 country code for international',
    intermediary_fi_name VARCHAR(255) NULL COMMENT 'Intermediary bank name (intl)',
    intermediary_fi_routing VARCHAR(255) NULL COMMENT 'Intermediary bank routing/SWIFT',
    purpose_code VARCHAR(255) NULL COMMENT 'Wire purpose/type code',
    reference_for_beneficiary VARCHAR(255) NULL COMMENT 'OBI - Originator to Beneficiary Info',
    fi_to_fi_info VARCHAR(255) NULL COMMENT 'FI to FI information',
    fedwire_business_function VARCHAR(255) NULL COMMENT 'FedWire business function code',
    iso20022_message_type VARCHAR(255) NULL COMMENT 'ISO 20022 message type',
    ofac_screening_status VARCHAR(255) NULL COMMENT 'OFAC/sanctions screening result',
    status VARCHAR(255) NOT NULL COMMENT 'Transaction status',
    initiated_timestamp TIMESTAMP NOT NULL COMMENT 'When wire was initiated',
    sent_timestamp TIMESTAMP NULL COMMENT 'When wire was sent to Fed/network',
    completed_timestamp TIMESTAMP NULL COMMENT 'When wire completed/settled',
    source_product VARCHAR(255) NOT NULL COMMENT 'Always: JH_WIRES',
    channel VARCHAR(255) NULL COMMENT 'Origination channel',
    _cdc_sequence_id VARCHAR(255) NOT NULL COMMENT 'CDC sequence number for ordering',
    _cdc_operation VARCHAR(255) NOT NULL COMMENT 'CDC operation type: I(nsert), U(pdate), D(elete)',
    _cdc_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when change was captured at source',
    _cdc_source_system VARCHAR(255) NOT NULL COMMENT 'Source application identifier',
    _cdc_load_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when record landed in BigQuery raw zone',
    _tenant_id VARCHAR(255) NOT NULL COMMENT 'Financial institution identifier for multi-tenant isolation'
,
    PRIMARY KEY (wire_transaction_id)
);

COMMENT ON TABLE raw_wire IS 'Raw Wire transaction data from source systems';

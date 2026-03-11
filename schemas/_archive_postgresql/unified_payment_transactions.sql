-- Unified Payment Transactions Table
-- Single table for all payment types with JSON column for type-specific fields
-- Generated from JHBI Data Catalog

CREATE TABLE unified_payment_transactions (
    -- Primary Key
    transaction_id VARCHAR(255) NOT NULL,
    
    -- Common Fields (shared across all payment types)
    tenant_id VARCHAR(255) NOT NULL COMMENT 'Financial institution identifier for multi-tenant isolation',
    payment_type VARCHAR(50) NOT NULL COMMENT 'Payment type: ACH, WIRE, CARD, ZELLE, RTP, FEDNOW, CHECK, RDC, BILLPAY',
    source_system VARCHAR(100) NOT NULL COMMENT 'Source application identifier (ipay, eps, payrailz, bps)',
    source_transaction_id VARCHAR(255) NOT NULL COMMENT 'Original transaction ID from source system',
    
    -- Amount and Currency
    amount NUMERIC(18,2) NOT NULL COMMENT 'Transaction amount',
    currency_code VARCHAR(3) NOT NULL DEFAULT 'USD' COMMENT 'ISO 4217 currency code',
    fee_amount NUMERIC(12,4) NULL COMMENT 'Fee associated with transaction',
    
    -- Dates and Timestamps
    transaction_date DATE NOT NULL COMMENT 'Transaction date',
    effective_date DATE NULL COMMENT 'Effective/value date',
    settlement_date DATE NULL COMMENT 'Settlement date',
    initiated_timestamp TIMESTAMP NOT NULL COMMENT 'When transaction was initiated',
    posted_timestamp TIMESTAMP NULL COMMENT 'When posted to account',
    settled_timestamp TIMESTAMP NULL COMMENT 'When transaction settled',
    
    -- Status
    status VARCHAR(50) NOT NULL COMMENT 'Transaction status',
    status_reason_code VARCHAR(50) NULL COMMENT 'Reason code for returns/failures',
    
    -- Direction and Channel
    direction VARCHAR(20) NOT NULL COMMENT 'INBOUND or OUTBOUND',
    channel VARCHAR(50) NULL COMMENT 'Origination channel (ONLINE, MOBILE, BRANCH, API, FILE)',
    
    -- Party Information (common fields)
    originator_name VARCHAR(255) NULL COMMENT 'Originator/sender name (PII)',
    originator_account_token VARCHAR(255) NULL COMMENT 'Originator account (tokenized, PCI)',
    originator_routing_number VARCHAR(255) NULL COMMENT 'Originator routing number',
    beneficiary_name VARCHAR(255) NULL COMMENT 'Beneficiary/receiver name (PII)',
    beneficiary_account_token VARCHAR(255) NULL COMMENT 'Beneficiary account (tokenized, PCI)',
    beneficiary_routing_number VARCHAR(255) NULL COMMENT 'Beneficiary routing number',
    
    -- Payment Type Specific Fields (stored as JSON)
    payment_details JSONB NOT NULL COMMENT 'Payment-type-specific fields as JSON',
    
    -- CDC Metadata
    _cdc_sequence_id VARCHAR(255) NOT NULL COMMENT 'CDC sequence number for ordering',
    _cdc_operation VARCHAR(1) NOT NULL COMMENT 'CDC operation: I(nsert), U(pdate), D(elete)',
    _cdc_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when change was captured at source',
    _cdc_source_system VARCHAR(100) NOT NULL COMMENT 'Source application identifier',
    _cdc_load_timestamp TIMESTAMP NOT NULL COMMENT 'Timestamp when record landed in database',
    
    -- Audit Fields
    created_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP NULL,
    
    PRIMARY KEY (transaction_id)
);

-- Indexes
CREATE INDEX idx_unified_payment_tenant_id ON unified_payment_transactions(tenant_id);
CREATE INDEX idx_unified_payment_type ON unified_payment_transactions(payment_type);
CREATE INDEX idx_unified_payment_status ON unified_payment_transactions(status);
CREATE INDEX idx_unified_payment_transaction_date ON unified_payment_transactions(transaction_date);
CREATE INDEX idx_unified_payment_settlement_date ON unified_payment_transactions(settlement_date);
CREATE INDEX idx_unified_payment_source_system ON unified_payment_transactions(source_system);
CREATE INDEX idx_unified_payment_source_transaction_id ON unified_payment_transactions(source_transaction_id);
CREATE INDEX idx_unified_payment_cdc_timestamp ON unified_payment_transactions(_cdc_timestamp);
CREATE INDEX idx_unified_payment_direction ON unified_payment_transactions(direction);

-- GIN index for JSONB queries
CREATE INDEX idx_unified_payment_details_gin ON unified_payment_transactions USING GIN (payment_details);

-- Check constraints
ALTER TABLE unified_payment_transactions ADD CONSTRAINT chk_payment_type 
    CHECK (payment_type IN ('ACH', 'WIRE', 'CARD', 'ZELLE', 'RTP', 'FEDNOW', 'CHECK', 'RDC', 'BILLPAY'));

ALTER TABLE unified_payment_transactions ADD CONSTRAINT chk_direction 
    CHECK (direction IN ('INBOUND', 'OUTBOUND'));

ALTER TABLE unified_payment_transactions ADD CONSTRAINT chk_amount_positive 
    CHECK (amount >= 0);

ALTER TABLE unified_payment_transactions ADD CONSTRAINT chk_cdc_operation 
    CHECK (_cdc_operation IN ('I', 'U', 'D'));

-- Table comment
COMMENT ON TABLE unified_payment_transactions IS 'Unified payment transactions table for all payment types. Type-specific fields stored in payment_details JSONB column.';



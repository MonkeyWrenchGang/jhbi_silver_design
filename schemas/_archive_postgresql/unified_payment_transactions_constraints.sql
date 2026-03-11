-- Additional Constraints and Indexes for Unified Payment Transactions
-- Payment-type-specific JSON field indexes and validations

-- ============================================================================
-- JSON FIELD INDEXES (for frequently queried JSON fields)
-- ============================================================================

-- ACH specific indexes
CREATE INDEX idx_ach_trace_number ON unified_payment_transactions 
    USING BTREE ((payment_details->>'trace_number'))
    WHERE payment_type = 'ACH';

CREATE INDEX idx_ach_batch_number ON unified_payment_transactions 
    USING BTREE ((payment_details->>'batch_number'))
    WHERE payment_type = 'ACH';

CREATE INDEX idx_ach_entry_class_code ON unified_payment_transactions 
    USING BTREE ((payment_details->>'entry_class_code'))
    WHERE payment_type = 'ACH';

-- Wire specific indexes
CREATE INDEX idx_wire_reference_number ON unified_payment_transactions 
    USING BTREE ((payment_details->>'wire_reference_number'))
    WHERE payment_type = 'WIRE';

-- Card specific indexes
CREATE INDEX idx_card_merchant_category_code ON unified_payment_transactions 
    USING BTREE ((payment_details->>'merchant_category_code'))
    WHERE payment_type = 'CARD';

CREATE INDEX idx_card_authorization_code ON unified_payment_transactions 
    USING BTREE ((payment_details->>'authorization_code'))
    WHERE payment_type = 'CARD';

CREATE INDEX idx_card_card_brand ON unified_payment_transactions 
    USING BTREE ((payment_details->>'card_brand'))
    WHERE payment_type = 'CARD';

-- Zelle specific indexes
CREATE INDEX idx_zelle_request_id ON unified_payment_transactions 
    USING BTREE ((payment_details->>'request_id'))
    WHERE payment_type = 'ZELLE';

-- RTP/FedNow specific indexes
CREATE INDEX idx_rtp_instant_payment_id ON unified_payment_transactions 
    USING BTREE ((payment_details->>'instant_payment_id'))
    WHERE payment_type IN ('RTP', 'FEDNOW');

CREATE INDEX idx_rtp_end_to_end_id ON unified_payment_transactions 
    USING BTREE ((payment_details->>'end_to_end_id'))
    WHERE payment_type IN ('RTP', 'FEDNOW');

-- Check/RDC specific indexes
CREATE INDEX idx_check_check_number ON unified_payment_transactions 
    USING BTREE ((payment_details->>'check_number'))
    WHERE payment_type IN ('CHECK', 'RDC');

-- BillPay specific indexes
CREATE INDEX idx_billpay_confirmation_number ON unified_payment_transactions 
    USING BTREE ((payment_details->>'confirmation_number'))
    WHERE payment_type = 'BILLPAY';

CREATE INDEX idx_billpay_payee_id ON unified_payment_transactions 
    USING BTREE ((payment_details->>'payee_id'))
    WHERE payment_type = 'BILLPAY';

-- ============================================================================
-- JSON VALIDATION CONSTRAINTS (PostgreSQL)
-- ============================================================================

-- ACH validation: must have trace_number, entry_class_code, transaction_type
ALTER TABLE unified_payment_transactions 
ADD CONSTRAINT chk_ach_payment_details 
CHECK (
    payment_type != 'ACH' OR (
        payment_details ? 'trace_number' AND
        payment_details ? 'entry_class_code' AND
        payment_details ? 'transaction_type'
    )
);

-- Wire validation: must have wire_reference_number
ALTER TABLE unified_payment_transactions 
ADD CONSTRAINT chk_wire_payment_details 
CHECK (
    payment_type != 'WIRE' OR payment_details ? 'wire_reference_number'
);

-- Card validation: must have card_brand and transaction_type
ALTER TABLE unified_payment_transactions 
ADD CONSTRAINT chk_card_payment_details 
CHECK (
    payment_type != 'CARD' OR (
        payment_details ? 'card_brand' AND
        payment_details ? 'transaction_type'
    )
);

-- Zelle validation: must have request_id
ALTER TABLE unified_payment_transactions 
ADD CONSTRAINT chk_zelle_payment_details 
CHECK (
    payment_type != 'ZELLE' OR payment_details ? 'request_id'
);

-- RTP/FedNow validation: must have network_type and instant_payment_id
ALTER TABLE unified_payment_transactions 
ADD CONSTRAINT chk_rtp_payment_details 
CHECK (
    payment_type NOT IN ('RTP', 'FEDNOW') OR (
        payment_details ? 'network_type' AND
        payment_details ? 'instant_payment_id'
    )
);

-- Check/RDC validation: must have check_number
ALTER TABLE unified_payment_transactions 
ADD CONSTRAINT chk_check_payment_details 
CHECK (
    payment_type NOT IN ('CHECK', 'RDC') OR payment_details ? 'check_number'
);

-- BillPay validation: must have confirmation_number
ALTER TABLE unified_payment_transactions 
ADD CONSTRAINT chk_billpay_payment_details 
CHECK (
    payment_type != 'BILLPAY' OR payment_details ? 'confirmation_number'
);

-- ============================================================================
-- COMPOSITE INDEXES FOR COMMON QUERY PATTERNS
-- ============================================================================

-- Tenant + Payment Type + Date (common filtering pattern)
CREATE INDEX idx_unified_tenant_type_date ON unified_payment_transactions 
    (tenant_id, payment_type, transaction_date);

-- Tenant + Status + Date (status tracking)
CREATE INDEX idx_unified_tenant_status_date ON unified_payment_transactions 
    (tenant_id, status, transaction_date);

-- Source System + Source Transaction ID (lookup)
CREATE INDEX idx_unified_source_lookup ON unified_payment_transactions 
    (source_system, source_transaction_id);

-- ============================================================================
-- PARTIAL INDEXES FOR PERFORMANCE
-- ============================================================================

-- Active transactions only (status not in terminal states)
CREATE INDEX idx_unified_active_transactions ON unified_payment_transactions 
    (tenant_id, payment_type, transaction_date)
    WHERE status NOT IN ('SETTLED', 'CANCELLED', 'VOIDED', 'COMPLETED');

-- Recent transactions (last 90 days)
CREATE INDEX idx_unified_recent_transactions ON unified_payment_transactions 
    (tenant_id, payment_type, _cdc_timestamp)
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '90 days';

-- Failed/Returned transactions (for monitoring)
CREATE INDEX idx_unified_failed_transactions ON unified_payment_transactions 
    (tenant_id, payment_type, transaction_date)
    WHERE status IN ('RETURNED', 'FAILED', 'REJECTED', 'DECLINED');



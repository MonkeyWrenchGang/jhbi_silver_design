-- Production-ready unified transactions table (PostgreSQL 14+)
-- Deployment guidance:
-- - Keep sensitive values tokenized before loading.
-- - Validate rail_details_json in ingestion/app layer using versioned JSON Schemas.
-- - Use CDC merge/upsert keyed by (tenant_id, source_system, source_transaction_id, _cdc_sequence_id).

CREATE SCHEMA IF NOT EXISTS lake;

CREATE TABLE IF NOT EXISTS lake.unified_transactions (
  -- Identity and tenancy
  transaction_id UUID PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  source_system TEXT NOT NULL,
  source_transaction_id TEXT NOT NULL,
  event_id TEXT NOT NULL,

  -- Canonical classification
  payment_type TEXT NOT NULL,
  payment_rail TEXT NOT NULL,
  direction TEXT NOT NULL,
  channel TEXT,

  -- Amount/time/status
  amount NUMERIC(18,2) NOT NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'USD',
  fee_amount NUMERIC(18,4),
  transaction_ts TIMESTAMPTZ NOT NULL,
  effective_date DATE,
  settlement_date DATE,
  status TEXT NOT NULL,
  status_reason_code TEXT,

  -- Common party fields (tokenized where applicable)
  originator_party_id TEXT,
  originator_account_token TEXT,
  originator_routing_number TEXT,
  beneficiary_party_id TEXT,
  beneficiary_account_token TEXT,
  beneficiary_routing_number TEXT,

  -- Rail extension
  rail_schema_version TEXT NOT NULL,
  rail_details_json JSONB NOT NULL,
  dq_flags_json JSONB,

  -- Schema and audit metadata
  schema_version TEXT NOT NULL DEFAULT 'v1',
  event_ts TIMESTAMPTZ NOT NULL,
  ingestion_ts TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- CDC metadata
  _cdc_sequence_id TEXT NOT NULL,
  _cdc_operation CHAR(1) NOT NULL,
  _cdc_timestamp TIMESTAMPTZ NOT NULL,
  _cdc_source_system TEXT NOT NULL,
  _cdc_load_timestamp TIMESTAMPTZ NOT NULL,

  -- Contract constraints
  CONSTRAINT uq_unified_source_cdc UNIQUE (tenant_id, source_system, source_transaction_id, _cdc_sequence_id),
  CONSTRAINT chk_payment_type
    CHECK (payment_type IN ('ACH', 'WIRE', 'CARD', 'ZELLE', 'RTP', 'FEDNOW', 'CHECK', 'RDC', 'BILLPAY')),
  CONSTRAINT chk_direction
    CHECK (direction IN ('INBOUND', 'OUTBOUND')),
  CONSTRAINT chk_cdc_operation
    CHECK (_cdc_operation IN ('I', 'U', 'D')),
  CONSTRAINT chk_currency_code_upper
    CHECK (currency_code = upper(currency_code)),
  CONSTRAINT chk_amount_non_negative
    CHECK (amount >= 0),
  CONSTRAINT chk_rail_details_is_object
    CHECK (jsonb_typeof(rail_details_json) = 'object')
);

-- Core operational indexes
CREATE INDEX IF NOT EXISTS idx_ut_tenant_type_ts
  ON lake.unified_transactions (tenant_id, payment_type, transaction_ts DESC);

CREATE INDEX IF NOT EXISTS idx_ut_tenant_status_ts
  ON lake.unified_transactions (tenant_id, status, transaction_ts DESC);

CREATE INDEX IF NOT EXISTS idx_ut_source_lookup
  ON lake.unified_transactions (tenant_id, source_system, source_transaction_id);

CREATE INDEX IF NOT EXISTS idx_ut_cdc_ts
  ON lake.unified_transactions (_cdc_timestamp DESC);

-- JSON search index
CREATE INDEX IF NOT EXISTS idx_ut_rail_details_gin
  ON lake.unified_transactions USING GIN (rail_details_json);

-- Useful partial index for exception queues
CREATE INDEX IF NOT EXISTS idx_ut_failed_status
  ON lake.unified_transactions (tenant_id, payment_type, transaction_ts DESC)
  WHERE status IN ('FAILED', 'RETURNED', 'DECLINED', 'REJECTED');

-- Optional RLS template:
-- ALTER TABLE lake.unified_transactions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY tenant_isolation ON lake.unified_transactions
--   USING (tenant_id = current_setting('app.tenant_id', true));


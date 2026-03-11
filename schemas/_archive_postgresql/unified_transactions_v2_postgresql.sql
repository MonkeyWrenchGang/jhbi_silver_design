-- =============================================================================
-- JHBI Unified Payments Platform
-- Silver Layer: unified_transactions  v2.0.0  (PostgreSQL 14+)
-- =============================================================================
-- Changes from v1:
--   • originator / beneficiary party fields now FK-linked to identity schema
--   • on_us flag promoted to first-class column (not only in rail JSON)
--   • party_resolution_status exposes identity confidence on the transaction
--   • compliance_json added for AML/fraud flag capture
--   • identity_resolution_hook_ts tracks when IR service last processed record
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lake;

CREATE TABLE IF NOT EXISTS lake.unified_transactions (

  -- -------------------------------------------------------------------------
  -- IDENTITY AND TENANCY
  -- -------------------------------------------------------------------------
  transaction_id          UUID PRIMARY KEY,
  tenant_id               TEXT NOT NULL,
  source_system           TEXT NOT NULL,         -- ipay | eps | payrailz | bps | ...
  source_transaction_id   TEXT NOT NULL,
  event_id                TEXT NOT NULL,

  -- -------------------------------------------------------------------------
  -- CANONICAL CLASSIFICATION
  -- -------------------------------------------------------------------------
  payment_type            TEXT NOT NULL,
  -- ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK_RDC | BILLPAY

  payment_rail            TEXT NOT NULL,
  -- The physical network: ACH_NACHA | FEDWIRE | SWIFT | TCH_RTP | FEDNOW |
  --   VISA | MASTERCARD | ZELLE_EWS | CHECK21 | BILLPAY_AGGREGATOR

  payment_subtype         TEXT,
  -- e.g. ACH_CREDIT | ACH_DEBIT | WIRE_DOMESTIC | WIRE_INTERNATIONAL |
  --      CARD_DEBIT | CARD_CREDIT | ZELLE_SEND | RTP_CREDIT | ...

  direction               TEXT NOT NULL,         -- INBOUND | OUTBOUND
  channel                 TEXT,
  -- ONLINE | MOBILE | BRANCH | ATM | API | TELLER | IVR

  -- -------------------------------------------------------------------------
  -- AMOUNT / CURRENCY / FEES
  -- -------------------------------------------------------------------------
  amount                  NUMERIC(18,2) NOT NULL,
  currency_code           CHAR(3) NOT NULL DEFAULT 'USD',
  fee_amount              NUMERIC(18,4),
  fee_breakdown_json      JSONB,
  -- [{ "fee_type": "PROCESSING_FEE", "amount": 0.25 }, ...]

  -- -------------------------------------------------------------------------
  -- TIMELINE
  -- -------------------------------------------------------------------------
  transaction_ts          TIMESTAMPTZ NOT NULL,  -- when transaction was initiated
  submitted_ts            TIMESTAMPTZ,           -- when submitted to rail
  acknowledged_ts         TIMESTAMPTZ,           -- rail acknowledgement received
  effective_date          DATE,
  expected_settlement_date DATE,
  settlement_date         DATE,
  settled_ts              TIMESTAMPTZ,

  -- -------------------------------------------------------------------------
  -- STATUS
  -- -------------------------------------------------------------------------
  status                  TEXT NOT NULL,
  -- INITIATED | PENDING | PROCESSING | SETTLED | COMPLETED |
  -- FAILED | RETURNED | DECLINED | REJECTED | CANCELLED | REVERSED

  status_reason_code      TEXT,
  status_reason_detail    TEXT,

  -- -------------------------------------------------------------------------
  -- ON-US / OFF-US
  -- -------------------------------------------------------------------------
  is_on_us                BOOLEAN NOT NULL DEFAULT FALSE,
  -- True when both originator and destination accounts reside at the same FI.
  -- Derived from originator_fi_routing == beneficiary_fi_routing, or from
  -- identity.party_account.is_on_us on both linked accounts.

  on_us_settlement_type   TEXT,
  -- BOOK_TRANSFER | INTERNAL_ACH | INTERNAL_WIRE | INTERNAL_ZELLE | ...
  -- Populated only when is_on_us = TRUE

  -- -------------------------------------------------------------------------
  -- ORIGINATOR PARTY  (FK into identity schema)
  -- -------------------------------------------------------------------------
  originator_party_id     UUID,
  -- FK → identity.party.party_id  (NULL if not yet resolved)

  originator_account_id   UUID,
  -- FK → identity.party_account.account_id  (NULL if not yet resolved)

  -- Denormalized for query convenience (sourced from identity.party_account)
  originator_account_token TEXT,                 -- Vault token for account number
  originator_routing_number TEXT,                -- Plain ABA routing (non-sensitive)
  originator_fi_name      TEXT,                  -- Non-sensitive FI name
  originator_party_type   TEXT,
  -- INDIVIDUAL | BUSINESS | BILLER | GOVERNMENT | FINANCIAL_INSTITUTION

  -- -------------------------------------------------------------------------
  -- DESTINATION / BENEFICIARY PARTY  (FK into identity schema)
  -- -------------------------------------------------------------------------
  beneficiary_party_id    UUID,
  -- FK → identity.party.party_id  (NULL if not yet resolved)

  beneficiary_account_id  UUID,
  -- FK → identity.party_account.account_id  (NULL if not yet resolved)

  beneficiary_account_token TEXT,
  beneficiary_routing_number TEXT,
  beneficiary_fi_name     TEXT,
  beneficiary_party_type  TEXT,

  -- -------------------------------------------------------------------------
  -- IDENTITY RESOLUTION STATE
  -- -------------------------------------------------------------------------
  originator_resolution_status  TEXT NOT NULL DEFAULT 'UNRESOLVED',
  -- UNRESOLVED | CANDIDATE | CONFIRMED | MERGED | SUPERSEDED
  originator_resolution_confidence  NUMERIC(5,4),

  beneficiary_resolution_status TEXT NOT NULL DEFAULT 'UNRESOLVED',
  beneficiary_resolution_confidence NUMERIC(5,4),

  identity_resolution_hook_ts   TIMESTAMPTZ,
  -- Timestamp of last identity resolution service pass on this record.
  -- NULL = not yet processed. Used by the IR service to find unprocessed rows.

  -- -------------------------------------------------------------------------
  -- RAIL-SPECIFIC EXTENSION
  -- -------------------------------------------------------------------------
  rail_schema_version     TEXT NOT NULL,         -- v2
  rail_details_json       JSONB NOT NULL,
  -- Contents validated against the versioned JSON schema for each payment_type.
  -- See schemas/rail_json_schemas/v2/<rail>_v2.schema.json

  -- -------------------------------------------------------------------------
  -- COMPLIANCE
  -- -------------------------------------------------------------------------
  compliance_json         JSONB,
  -- {
  --   "aml_status":       "PASSED" | "FLAGGED" | "PENDING" | "BLOCKED",
  --   "sanction_status":  "PASSED" | "FLAGGED" | "BLOCKED",
  --   "fraud_status":     "PASSED" | "FLAGGED" | "BLOCKED",
  --   "flags":            [{ "flag_type": "...", "reason": "...", "ts": "..." }],
  --   "reviewed_by":      null,
  --   "reviewed_at":      null
  -- }

  -- -------------------------------------------------------------------------
  -- DATA QUALITY
  -- -------------------------------------------------------------------------
  dq_flags_json           JSONB,

  -- -------------------------------------------------------------------------
  -- SCHEMA AND AUDIT METADATA
  -- -------------------------------------------------------------------------
  schema_version          TEXT NOT NULL DEFAULT 'v2',
  event_ts                TIMESTAMPTZ NOT NULL,
  ingestion_ts            TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- -------------------------------------------------------------------------
  -- CDC METADATA
  -- -------------------------------------------------------------------------
  _cdc_sequence_id        TEXT NOT NULL,
  _cdc_operation          CHAR(1) NOT NULL,      -- I | U | D
  _cdc_timestamp          TIMESTAMPTZ NOT NULL,
  _cdc_source_system      TEXT NOT NULL,
  _cdc_load_timestamp     TIMESTAMPTZ NOT NULL,

  -- -------------------------------------------------------------------------
  -- CONSTRAINTS
  -- -------------------------------------------------------------------------
  CONSTRAINT uq_unified_source_cdc
    UNIQUE (tenant_id, source_system, source_transaction_id, _cdc_sequence_id),

  CONSTRAINT chk_payment_type
    CHECK (payment_type IN ('ACH','WIRE','CARD','ZELLE','RTP','FEDNOW','CHECK_RDC','BILLPAY')),

  CONSTRAINT chk_direction
    CHECK (direction IN ('INBOUND','OUTBOUND')),

  CONSTRAINT chk_cdc_operation
    CHECK (_cdc_operation IN ('I','U','D')),

  CONSTRAINT chk_currency_code_upper
    CHECK (currency_code = upper(currency_code)),

  CONSTRAINT chk_amount_non_negative
    CHECK (amount >= 0),

  CONSTRAINT chk_rail_details_is_object
    CHECK (jsonb_typeof(rail_details_json) = 'object'),

  CONSTRAINT chk_originator_resolution_status
    CHECK (originator_resolution_status IN ('UNRESOLVED','CANDIDATE','CONFIRMED','MERGED','SUPERSEDED')),

  CONSTRAINT chk_beneficiary_resolution_status
    CHECK (beneficiary_resolution_status IN ('UNRESOLVED','CANDIDATE','CONFIRMED','MERGED','SUPERSEDED'))
);

-- =============================================================================
-- FOREIGN KEY CONSTRAINTS
-- (Deferrable so bulk CDC loads can insert before identity rows exist)
-- =============================================================================
ALTER TABLE lake.unified_transactions
  ADD CONSTRAINT fk_originator_party
    FOREIGN KEY (originator_party_id)
    REFERENCES identity.party(party_id)
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE lake.unified_transactions
  ADD CONSTRAINT fk_originator_account
    FOREIGN KEY (originator_account_id)
    REFERENCES identity.party_account(account_id)
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE lake.unified_transactions
  ADD CONSTRAINT fk_beneficiary_party
    FOREIGN KEY (beneficiary_party_id)
    REFERENCES identity.party(party_id)
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE lake.unified_transactions
  ADD CONSTRAINT fk_beneficiary_account
    FOREIGN KEY (beneficiary_account_id)
    REFERENCES identity.party_account(account_id)
    DEFERRABLE INITIALLY DEFERRED;

-- =============================================================================
-- INDEXES
-- =============================================================================

-- Core operational queries
CREATE INDEX IF NOT EXISTS idx_ut_tenant_type_ts
  ON lake.unified_transactions (tenant_id, payment_type, transaction_ts DESC);

CREATE INDEX IF NOT EXISTS idx_ut_tenant_status_ts
  ON lake.unified_transactions (tenant_id, status, transaction_ts DESC);

CREATE INDEX IF NOT EXISTS idx_ut_source_lookup
  ON lake.unified_transactions (tenant_id, source_system, source_transaction_id);

CREATE INDEX IF NOT EXISTS idx_ut_cdc_ts
  ON lake.unified_transactions (_cdc_timestamp DESC);

-- On-us queries (treasury, intrabank reporting)
CREATE INDEX IF NOT EXISTS idx_ut_on_us
  ON lake.unified_transactions (tenant_id, is_on_us, payment_type, transaction_ts DESC);

-- Party resolution queue — find unprocessed records
CREATE INDEX IF NOT EXISTS idx_ut_ir_queue
  ON lake.unified_transactions (tenant_id, identity_resolution_hook_ts NULLS FIRST)
  WHERE originator_resolution_status = 'UNRESOLVED'
     OR beneficiary_resolution_status = 'UNRESOLVED';

-- Party lookups (joins from identity schema)
CREATE INDEX IF NOT EXISTS idx_ut_originator_party
  ON lake.unified_transactions (originator_party_id)
  WHERE originator_party_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ut_beneficiary_party
  ON lake.unified_transactions (beneficiary_party_id)
  WHERE beneficiary_party_id IS NOT NULL;

-- GIN for rail_details_json and compliance_json searches
CREATE INDEX IF NOT EXISTS idx_ut_rail_details_gin
  ON lake.unified_transactions USING GIN (rail_details_json);

CREATE INDEX IF NOT EXISTS idx_ut_compliance_gin
  ON lake.unified_transactions USING GIN (compliance_json)
  WHERE compliance_json IS NOT NULL;

-- Exception/failure queue
CREATE INDEX IF NOT EXISTS idx_ut_failed_status
  ON lake.unified_transactions (tenant_id, payment_type, transaction_ts DESC)
  WHERE status IN ('FAILED','RETURNED','DECLINED','REJECTED');

-- =============================================================================
-- IDENTITY RESOLUTION HELPER VIEW
-- Returns transactions with resolved party context (on-us/off-us enriched)
-- =============================================================================
CREATE OR REPLACE VIEW lake.v_transactions_with_parties AS
SELECT
  t.transaction_id,
  t.tenant_id,
  t.payment_type,
  t.payment_rail,
  t.payment_subtype,
  t.direction,
  t.amount,
  t.currency_code,
  t.status,
  t.transaction_ts,
  t.settlement_date,
  t.is_on_us,
  t.on_us_settlement_type,

  -- Originator resolved identity
  op.party_type            AS orig_party_type,
  op.resolution_status     AS orig_resolution_status,
  op.resolution_confidence AS orig_resolution_confidence,
  oa.account_type          AS orig_account_type,
  oa.account_subtype       AS orig_account_subtype,
  oa.institution_routing_number AS orig_fi_routing,
  oa.institution_name      AS orig_fi_name,
  oa.is_on_us              AS orig_account_is_on_us,
  t.originator_account_token,
  t.originator_routing_number,

  -- Beneficiary resolved identity
  bp.party_type            AS bene_party_type,
  bp.resolution_status     AS bene_resolution_status,
  bp.resolution_confidence AS bene_resolution_confidence,
  ba.account_type          AS bene_account_type,
  ba.account_subtype       AS bene_account_subtype,
  ba.institution_routing_number AS bene_fi_routing,
  ba.institution_name      AS bene_fi_name,
  ba.is_on_us              AS bene_account_is_on_us,
  t.beneficiary_account_token,
  t.beneficiary_routing_number,

  -- Rail details
  t.rail_schema_version,
  t.rail_details_json,
  t.compliance_json,
  t.schema_version

FROM lake.unified_transactions t
LEFT JOIN identity.party   op ON op.party_id   = t.originator_party_id
LEFT JOIN identity.party_account oa ON oa.account_id = t.originator_account_id
LEFT JOIN identity.party   bp ON bp.party_id   = t.beneficiary_party_id
LEFT JOIN identity.party_account ba ON ba.account_id = t.beneficiary_account_id;

-- =============================================================================
-- IDENTITY RESOLUTION HOOK FUNCTION
-- Called by the IR service / CDC pipeline to stamp processed records.
-- Usage: SELECT lake.mark_identity_resolved(transaction_id, orig_party_id,
--              orig_acct_id, orig_status, orig_conf,
--              bene_party_id, bene_acct_id, bene_status, bene_conf);
-- =============================================================================
CREATE OR REPLACE FUNCTION lake.mark_identity_resolved(
  p_transaction_id              UUID,
  p_originator_party_id         UUID,
  p_originator_account_id       UUID,
  p_orig_resolution_status      TEXT,
  p_orig_resolution_confidence  NUMERIC,
  p_beneficiary_party_id        UUID,
  p_beneficiary_account_id      UUID,
  p_bene_resolution_status      TEXT,
  p_bene_resolution_confidence  NUMERIC
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  UPDATE lake.unified_transactions
  SET
    originator_party_id             = p_originator_party_id,
    originator_account_id           = p_originator_account_id,
    originator_resolution_status    = p_orig_resolution_status,
    originator_resolution_confidence= p_orig_resolution_confidence,
    beneficiary_party_id            = p_beneficiary_party_id,
    beneficiary_account_id          = p_beneficiary_account_id,
    beneficiary_resolution_status   = p_bene_resolution_status,
    beneficiary_resolution_confidence = p_bene_resolution_confidence,
    identity_resolution_hook_ts     = now()
  WHERE transaction_id = p_transaction_id;
END;
$$;

COMMENT ON FUNCTION lake.mark_identity_resolved IS
  'Called by the identity resolution service after matching originator/beneficiary '
  'tokens to canonical party and account records. Updates resolution status and '
  'stamps the hook timestamp so the IR queue index stays efficient.';

-- =============================================================================
-- ROW LEVEL SECURITY (template)
-- =============================================================================
-- ALTER TABLE lake.unified_transactions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY tenant_isolation ON lake.unified_transactions
--   USING (tenant_id = current_setting('app.tenant_id', true));

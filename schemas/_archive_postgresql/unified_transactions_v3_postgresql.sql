-- =============================================================================
-- JHBI Unified Payments Platform
-- Silver Layer: unified_transactions  v3.0.0  (PostgreSQL 14+)
-- Date: 2026-03-10
-- Supersedes: unified_transactions_v2_postgresql.sql
-- =============================================================================
-- What's new in v3:
--   + FX / Multi-Currency first-class columns:
--       settlement_currency_code, original_currency_code, original_amount,
--       fx_rate, fx_rate_source, fx_rate_timestamp, fx_charges_borne_by
--   + International wire enrichment: originator_swift_bic, beneficiary_swift_bic,
--       originator_iban_country_code, beneficiary_iban_country_code
--   + Block-and-key resolution fields surfaced on transaction:
--       originator_block_key, beneficiary_block_key, originator_match_rule,
--       beneficiary_match_rule (for audit and debugging)
--   + schema_version bumped to 'v3'
-- All v3 columns are nullable; backward-compatible with v2 records.
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
  -- ACH_NACHA | FEDWIRE | SWIFT | TCH_RTP | FEDNOW | VISA | MASTERCARD |
  -- ZELLE_EWS | CHECK21 | BILLPAY_AGGREGATOR

  payment_subtype         TEXT,
  -- ACH_CREDIT | ACH_DEBIT | WIRE_DOMESTIC | WIRE_INTERNATIONAL |
  -- CARD_DEBIT | CARD_CREDIT | ZELLE_SEND | RTP_CREDIT | ...

  direction               TEXT NOT NULL,         -- INBOUND | OUTBOUND
  channel                 TEXT,
  -- ONLINE | MOBILE | BRANCH | ATM | API | TELLER | IVR

  -- -------------------------------------------------------------------------
  -- AMOUNT / CURRENCY / FEES
  -- -------------------------------------------------------------------------
  amount                  NUMERIC(18,2) NOT NULL,
  currency_code           CHAR(3) NOT NULL DEFAULT 'USD',
  -- Settlement currency (the currency in which amount is expressed)

  fee_amount              NUMERIC(18,4),
  fee_breakdown_json      JSONB,
  -- [{ "fee_type": "PROCESSING_FEE", "amount": 0.25 }, ...]

  -- -------------------------------------------------------------------------
  -- FX / MULTI-CURRENCY  *** NEW v3 ***
  -- Populated for cross-currency transactions (international wires, multi-
  -- currency cards). All three FX columns are set together or all NULL.
  -- -------------------------------------------------------------------------
  settlement_currency_code    CHAR(3),
  -- Currency in which settlement occurs at the receiving FI (may differ from
  -- currency_code when the transaction crosses a currency boundary).
  -- e.g. USD for a domestic transaction; GBP when paying a UK beneficiary.

  original_currency_code      CHAR(3),
  -- Currency in which the originator initiated the payment.
  -- e.g. EUR when a US customer sends money to a Euro account.
  -- NULL for same-currency transactions.

  original_amount             NUMERIC(18,2),
  -- Amount in original_currency_code before FX conversion. NULL if no conversion.

  fx_rate                     NUMERIC(18,8),
  -- Exchange rate applied: original_amount * fx_rate = amount (settlement).
  -- e.g. 1.08500000 (USD/EUR). NULL if no FX conversion.

  fx_rate_source              TEXT,
  -- Who/what provided the FX rate.
  -- FEDWIRE | SWIFT | CHIPS | INTERNAL_TREASURY | BANK_OF_AMERICA | VISA_RATE |
  -- MASTERCARD_RATE | CORRESPONDENT_BANK | MANUAL
  -- NULL if no FX conversion.

  fx_rate_timestamp           TIMESTAMPTZ,
  -- When the FX rate was fixed/locked. NULL if no conversion.

  fx_charges_borne_by         TEXT,
  -- Who bears the FX conversion charges (maps to SWIFT charges field).
  -- OUR | BEN | SHA (sharing)
  -- NULL if no FX conversion.

  -- -------------------------------------------------------------------------
  -- INTERNATIONAL WIRE FI CONTEXT  *** NEW v3 ***
  -- BIC / IBAN country surfaced as first-class columns for cross-rail FX
  -- reporting without parsing rail_details_json.
  -- -------------------------------------------------------------------------
  originator_swift_bic        TEXT,             -- Originator FI SWIFT BIC
  originator_iban_country_code CHAR(2),         -- Non-sensitive IBAN country prefix
  beneficiary_swift_bic       TEXT,             -- Beneficiary FI SWIFT BIC
  beneficiary_iban_country_code CHAR(2),        -- Non-sensitive IBAN country prefix

  -- -------------------------------------------------------------------------
  -- TIMELINE
  -- -------------------------------------------------------------------------
  transaction_ts          TIMESTAMPTZ NOT NULL,
  submitted_ts            TIMESTAMPTZ,
  acknowledged_ts         TIMESTAMPTZ,
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
  on_us_settlement_type   TEXT,
  -- BOOK_TRANSFER | INTERNAL_ACH | INTERNAL_WIRE | INTERNAL_ZELLE | ...

  -- -------------------------------------------------------------------------
  -- ORIGINATOR PARTY  (FK into identity schema)
  -- -------------------------------------------------------------------------
  originator_party_id     UUID,                 -- FK → identity.party (deferrable)
  originator_account_id   UUID,                 -- FK → identity.party_account (deferrable)
  originator_account_token TEXT,                -- Vault token (PCI)
  originator_routing_number TEXT,               -- Plain ABA routing
  originator_fi_name      TEXT,
  originator_party_type   TEXT,

  -- -------------------------------------------------------------------------
  -- BENEFICIARY PARTY  (FK into identity schema)
  -- -------------------------------------------------------------------------
  beneficiary_party_id    UUID,                 -- FK → identity.party (deferrable)
  beneficiary_account_id  UUID,                 -- FK → identity.party_account (deferrable)
  beneficiary_account_token TEXT,
  beneficiary_routing_number TEXT,
  beneficiary_fi_name     TEXT,
  beneficiary_party_type  TEXT,

  -- -------------------------------------------------------------------------
  -- IDENTITY RESOLUTION STATE (block-and-key — v3 updated)
  -- -------------------------------------------------------------------------
  originator_resolution_status  TEXT NOT NULL DEFAULT 'UNRESOLVED',
  -- UNRESOLVED | CANDIDATE | CONFIRMED | MERGED | SUPERSEDED
  originator_resolution_confidence  NUMERIC(5,4),

  beneficiary_resolution_status TEXT NOT NULL DEFAULT 'UNRESOLVED',
  beneficiary_resolution_confidence NUMERIC(5,4),

  identity_resolution_hook_ts   TIMESTAMPTZ,
  -- NULL = not yet processed by IR service

  -- Block-and-key audit columns  *** NEW v3 ***
  originator_block_key    TEXT,
  -- The blocking key used during IR for originator (e.g. 'routing:021000021')
  beneficiary_block_key   TEXT,
  -- The blocking key used during IR for beneficiary

  originator_match_rule   TEXT,
  -- The rule that fired (e.g. 'EXACT_TOKEN', 'ROUTING_LAST4')
  beneficiary_match_rule  TEXT,

  -- -------------------------------------------------------------------------
  -- RAIL-SPECIFIC EXTENSION
  -- -------------------------------------------------------------------------
  rail_schema_version     TEXT NOT NULL,        -- v3
  rail_details_json       JSONB NOT NULL,
  -- Validated against schemas/rail_json_schemas/v2/<rail>_v2.schema.json

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
  schema_version          TEXT NOT NULL DEFAULT 'v3',
  event_ts                TIMESTAMPTZ NOT NULL,
  ingestion_ts            TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- -------------------------------------------------------------------------
  -- CDC METADATA
  -- -------------------------------------------------------------------------
  _cdc_sequence_id        TEXT NOT NULL,
  _cdc_operation          CHAR(1) NOT NULL,     -- I | U | D
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
    CHECK (beneficiary_resolution_status IN ('UNRESOLVED','CANDIDATE','CONFIRMED','MERGED','SUPERSEDED')),

  -- FX consistency: if fx_rate is set, original_currency must be set and differ
  CONSTRAINT chk_fx_consistency
    CHECK (
      fx_rate IS NULL
      OR (original_currency_code IS NOT NULL
          AND original_amount IS NOT NULL
          AND original_currency_code <> currency_code)
    )
);

-- =============================================================================
-- FOREIGN KEY CONSTRAINTS (deferrable — CDC bulk loads)
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

-- Core operational
CREATE INDEX IF NOT EXISTS idx_ut_tenant_type_ts
  ON lake.unified_transactions (tenant_id, payment_type, transaction_ts DESC);

CREATE INDEX IF NOT EXISTS idx_ut_tenant_status_ts
  ON lake.unified_transactions (tenant_id, status, transaction_ts DESC);

CREATE INDEX IF NOT EXISTS idx_ut_source_lookup
  ON lake.unified_transactions (tenant_id, source_system, source_transaction_id);

CREATE INDEX IF NOT EXISTS idx_ut_cdc_ts
  ON lake.unified_transactions (_cdc_timestamp DESC);

-- On-us
CREATE INDEX IF NOT EXISTS idx_ut_on_us
  ON lake.unified_transactions (tenant_id, is_on_us, payment_type, transaction_ts DESC);

-- FX / cross-currency queries  *** NEW v3 ***
CREATE INDEX IF NOT EXISTS idx_ut_fx_currency
  ON lake.unified_transactions (tenant_id, original_currency_code, settlement_currency_code)
  WHERE original_currency_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ut_bene_swift_bic
  ON lake.unified_transactions (beneficiary_swift_bic)
  WHERE beneficiary_swift_bic IS NOT NULL;

-- Block-and-key IR queue (unprocessed records)
CREATE INDEX IF NOT EXISTS idx_ut_ir_queue
  ON lake.unified_transactions (tenant_id, identity_resolution_hook_ts NULLS FIRST)
  WHERE originator_resolution_status = 'UNRESOLVED'
     OR beneficiary_resolution_status = 'UNRESOLVED';

-- Block key lookups for IR service  *** NEW v3 ***
CREATE INDEX IF NOT EXISTS idx_ut_orig_block_key
  ON lake.unified_transactions (originator_block_key)
  WHERE originator_block_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ut_bene_block_key
  ON lake.unified_transactions (beneficiary_block_key)
  WHERE beneficiary_block_key IS NOT NULL;

-- Party joins
CREATE INDEX IF NOT EXISTS idx_ut_originator_party
  ON lake.unified_transactions (originator_party_id)
  WHERE originator_party_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ut_beneficiary_party
  ON lake.unified_transactions (beneficiary_party_id)
  WHERE beneficiary_party_id IS NOT NULL;

-- GIN for JSONB
CREATE INDEX IF NOT EXISTS idx_ut_rail_details_gin
  ON lake.unified_transactions USING GIN (rail_details_json);

CREATE INDEX IF NOT EXISTS idx_ut_compliance_gin
  ON lake.unified_transactions USING GIN (compliance_json)
  WHERE compliance_json IS NOT NULL;

-- Exception queue
CREATE INDEX IF NOT EXISTS idx_ut_failed_status
  ON lake.unified_transactions (tenant_id, payment_type, transaction_ts DESC)
  WHERE status IN ('FAILED','RETURNED','DECLINED','REJECTED');

-- =============================================================================
-- IDENTITY RESOLUTION VIEW (updated for v3 FX columns)
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

  -- FX context  *** NEW v3 ***
  t.original_currency_code,
  t.original_amount,
  t.fx_rate,
  t.fx_rate_source,
  t.settlement_currency_code,

  -- International routing context  *** NEW v3 ***
  t.originator_swift_bic,
  t.beneficiary_swift_bic,
  t.originator_iban_country_code,
  t.beneficiary_iban_country_code,

  -- Originator resolved identity
  op.party_type            AS orig_party_type,
  op.resolution_status     AS orig_resolution_status,
  op.resolution_confidence AS orig_resolution_confidence,
  oa.account_type          AS orig_account_type,
  oa.institution_routing_number AS orig_fi_routing,
  oa.institution_swift_bic AS orig_fi_swift_bic,
  oa.institution_name      AS orig_fi_name,
  oa.is_on_us              AS orig_account_is_on_us,
  t.originator_account_token,
  t.originator_routing_number,
  t.originator_block_key,
  t.originator_match_rule,

  -- Beneficiary resolved identity
  bp.party_type            AS bene_party_type,
  bp.resolution_status     AS bene_resolution_status,
  bp.resolution_confidence AS bene_resolution_confidence,
  ba.account_type          AS bene_account_type,
  ba.institution_routing_number AS bene_fi_routing,
  ba.institution_swift_bic AS bene_fi_swift_bic,
  ba.institution_name      AS bene_fi_name,
  ba.institution_iban_country_code AS bene_iban_country_code,
  ba.is_on_us              AS bene_account_is_on_us,
  t.beneficiary_account_token,
  t.beneficiary_routing_number,
  t.beneficiary_block_key,
  t.beneficiary_match_rule,

  -- Rail details
  t.rail_schema_version,
  t.rail_details_json,
  t.compliance_json,
  t.schema_version

FROM lake.unified_transactions t
LEFT JOIN identity.party          op ON op.party_id   = t.originator_party_id
LEFT JOIN identity.party_account  oa ON oa.account_id = t.originator_account_id
LEFT JOIN identity.party          bp ON bp.party_id   = t.beneficiary_party_id
LEFT JOIN identity.party_account  ba ON ba.account_id = t.beneficiary_account_id;

-- =============================================================================
-- IDENTITY RESOLUTION HOOK FUNCTION  (v3: adds block_key + match_rule)
-- Usage:
--   SELECT lake.mark_identity_resolved(
--     transaction_id  := <uuid>,
--     p_orig_party_id := <uuid>,  p_orig_acct_id := <uuid>,
--     p_orig_status   := 'CONFIRMED', p_orig_conf := 0.9500,
--     p_orig_block_key:= 'routing:021000021',
--     p_orig_match_rule:= 'ROUTING_LAST4',
--     p_bene_party_id := <uuid>,  p_bene_acct_id := <uuid>,
--     p_bene_status   := 'CONFIRMED', p_bene_conf := 1.0000,
--     p_bene_block_key:= 'routing:021000021',
--     p_bene_match_rule:= 'EXACT_TOKEN'
--   );
-- =============================================================================
CREATE OR REPLACE FUNCTION lake.mark_identity_resolved(
  p_transaction_id              UUID,
  p_orig_party_id               UUID,
  p_orig_acct_id                UUID,
  p_orig_status                 TEXT,
  p_orig_conf                   NUMERIC,
  p_orig_block_key              TEXT DEFAULT NULL,
  p_orig_match_rule             TEXT DEFAULT NULL,
  p_bene_party_id               UUID,
  p_bene_acct_id                UUID,
  p_bene_status                 TEXT,
  p_bene_conf                   NUMERIC,
  p_bene_block_key              TEXT DEFAULT NULL,
  p_bene_match_rule             TEXT DEFAULT NULL
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  UPDATE lake.unified_transactions
  SET
    originator_party_id               = p_orig_party_id,
    originator_account_id             = p_orig_acct_id,
    originator_resolution_status      = p_orig_status,
    originator_resolution_confidence  = p_orig_conf,
    originator_block_key              = p_orig_block_key,
    originator_match_rule             = p_orig_match_rule,
    beneficiary_party_id              = p_bene_party_id,
    beneficiary_account_id            = p_bene_acct_id,
    beneficiary_resolution_status     = p_bene_status,
    beneficiary_resolution_confidence = p_bene_conf,
    beneficiary_block_key             = p_bene_block_key,
    beneficiary_match_rule            = p_bene_match_rule,
    identity_resolution_hook_ts       = now()
  WHERE transaction_id = p_transaction_id;
END;
$$;

COMMENT ON FUNCTION lake.mark_identity_resolved IS
  'Called by the block-and-key identity resolution service. '
  'Writes party/account FKs, resolution status, confidence, block_key, '
  'and match_rule for both originator and beneficiary in a single atomic update. '
  'Stamps identity_resolution_hook_ts to keep the IR queue index efficient.';

-- =============================================================================
-- FX REPORTING QUERIES (examples)
-- =============================================================================

-- Cross-currency volume by currency pair in last 30 days:
-- SELECT
--   original_currency_code,
--   currency_code            AS settlement_currency_code,
--   COUNT(*)                 AS txn_count,
--   SUM(original_amount)     AS total_original,
--   AVG(fx_rate)             AS avg_fx_rate
-- FROM lake.unified_transactions
-- WHERE tenant_id = :tenant_id
--   AND original_currency_code IS NOT NULL
--   AND transaction_ts >= now() - interval '30 days'
-- GROUP BY 1, 2
-- ORDER BY txn_count DESC;

-- =============================================================================
-- ROW LEVEL SECURITY (template)
-- =============================================================================
-- ALTER TABLE lake.unified_transactions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY tenant_isolation ON lake.unified_transactions
--   USING (tenant_id = current_setting('app.tenant_id', true));

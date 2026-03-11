-- =============================================================================
-- JHBI Unified Payments Platform
-- Silver Layer: unified_transactions  (BigQuery)
-- Version: v4.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Changes from v3:
--   + settlement_amount / settlement_currency_code for cross-currency (FX) txns
--   + description (promoted from rail_details_json for search / reporting)
--   + return_reason_code (promoted; analytics hotspot for return-rate dashboards)
--   + is_on_us (promoted from rail_details_json; analytics hotspot)
--   + is_recurring (promoted from billpay/card rail_details; analytics filter)
-- Notes:
--   1) Replace `your_project.lake` with actual project.dataset.
--   2) MERGE upserts keyed on (tenant_id, source_system, source_transaction_id, _cdc_sequence_id).
--   3) rail_details_json validated upstream against versioned JSON schemas in schemas/rail_json_schemas/v2/.
--   4) block_key / match_rule live in identity.party_resolution_event — NOT here.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.lake.unified_transactions`
(
  -- ── IDENTITY & TENANCY ──────────────────────────────────────────────────
  transaction_id            STRING    NOT NULL  OPTIONS(description = "Globally unique transaction identifier (vault-generated UUID)"),
  tenant_id                 STRING    NOT NULL  OPTIONS(description = "FI tenant identifier — row-level isolation key"),
  source_system             STRING    NOT NULL  OPTIONS(description = "Source platform: ipay | eps | payrailz | cps | visa_dps | mc_banknet | ews | tch | fednow | …"),
  source_transaction_id     STRING    NOT NULL  OPTIONS(description = "Transaction ID from source system (unique within source)"),
  event_id                  STRING    NOT NULL  OPTIONS(description = "Unique CDC / event identifier from ingestion pipeline"),

  -- ── CANONICAL CLASSIFICATION ────────────────────────────────────────────
  payment_type              STRING    NOT NULL  OPTIONS(description = "Canonical type: ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK | RDC | BILLPAY"),
  payment_rail              STRING    NOT NULL  OPTIONS(description = "Underlying network / rail (e.g. NACHA, FEDWIRE, SWIFT, CHIPS, TCH_RTP, FEDNOW, EWS, SVPCO)"),
  direction                 STRING    NOT NULL  OPTIONS(description = "INBOUND | OUTBOUND"),
  channel                   STRING              OPTIONS(description = "Originating channel: ONLINE | MOBILE | BRANCH | API | FILE | ATM | IVR | …"),

  -- ── AMOUNT / CURRENCY / FX ──────────────────────────────────────────────
  amount                    NUMERIC   NOT NULL  OPTIONS(description = "Transaction amount in currency_code currency"),
  currency_code             STRING    NOT NULL  OPTIONS(description = "ISO 4217 transaction currency (e.g. USD, EUR, GBP)"),
  settlement_amount         NUMERIC             OPTIONS(description = "Amount in settlement currency; NULL when currency_code = settlement_currency_code (no FX)"),
  settlement_currency_code  STRING              OPTIONS(description = "ISO 4217 settlement currency; NULL when same as currency_code"),
  fee_amount                NUMERIC             OPTIONS(description = "Associated fee amount (nullable)"),

  -- ── TIME / STATUS ───────────────────────────────────────────────────────
  transaction_ts            TIMESTAMP NOT NULL  OPTIONS(description = "Business transaction timestamp — PARTITION KEY"),
  effective_date            DATE                OPTIONS(description = "Effective / value date"),
  settlement_date           DATE                OPTIONS(description = "Settlement date"),
  status                    STRING    NOT NULL  OPTIONS(description = "Canonical lifecycle status (see ref.status_codes)"),
  status_reason_code        STRING              OPTIONS(description = "Standardized reason / return / reject code"),
  return_reason_code        STRING              OPTIONS(description = "Promoted: ACH R01-R99, ISO 20022 AC04/AG01, check NSF/STOP_PAYMENT — NULL if not a return"),

  -- ── PROMOTED ANALYTICS FLAGS ────────────────────────────────────────────
  description               STRING              OPTIONS(description = "Promoted from rail_details_json: ACH company_entry_description, wire OBI, Zelle memo, check memo_line, billpay memo"),
  is_on_us                  BOOL                OPTIONS(description = "Promoted from rail_details_json: TRUE when both parties at same FI tenant"),
  is_recurring              BOOL                OPTIONS(description = "Promoted: TRUE for recurring billpay, scheduled card, autopay ACH"),

  -- ── PARTY REFERENCES (tokenized PII — MDM keys in identity.*) ──────────
  originator_party_id       STRING              OPTIONS(description = "FK → identity.party — resolved by block-and-key IR service; NULL before IR runs"),
  originator_account_token  STRING              OPTIONS(description = "Vault token for sender account (PCI — never raw)"),
  originator_routing_number STRING              OPTIONS(description = "Sender ABA routing / transit number"),
  beneficiary_party_id      STRING              OPTIONS(description = "FK → identity.party — resolved by block-and-key IR service; NULL before IR runs"),
  beneficiary_account_token STRING              OPTIONS(description = "Vault token for receiver account (PCI — never raw)"),
  beneficiary_routing_number STRING             OPTIONS(description = "Receiver ABA routing / transit number"),

  -- ── RAIL JSON EXTENSION ─────────────────────────────────────────────────
  rail_schema_version       STRING    NOT NULL  OPTIONS(description = "Version tag for rail_details_json contract (e.g. v2)"),
  rail_details_json         JSON      NOT NULL  OPTIONS(description = "Rail-native fields validated against versioned JSON schema in schemas/rail_json_schemas/"),
  dq_flags_json             JSON                OPTIONS(description = "Data-quality flags array / object from pipeline DQ checks"),

  -- ── SCHEMA & AUDIT METADATA ─────────────────────────────────────────────
  schema_version            STRING    NOT NULL  OPTIONS(description = "Unified schema contract version (e.g. v4)"),
  event_ts                  TIMESTAMP NOT NULL  OPTIONS(description = "Source event timestamp"),
  ingestion_ts              TIMESTAMP NOT NULL  OPTIONS(description = "Landing / ingestion timestamp in warehouse"),

  -- ── CDC METADATA ────────────────────────────────────────────────────────
  _cdc_sequence_id          STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation            STRING    NOT NULL  OPTIONS(description = "CDC operation: I (insert) | U (update) | D (delete)"),
  _cdc_timestamp            TIMESTAMP NOT NULL  OPTIONS(description = "Source change-capture timestamp"),
  _cdc_source_system        STRING    NOT NULL  OPTIONS(description = "Source app / system for this CDC event"),
  _cdc_load_timestamp       TIMESTAMP NOT NULL  OPTIONS(description = "Load timestamp in raw / bronze layer"),

  -- ── CONSTRAINTS (NOT ENFORCED — metadata for optimizers and tooling) ────
  CONSTRAINT pk_unified_transactions PRIMARY KEY (transaction_id) NOT ENFORCED,
  CONSTRAINT fk_originator_party FOREIGN KEY (originator_party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED,
  CONSTRAINT fk_beneficiary_party FOREIGN KEY (beneficiary_party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED,
  CONSTRAINT uq_source_cdc UNIQUE (tenant_id, source_system, source_transaction_id, _cdc_sequence_id) NOT ENFORCED
)
PARTITION BY DATE(transaction_ts)
CLUSTER BY tenant_id, payment_type, status
OPTIONS(
  description = "Silver layer: unified payment transactions for all 8+ rails. Canonical typed columns + JSON rail extension. Partitioned by transaction_ts, clustered by tenant/type/status. Partition filter required.",
  require_partition_filter = TRUE
);

-- =============================================================================
-- JHBI Unified Payments Platform
-- Silver Layer: unified_transactions  (BigQuery)
-- =============================================================================
-- Replace `your_project` and dataset names with actual deployment values.
-- Partitioned by transaction_ts (DATE), clustered by tenant_id + payment_type + status.
-- All constraints declared NOT ENFORCED (BigQuery does not enforce FK/PK/UNIQUE).
-- FX and international routing fields are first-class columns — no JSON parsing needed.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.lake.unified_transactions`
(
  -- -------------------------------------------------------------------------
  -- IDENTITY AND TENANCY
  -- -------------------------------------------------------------------------
  transaction_id              STRING    NOT NULL OPTIONS(description = "Globally unique transaction identifier (UUID string)"),
  tenant_id                   STRING    NOT NULL OPTIONS(description = "FI tenant identifier for row-level isolation"),
  source_system               STRING    NOT NULL OPTIONS(description = "ipay | eps | payrailz | bps | ..."),
  source_transaction_id       STRING    NOT NULL OPTIONS(description = "Transaction ID from the source system"),
  event_id                    STRING    NOT NULL OPTIONS(description = "Unique CDC/event identifier from ingestion pipeline"),

  -- -------------------------------------------------------------------------
  -- CANONICAL CLASSIFICATION
  -- -------------------------------------------------------------------------
  payment_type                STRING    NOT NULL OPTIONS(description = "ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK_RDC | BILLPAY"),
  payment_rail                STRING    NOT NULL OPTIONS(description = "ACH_NACHA | FEDWIRE | SWIFT | TCH_RTP | FEDNOW | VISA | MASTERCARD | ZELLE_EWS | CHECK21 | BILLPAY_AGGREGATOR"),
  payment_subtype             STRING             OPTIONS(description = "ACH_CREDIT | ACH_DEBIT | WIRE_DOMESTIC | WIRE_INTERNATIONAL | CARD_DEBIT | CARD_CREDIT | ZELLE_SEND | RTP_CREDIT | ..."),
  direction                   STRING    NOT NULL OPTIONS(description = "INBOUND | OUTBOUND"),
  channel                     STRING             OPTIONS(description = "ONLINE | MOBILE | BRANCH | ATM | API | TELLER | IVR"),

  -- -------------------------------------------------------------------------
  -- AMOUNT / CURRENCY / FEES
  -- -------------------------------------------------------------------------
  amount                      NUMERIC   NOT NULL OPTIONS(description = "Settlement amount in currency_code"),
  currency_code               STRING    NOT NULL OPTIONS(description = "ISO-4217 settlement currency (e.g., USD)"),

  -- FX / Multi-currency (NULL for same-currency transactions)
  original_currency_code      STRING             OPTIONS(description = "Source currency before conversion (e.g., EUR). NULL if no conversion."),
  original_amount             NUMERIC            OPTIONS(description = "Amount in original_currency_code before conversion"),
  fx_rate                     NUMERIC            OPTIONS(description = "Exchange rate: original_amount × fx_rate = amount. NULL if no conversion."),
  fx_rate_source              STRING             OPTIONS(description = "FEDWIRE | SWIFT | CHIPS | INTERNAL_TREASURY | VISA_RATE | MASTERCARD_RATE | CORRESPONDENT_BANK | MANUAL"),
  fx_rate_timestamp           TIMESTAMP          OPTIONS(description = "When the rate was fixed/locked"),
  fx_charges_borne_by         STRING             OPTIONS(description = "OUR | BEN | SHA (SWIFT charges field)"),
  settlement_currency_code    STRING             OPTIONS(description = "Currency in which settlement occurs at receiving FI"),

  fee_amount                  NUMERIC            OPTIONS(description = "Total fee amount in currency_code"),
  fee_breakdown_json          JSON               OPTIONS(description = "Array of fee components: [{fee_type, amount, currency_code}]"),

  -- -------------------------------------------------------------------------
  -- LIFECYCLE
  -- -------------------------------------------------------------------------
  status                      STRING    NOT NULL OPTIONS(description = "PENDING | PROCESSING | SETTLED | RETURNED | REJECTED | CANCELLED | REVERSED | ON_HOLD"),
  status_reason_code          STRING             OPTIONS(description = "Standardized return/reject/reason code"),
  transaction_ts              TIMESTAMP NOT NULL OPTIONS(description = "Business transaction timestamp"),
  effective_date              DATE               OPTIONS(description = "Effective / value date"),
  settlement_date             DATE               OPTIONS(description = "Expected or actual settlement date"),
  network_settlement_date     DATE               OPTIONS(description = "Network-level settlement date (may differ from settlement_date)"),
  return_deadline_ts          TIMESTAMP          OPTIONS(description = "Deadline by which a return must be initiated"),

  -- -------------------------------------------------------------------------
  -- ON-US INDICATOR
  -- -------------------------------------------------------------------------
  is_on_us                    BOOL      NOT NULL OPTIONS(description = "TRUE = both parties at same FI tenant; derived at ETL time"),
  on_us_settlement_type       STRING             OPTIONS(description = "BOOK_TRANSFER | INTERNAL_ACH | NULL for off-us"),

  -- -------------------------------------------------------------------------
  -- ORIGINATOR
  -- -------------------------------------------------------------------------
  originator_party_id         STRING             OPTIONS(description = "FK → identity.party (NULL until IR service resolves)"),
  originator_account_id       STRING             OPTIONS(description = "FK → identity.party_account (NULL until IR service resolves)"),
  originator_account_token    STRING             OPTIONS(description = "Vault token → originator account number (PCI)"),
  originator_routing_number   STRING             OPTIONS(description = "Originator ABA routing number"),
  originator_name_token       STRING             OPTIONS(description = "Vault token → originator name (PII)"),
  originator_swift_bic        STRING             OPTIONS(description = "Originator FI SWIFT BIC (non-sensitive)"),
  originator_iban_country_code STRING            OPTIONS(description = "Non-sensitive IBAN country prefix for originator"),

  -- Identity resolution state for originator
  originator_resolution_status     STRING        OPTIONS(description = "UNRESOLVED | CANDIDATE | CONFIRMED | MERGED | SUPERSEDED"),
  originator_resolution_confidence NUMERIC       OPTIONS(description = "0.0–1.0; set by IR service"),
  originator_block_key             STRING        OPTIONS(description = "Blocking key used during IR (e.g., routing:021000021)"),
  originator_match_rule            STRING        OPTIONS(description = "Rule that fired: EXACT_TOKEN | ROUTING_ACCOUNT | PROXY_EXACT | NAME_ROUTING | NEW_PARTY"),

  -- -------------------------------------------------------------------------
  -- BENEFICIARY
  -- -------------------------------------------------------------------------
  beneficiary_party_id        STRING             OPTIONS(description = "FK → identity.party (NULL until IR service resolves)"),
  beneficiary_account_id      STRING             OPTIONS(description = "FK → identity.party_account (NULL until IR service resolves)"),
  beneficiary_account_token   STRING             OPTIONS(description = "Vault token → beneficiary account number (PCI)"),
  beneficiary_routing_number  STRING             OPTIONS(description = "Beneficiary ABA routing number"),
  beneficiary_name_token      STRING             OPTIONS(description = "Vault token → beneficiary name (PII)"),
  beneficiary_swift_bic       STRING             OPTIONS(description = "Beneficiary FI SWIFT BIC (non-sensitive)"),
  beneficiary_iban_country_code STRING           OPTIONS(description = "Non-sensitive IBAN country prefix for beneficiary"),

  -- Identity resolution state for beneficiary
  beneficiary_resolution_status     STRING       OPTIONS(description = "UNRESOLVED | CANDIDATE | CONFIRMED | MERGED | SUPERSEDED"),
  beneficiary_resolution_confidence NUMERIC      OPTIONS(description = "0.0–1.0; set by IR service"),
  beneficiary_block_key             STRING       OPTIONS(description = "Blocking key used during IR"),
  beneficiary_match_rule            STRING       OPTIONS(description = "Rule that fired for beneficiary"),

  identity_resolution_hook_ts TIMESTAMP          OPTIONS(description = "Timestamp when IR service last updated this row"),

  -- -------------------------------------------------------------------------
  -- RAIL JSON EXTENSION
  -- -------------------------------------------------------------------------
  rail_schema_version         STRING    NOT NULL  OPTIONS(description = "Version of rail_details_json contract"),
  rail_details_json           JSON      NOT NULL  OPTIONS(description = "Rail-specific fields validated against schemas/rail_json_schemas/<rail>.schema.json"),

  -- -------------------------------------------------------------------------
  -- COMPLIANCE
  -- -------------------------------------------------------------------------
  compliance_json             JSON               OPTIONS(description = "Compliance screening results: OFAC, AML, fraud flags"),

  -- -------------------------------------------------------------------------
  -- AUDIT / CDC METADATA
  -- -------------------------------------------------------------------------
  schema_version              STRING    NOT NULL  OPTIONS(description = "Schema contract version"),
  event_ts                    TIMESTAMP NOT NULL  OPTIONS(description = "Source event timestamp"),
  ingestion_ts                TIMESTAMP NOT NULL  OPTIONS(description = "Warehouse ingestion timestamp"),
  _cdc_sequence_id            STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation              STRING    NOT NULL  OPTIONS(description = "CDC operation: I | U | D"),
  _cdc_timestamp              TIMESTAMP NOT NULL  OPTIONS(description = "Source change capture timestamp"),
  _cdc_source_system          STRING    NOT NULL  OPTIONS(description = "Source app/system for CDC event"),
  _cdc_load_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "Load timestamp in raw/bronze layer"),

  CONSTRAINT pk_unified_transactions PRIMARY KEY (transaction_id) NOT ENFORCED,
  CONSTRAINT uq_unified_source_cdc UNIQUE (tenant_id, source_system, source_transaction_id, _cdc_sequence_id) NOT ENFORCED,
  CONSTRAINT fk_orig_party FOREIGN KEY (originator_party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED,
  CONSTRAINT fk_orig_account FOREIGN KEY (originator_account_id) REFERENCES `your_project.identity.party_account`(account_id) NOT ENFORCED,
  CONSTRAINT fk_bene_party FOREIGN KEY (beneficiary_party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED,
  CONSTRAINT fk_bene_account FOREIGN KEY (beneficiary_account_id) REFERENCES `your_project.identity.party_account`(account_id) NOT ENFORCED
)
PARTITION BY DATE(transaction_ts)
CLUSTER BY tenant_id, payment_type, status
OPTIONS(
  description = "Unified payment transactions across all rails. FX, international routing, and IR audit fields are first-class columns.",
  require_partition_filter = TRUE
);

-- =============================================================================
-- UNRESOLVED IR QUEUE VIEW
-- Equivalent to PostgreSQL partial index — use this as the IR service poll target.
-- =============================================================================
CREATE OR REPLACE VIEW `your_project.lake.v_ir_queue` AS
SELECT
  transaction_id,
  tenant_id,
  payment_type,
  originator_account_token,
  originator_routing_number,
  originator_resolution_status,
  beneficiary_account_token,
  beneficiary_routing_number,
  beneficiary_resolution_status,
  transaction_ts,
  ingestion_ts
FROM `your_project.lake.unified_transactions`
WHERE originator_resolution_status = 'UNRESOLVED'
   OR beneficiary_resolution_status = 'UNRESOLVED';

-- =============================================================================
-- TRANSACTIONS WITH PARTIES VIEW
-- Joins unified_transactions to identity schema for reporting queries.
-- =============================================================================
CREATE OR REPLACE VIEW `your_project.lake.v_transactions_with_parties` AS
SELECT
  t.transaction_id,
  t.tenant_id,
  t.payment_type,
  t.payment_subtype,
  t.payment_rail,
  t.direction,
  t.amount,
  t.currency_code,
  t.original_currency_code,
  t.original_amount,
  t.fx_rate,
  t.fx_rate_source,
  t.fx_charges_borne_by,
  t.settlement_currency_code,
  t.status,
  t.transaction_ts,
  t.settlement_date,
  t.is_on_us,

  -- Originator
  t.originator_party_id,
  op.party_type                       AS originator_party_type,
  op.display_name                     AS originator_display_name,
  t.originator_routing_number,
  t.originator_swift_bic,
  t.originator_iban_country_code,
  t.originator_resolution_status,
  t.originator_match_rule,

  -- Beneficiary
  t.beneficiary_party_id,
  bp.party_type                       AS beneficiary_party_type,
  bp.display_name                     AS beneficiary_display_name,
  t.beneficiary_routing_number,
  t.beneficiary_swift_bic,
  t.beneficiary_iban_country_code,
  t.beneficiary_resolution_status,
  t.beneficiary_match_rule

FROM `your_project.lake.unified_transactions` t
LEFT JOIN `your_project.identity.party` op ON op.party_id = t.originator_party_id
LEFT JOIN `your_project.identity.party` bp ON bp.party_id = t.beneficiary_party_id;

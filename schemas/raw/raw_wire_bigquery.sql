-- =============================================================================
-- JHBI Unified Payments Platform
-- Raw Layer: raw_wire  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Landing table for Wire transactions (domestic + international, FedWire + SWIFT/CHIPS).
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.raw.raw_wire`
(
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  wire_transaction_id         STRING    NOT NULL  OPTIONS(description = "Unique wire transfer identifier"),
  tenant_id                   STRING    NOT NULL  OPTIONS(description = "FI tenant identifier — row-level isolation key"),

  -- ── WIRE-SPECIFIC FIELDS ──────────────────────────────────────────────────
  imad                        STRING              OPTIONS(description = "Input Message Accountability Data (FedWire)"),
  omad                        STRING              OPTIONS(description = "Output Message Accountability Data (FedWire)"),
  wire_type                   STRING    NOT NULL  OPTIONS(description = "DOMESTIC | INTERNATIONAL"),
  direction                   STRING    NOT NULL  OPTIONS(description = "INBOUND | OUTBOUND"),

  -- ── AMOUNT / CURRENCY / FX ────────────────────────────────────────────────
  amount                      NUMERIC   NOT NULL  OPTIONS(description = "Wire amount in originating currency"),
  currency_code               STRING    NOT NULL  OPTIONS(description = "ISO 4217 currency code"),
  fx_rate                     NUMERIC             OPTIONS(description = "Foreign exchange rate (international wires only)"),
  usd_equivalent_amount       NUMERIC             OPTIONS(description = "USD equivalent for international wires"),

  -- ── SENDER ────────────────────────────────────────────────────────────────
  sender_name                 STRING              OPTIONS(description = "Originator/sender name"),
  sender_routing_number       STRING              OPTIONS(description = "Sender FI routing number (ABA 9 digits)"),
  sender_account_number       STRING              OPTIONS(description = "Sender account (tokenized in vault)"),
  sender_address              STRING              OPTIONS(description = "Sender address (structured)"),

  -- ── BENEFICIARY ───────────────────────────────────────────────────────────
  beneficiary_name            STRING              OPTIONS(description = "Beneficiary/receiver name"),
  beneficiary_routing_number  STRING              OPTIONS(description = "Beneficiary FI routing number or BIC/SWIFT"),
  beneficiary_account_number  STRING              OPTIONS(description = "Beneficiary account (tokenized in vault)"),
  beneficiary_address         STRING              OPTIONS(description = "Beneficiary address"),
  beneficiary_country         STRING              OPTIONS(description = "ISO 3166-1 alpha-2 country code (international wires)"),

  -- ── INTERMEDIARY ──────────────────────────────────────────────────────────
  intermediary_fi_name        STRING              OPTIONS(description = "Intermediary bank name (international)"),
  intermediary_fi_routing     STRING              OPTIONS(description = "Intermediary bank routing/SWIFT"),

  -- ── DETAIL / COMPLIANCE ───────────────────────────────────────────────────
  purpose_code                STRING              OPTIONS(description = "Wire purpose/type code"),
  reference_for_beneficiary   STRING              OPTIONS(description = "OBI — Originator to Beneficiary Information"),
  fi_to_fi_info               STRING              OPTIONS(description = "FI to FI information"),
  fedwire_business_function   STRING              OPTIONS(description = "FedWire business function code"),
  iso20022_message_type       STRING              OPTIONS(description = "ISO 20022 message type (pacs.008, pacs.009, etc.)"),
  ofac_screening_status       STRING              OPTIONS(description = "OFAC/sanctions screening result: PASS | HOLD | BLOCKED | PENDING"),

  -- ── STATUS / SOURCE ───────────────────────────────────────────────────────
  status                      STRING    NOT NULL  OPTIONS(description = "Transaction lifecycle status"),
  source_product              STRING    NOT NULL  OPTIONS(description = "Source product: JH_WIRES"),
  channel                     STRING              OPTIONS(description = "Origination channel"),

  -- ── TIMESTAMPS ────────────────────────────────────────────────────────────
  initiated_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "When wire was initiated"),
  sent_timestamp              TIMESTAMP           OPTIONS(description = "When wire was sent to Fed/network"),
  completed_timestamp         TIMESTAMP           OPTIONS(description = "When wire completed/settled"),

  -- ── CDC METADATA ──────────────────────────────────────────────────────────
  _cdc_sequence_id            STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation              STRING    NOT NULL  OPTIONS(description = "CDC operation: I (insert) | U (update) | D (delete)"),
  _cdc_timestamp              TIMESTAMP NOT NULL  OPTIONS(description = "Source change-capture timestamp"),
  _cdc_source_system          STRING    NOT NULL  OPTIONS(description = "Source application identifier"),
  _cdc_load_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "Timestamp when record landed in BigQuery raw zone")
)
PARTITION BY DATE(initiated_timestamp)
CLUSTER BY tenant_id, wire_type, direction
OPTIONS(
  description = "Raw Wire transactions (domestic + international). No transformation — 1:1 landing zone with CDC metadata.",
  require_partition_filter = TRUE
);

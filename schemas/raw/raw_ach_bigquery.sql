-- =============================================================================
-- JHBI Unified Payments Platform
-- Raw Layer: raw_ach  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Landing table for ACH transactions from source systems (iPay, EPS, Payrailz, BPS).
-- No transformations — 1:1 copy of source with CDC metadata appended.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.raw.raw_ach`
(
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  ach_transaction_id          STRING    NOT NULL  OPTIONS(description = "Unique transaction identifier from source system"),
  tenant_id                   STRING    NOT NULL  OPTIONS(description = "FI tenant identifier — row-level isolation key"),

  -- ── ACH-SPECIFIC FIELDS ───────────────────────────────────────────────────
  trace_number                STRING    NOT NULL  OPTIONS(description = "ACH trace number (15 digits)"),
  batch_number                STRING              OPTIONS(description = "ACH batch number"),
  file_id                     STRING              OPTIONS(description = "ACH file identifier"),
  transaction_code            STRING    NOT NULL  OPTIONS(description = "NACHA transaction code (22=checking credit, 27=checking debit, etc.)"),
  entry_class_code            STRING    NOT NULL  OPTIONS(description = "Standard Entry Class code: PPD | CCD | WEB | TEL | CTX | IAT | …"),
  transaction_type            STRING    NOT NULL  OPTIONS(description = "CREDIT or DEBIT"),

  -- ── AMOUNT / DATES ────────────────────────────────────────────────────────
  amount                      NUMERIC   NOT NULL  OPTIONS(description = "Transaction amount in USD"),
  effective_entry_date        DATE      NOT NULL  OPTIONS(description = "Intended settlement date"),
  settlement_date             DATE                OPTIONS(description = "Actual settlement date"),
  same_day_flag               BOOL      NOT NULL  OPTIONS(description = "TRUE if same-day ACH"),
  direction                   STRING    NOT NULL  OPTIONS(description = "INBOUND | OUTBOUND"),

  -- ── ORIGINATOR ────────────────────────────────────────────────────────────
  originator_name             STRING              OPTIONS(description = "Name of the originating party"),
  originator_id               STRING              OPTIONS(description = "Originator identification number"),
  originator_routing_number   STRING              OPTIONS(description = "Originating DFI routing/transit number (9 digits)"),
  originator_account_number   STRING              OPTIONS(description = "Originator account number (tokenized in vault)"),

  -- ── RECEIVER ──────────────────────────────────────────────────────────────
  receiver_name               STRING              OPTIONS(description = "Name of the receiving party"),
  receiver_routing_number     STRING              OPTIONS(description = "Receiving DFI routing/transit number (9 digits)"),
  receiver_account_number     STRING              OPTIONS(description = "Receiver account number (tokenized in vault)"),
  receiver_account_type       STRING              OPTIONS(description = "CHECKING | SAVINGS | LOAN | GL"),

  -- ── DETAIL / ADDENDA ─────────────────────────────────────────────────────
  company_entry_description   STRING              OPTIONS(description = "Company entry description (10 chars max)"),
  addenda_record_indicator    BOOL                OPTIONS(description = "TRUE when addenda records are present"),
  addenda_information         STRING              OPTIONS(description = "Addenda record content (payment details)"),

  -- ── RETURNS / NOC ─────────────────────────────────────────────────────────
  return_reason_code          STRING              OPTIONS(description = "ACH return reason code (R01–R85) if returned; NULL otherwise"),
  return_date                 DATE                OPTIONS(description = "Date the return was processed"),
  noc_code                    STRING              OPTIONS(description = "Notification of Change code (C01–C14)"),

  -- ── STATUS / SOURCE ───────────────────────────────────────────────────────
  status                      STRING    NOT NULL  OPTIONS(description = "Transaction lifecycle status"),
  source_product              STRING    NOT NULL  OPTIONS(description = "Source JH product: IPAY | EPS | PAYRAILZ | BPS"),
  channel                     STRING              OPTIONS(description = "Origination channel: ONLINE | MOBILE | BRANCH | API | FILE"),

  -- ── TIMESTAMPS ────────────────────────────────────────────────────────────
  created_timestamp           TIMESTAMP NOT NULL  OPTIONS(description = "When transaction was created in source"),
  updated_timestamp           TIMESTAMP           OPTIONS(description = "Last update timestamp in source"),

  -- ── CDC METADATA ──────────────────────────────────────────────────────────
  _cdc_sequence_id            STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation              STRING    NOT NULL  OPTIONS(description = "CDC operation: I (insert) | U (update) | D (delete)"),
  _cdc_timestamp              TIMESTAMP NOT NULL  OPTIONS(description = "Source change-capture timestamp"),
  _cdc_source_system          STRING    NOT NULL  OPTIONS(description = "Source application identifier"),
  _cdc_load_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "Timestamp when record landed in BigQuery raw zone")
)
PARTITION BY DATE(created_timestamp)
CLUSTER BY tenant_id, entry_class_code, direction
OPTIONS(
  description = "Raw ACH transactions from source systems. No transformation — 1:1 landing zone with CDC metadata.",
  require_partition_filter = TRUE
);

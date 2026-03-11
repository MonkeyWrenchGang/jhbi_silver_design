-- =============================================================================
-- JHBI Unified Payments Platform
-- Raw Layer: raw_check_rdc  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Landing table for Check and RDC (Remote Deposit Capture) transactions.
-- Includes traditional check clearing, mobile RDC, branch deposits, and ATM deposits.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.raw.raw_check_rdc`
(
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  check_transaction_id        STRING    NOT NULL  OPTIONS(description = "Unique check/deposit transaction ID"),
  tenant_id                   STRING    NOT NULL  OPTIONS(description = "FI tenant identifier — row-level isolation key"),

  -- ── CHECK-SPECIFIC FIELDS ─────────────────────────────────────────────────
  check_number                STRING              OPTIONS(description = "Check number from MICR line"),
  check_type                  STRING    NOT NULL  OPTIONS(description = "PERSONAL | BUSINESS | CASHIER | GOVERNMENT | THIRD_PARTY"),
  deposit_type                STRING    NOT NULL  OPTIONS(description = "How deposited: MOBILE_RDC | BRANCH | ATM | LOCKBOX | MAIL | IMAGE_EXCHANGE"),
  transaction_type            STRING    NOT NULL  OPTIONS(description = "DEPOSIT | PRESENTED_CHECK"),
  amount                      NUMERIC   NOT NULL  OPTIONS(description = "Check amount"),

  -- ── PAYER ─────────────────────────────────────────────────────────────────
  payer_routing_number        STRING              OPTIONS(description = "Payor bank routing number (from MICR line)"),
  payer_account_number        STRING              OPTIONS(description = "Payor account number (tokenized in vault)"),
  payer_name                  STRING              OPTIONS(description = "Name of check writer"),

  -- ── PAYEE ─────────────────────────────────────────────────────────────────
  payee_name                  STRING              OPTIONS(description = "Name of check recipient"),
  payee_account_token         STRING              OPTIONS(description = "Deposit account (tokenized in vault)"),

  -- ── IMAGE / ICL ───────────────────────────────────────────────────────────
  image_reference_id          STRING              OPTIONS(description = "Reference to check image (front/back) in image store"),
  icl_sequence_number         STRING              OPTIONS(description = "Image Cash Letter sequence number"),

  -- ── HOLDS / RISK ──────────────────────────────────────────────────────────
  hold_type                   STRING              OPTIONS(description = "Funds hold type: NONE | REG_CC | LARGE_DEPOSIT | EXCEPTION | NEW_ACCOUNT"),
  hold_amount                 NUMERIC             OPTIONS(description = "Amount placed on hold"),
  funds_availability_date     DATE                OPTIONS(description = "When funds become available"),
  risk_score                  NUMERIC             OPTIONS(description = "Ensenta/fraud risk score (0.00–100.00)"),
  positive_pay_status         STRING              OPTIONS(description = "Positive Pay match result: MATCH | MISMATCH | NOT_ENROLLED | PENDING"),
  ach_conversion_flag         BOOL                OPTIONS(description = "TRUE when check was converted to ACH (ARC/BOC)"),

  -- ── RETURNS ───────────────────────────────────────────────────────────────
  return_reason_code          STRING              OPTIONS(description = "Check return reason: NSF | STOP_PAYMENT | ACCOUNT_CLOSED | …"),

  -- ── STATUS / SOURCE ───────────────────────────────────────────────────────
  status                      STRING    NOT NULL  OPTIONS(description = "Transaction lifecycle status"),
  source_product              STRING    NOT NULL  OPTIONS(description = "Source: EPS | ENSENTA | SMARTPAY_MRDC"),
  channel                     STRING              OPTIONS(description = "Deposit channel: MOBILE | BRANCH | ATM | LOCKBOX | MAIL"),

  -- ── TIMESTAMPS ────────────────────────────────────────────────────────────
  deposit_timestamp           TIMESTAMP NOT NULL  OPTIONS(description = "When deposit was made"),
  cleared_timestamp           TIMESTAMP           OPTIONS(description = "When check cleared"),

  -- ── CDC METADATA ──────────────────────────────────────────────────────────
  _cdc_sequence_id            STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation              STRING    NOT NULL  OPTIONS(description = "CDC operation: I (insert) | U (update) | D (delete)"),
  _cdc_timestamp              TIMESTAMP NOT NULL  OPTIONS(description = "Source change-capture timestamp"),
  _cdc_source_system          STRING    NOT NULL  OPTIONS(description = "Source application identifier"),
  _cdc_load_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "Timestamp when record landed in BigQuery raw zone")
)
PARTITION BY DATE(deposit_timestamp)
CLUSTER BY tenant_id, deposit_type, check_type
OPTIONS(
  description = "Raw Check and RDC transactions. No transformation — 1:1 landing zone with CDC metadata.",
  require_partition_filter = TRUE
);

-- =============================================================================
-- JHBI Unified Payments Platform
-- Raw Layer: raw_billpay  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Landing table for BillPay transactions (iPay, Payrailz, BPS, CardPay).
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.raw.raw_billpay`
(
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  bill_pay_transaction_id     STRING    NOT NULL  OPTIONS(description = "Unique bill pay transaction ID"),
  tenant_id                   STRING    NOT NULL  OPTIONS(description = "FI tenant identifier — row-level isolation key"),

  -- ── BILLPAY-SPECIFIC FIELDS ───────────────────────────────────────────────
  payment_type                STRING    NOT NULL  OPTIONS(description = "CONSUMER | BUSINESS | CARD_FUNDED | DONATION | GIFT_CHECK"),
  payment_method              STRING    NOT NULL  OPTIONS(description = "How payment is funded: ACH | CARD | CHECK | REAL_TIME"),
  amount                      NUMERIC   NOT NULL  OPTIONS(description = "Payment amount"),
  fee_amount                  NUMERIC             OPTIONS(description = "Expedite or convenience fee"),

  -- ── PAYER ─────────────────────────────────────────────────────────────────
  payer_name                  STRING              OPTIONS(description = "Accountholder/payer name"),
  payer_account_token         STRING              OPTIONS(description = "Funding account (tokenized in vault)"),
  payer_card_token            STRING              OPTIONS(description = "Funding card (tokenized — for CardPay)"),

  -- ── BILLER ────────────────────────────────────────────────────────────────
  biller_name                 STRING              OPTIONS(description = "Biller/payee name"),
  biller_id                   STRING              OPTIONS(description = "Biller identifier in iPay/Payrailz network"),
  biller_account_number       STRING              OPTIONS(description = "Customer account number at biller"),

  -- ── RECURRENCE / SCHEDULING ───────────────────────────────────────────────
  is_recurring                BOOL                OPTIONS(description = "TRUE for recurring/autopay payments"),
  recurrence_frequency        STRING              OPTIONS(description = "Frequency: WEEKLY | BIWEEKLY | MONTHLY | QUARTERLY | ANNUAL"),
  is_expedited                BOOL                OPTIONS(description = "TRUE for expedited (rush) payments"),
  delivery_method             STRING              OPTIONS(description = "Delivery method: ELECTRONIC_ACH | ELECTRONIC_REAL_TIME | PAPER_CHECK | LASER_DRAFT"),
  scheduled_date              DATE                OPTIONS(description = "Scheduled payment date"),
  delivery_date               DATE                OPTIONS(description = "Expected delivery date to biller"),
  confirmation_number         STRING              OPTIONS(description = "Payment confirmation number"),

  -- ── STATUS / SOURCE ───────────────────────────────────────────────────────
  status                      STRING    NOT NULL  OPTIONS(description = "Transaction lifecycle status"),
  failure_reason              STRING              OPTIONS(description = "Reason for failure if applicable"),
  source_product              STRING    NOT NULL  OPTIONS(description = "Source: IPAY_CONSUMER | IPAY_BUSINESS | IPAY_CARDPAY | PAYRAILZ_BILLPAY"),
  channel                     STRING              OPTIONS(description = "Origination channel"),

  -- ── TIMESTAMPS ────────────────────────────────────────────────────────────
  created_timestamp           TIMESTAMP NOT NULL  OPTIONS(description = "When payment was created"),
  processed_timestamp         TIMESTAMP           OPTIONS(description = "When payment was processed"),
  delivered_timestamp         TIMESTAMP           OPTIONS(description = "When payment was delivered to biller"),

  -- ── CDC METADATA ──────────────────────────────────────────────────────────
  _cdc_sequence_id            STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation              STRING    NOT NULL  OPTIONS(description = "CDC operation: I (insert) | U (update) | D (delete)"),
  _cdc_timestamp              TIMESTAMP NOT NULL  OPTIONS(description = "Source change-capture timestamp"),
  _cdc_source_system          STRING    NOT NULL  OPTIONS(description = "Source application identifier"),
  _cdc_load_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "Timestamp when record landed in BigQuery raw zone")
)
PARTITION BY DATE(created_timestamp)
CLUSTER BY tenant_id, payment_type, delivery_method
OPTIONS(
  description = "Raw BillPay transactions from iPay, Payrailz, BPS. No transformation — 1:1 landing zone with CDC metadata.",
  require_partition_filter = TRUE
);

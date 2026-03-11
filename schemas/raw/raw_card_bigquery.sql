-- =============================================================================
-- JHBI Unified Payments Platform
-- Raw Layer: raw_card  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Landing table for Card transactions (Visa DPS, MasterCard Banknet, etc.).
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.raw.raw_card`
(
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  card_transaction_id         STRING    NOT NULL  OPTIONS(description = "Unique card transaction identifier"),
  tenant_id                   STRING    NOT NULL  OPTIONS(description = "FI tenant identifier — row-level isolation key"),

  -- ── CARD-SPECIFIC FIELDS ──────────────────────────────────────────────────
  authorization_code          STRING              OPTIONS(description = "Authorization approval code"),
  retrieval_reference_number  STRING              OPTIONS(description = "Acquirer reference number (ARN)"),
  card_type                   STRING    NOT NULL  OPTIONS(description = "CREDIT | DEBIT | PREPAID | GIFT"),
  card_brand                  STRING    NOT NULL  OPTIONS(description = "Card network brand: VISA | MASTERCARD | AMEX | DISCOVER"),
  card_number_token           STRING    NOT NULL  OPTIONS(description = "Tokenized PAN (PCI — never raw)"),
  card_last_four              STRING              OPTIONS(description = "Last 4 digits of PAN"),
  card_expiry_month           INT64               OPTIONS(description = "Card expiration month (1-12)"),
  card_expiry_year            INT64               OPTIONS(description = "Card expiration year (4-digit)"),
  cardholder_name             STRING              OPTIONS(description = "Name on card"),

  -- ── TRANSACTION DETAIL ────────────────────────────────────────────────────
  transaction_type            STRING    NOT NULL  OPTIONS(description = "PURCHASE | REFUND | REVERSAL | CASH_ADVANCE | BALANCE_INQUIRY"),
  entry_mode                  STRING    NOT NULL  OPTIONS(description = "CHIP | SWIPE | CONTACTLESS | KEYED | ECOMMERCE | RECURRING | TOKEN"),
  amount                      NUMERIC   NOT NULL  OPTIONS(description = "Transaction amount in transaction currency"),
  currency_code               STRING    NOT NULL  OPTIONS(description = "ISO 4217 currency code"),
  billing_amount              NUMERIC             OPTIONS(description = "Amount in cardholder billing currency"),
  billing_currency            STRING              OPTIONS(description = "Billing currency code"),
  cashback_amount             NUMERIC             OPTIONS(description = "Cashback amount (debit POS)"),
  surcharge_amount            NUMERIC             OPTIONS(description = "Surcharge/convenience fee"),

  -- ── MERCHANT ──────────────────────────────────────────────────────────────
  merchant_name               STRING              OPTIONS(description = "Merchant name"),
  merchant_id                 STRING              OPTIONS(description = "Merchant identifier"),
  merchant_category_code      STRING              OPTIONS(description = "MCC — 4-digit ISO 18245 code"),
  terminal_id                 STRING              OPTIONS(description = "Terminal identifier"),
  merchant_city               STRING              OPTIONS(description = "Merchant city"),
  merchant_state              STRING              OPTIONS(description = "Merchant state/province"),
  merchant_country            STRING              OPTIONS(description = "Merchant country code (ISO 3166)"),

  -- ── VERIFICATION / SECURITY ───────────────────────────────────────────────
  pos_condition_code          STRING              OPTIONS(description = "POS condition code"),
  network_response_code       STRING              OPTIONS(description = "Network response/action code"),
  avs_response_code           STRING              OPTIONS(description = "Address verification response"),
  cvv_response_code           STRING              OPTIONS(description = "CVV verification response"),
  is_pin_present              BOOL                OPTIONS(description = "TRUE when PIN was used"),
  is_recurring                BOOL                OPTIONS(description = "TRUE for recurring/subscription transactions"),
  is_card_present             BOOL                OPTIONS(description = "TRUE for card-present; FALSE for CNP"),
  digital_wallet_type         STRING              OPTIONS(description = "APPLE_PAY | GOOGLE_PAY | SAMSUNG_PAY | NULL"),

  -- ── DISPUTES / FEES ───────────────────────────────────────────────────────
  dispute_status              STRING              OPTIONS(description = "Chargeback/dispute status"),
  dispute_reason_code         STRING              OPTIONS(description = "Dispute/chargeback reason code"),
  interchange_fee             NUMERIC             OPTIONS(description = "Interchange fee amount"),
  network_fee                 NUMERIC             OPTIONS(description = "Network/assessment fee"),

  -- ── STATUS / SOURCE ───────────────────────────────────────────────────────
  status                      STRING    NOT NULL  OPTIONS(description = "Transaction lifecycle status"),
  source_product              STRING    NOT NULL  OPTIONS(description = "Source: CPS | TAP2LOCAL | IPAY_CARDPAY | EPS_GATEWAY"),
  channel                     STRING              OPTIONS(description = "Origination channel"),

  -- ── TIMESTAMPS ────────────────────────────────────────────────────────────
  auth_timestamp              TIMESTAMP           OPTIONS(description = "Authorization timestamp"),
  settlement_timestamp        TIMESTAMP           OPTIONS(description = "Settlement timestamp"),
  posted_timestamp            TIMESTAMP           OPTIONS(description = "Posted to account timestamp"),

  -- ── CDC METADATA ──────────────────────────────────────────────────────────
  _cdc_sequence_id            STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation              STRING    NOT NULL  OPTIONS(description = "CDC operation: I (insert) | U (update) | D (delete)"),
  _cdc_timestamp              TIMESTAMP NOT NULL  OPTIONS(description = "Source change-capture timestamp"),
  _cdc_source_system          STRING    NOT NULL  OPTIONS(description = "Source application identifier"),
  _cdc_load_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "Timestamp when record landed in BigQuery raw zone")
)
PARTITION BY DATE(auth_timestamp)
CLUSTER BY tenant_id, card_brand, card_type
OPTIONS(
  description = "Raw Card transactions (Visa, MC, Amex, Discover). No transformation — 1:1 landing zone with CDC metadata.",
  require_partition_filter = TRUE
);

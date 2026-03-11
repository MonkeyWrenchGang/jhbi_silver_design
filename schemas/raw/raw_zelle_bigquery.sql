-- =============================================================================
-- JHBI Unified Payments Platform
-- Raw Layer: raw_zelle  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Landing table for Zelle P2P transactions via JHA PayCenter / EWS.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.raw.raw_zelle`
(
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  zelle_transaction_id        STRING    NOT NULL  OPTIONS(description = "Unique Zelle transaction ID"),
  tenant_id                   STRING    NOT NULL  OPTIONS(description = "FI tenant identifier — row-level isolation key"),

  -- ── ZELLE-SPECIFIC FIELDS ─────────────────────────────────────────────────
  zelle_network_ref           STRING              OPTIONS(description = "Zelle network reference number (EWS-assigned)"),
  transaction_type            STRING    NOT NULL  OPTIONS(description = "SEND | RECEIVE"),
  payment_type                STRING    NOT NULL  OPTIONS(description = "P2P_CONSUMER | P2P_COMMERCIAL"),
  amount                      NUMERIC   NOT NULL  OPTIONS(description = "Payment amount in USD"),

  -- ── SENDER ────────────────────────────────────────────────────────────────
  sender_token                STRING              OPTIONS(description = "Sender Zelle token (email or phone — tokenized)"),
  sender_name                 STRING              OPTIONS(description = "Sender name"),
  sender_fi_id                STRING              OPTIONS(description = "Sender financial institution ID"),
  sender_account_token        STRING              OPTIONS(description = "Sender account (tokenized in vault)"),

  -- ── RECEIVER ──────────────────────────────────────────────────────────────
  receiver_token              STRING              OPTIONS(description = "Receiver Zelle token (email or phone — tokenized)"),
  receiver_name               STRING              OPTIONS(description = "Receiver name"),
  receiver_fi_id              STRING              OPTIONS(description = "Receiver financial institution ID"),
  receiver_account_token      STRING              OPTIONS(description = "Receiver account (tokenized in vault)"),

  -- ── DETAIL ────────────────────────────────────────────────────────────────
  memo                        STRING              OPTIONS(description = "Payment memo/note from sender"),
  is_enrolled_recipient       BOOL                OPTIONS(description = "TRUE when recipient was enrolled at time of payment"),
  token_validation_status     STRING              OPTIONS(description = "JH Token Validation result"),
  fraud_score                 NUMERIC             OPTIONS(description = "Real-time fraud risk score (0.00–100.00)"),

  -- ── STATUS / SOURCE ───────────────────────────────────────────────────────
  status                      STRING    NOT NULL  OPTIONS(description = "Transaction lifecycle status"),
  source_product              STRING    NOT NULL  OPTIONS(description = "Source: JHA_PAYCENTER_ZELLE"),
  channel                     STRING              OPTIONS(description = "Origination channel: ONLINE | MOBILE"),

  -- ── TIMESTAMPS ────────────────────────────────────────────────────────────
  initiated_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "When payment was initiated"),
  completed_timestamp         TIMESTAMP           OPTIONS(description = "When funds were available to recipient"),

  -- ── CDC METADATA ──────────────────────────────────────────────────────────
  _cdc_sequence_id            STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation              STRING    NOT NULL  OPTIONS(description = "CDC operation: I (insert) | U (update) | D (delete)"),
  _cdc_timestamp              TIMESTAMP NOT NULL  OPTIONS(description = "Source change-capture timestamp"),
  _cdc_source_system          STRING    NOT NULL  OPTIONS(description = "Source application identifier"),
  _cdc_load_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "Timestamp when record landed in BigQuery raw zone")
)
PARTITION BY DATE(initiated_timestamp)
CLUSTER BY tenant_id, payment_type
OPTIONS(
  description = "Raw Zelle P2P transactions from JHA PayCenter / EWS. No transformation — 1:1 landing zone with CDC metadata.",
  require_partition_filter = TRUE
);

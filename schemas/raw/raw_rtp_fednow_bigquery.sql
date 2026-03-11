-- =============================================================================
-- JHBI Unified Payments Platform
-- Raw Layer: raw_rtp_fednow  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Landing table for instant payment transactions (TCH RTP + FedNow).
-- Both rails share common ISO 20022 fields; rail-specific differences are minimal.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.raw.raw_rtp_fednow`
(
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  instant_payment_id          STRING    NOT NULL  OPTIONS(description = "Unique instant payment identifier"),
  tenant_id                   STRING    NOT NULL  OPTIONS(description = "FI tenant identifier — row-level isolation key"),

  -- ── RAIL / MESSAGE DETAIL ─────────────────────────────────────────────────
  network_reference_id        STRING              OPTIONS(description = "Network-assigned reference (TCH or Fed)"),
  payment_rail                STRING    NOT NULL  OPTIONS(description = "RTP | FEDNOW"),
  message_type                STRING    NOT NULL  OPTIONS(description = "ISO 20022 message type (pacs.008, pacs.004, pain.013, etc.)"),
  transaction_type            STRING    NOT NULL  OPTIONS(description = "CREDIT_TRANSFER | REQUEST_FOR_PAYMENT | RETURN | RFP_RESPONSE"),
  direction                   STRING    NOT NULL  OPTIONS(description = "SEND | RECEIVE"),

  -- ── AMOUNT ────────────────────────────────────────────────────────────────
  amount                      NUMERIC   NOT NULL  OPTIONS(description = "Payment amount in USD"),

  -- ── SENDER ────────────────────────────────────────────────────────────────
  sender_name                 STRING              OPTIONS(description = "Debtor/sender name"),
  sender_routing_number       STRING              OPTIONS(description = "Sender FI routing number (9 digits)"),
  sender_account_token        STRING              OPTIONS(description = "Sender account (tokenized in vault)"),

  -- ── RECEIVER ──────────────────────────────────────────────────────────────
  receiver_name               STRING              OPTIONS(description = "Creditor/receiver name"),
  receiver_routing_number     STRING              OPTIONS(description = "Receiver FI routing number (9 digits)"),
  receiver_account_token      STRING              OPTIONS(description = "Receiver account (tokenized in vault)"),

  -- ── ISO 20022 IDENTIFIERS ─────────────────────────────────────────────────
  end_to_end_id               STRING              OPTIONS(description = "End-to-end identification (ISO 20022 — flows through unmodified)"),
  remittance_info             STRING              OPTIONS(description = "Structured or unstructured remittance information (max 140 chars)"),

  -- ── REQUEST FOR PAYMENT ───────────────────────────────────────────────────
  rfp_expiry_timestamp        TIMESTAMP           OPTIONS(description = "Request for Payment expiration timestamp"),
  rfp_original_ref            STRING              OPTIONS(description = "Original RfP reference (for RfP responses)"),

  -- ── RETURNS / REJECTIONS ──────────────────────────────────────────────────
  return_reason_code          STRING              OPTIONS(description = "Return reason code (ISO 20022: AC04, AG01, etc.)"),
  rejection_reason            STRING              OPTIONS(description = "Rejection reason from receiving FI"),

  -- ── RAIL FINDER ───────────────────────────────────────────────────────────
  rail_finder_selected        BOOL                OPTIONS(description = "TRUE when PayCenter Rail Finder auto-selected this rail"),

  -- ── STATUS / SOURCE ───────────────────────────────────────────────────────
  status                      STRING    NOT NULL  OPTIONS(description = "Transaction lifecycle status"),
  source_product              STRING    NOT NULL  OPTIONS(description = "Source: JHA_PAYCENTER_RTP | JHA_PAYCENTER_FEDNOW"),
  channel                     STRING              OPTIONS(description = "Origination channel"),

  -- ── TIMESTAMPS ────────────────────────────────────────────────────────────
  initiated_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "When payment was initiated"),
  acceptance_timestamp        TIMESTAMP           OPTIONS(description = "When receiving FI accepted/posted"),
  settled_timestamp           TIMESTAMP           OPTIONS(description = "When payment settled (sub-second for instant)"),

  -- ── CDC METADATA ──────────────────────────────────────────────────────────
  _cdc_sequence_id            STRING    NOT NULL  OPTIONS(description = "Monotonic source sequence for deterministic ordering"),
  _cdc_operation              STRING    NOT NULL  OPTIONS(description = "CDC operation: I (insert) | U (update) | D (delete)"),
  _cdc_timestamp              TIMESTAMP NOT NULL  OPTIONS(description = "Source change-capture timestamp"),
  _cdc_source_system          STRING    NOT NULL  OPTIONS(description = "Source application identifier"),
  _cdc_load_timestamp         TIMESTAMP NOT NULL  OPTIONS(description = "Timestamp when record landed in BigQuery raw zone")
)
PARTITION BY DATE(initiated_timestamp)
CLUSTER BY tenant_id, payment_rail, transaction_type
OPTIONS(
  description = "Raw RTP + FedNow instant payment transactions. No transformation — 1:1 landing zone with CDC metadata.",
  require_partition_filter = TRUE
);

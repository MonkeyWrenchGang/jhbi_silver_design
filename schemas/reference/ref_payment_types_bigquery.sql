-- =============================================================================
-- JHBI Unified Payments Platform
-- Reference Layer: ref.payment_types  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Canonical payment type codes used across the platform.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.ref.payment_types`
(
  payment_type_code   STRING    NOT NULL  OPTIONS(description = "Canonical payment type code — PK"),
  payment_type_name   STRING    NOT NULL  OPTIONS(description = "Human-readable payment type name"),
  payment_rail        STRING    NOT NULL  OPTIONS(description = "Underlying network/rail"),
  description         STRING              OPTIONS(description = "Extended description"),
  is_instant          BOOL      NOT NULL  OPTIONS(description = "TRUE for real-time settlement rails (RTP, FedNow, Zelle)"),
  is_active           BOOL      NOT NULL  OPTIONS(description = "Soft-delete flag"),
  created_at          TIMESTAMP NOT NULL,
  updated_at          TIMESTAMP
)
OPTIONS(description = "Reference table for canonical payment types (ACH, Wire, Card, Zelle, RTP, FedNow, Check, RDC, BillPay).");

-- ── SEED DATA ─────────────────────────────────────────────────────────────────
INSERT INTO `your_project.ref.payment_types`
  (payment_type_code, payment_type_name, payment_rail, description, is_instant, is_active, created_at)
VALUES
  ('ACH',     'ACH',          'NACHA',    'Automated Clearing House batch payments',                          FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('WIRE',    'Wire',         'FEDWIRE',  'Domestic and international wire transfers (FedWire, SWIFT, CHIPS)', FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('CARD',    'Card',         'CARD_NET', 'Credit/debit/prepaid card transactions (Visa, MC, Amex, Discover)', FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('ZELLE',   'Zelle',        'EWS',      'Zelle P2P payments via Early Warning Services',                    TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('RTP',     'RTP',          'TCH_RTP',  'The Clearing House Real-Time Payments',                            TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('FEDNOW',  'FedNow',       'FEDNOW',   'Federal Reserve FedNow instant payment service',                   TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('CHECK',   'Check',        'SVPCO',    'Traditional paper check clearing via SVPCO/Fed',                   FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('RDC',     'Remote Deposit Capture', 'SVPCO', 'Mobile/branch remote deposit capture',                      FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('BILLPAY', 'Bill Payment', 'MIXED',    'Bill payments via iPay, Payrailz, BPS (ACH, check, or real-time delivery)', FALSE, TRUE, CURRENT_TIMESTAMP());

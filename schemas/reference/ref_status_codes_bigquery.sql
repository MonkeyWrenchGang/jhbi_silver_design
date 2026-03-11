-- =============================================================================
-- JHBI Unified Payments Platform
-- Reference Layer: ref.status_codes  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Canonical transaction lifecycle status codes.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.ref.status_codes`
(
  status_code       STRING    NOT NULL  OPTIONS(description = "Canonical status code — PK"),
  status_name       STRING    NOT NULL  OPTIONS(description = "Human-readable status name"),
  status_category   STRING    NOT NULL  OPTIONS(description = "Category: PENDING | ACTIVE | COMPLETED | FAILED | REVERSED"),
  description       STRING              OPTIONS(description = "Extended description"),
  is_terminal       BOOL      NOT NULL  OPTIONS(description = "TRUE if this is a terminal (final) state"),
  is_active         BOOL      NOT NULL  OPTIONS(description = "Soft-delete flag"),
  created_at        TIMESTAMP NOT NULL
)
OPTIONS(description = "Reference table for canonical transaction lifecycle status codes.");

-- ── SEED DATA ─────────────────────────────────────────────────────────────────
INSERT INTO `your_project.ref.status_codes`
  (status_code, status_name, status_category, description, is_terminal, is_active, created_at)
VALUES
  ('INITIATED',   'Initiated',    'PENDING',    'Transaction created, not yet submitted to network',   FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('PENDING',     'Pending',      'PENDING',    'Submitted to network, awaiting response',             FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('AUTHORIZED',  'Authorized',   'ACTIVE',     'Card authorization approved, pending settlement',     FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('PROCESSING',  'Processing',   'ACTIVE',     'In-flight at network or clearing house',              FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('SETTLED',     'Settled',      'COMPLETED',  'Funds settled between FIs',                           TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('COMPLETED',   'Completed',    'COMPLETED',  'Transaction fully completed (posted to accounts)',    TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('RETURNED',    'Returned',     'REVERSED',   'Transaction returned by receiving FI or network',     TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('REJECTED',    'Rejected',     'FAILED',     'Rejected by network or receiving FI',                 TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('FAILED',      'Failed',       'FAILED',     'Transaction failed (system error, timeout, etc.)',    TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('CANCELLED',   'Cancelled',    'FAILED',     'Cancelled by originator before processing',           TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('REVERSED',    'Reversed',     'REVERSED',   'Full reversal processed',                             TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('DISPUTED',    'Disputed',     'ACTIVE',     'Under chargeback/dispute investigation',              FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('HELD',        'Held',         'PENDING',    'Funds on hold (compliance, risk, Reg CC)',             FALSE, TRUE, CURRENT_TIMESTAMP()),
  ('EXPIRED',     'Expired',      'FAILED',     'Request for Payment expired without response',        TRUE,  TRUE, CURRENT_TIMESTAMP()),
  ('ON_HOLD',     'On Hold',      'PENDING',    'OFAC/AML screening hold',                             FALSE, TRUE, CURRENT_TIMESTAMP());

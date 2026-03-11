-- =============================================================================
-- JHBI Unified Payments Platform
-- Reference Layer: ref.transaction_directions  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Transaction direction reference.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.ref.transaction_directions`
(
  direction_code  STRING    NOT NULL  OPTIONS(description = "Direction code — PK"),
  direction_name  STRING    NOT NULL  OPTIONS(description = "Human-readable direction name"),
  description     STRING              OPTIONS(description = "Extended description"),
  created_at      TIMESTAMP NOT NULL
)
OPTIONS(description = "Reference table for transaction direction codes.");

-- ── SEED DATA ─────────────────────────────────────────────────────────────────
INSERT INTO `your_project.ref.transaction_directions`
  (direction_code, direction_name, description, created_at)
VALUES
  ('INBOUND',  'Inbound',  'Transaction received into the FI — funds coming in',  CURRENT_TIMESTAMP()),
  ('OUTBOUND', 'Outbound', 'Transaction sent from the FI — funds going out',      CURRENT_TIMESTAMP());

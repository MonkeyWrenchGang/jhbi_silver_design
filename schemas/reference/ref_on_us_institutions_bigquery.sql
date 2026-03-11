-- =============================================================================
-- JHBI Unified Payments Platform
-- Reference Layer: ref.on_us_institutions  (BigQuery)  ★ NEW
-- Version: v1.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Mapping of routing numbers / BICs to tenant_ids for on-us determination.
-- When both originator and beneficiary routing numbers resolve to the same
-- tenant_id, the transaction is flagged is_on_us = TRUE during silver ETL.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.ref.on_us_institutions`
(
  tenant_id           STRING    NOT NULL  OPTIONS(description = "FI tenant identifier"),
  routing_number      STRING    NOT NULL  OPTIONS(description = "ABA routing/transit number (9 digits)"),
  institution_name    STRING    NOT NULL  OPTIONS(description = "Full legal institution name"),
  institution_type    STRING              OPTIONS(description = "BANK | CREDIT_UNION | SAVINGS | HOLDING_CO"),
  swift_bic           STRING              OPTIONS(description = "SWIFT/BIC code (international wires)"),
  fed_member_id       STRING              OPTIONS(description = "Federal Reserve member ID"),
  is_rtp_participant  BOOL      NOT NULL  OPTIONS(description = "TRUE if connected to TCH RTP network"),
  is_fednow_participant BOOL    NOT NULL  OPTIONS(description = "TRUE if connected to FedNow network"),
  is_zelle_participant BOOL     NOT NULL  OPTIONS(description = "TRUE if connected to Zelle/EWS network"),
  is_active           BOOL      NOT NULL  OPTIONS(description = "Soft-delete flag"),
  effective_date      DATE      NOT NULL  OPTIONS(description = "Date this routing number became active"),
  expiry_date         DATE                OPTIONS(description = "Date this routing number was retired (NULL if active)"),
  created_at          TIMESTAMP NOT NULL,
  updated_at          TIMESTAMP
)
OPTIONS(description = "Routing number → tenant mapping for on-us determination + rail participation flags. Used by silver ETL to set is_on_us and by IR service for routing.");

-- ── EXAMPLE SEED DATA (replace with actual institution data) ──────────────────
-- INSERT INTO `your_project.ref.on_us_institutions`
--   (tenant_id, routing_number, institution_name, institution_type, swift_bic,
--    is_rtp_participant, is_fednow_participant, is_zelle_participant,
--    is_active, effective_date, created_at)
-- VALUES
--   ('TENANT_001', '021000021', 'Example Community Bank', 'BANK', NULL,
--    TRUE, TRUE, TRUE, TRUE, '2020-01-01', CURRENT_TIMESTAMP()),
--   ('TENANT_001', '021000089', 'Example Community Bank — Trust', 'BANK', NULL,
--    FALSE, FALSE, FALSE, TRUE, '2021-06-15', CURRENT_TIMESTAMP());

-- =============================================================================
-- JHBI Unified Payments Platform
-- Metadata Layer: metadata.source_to_target  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Source-to-target field mapping for every raw → silver transformation.
-- Used by data lineage tools, dbt docs, and audit reviews.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.metadata.source_to_target`
(
  mapping_id            INT64     NOT NULL  OPTIONS(description = "Auto-incrementing surrogate key"),
  source_system         STRING    NOT NULL  OPTIONS(description = "Source system name: ipay | eps | payrailz | cps | visa_dps | mc_banknet | ews | tch | fednow"),
  source_table          STRING    NOT NULL  OPTIONS(description = "Raw layer table name (e.g. raw.raw_ach)"),
  source_field          STRING    NOT NULL  OPTIONS(description = "Source column name in raw table"),
  target_table          STRING    NOT NULL  OPTIONS(description = "Target silver/identity table (e.g. lake.unified_transactions)"),
  target_field          STRING    NOT NULL  OPTIONS(description = "Target column name"),
  transformation_rule   STRING              OPTIONS(description = "Transformation logic: DIRECT_MAP | CAST | LOOKUP | CONDITIONAL | EXPRESSION"),
  transformation_expr   STRING              OPTIONS(description = "Expression or SQL fragment for non-trivial mappings"),
  data_type             STRING              OPTIONS(description = "Target BigQuery data type"),
  is_pci                BOOL      NOT NULL  OPTIONS(description = "TRUE if field contains PCI-sensitive data (card numbers, etc.)"),
  is_pii                BOOL      NOT NULL  OPTIONS(description = "TRUE if field contains PII (names, addresses, SSN tokens, etc.)"),
  is_active             BOOL      NOT NULL  OPTIONS(description = "Soft-delete flag"),
  created_at            TIMESTAMP NOT NULL,
  updated_at            TIMESTAMP
)
OPTIONS(description = "Source-to-target field mapping for raw → silver transformations. Supports lineage, audit, and dbt documentation.");

-- =============================================================================
-- JHBI Unified Payments Platform
-- Metadata Layer: metadata.data_catalog  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Master data catalog for all tables and columns across all layers.
-- Used by governance tools, search, and PCI/PII classification reports.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.metadata.data_catalog`
(
  catalog_id        INT64     NOT NULL  OPTIONS(description = "Auto-incrementing surrogate key"),
  dataset_name      STRING    NOT NULL  OPTIONS(description = "BigQuery dataset: raw | lake | identity | gold | ref | metadata"),
  table_name        STRING    NOT NULL  OPTIONS(description = "Full table name (e.g. raw_ach, unified_transactions, party)"),
  column_name       STRING    NOT NULL  OPTIONS(description = "Column name"),
  data_type         STRING    NOT NULL  OPTIONS(description = "BigQuery data type: STRING | INT64 | NUMERIC | BOOL | TIMESTAMP | DATE | JSON"),
  is_nullable       BOOL      NOT NULL  OPTIONS(description = "TRUE if column allows NULLs"),
  is_primary_key    BOOL      NOT NULL  OPTIONS(description = "TRUE if part of primary key"),
  is_foreign_key    BOOL      NOT NULL  OPTIONS(description = "TRUE if foreign key reference"),
  is_pci            BOOL      NOT NULL  OPTIONS(description = "TRUE if PCI-sensitive (card data, account tokens)"),
  is_pii            BOOL      NOT NULL  OPTIONS(description = "TRUE if PII (names, addresses, SSN tokens, phone, email)"),
  is_partition_key  BOOL      NOT NULL  OPTIONS(description = "TRUE if this column is the partition key"),
  is_cluster_key    BOOL      NOT NULL  OPTIONS(description = "TRUE if this column is in the CLUSTER BY clause"),
  description       STRING              OPTIONS(description = "Column description (mirrors OPTIONS description in DDL)"),
  cdc_source_field  STRING              OPTIONS(description = "Corresponding field name in CDC source if applicable"),
  notes             STRING              OPTIONS(description = "Additional governance or implementation notes"),
  created_at        TIMESTAMP NOT NULL,
  updated_at        TIMESTAMP
)
OPTIONS(description = "Master data catalog for all tables/columns across raw, silver, identity, gold, ref, and metadata layers. PCI/PII classification for governance.");

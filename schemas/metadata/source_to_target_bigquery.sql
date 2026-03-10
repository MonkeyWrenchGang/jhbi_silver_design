-- =============================================================================
-- JHBI Unified Payments Platform
-- Source-to-Target Mapping  (BigQuery)
-- =============================================================================
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.metadata.source_to_target`
(
  mapping_id              INT64     NOT NULL OPTIONS(description = "Surrogate key"),
  source_system           STRING    NOT NULL OPTIONS(description = "ipay | eps | payrailz | bps | ..."),
  payment_type            STRING    NOT NULL OPTIONS(description = "ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK_RDC | BILLPAY"),
  source_field            STRING    NOT NULL OPTIONS(description = "Field name in source system"),
  source_data_type        STRING             OPTIONS(description = "Data type in source"),
  target_schema           STRING    NOT NULL OPTIONS(description = "lake | identity | metadata | gold"),
  target_table            STRING    NOT NULL OPTIONS(description = "Target table name"),
  target_field            STRING    NOT NULL OPTIONS(description = "Column name in target table"),
  target_data_type        STRING             OPTIONS(description = "Data type in BigQuery target"),
  transformation_type     STRING    NOT NULL OPTIONS(description = "DIRECT | TOKENIZE | HASH | DERIVED | CONSTANT | IGNORED | SPLIT | CONCATENATE"),
  transformation_notes    STRING             OPTIONS(description = "Free-text notes on the transformation logic"),
  sensitivity_class       STRING    NOT NULL OPTIONS(description = "PCI | PII | NON_SENSITIVE"),
  ir_role                 STRING             OPTIONS(description = "BLOCK_KEY | MATCH_KEY | PARTY_ID | ACCOUNT_TOKEN | NULL"),
  ir_priority             INT64              OPTIONS(description = "Lower = higher priority in IR matching"),
  is_on_us_indicator      BOOL               OPTIONS(description = "TRUE = field used in on-us detection logic"),
  is_required             BOOL      NOT NULL OPTIONS(description = "TRUE = field must be populated for valid row"),
  notes                   STRING,
  created_at              TIMESTAMP NOT NULL,
  updated_at              TIMESTAMP NOT NULL,

  CONSTRAINT pk_source_to_target PRIMARY KEY (mapping_id) NOT ENFORCED
)
CLUSTER BY source_system, payment_type
OPTIONS(description = "Field-level lineage from source system to target BigQuery table. Single source of truth for ETL mapping documentation.");

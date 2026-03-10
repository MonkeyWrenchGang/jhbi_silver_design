-- =============================================================================
-- JHBI Unified Payments Platform
-- Gold Layer  (BigQuery)
-- =============================================================================
-- Aggregated reporting tables. Typically populated by scheduled queries or
-- dbt models reading from lake.unified_transactions.
-- Replace `your_project` with actual project ID.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Payment volume by type, tenant, and date
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.by_payment_type`
(
  tenant_id             STRING    NOT NULL  OPTIONS(description = "FI tenant"),
  payment_type          STRING    NOT NULL  OPTIONS(description = "ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK_RDC | BILLPAY"),
  period_date           DATE      NOT NULL  OPTIONS(description = "Aggregation date (partition key)"),
  txn_count             INT64     NOT NULL,
  total_amount          NUMERIC   NOT NULL,
  on_us_count           INT64     NOT NULL,
  on_us_amount          NUMERIC   NOT NULL,
  off_us_count          INT64     NOT NULL,
  off_us_amount         NUMERIC   NOT NULL,
  cross_currency_count  INT64              OPTIONS(description = "Transactions where original_currency_code IS NOT NULL"),
  cross_currency_amount NUMERIC            OPTIONS(description = "Sum of original_amount for cross-currency transactions"),
  updated_at            TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, payment_type
OPTIONS(description = "Daily payment volume aggregated by tenant and payment type.");

-- ---------------------------------------------------------------------------
-- 2. Identity resolution quality summary
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.ir_quality_daily`
(
  tenant_id         STRING    NOT NULL,
  period_date       DATE      NOT NULL,
  match_rule        STRING    NOT NULL  OPTIONS(description = "EXACT_TOKEN | ROUTING_ACCOUNT | PROXY_EXACT | NAME_ROUTING | NEW_PARTY"),
  party_role        STRING    NOT NULL  OPTIONS(description = "ORIGINATOR | BENEFICIARY"),
  txn_count         INT64     NOT NULL,
  avg_confidence    NUMERIC            OPTIONS(description = "Average confidence score for this rule"),
  updated_at        TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, match_rule
OPTIONS(description = "Daily IR resolution quality by match rule. Use to monitor shifts in rule distribution.");

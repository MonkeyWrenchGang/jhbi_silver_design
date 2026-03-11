-- =============================================================================
-- JHBI Unified Payments Platform
-- Gold Layer  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Aggregated reporting tables populated by scheduled queries or dbt models
-- reading from lake.unified_transactions + identity.*.
-- Replace `your_project` with actual project ID.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. PAYMENT VOLUME  — daily volume by type, tenant
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.by_payment_type`
(
  tenant_id               STRING    NOT NULL  OPTIONS(description = "FI tenant"),
  payment_type            STRING    NOT NULL  OPTIONS(description = "ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK | RDC | BILLPAY"),
  period_date             DATE      NOT NULL  OPTIONS(description = "Aggregation date (partition key)"),
  txn_count               INT64     NOT NULL,
  total_amount            NUMERIC   NOT NULL,
  avg_amount              NUMERIC             OPTIONS(description = "Average transaction amount"),
  inbound_count           INT64     NOT NULL,
  inbound_amount          NUMERIC   NOT NULL,
  outbound_count          INT64     NOT NULL,
  outbound_amount         NUMERIC   NOT NULL,
  on_us_count             INT64     NOT NULL,
  on_us_amount            NUMERIC   NOT NULL,
  off_us_count            INT64     NOT NULL,
  off_us_amount           NUMERIC   NOT NULL,
  return_count            INT64               OPTIONS(description = "Transactions with non-NULL return_reason_code"),
  return_amount           NUMERIC             OPTIONS(description = "Sum of returned transaction amounts"),
  recurring_count         INT64               OPTIONS(description = "Transactions where is_recurring = TRUE"),
  cross_currency_count    INT64               OPTIONS(description = "Transactions where settlement_currency_code IS NOT NULL"),
  cross_currency_amount   NUMERIC             OPTIONS(description = "Sum of settlement_amount for FX transactions"),
  updated_at              TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, payment_type
OPTIONS(description = "Daily payment volume aggregated by tenant and payment type. Includes inbound/outbound, on-us/off-us, returns, recurring, and FX splits.");

-- ---------------------------------------------------------------------------
-- 2. IR QUALITY  — identity resolution quality summary
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.ir_quality_daily`
(
  tenant_id               STRING    NOT NULL,
  period_date             DATE      NOT NULL,
  match_rule              STRING    NOT NULL  OPTIONS(description = "EXACT_TOKEN | ROUTING_ACCOUNT | PROXY_EXACT | NAME_ROUTING | NEW_PARTY"),
  party_role              STRING    NOT NULL  OPTIONS(description = "ORIGINATOR | BENEFICIARY"),
  txn_count               INT64     NOT NULL,
  avg_confidence          NUMERIC             OPTIONS(description = "Average confidence score for this rule"),
  min_confidence          NUMERIC,
  max_confidence          NUMERIC,
  new_party_count         INT64               OPTIONS(description = "Count where resolution_method = NEW_PARTY"),
  updated_at              TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, match_rule
OPTIONS(description = "Daily IR resolution quality by match rule. Monitor shifts in rule distribution and confidence drift.");

-- ---------------------------------------------------------------------------
-- 3. CROSS-RAIL FLOW  — daily inflow / outflow / net by rail (Sankey feed)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.cross_rail_flow_daily`
(
  tenant_id               STRING    NOT NULL,
  period_date             DATE      NOT NULL,
  payment_type            STRING    NOT NULL,
  inbound_count           INT64     NOT NULL,
  inbound_amount          NUMERIC   NOT NULL,
  outbound_count          INT64     NOT NULL,
  outbound_amount         NUMERIC   NOT NULL,
  net_amount              NUMERIC   NOT NULL  OPTIONS(description = "inbound_amount - outbound_amount"),
  on_us_count             INT64,
  on_us_amount            NUMERIC,
  updated_at              TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, payment_type
OPTIONS(description = "Daily cross-rail inflow/outflow/net. Primary feed for Sankey diagrams and cross-rail flow analysis.");

-- ---------------------------------------------------------------------------
-- 4. BY CHANNEL  — daily volume by originating channel
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.by_channel`
(
  tenant_id               STRING    NOT NULL,
  period_date             DATE      NOT NULL,
  channel                 STRING    NOT NULL  OPTIONS(description = "ONLINE | MOBILE | BRANCH | API | FILE | ATM | IVR | UNKNOWN"),
  payment_type            STRING    NOT NULL,
  txn_count               INT64     NOT NULL,
  total_amount            NUMERIC   NOT NULL,
  avg_amount              NUMERIC,
  return_count            INT64,
  updated_at              TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, channel, payment_type
OPTIONS(description = "Daily transaction volume by originating channel and payment type. Supports channel-mix analysis and digital adoption tracking.");

-- ---------------------------------------------------------------------------
-- 5. BILLER VOLUME  — daily billpay volume by biller / category
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.biller_volume_daily`
(
  tenant_id               STRING    NOT NULL,
  period_date             DATE      NOT NULL,
  biller_category         STRING    NOT NULL  OPTIONS(description = "UTILITIES | TELECOM | INSURANCE | MORTGAGE | …"),
  aggregator_name         STRING    NOT NULL  OPTIONS(description = "IPAY | PAYRAILZ | BPS | CHECKFREE | OTHER"),
  delivery_method         STRING              OPTIONS(description = "ELECTRONIC_ACH | ELECTRONIC_REAL_TIME | PAPER_CHECK | LASER_DRAFT"),
  txn_count               INT64     NOT NULL,
  total_amount            NUMERIC   NOT NULL,
  recurring_count         INT64               OPTIONS(description = "Recurring bill payments"),
  unique_payers           INT64               OPTIONS(description = "COUNT(DISTINCT originator_party_id)"),
  unique_billers          INT64               OPTIONS(description = "COUNT(DISTINCT biller_id from rail_details_json)"),
  updated_at              TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, biller_category
OPTIONS(description = "Daily BillPay volume by biller category and aggregator. Supports biller analytics, aggregator comparison, and delivery-method migration tracking.");

-- ---------------------------------------------------------------------------
-- 6. FX SUMMARY  — daily cross-currency / FX summary
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.fx_summary_daily`
(
  tenant_id               STRING    NOT NULL,
  period_date             DATE      NOT NULL,
  currency_pair           STRING    NOT NULL  OPTIONS(description = "ISO 4217 pair: e.g. EUR/USD, GBP/USD"),
  payment_type            STRING    NOT NULL  OPTIONS(description = "Typically WIRE for FX transactions"),
  txn_count               INT64     NOT NULL,
  total_original_amount   NUMERIC   NOT NULL  OPTIONS(description = "Sum of amount (in original currency)"),
  total_settlement_amount NUMERIC   NOT NULL  OPTIONS(description = "Sum of settlement_amount (in settlement currency)"),
  avg_fx_rate             NUMERIC             OPTIONS(description = "Weighted average exchange rate"),
  min_fx_rate             NUMERIC,
  max_fx_rate             NUMERIC,
  total_fx_fee            NUMERIC             OPTIONS(description = "Sum of FX-related fees if captured"),
  updated_at              TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, currency_pair
OPTIONS(description = "Daily FX / cross-currency summary. Currency pair, volume, rate range, and settlement totals.");

-- ---------------------------------------------------------------------------
-- 7. PARTY ACTIVITY  — daily party-level transaction summary
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.gold.party_activity_daily`
(
  tenant_id               STRING    NOT NULL,
  period_date             DATE      NOT NULL,
  party_id                STRING    NOT NULL  OPTIONS(description = "FK → identity.party"),
  party_type              STRING    NOT NULL,
  role                    STRING    NOT NULL  OPTIONS(description = "ORIGINATOR | BENEFICIARY | BOTH"),
  txn_count               INT64     NOT NULL,
  total_amount            NUMERIC   NOT NULL,
  distinct_rails          INT64               OPTIONS(description = "Number of distinct payment_types used"),
  distinct_counterparties INT64               OPTIONS(description = "Number of distinct other-side party_ids"),
  on_us_count             INT64,
  return_count            INT64,
  updated_at              TIMESTAMP NOT NULL
)
PARTITION BY period_date
CLUSTER BY tenant_id, party_id
OPTIONS(description = "Daily party-level activity summary. Supports entity-level dashboards, anomaly detection features, and cross-rail behavioral analytics.");

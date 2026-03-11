-- =============================================================================
-- JHBI Unified Payments Platform
-- Metadata Layer: metadata.bq_dataset_layout  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Registry of all BigQuery datasets, tables, and their medallion layer assignments.
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.metadata.bq_dataset_layout`
(
  dataset_name    STRING    NOT NULL  OPTIONS(description = "BigQuery dataset name"),
  table_name      STRING    NOT NULL  OPTIONS(description = "Table name within dataset"),
  layer           STRING    NOT NULL  OPTIONS(description = "Medallion layer: RAW | SILVER | GOLD | IDENTITY | REFERENCE | METADATA"),
  description     STRING              OPTIONS(description = "Table description"),
  partition_key   STRING              OPTIONS(description = "Partition column if partitioned"),
  cluster_keys    ARRAY<STRING>       OPTIONS(description = "Cluster columns if clustered"),
  row_access_policy STRING            OPTIONS(description = "Row-level security policy name if applicable"),
  created_at      TIMESTAMP NOT NULL,
  updated_at      TIMESTAMP
)
OPTIONS(description = "Registry of all BigQuery datasets and tables with medallion layer assignments, partition/cluster metadata.");

-- ── SEED DATA ─────────────────────────────────────────────────────────────────
INSERT INTO `your_project.metadata.bq_dataset_layout`
  (dataset_name, table_name, layer, description, partition_key, cluster_keys, created_at)
VALUES
  -- RAW LAYER
  ('raw', 'raw_ach',            'RAW',       'ACH transactions from source',                      'created_timestamp',   ['tenant_id','entry_class_code','direction'], CURRENT_TIMESTAMP()),
  ('raw', 'raw_wire',           'RAW',       'Wire transactions from source',                     'initiated_timestamp', ['tenant_id','wire_type','direction'],         CURRENT_TIMESTAMP()),
  ('raw', 'raw_card',           'RAW',       'Card transactions from source',                     'auth_timestamp',      ['tenant_id','card_brand','card_type'],        CURRENT_TIMESTAMP()),
  ('raw', 'raw_zelle',          'RAW',       'Zelle P2P transactions from source',                'initiated_timestamp', ['tenant_id','payment_type'],                  CURRENT_TIMESTAMP()),
  ('raw', 'raw_rtp_fednow',     'RAW',       'RTP + FedNow instant payment transactions',         'initiated_timestamp', ['tenant_id','payment_rail','transaction_type'], CURRENT_TIMESTAMP()),
  ('raw', 'raw_check_rdc',      'RAW',       'Check and RDC transactions from source',            'deposit_timestamp',   ['tenant_id','deposit_type','check_type'],     CURRENT_TIMESTAMP()),
  ('raw', 'raw_billpay',        'RAW',       'BillPay transactions from source',                  'created_timestamp',   ['tenant_id','payment_type','delivery_method'], CURRENT_TIMESTAMP()),

  -- SILVER LAYER
  ('lake', 'unified_transactions', 'SILVER', 'Canonical unified payment transactions (8+ rails)', 'transaction_ts',      ['tenant_id','payment_type','status'],         CURRENT_TIMESTAMP()),

  -- IDENTITY LAYER
  ('identity', 'party',                    'IDENTITY', 'Master party entity',                     NULL, ['tenant_id','party_type'],        CURRENT_TIMESTAMP()),
  ('identity', 'party_name',              'IDENTITY', 'Party name history (tokenized)',            NULL, ['tenant_id'],                     CURRENT_TIMESTAMP()),
  ('identity', 'party_account',           'IDENTITY', 'Party account records (tokenized)',         NULL, ['tenant_id','account_type'],      CURRENT_TIMESTAMP()),
  ('identity', 'party_account_rail_ref',  'IDENTITY', 'Account-to-rail-network mapping',          NULL, ['tenant_id','rail_network'],      CURRENT_TIMESTAMP()),
  ('identity', 'party_proxy',             'IDENTITY', 'Party proxy identifiers (email, phone)',    NULL, ['tenant_id','proxy_type'],        CURRENT_TIMESTAMP()),
  ('identity', 'party_relationship',      'IDENTITY', 'Inter-party relationships',                NULL, ['tenant_id'],                     CURRENT_TIMESTAMP()),
  ('identity', 'party_resolution_event',  'IDENTITY', 'IR resolution audit log',                  NULL, ['tenant_id','match_rule'],        CURRENT_TIMESTAMP()),
  ('identity', 'biller_registry',         'IDENTITY', 'Known biller registry for BillPay IR',     NULL, ['tenant_id','biller_category'],   CURRENT_TIMESTAMP()),

  -- GOLD LAYER
  ('gold', 'by_payment_type',         'GOLD', 'Daily volume by payment type and tenant',          'period_date', ['tenant_id','payment_type'],     CURRENT_TIMESTAMP()),
  ('gold', 'ir_quality_daily',        'GOLD', 'Daily IR resolution quality by match rule',        'period_date', ['tenant_id','match_rule'],       CURRENT_TIMESTAMP()),
  ('gold', 'cross_rail_flow_daily',   'GOLD', 'Daily cross-rail inflow/outflow/net',              'period_date', ['tenant_id','payment_type'],     CURRENT_TIMESTAMP()),
  ('gold', 'by_channel',              'GOLD', 'Daily volume by originating channel',              'period_date', ['tenant_id','channel','payment_type'], CURRENT_TIMESTAMP()),
  ('gold', 'biller_volume_daily',     'GOLD', 'Daily BillPay volume by biller category',          'period_date', ['tenant_id','biller_category'],  CURRENT_TIMESTAMP()),
  ('gold', 'fx_summary_daily',        'GOLD', 'Daily FX/cross-currency summary',                  'period_date', ['tenant_id','currency_pair'],    CURRENT_TIMESTAMP()),
  ('gold', 'party_activity_daily',    'GOLD', 'Daily party-level transaction summary',             'period_date', ['tenant_id','party_id'],         CURRENT_TIMESTAMP()),

  -- REFERENCE LAYER
  ('ref', 'payment_types',            'REFERENCE', 'Canonical payment type codes',                 NULL, NULL, CURRENT_TIMESTAMP()),
  ('ref', 'status_codes',             'REFERENCE', 'Transaction lifecycle status codes',           NULL, NULL, CURRENT_TIMESTAMP()),
  ('ref', 'ach_return_codes',         'REFERENCE', 'NACHA ACH return reason codes (R01–R85)',      NULL, NULL, CURRENT_TIMESTAMP()),
  ('ref', 'transaction_directions',   'REFERENCE', 'Transaction direction codes',                  NULL, NULL, CURRENT_TIMESTAMP()),
  ('ref', 'on_us_institutions',       'REFERENCE', 'Routing number → tenant mapping for on-us',   NULL, NULL, CURRENT_TIMESTAMP()),

  -- METADATA LAYER
  ('metadata', 'source_to_target',    'METADATA', 'Source-to-target field mappings',               NULL, NULL, CURRENT_TIMESTAMP()),
  ('metadata', 'data_catalog',        'METADATA', 'Master data catalog (all columns)',             NULL, NULL, CURRENT_TIMESTAMP()),
  ('metadata', 'bq_dataset_layout',   'METADATA', 'Dataset/table registry',                        NULL, NULL, CURRENT_TIMESTAMP());

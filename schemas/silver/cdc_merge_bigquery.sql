-- =============================================================================
-- JHBI Unified Payments Platform
-- CDC MERGE Pattern for unified_transactions  (BigQuery)
-- Version: v4.0.0  |  Date: 2026-03-10
-- =============================================================================
-- Target: `your_project.lake.unified_transactions`
-- Source:  `your_project.lake.stg_unified_transactions`
--
-- Assumptions:
--   1) Source rows already validated (including rail_details_json schema).
--   2) Source may contain multiple changes per business key; we keep latest
--      by _cdc_timestamp / _cdc_sequence_id.
--   3) Deletes represented by _cdc_operation = 'D' remove rows from silver.
--
-- v4 Changes:
--   + settlement_amount / settlement_currency_code (FX support)
--   + description (promoted from rail_details_json)
--   + return_reason_code (promoted from rail_details_json)
--   + is_on_us (promoted from rail_details_json)
--   + is_recurring (promoted from rail_details_json)
-- =============================================================================

MERGE `your_project.lake.unified_transactions` AS t
USING (
  SELECT * EXCEPT(rn)
  FROM (
    SELECT
      s.*,
      ROW_NUMBER() OVER (
        PARTITION BY s.tenant_id, s.source_system, s.source_transaction_id
        ORDER BY s._cdc_timestamp DESC, s._cdc_sequence_id DESC, s.ingestion_ts DESC
      ) AS rn
    FROM `your_project.lake.stg_unified_transactions` s
  )
  WHERE rn = 1
) AS s
ON t.tenant_id = s.tenant_id
AND t.source_system = s.source_system
AND t.source_transaction_id = s.source_transaction_id

-- ── DELETE on soft-delete CDC event ──────────────────────────────────────────
WHEN MATCHED
  AND s._cdc_operation = 'D'
THEN DELETE

-- ── UPDATE when source is newer ──────────────────────────────────────────────
WHEN MATCHED
  AND s._cdc_operation IN ('I', 'U')
  AND (
    s._cdc_timestamp > t._cdc_timestamp OR
    (s._cdc_timestamp = t._cdc_timestamp AND s._cdc_sequence_id > t._cdc_sequence_id)
  )
THEN UPDATE SET
  transaction_id            = s.transaction_id,
  event_id                  = s.event_id,
  payment_type              = s.payment_type,
  payment_rail              = s.payment_rail,
  direction                 = s.direction,
  channel                   = s.channel,
  -- amount / currency / FX
  amount                    = s.amount,
  currency_code             = s.currency_code,
  settlement_amount         = s.settlement_amount,           -- v4
  settlement_currency_code  = s.settlement_currency_code,    -- v4
  fee_amount                = s.fee_amount,
  -- time / status
  transaction_ts            = s.transaction_ts,
  effective_date            = s.effective_date,
  settlement_date           = s.settlement_date,
  status                    = s.status,
  status_reason_code        = s.status_reason_code,
  return_reason_code        = s.return_reason_code,          -- v4
  -- promoted analytics flags
  description               = s.description,                 -- v4
  is_on_us                  = s.is_on_us,                    -- v4
  is_recurring              = s.is_recurring,                -- v4
  -- party references
  originator_party_id       = s.originator_party_id,
  originator_account_token  = s.originator_account_token,
  originator_routing_number = s.originator_routing_number,
  beneficiary_party_id      = s.beneficiary_party_id,
  beneficiary_account_token = s.beneficiary_account_token,
  beneficiary_routing_number = s.beneficiary_routing_number,
  -- rail JSON
  rail_schema_version       = s.rail_schema_version,
  rail_details_json         = s.rail_details_json,
  dq_flags_json             = s.dq_flags_json,
  -- schema & audit
  schema_version            = s.schema_version,
  event_ts                  = s.event_ts,
  ingestion_ts              = s.ingestion_ts,
  -- CDC metadata
  _cdc_sequence_id          = s._cdc_sequence_id,
  _cdc_operation            = s._cdc_operation,
  _cdc_timestamp            = s._cdc_timestamp,
  _cdc_source_system        = s._cdc_source_system,
  _cdc_load_timestamp       = s._cdc_load_timestamp

-- ── INSERT new rows ──────────────────────────────────────────────────────────
WHEN NOT MATCHED
  AND s._cdc_operation IN ('I', 'U')
THEN INSERT (
  transaction_id,
  tenant_id,
  source_system,
  source_transaction_id,
  event_id,
  payment_type,
  payment_rail,
  direction,
  channel,
  -- amount / currency / FX
  amount,
  currency_code,
  settlement_amount,                -- v4
  settlement_currency_code,         -- v4
  fee_amount,
  -- time / status
  transaction_ts,
  effective_date,
  settlement_date,
  status,
  status_reason_code,
  return_reason_code,               -- v4
  -- promoted analytics flags
  description,                      -- v4
  is_on_us,                         -- v4
  is_recurring,                     -- v4
  -- party references
  originator_party_id,
  originator_account_token,
  originator_routing_number,
  beneficiary_party_id,
  beneficiary_account_token,
  beneficiary_routing_number,
  -- rail JSON
  rail_schema_version,
  rail_details_json,
  dq_flags_json,
  -- schema & audit
  schema_version,
  event_ts,
  ingestion_ts,
  -- CDC metadata
  _cdc_sequence_id,
  _cdc_operation,
  _cdc_timestamp,
  _cdc_source_system,
  _cdc_load_timestamp
)
VALUES (
  s.transaction_id,
  s.tenant_id,
  s.source_system,
  s.source_transaction_id,
  s.event_id,
  s.payment_type,
  s.payment_rail,
  s.direction,
  s.channel,
  s.amount,
  s.currency_code,
  s.settlement_amount,              -- v4
  s.settlement_currency_code,       -- v4
  s.fee_amount,
  s.transaction_ts,
  s.effective_date,
  s.settlement_date,
  s.status,
  s.status_reason_code,
  s.return_reason_code,             -- v4
  s.description,                    -- v4
  s.is_on_us,                       -- v4
  s.is_recurring,                   -- v4
  s.originator_party_id,
  s.originator_account_token,
  s.originator_routing_number,
  s.beneficiary_party_id,
  s.beneficiary_account_token,
  s.beneficiary_routing_number,
  s.rail_schema_version,
  s.rail_details_json,
  s.dq_flags_json,
  s.schema_version,
  s.event_ts,
  s.ingestion_ts,
  s._cdc_sequence_id,
  s._cdc_operation,
  s._cdc_timestamp,
  s._cdc_source_system,
  s._cdc_load_timestamp
);

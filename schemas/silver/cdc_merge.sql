-- PostgreSQL CDC MERGE pattern for lake.unified_transactions
-- Requires PostgreSQL 15+ for MERGE.
--
-- Target table:
--   lake.unified_transactions
-- Source/staging table:
--   lake.stg_unified_transactions
--
-- Assumptions:
-- 1) Source rows already validated (including rail_details_json schema).
-- 2) Keep latest source row by (_cdc_timestamp, _cdc_sequence_id) per business key.
-- 3) _cdc_operation = 'D' means delete from silver.

WITH latest_src AS (
  SELECT DISTINCT ON (tenant_id, source_system, source_transaction_id)
    s.*
  FROM lake.stg_unified_transactions s
  ORDER BY
    tenant_id,
    source_system,
    source_transaction_id,
    _cdc_timestamp DESC,
    _cdc_sequence_id DESC,
    ingestion_ts DESC
)
MERGE INTO lake.unified_transactions AS t
USING latest_src AS s
ON t.tenant_id = s.tenant_id
AND t.source_system = s.source_system
AND t.source_transaction_id = s.source_transaction_id

WHEN MATCHED
  AND s._cdc_operation = 'D'
THEN DELETE

WHEN MATCHED
  AND s._cdc_operation IN ('I', 'U')
  AND (
    s._cdc_timestamp > t._cdc_timestamp OR
    (s._cdc_timestamp = t._cdc_timestamp AND s._cdc_sequence_id > t._cdc_sequence_id)
  )
THEN UPDATE SET
  transaction_id = s.transaction_id,
  event_id = s.event_id,
  payment_type = s.payment_type,
  payment_rail = s.payment_rail,
  direction = s.direction,
  channel = s.channel,
  amount = s.amount,
  currency_code = s.currency_code,
  fee_amount = s.fee_amount,
  transaction_ts = s.transaction_ts,
  effective_date = s.effective_date,
  settlement_date = s.settlement_date,
  status = s.status,
  status_reason_code = s.status_reason_code,
  originator_party_id = s.originator_party_id,
  originator_account_token = s.originator_account_token,
  originator_routing_number = s.originator_routing_number,
  beneficiary_party_id = s.beneficiary_party_id,
  beneficiary_account_token = s.beneficiary_account_token,
  beneficiary_routing_number = s.beneficiary_routing_number,
  rail_schema_version = s.rail_schema_version,
  rail_details_json = s.rail_details_json,
  dq_flags_json = s.dq_flags_json,
  schema_version = s.schema_version,
  event_ts = s.event_ts,
  ingestion_ts = s.ingestion_ts,
  _cdc_sequence_id = s._cdc_sequence_id,
  _cdc_operation = s._cdc_operation,
  _cdc_timestamp = s._cdc_timestamp,
  _cdc_source_system = s._cdc_source_system,
  _cdc_load_timestamp = s._cdc_load_timestamp

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
  amount,
  currency_code,
  fee_amount,
  transaction_ts,
  effective_date,
  settlement_date,
  status,
  status_reason_code,
  originator_party_id,
  originator_account_token,
  originator_routing_number,
  beneficiary_party_id,
  beneficiary_account_token,
  beneficiary_routing_number,
  rail_schema_version,
  rail_details_json,
  dq_flags_json,
  schema_version,
  event_ts,
  ingestion_ts,
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
  s.fee_amount,
  s.transaction_ts,
  s.effective_date,
  s.settlement_date,
  s.status,
  s.status_reason_code,
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


-- =============================================================================
-- JHBI Unified Payments Platform
-- Source-to-Target Mapping  (PostgreSQL 14+)
-- =============================================================================
-- This table is the authoritative mapping between:
--   source system fields  →  unified_transactions columns
--                         →  identity schema columns
--   including:
--     - PCI/PII handling instructions (tokenize | hash | mask | passthrough)
--     - Identity resolution hook (which source fields seed the IR service)
--     - on-us detection logic per rail
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS metadata;

CREATE TABLE IF NOT EXISTS metadata.source_to_target (
  mapping_id            SERIAL PRIMARY KEY,

  -- Source context
  source_system         TEXT NOT NULL,
  -- ipay | eps | payrailz | bps | fednow_gateway | tchrtp_gateway | visa_dps | mc_connect

  payment_type          TEXT NOT NULL,
  -- ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK_RDC | BILLPAY

  source_table          TEXT NOT NULL,
  source_field          TEXT NOT NULL,
  source_data_type      TEXT,
  source_description    TEXT,

  -- Target context
  target_schema         TEXT NOT NULL,
  -- lake | identity | metadata

  target_table          TEXT NOT NULL,
  target_field          TEXT NOT NULL,
  target_data_type      TEXT,

  -- Transformation instructions
  transformation_type   TEXT NOT NULL,
  -- DIRECT_MAP | TOKENIZE | HASH | MASK | DERIVE | CONSTANT | CONCAT | LOOKUP | IGNORE

  transformation_notes  TEXT,
  -- Free-text explanation of any logic (e.g. "Cast YYYYMMDD to DATE", "Prefix 'tok_'")

  -- PCI/PII classification
  sensitivity_class     TEXT NOT NULL DEFAULT 'STANDARD',
  -- PCI | PII | PCI_PII | STANDARD

  -- Identity resolution role
  ir_role               TEXT,
  -- ORIGINATOR_ACCOUNT_TOKEN | ORIGINATOR_ROUTING | ORIGINATOR_PROXY |
  -- BENEFICIARY_ACCOUNT_TOKEN | BENEFICIARY_ROUTING | BENEFICIARY_PROXY |
  -- ORIGINATOR_NAME_TOKEN | BENEFICIARY_NAME_TOKEN | NULL (not used by IR)

  ir_priority           SMALLINT,
  -- 1 = primary match attribute, 2 = secondary, 3 = supporting; NULL if ir_role is null

  -- On-us detection
  is_on_us_indicator    BOOLEAN NOT NULL DEFAULT FALSE,
  -- TRUE when this field is part of the on-us detection logic
  on_us_detection_notes TEXT,
  -- e.g. "Compare originator_routing == beneficiary_routing; if equal, is_on_us=TRUE"

  -- Compliance
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  effective_date        DATE NOT NULL DEFAULT CURRENT_DATE,
  expiry_date           DATE,

  -- Audit
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by            TEXT NOT NULL DEFAULT 'system',
  schema_version        TEXT NOT NULL DEFAULT '1.0'
);

-- =============================================================================
-- SEED DATA — ACH (iPay source)
-- =============================================================================
INSERT INTO metadata.source_to_target
  (source_system, payment_type, source_table, source_field, source_data_type, source_description,
   target_schema, target_table, target_field, target_data_type,
   transformation_type, transformation_notes, sensitivity_class, ir_role, ir_priority,
   is_on_us_indicator, on_us_detection_notes)
VALUES

-- Core identity / keys
('ipay','ACH','ipay.ach_transactions','txn_id','VARCHAR','iPay transaction ID',
 'lake','unified_transactions','source_transaction_id','TEXT',
 'DIRECT_MAP',NULL,'STANDARD',NULL,NULL,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','tenant_fi_id','VARCHAR','FI tenant identifier',
 'lake','unified_transactions','tenant_id','TEXT',
 'DIRECT_MAP',NULL,'STANDARD',NULL,NULL,FALSE,NULL),

-- Amount / dates / status
('ipay','ACH','ipay.ach_transactions','txn_amt','DECIMAL','Transaction amount',
 'lake','unified_transactions','amount','NUMERIC(18,2)',
 'DIRECT_MAP','Confirm positive for credits, absolute value for debits','STANDARD',NULL,NULL,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','eff_dt','CHAR(6)','Effective date YYMMDD',
 'lake','unified_transactions','effective_date','DATE',
 'DERIVE','Parse YYMMDD → DATE; prefix 20xx for century','STANDARD',NULL,NULL,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','settle_dt','CHAR(6)','Settlement date',
 'lake','unified_transactions','settlement_date','DATE',
 'DERIVE','Parse YYMMDD → DATE','STANDARD',NULL,NULL,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','txn_status','VARCHAR','iPay status code',
 'lake','unified_transactions','status','TEXT',
 'LOOKUP','Map iPay status codes → canonical: 00=SETTLED, 01=PENDING, R*=RETURNED','STANDARD',NULL,NULL,FALSE,NULL),

-- ACH rail fields
('ipay','ACH','ipay.ach_transactions','trace_num','CHAR(15)','NACHA trace number',
 'lake','unified_transactions','rail_details_json','JSONB',
 'DERIVE','Set rail_details_json.trace_number','STANDARD',NULL,NULL,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','sec_code','CHAR(3)','SEC code',
 'lake','unified_transactions','rail_details_json','JSONB',
 'DERIVE','Set rail_details_json.entry_class_code','STANDARD',NULL,NULL,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','txn_type','CHAR(2)','CR/DR indicator',
 'lake','unified_transactions','rail_details_json','JSONB',
 'DERIVE','Map CR→CREDIT, DR→DEBIT into rail_details_json.transaction_type','STANDARD',NULL,NULL,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','same_day_flg','CHAR(1)','Same-day flag',
 'lake','unified_transactions','rail_details_json','JSONB',
 'DERIVE','Y→true, N→false in rail_details_json.same_day_flag','STANDARD',NULL,NULL,FALSE,NULL),

-- Originator (PCI — tokenize)
('ipay','ACH','ipay.ach_transactions','orig_acct_num','VARCHAR(17)','Originator DDA number — PCI',
 'lake','unified_transactions','originator_account_token','TEXT',
 'TOKENIZE','Call vault API; store returned token; never persist raw value','PCI',
 'ORIGINATOR_ACCOUNT_TOKEN',1,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','odfi_routing','CHAR(9)','ODFI routing number',
 'lake','unified_transactions','originator_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD',
 'ORIGINATOR_ROUTING',2,TRUE,'Also written to identity.party_account.institution_routing_number for originator'),

('ipay','ACH','ipay.ach_transactions','orig_name','VARCHAR(22)','Originator name — PII',
 'identity','party','name_token','TEXT',
 'TOKENIZE','Vault tokenize; link to identity.party row via originator_party_id','PII',
 'ORIGINATOR_NAME_TOKEN',3,FALSE,NULL),

-- Beneficiary / receiver (PCI — tokenize)
('ipay','ACH','ipay.ach_transactions','recv_acct_num','VARCHAR(17)','Receiver DDA — PCI',
 'lake','unified_transactions','beneficiary_account_token','TEXT',
 'TOKENIZE','Call vault API; store returned token','PCI',
 'BENEFICIARY_ACCOUNT_TOKEN',1,FALSE,NULL),

('ipay','ACH','ipay.ach_transactions','rdfi_routing','CHAR(9)','RDFI routing number',
 'lake','unified_transactions','beneficiary_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD',
 'BENEFICIARY_ROUTING',2,TRUE,'Compare to odfi_routing to determine is_on_us'),

('ipay','ACH','ipay.ach_transactions','recv_name','VARCHAR(22)','Receiver name — PII',
 'identity','party','name_token','TEXT',
 'TOKENIZE','Vault tokenize; link to identity.party row via beneficiary_party_id','PII',
 'BENEFICIARY_NAME_TOKEN',3,FALSE,NULL),

-- On-us detection (derived column, not directly from source)
('ipay','ACH','ipay.ach_transactions','[DERIVED]','BOOLEAN','On-us flag (derived)',
 'lake','unified_transactions','is_on_us','BOOLEAN',
 'DERIVE','IF odfi_routing = rdfi_routing THEN TRUE ELSE FALSE','STANDARD',NULL,NULL,
 TRUE,'odfi_routing == rdfi_routing → is_on_us=TRUE; on_us_settlement_type=INTERNAL_ACH'),

-- CDC metadata
('ipay','ACH','ipay.cdc_events','cdc_seq','BIGINT','CDC sequence',
 'lake','unified_transactions','_cdc_sequence_id','TEXT',
 'DIRECT_MAP',NULL,'STANDARD',NULL,NULL,FALSE,NULL),

('ipay','ACH','ipay.cdc_events','cdc_op','CHAR(1)','CDC operation',
 'lake','unified_transactions','_cdc_operation','CHAR(1)',
 'DIRECT_MAP',NULL,'STANDARD',NULL,NULL,FALSE,NULL);

-- =============================================================================
-- SEED DATA — WIRE (EPS source)
-- =============================================================================
INSERT INTO metadata.source_to_target
  (source_system, payment_type, source_table, source_field, source_data_type, source_description,
   target_schema, target_table, target_field, target_data_type,
   transformation_type, transformation_notes, sensitivity_class, ir_role, ir_priority,
   is_on_us_indicator, on_us_detection_notes)
VALUES

('eps','WIRE','eps.wire_transactions','wire_txn_id','VARCHAR','EPS wire ID',
 'lake','unified_transactions','source_transaction_id','TEXT',
 'DIRECT_MAP',NULL,'STANDARD',NULL,NULL,FALSE,NULL),

('eps','WIRE','eps.wire_transactions','imad','CHAR(22)','Fedwire IMAD',
 'lake','unified_transactions','rail_details_json','JSONB',
 'DERIVE','Set rail_details_json.imad','STANDARD',NULL,NULL,FALSE,NULL),

('eps','WIRE','eps.wire_transactions','orig_acct','VARCHAR','Originator account — PCI',
 'lake','unified_transactions','originator_account_token','TEXT',
 'TOKENIZE','Vault tokenize','PCI','ORIGINATOR_ACCOUNT_TOKEN',1,FALSE,NULL),

('eps','WIRE','eps.wire_transactions','orig_aba','CHAR(9)','Originator FI routing',
 'lake','unified_transactions','originator_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD','ORIGINATOR_ROUTING',2,TRUE,
 'Compare to bene_aba for on-us determination'),

('eps','WIRE','eps.wire_transactions','bene_acct','VARCHAR','Beneficiary account — PCI',
 'lake','unified_transactions','beneficiary_account_token','TEXT',
 'TOKENIZE','Vault tokenize','PCI','BENEFICIARY_ACCOUNT_TOKEN',1,FALSE,NULL),

('eps','WIRE','eps.wire_transactions','bene_aba','CHAR(9)','Beneficiary FI routing',
 'lake','unified_transactions','beneficiary_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD','BENEFICIARY_ROUTING',2,TRUE,
 'Compare to orig_aba for on-us determination'),

('eps','WIRE','eps.wire_transactions','[DERIVED]','BOOLEAN','On-us flag',
 'lake','unified_transactions','is_on_us','BOOLEAN',
 'DERIVE','orig_aba == bene_aba → is_on_us=TRUE; settlement_type=INTERNAL_WIRE','STANDARD',NULL,NULL,
 TRUE,'orig_aba == bene_aba → on-us wire (book transfer)');

-- =============================================================================
-- SEED DATA — ZELLE (iPay / Payrailz source)
-- =============================================================================
INSERT INTO metadata.source_to_target
  (source_system, payment_type, source_table, source_field, source_data_type, source_description,
   target_schema, target_table, target_field, target_data_type,
   transformation_type, transformation_notes, sensitivity_class, ir_role, ir_priority,
   is_on_us_indicator, on_us_detection_notes)
VALUES

('payrailz','ZELLE','prz.zelle_payments','zelle_ref_id','VARCHAR','Zelle reference ID',
 'lake','unified_transactions','rail_details_json','JSONB',
 'DERIVE','Set rail_details_json.zelle_reference_id','STANDARD',NULL,NULL,FALSE,NULL),

('payrailz','ZELLE','prz.zelle_payments','sender_email','VARCHAR','Sender email — PII',
 'lake','unified_transactions','originator_account_token','TEXT',
 'TOKENIZE','Vault tokenize; also populate identity.party_account.proxy_value_token + proxy_type=EMAIL',
 'PII','ORIGINATOR_PROXY',1,FALSE,NULL),

('payrailz','ZELLE','prz.zelle_payments','sender_fi_routing','CHAR(9)','Sender FI routing',
 'lake','unified_transactions','originator_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD','ORIGINATOR_ROUTING',2,TRUE,
 'Compare to receiver_fi_routing for on-us Zelle determination'),

('payrailz','ZELLE','prz.zelle_payments','receiver_proxy','VARCHAR','Receiver alias email/phone — PII',
 'lake','unified_transactions','beneficiary_account_token','TEXT',
 'TOKENIZE','Vault tokenize; populate identity.party_account.proxy_value_token','PII',
 'BENEFICIARY_PROXY',1,FALSE,NULL),

('payrailz','ZELLE','prz.zelle_payments','receiver_fi_routing','CHAR(9)','Receiver FI routing',
 'lake','unified_transactions','beneficiary_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD','BENEFICIARY_ROUTING',2,TRUE,
 'Compare to sender_fi_routing for on-us Zelle'),

('payrailz','ZELLE','prz.zelle_payments','[DERIVED]','BOOLEAN','On-us flag',
 'lake','unified_transactions','is_on_us','BOOLEAN',
 'DERIVE','sender_fi_routing == receiver_fi_routing → is_on_us=TRUE; settlement_type=INTERNAL_ZELLE',
 'STANDARD',NULL,NULL,TRUE,'Same FI for both sides');

-- =============================================================================
-- SEED DATA — RTP / FedNow (shared gateway pattern)
-- =============================================================================
INSERT INTO metadata.source_to_target
  (source_system, payment_type, source_table, source_field, source_data_type, source_description,
   target_schema, target_table, target_field, target_data_type,
   transformation_type, transformation_notes, sensitivity_class, ir_role, ir_priority,
   is_on_us_indicator, on_us_detection_notes)
VALUES

('tchrtp_gateway','RTP','rtp.messages','tch_txn_id','VARCHAR','TCH transaction ID',
 'lake','unified_transactions','source_transaction_id','TEXT',
 'DIRECT_MAP',NULL,'STANDARD',NULL,NULL,FALSE,NULL),

('tchrtp_gateway','RTP','rtp.messages','creditor_acct_token','VARCHAR','Creditor account token',
 'lake','unified_transactions','beneficiary_account_token','TEXT',
 'DIRECT_MAP','Already tokenized by gateway','PCI','BENEFICIARY_ACCOUNT_TOKEN',1,FALSE,NULL),

('tchrtp_gateway','RTP','rtp.messages','instructing_agent_aba','CHAR(9)','Sending FI routing',
 'lake','unified_transactions','originator_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD','ORIGINATOR_ROUTING',2,TRUE,
 'Compare to instructed_agent_aba for on-us RTP'),

('tchrtp_gateway','RTP','rtp.messages','instructed_agent_aba','CHAR(9)','Receiving FI routing',
 'lake','unified_transactions','beneficiary_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD','BENEFICIARY_ROUTING',2,TRUE,
 'Compare to instructing_agent_aba for on-us RTP'),

('fednow_gateway','FEDNOW','fn.messages','fn_txn_id','VARCHAR','FedNow transaction ID',
 'lake','unified_transactions','source_transaction_id','TEXT',
 'DIRECT_MAP',NULL,'STANDARD',NULL,NULL,FALSE,NULL),

('fednow_gateway','FEDNOW','fn.messages','instructing_agent_routing','CHAR(9)','Sending FI routing',
 'lake','unified_transactions','originator_routing_number','TEXT',
 'DIRECT_MAP',NULL,'STANDARD','ORIGINATOR_ROUTING',2,TRUE,
 'Compare to instructed_agent_routing for on-us FedNow');

-- =============================================================================
-- INDEX ON MAPPING TABLE
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_stm_source_payment
  ON metadata.source_to_target (source_system, payment_type);

CREATE INDEX IF NOT EXISTS idx_stm_ir_role
  ON metadata.source_to_target (ir_role, ir_priority)
  WHERE ir_role IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_stm_on_us
  ON metadata.source_to_target (payment_type, is_on_us_indicator)
  WHERE is_on_us_indicator = TRUE;

COMMENT ON TABLE metadata.source_to_target IS
  'Authoritative source-to-target field mapping for all payment rails. '
  'Includes PCI/PII handling, identity resolution role, and on-us detection logic.';

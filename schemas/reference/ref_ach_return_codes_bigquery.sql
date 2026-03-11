-- =============================================================================
-- JHBI Unified Payments Platform
-- Reference Layer: ref.ach_return_codes  (BigQuery)
-- Version: v2.0.0  |  Date: 2026-03-10
-- =============================================================================
-- NACHA ACH return reason codes (R01–R85).
-- Replace `your_project` with actual project ID.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `your_project.ref.ach_return_codes`
(
  return_code         STRING    NOT NULL  OPTIONS(description = "NACHA return code (R01–R85) — PK"),
  return_description  STRING    NOT NULL  OPTIONS(description = "Official NACHA description"),
  category            STRING    NOT NULL  OPTIONS(description = "ADMINISTRATIVE | UNAUTHORIZED | RETURN | NOC | INTL | DISHONORED"),
  is_active           BOOL      NOT NULL  OPTIONS(description = "Soft-delete flag"),
  created_at          TIMESTAMP NOT NULL
)
OPTIONS(description = "NACHA ACH return reason codes (R01–R85) with categories.");

-- ── SEED DATA (most common codes) ────────────────────────────────────────────
INSERT INTO `your_project.ref.ach_return_codes`
  (return_code, return_description, category, is_active, created_at)
VALUES
  ('R01', 'Insufficient Funds',                            'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R02', 'Account Closed',                                'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R03', 'No Account/Unable to Locate Account',           'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R04', 'Invalid Account Number',                        'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R05', 'Unauthorized Debit to Consumer Account',        'UNAUTHORIZED',   TRUE, CURRENT_TIMESTAMP()),
  ('R06', 'Returned per ODFI Request',                     'ADMINISTRATIVE', TRUE, CURRENT_TIMESTAMP()),
  ('R07', 'Authorization Revoked by Customer',             'UNAUTHORIZED',   TRUE, CURRENT_TIMESTAMP()),
  ('R08', 'Payment Stopped',                               'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R09', 'Uncollected Funds',                             'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R10', 'Customer Advises Originator is Not Known',      'UNAUTHORIZED',   TRUE, CURRENT_TIMESTAMP()),
  ('R11', 'Check Truncation Entry Return',                 'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R12', 'Branch Sold to Another DFI',                    'ADMINISTRATIVE', TRUE, CURRENT_TIMESTAMP()),
  ('R13', 'RDFI Not Qualified to Participate',             'ADMINISTRATIVE', TRUE, CURRENT_TIMESTAMP()),
  ('R14', 'Representative Payee Deceased',                 'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R15', 'Beneficiary or Account Holder Deceased',        'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R16', 'Account Frozen',                                'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R17', 'File Record Edit Criteria',                     'ADMINISTRATIVE', TRUE, CURRENT_TIMESTAMP()),
  ('R20', 'Non-Transaction Account',                       'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R21', 'Invalid Company Identification',                'ADMINISTRATIVE', TRUE, CURRENT_TIMESTAMP()),
  ('R22', 'Invalid Individual ID Number',                  'ADMINISTRATIVE', TRUE, CURRENT_TIMESTAMP()),
  ('R23', 'Credit Entry Refused by Receiver',              'UNAUTHORIZED',   TRUE, CURRENT_TIMESTAMP()),
  ('R24', 'Duplicate Entry',                               'ADMINISTRATIVE', TRUE, CURRENT_TIMESTAMP()),
  ('R29', 'Corporate Customer Advises Not Authorized',     'UNAUTHORIZED',   TRUE, CURRENT_TIMESTAMP()),
  ('R31', 'Permissible Return Entry (CCD/CTX)',            'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R51', 'Item Related to RCK Entry is Ineligible',       'RETURN',         TRUE, CURRENT_TIMESTAMP()),
  ('R61', 'Misrouted Return',                              'DISHONORED',     TRUE, CURRENT_TIMESTAMP()),
  ('R67', 'Duplicate Return',                              'DISHONORED',     TRUE, CURRENT_TIMESTAMP()),
  ('R68', 'Untimely Return',                               'DISHONORED',     TRUE, CURRENT_TIMESTAMP()),
  ('R69', 'Field Error(s)',                                'DISHONORED',     TRUE, CURRENT_TIMESTAMP()),
  ('R70', 'Permissible Return Entry Not Accepted',         'DISHONORED',     TRUE, CURRENT_TIMESTAMP());

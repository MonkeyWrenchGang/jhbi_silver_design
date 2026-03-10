-- =============================================================================
-- JHBI Unified Payments Platform
-- Party Identity Schema (PostgreSQL 14+)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS identity;

-- ---------------------------------------------------------------------------
-- 1. PARTY  — root canonical entity
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party (
  party_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  party_type            TEXT NOT NULL,
  -- INDIVIDUAL | BUSINESS | BILLER | GOVERNMENT | FINANCIAL_INSTITUTION
  party_subtype         TEXT,
  -- LLC | SOLE_PROPRIETOR | NONPROFIT | CREDIT_UNION | CORRESPONDENT_BANK | etc.

  name_token            TEXT,                  -- Vault token → legal name (PII)
  display_name          TEXT,                  -- Non-sensitive short label
  tax_id_token          TEXT,                  -- Vault token → SSN / EIN / ITIN (PII)

  country_code          CHAR(2)  NOT NULL DEFAULT 'US',
  state_province        TEXT,

  resolution_status     TEXT NOT NULL DEFAULT 'UNRESOLVED',
  -- UNRESOLVED | CANDIDATE | CONFIRMED | MERGED | SUPERSEDED
  resolution_confidence NUMERIC(5,4),          -- 0.0000–1.0000; set by IR service
  merged_into_party_id  UUID,                  -- Surviving party_id when MERGED

  tenant_id             TEXT NOT NULL,

  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by            TEXT NOT NULL DEFAULT 'system',
  schema_version        TEXT NOT NULL DEFAULT '1.0',

  CONSTRAINT chk_party_type
    CHECK (party_type IN ('INDIVIDUAL','BUSINESS','BILLER','GOVERNMENT','FINANCIAL_INSTITUTION')),
  CONSTRAINT chk_resolution_status
    CHECK (resolution_status IN ('UNRESOLVED','CANDIDATE','CONFIRMED','MERGED','SUPERSEDED')),
  CONSTRAINT chk_confidence_range
    CHECK (resolution_confidence IS NULL OR (resolution_confidence BETWEEN 0 AND 1))
);

-- ---------------------------------------------------------------------------
-- 2. PARTY ACCOUNT  — payment instrument attached to a party
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_account (
  account_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  party_id                UUID NOT NULL REFERENCES identity.party(party_id),

  account_type            TEXT NOT NULL,
  -- CHECKING | SAVINGS | MONEY_MARKET | LOAN | CARD | BILLER | PREPAID | WALLET | UNKNOWN
  account_subtype         TEXT,

  -- -----------------------------------------------------------------------
  -- ON-US / OFF-US
  -- -----------------------------------------------------------------------
  is_on_us                BOOLEAN NOT NULL DEFAULT FALSE,

  -- Holding FI — domestic
  institution_routing_number  TEXT,            -- ABA routing number
  institution_name            TEXT,            -- Human-readable FI name
  institution_country_code    CHAR(2) DEFAULT 'US',

  -- Holding FI — international
  institution_swift_bic   TEXT,                -- SWIFT BIC (e.g. CHASUS33)
  institution_iban_token  TEXT,                -- Vault token → IBAN of receiving account
  --   Stored as token because IBANs can contain account number info (PCI/PII)
  institution_iban_country_code  CHAR(2),      -- Non-sensitive 2-char IBAN country prefix

  -- Account identifier
  account_number_token    TEXT NOT NULL,       -- Vault token → account / DDA number (PCI)
  account_token_type      TEXT NOT NULL DEFAULT 'INTERNAL',
  -- INTERNAL | NETWORK | ALIAS | CARD_PAN | BILLER_REF | IBAN

  -- Card-specific
  card_brand              TEXT,
  card_last_four          TEXT,
  card_expiry_token       TEXT,

  -- Proxy / alias
  proxy_type              TEXT,                -- EMAIL | PHONE | ZELLE_TOKEN | ALIAS
  proxy_value_token       TEXT,                -- Vault token → alias value (PII)

  account_status          TEXT NOT NULL DEFAULT 'ACTIVE',
  -- ACTIVE | CLOSED | SUSPENDED | BLOCKED | UNKNOWN

  tenant_id               TEXT NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by              TEXT NOT NULL DEFAULT 'system',
  schema_version          TEXT NOT NULL DEFAULT '1.0',

  CONSTRAINT chk_account_type
    CHECK (account_type IN ('CHECKING','SAVINGS','MONEY_MARKET','LOAN','CARD',
                            'BILLER','PREPAID','WALLET','UNKNOWN')),
  CONSTRAINT chk_account_status
    CHECK (account_status IN ('ACTIVE','CLOSED','SUSPENDED','BLOCKED','UNKNOWN')),
  CONSTRAINT chk_token_type
    CHECK (account_token_type IN ('INTERNAL','NETWORK','ALIAS','CARD_PAN','BILLER_REF','IBAN'))
);

-- ---------------------------------------------------------------------------
-- 3. PARTY ACCOUNT RAIL REFERENCE  — per-rail identifiers 
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_account_rail_ref (
  rail_ref_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id              UUID NOT NULL REFERENCES identity.party_account(account_id),

  rail_type               TEXT NOT NULL,
  -- ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK | RDC | BILLPAY

  rail_identifier_type    TEXT NOT NULL,
  -- ROUTING_ACCOUNT | SWIFT_BIC | IBAN | CARD_TOKEN | ZELLE_ALIAS
  -- | RTP_PARTICIPANT_ID | FEDNOW_PARTICIPANT_ID | BILLER_ID | CHECK_MICR

  rail_identifier_token   TEXT,                -- Vault-tokenized (account numbers, card PANs)
  rail_identifier_plain   TEXT,                -- Non-sensitive (routing #, participant ID, BIC)

  is_receiving_participant   BOOLEAN DEFAULT FALSE,
  is_originating_participant BOOLEAN DEFAULT FALSE,
  participant_status         TEXT DEFAULT 'ACTIVE',

  tenant_id               TEXT NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  schema_version          TEXT NOT NULL DEFAULT '1.0',

  CONSTRAINT chk_rail_type
    CHECK (rail_type IN ('ACH','WIRE','CARD','ZELLE','RTP','FEDNOW','CHECK','RDC','BILLPAY')),
  CONSTRAINT uq_account_rail
    UNIQUE (account_id, rail_type, rail_identifier_type)
);

-- ---------------------------------------------------------------------------
-- 4. PARTY ADDRESS 
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_address (
  address_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  party_id                UUID NOT NULL REFERENCES identity.party(party_id),

  address_type            TEXT NOT NULL DEFAULT 'MAILING',
  -- MAILING | LEGAL | REGISTERED | BILLING | PHYSICAL | CORRESPONDENT

  -- Non-sensitive geographic context
  city                    TEXT,
  state_province          TEXT,
  postal_code             TEXT,
  country_code            CHAR(2) NOT NULL DEFAULT 'US',

  -- Sensitive domestic address lines — vault tokens
  address_line1_token     TEXT,
  address_line2_token     TEXT,

  -- International / wire address
  -- For international wires (SWIFT/IBAN), additional structured fields are needed
  -- per SWIFT MT103 / ISO 20022 pacs.008 addressing requirements
  swift_bic               TEXT,                -- Receiving bank BIC (non-sensitive; 8 or 11 chars)
  correspondent_bank_bic  TEXT,                -- Correspondent / intermediary bank BIC
  correspondent_bank_name TEXT,                -- Human-readable correspondent bank name
  iban_token              TEXT,                -- Vault token → IBAN (contains account number → PCI)
  iban_display_last_four  TEXT,                -- Non-sensitive last 4 of IBAN for display
  iban_country_code       CHAR(2),             -- Non-sensitive 2-char IBAN country code
  bank_name               TEXT,                -- Foreign bank name (non-sensitive)
  bank_address_token      TEXT,                -- Vault token → full bank address if needed

  is_primary              BOOLEAN NOT NULL DEFAULT TRUE,

  tenant_id               TEXT NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  schema_version          TEXT NOT NULL DEFAULT '1.0',

  CONSTRAINT chk_address_type
    CHECK (address_type IN ('MAILING','LEGAL','REGISTERED','BILLING','PHYSICAL','CORRESPONDENT'))
);

-- ---------------------------------------------------------------------------
-- 5. PARTY RELATIONSHIP
--    Links two party records with a typed relationship.
--    Use cases:
--      - JOINT_ACCOUNT: two individuals share an account
--      - AUTHORIZED_SIGNER: individual can act on behalf of a business
--      - PARENT_SUBSIDIARY: corporate hierarchy
--      - BENEFICIAL_OWNER: UBO / KYB requirement
--      - TRUST_BENEFICIARY: trust-to-individual link
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_relationship (
  relationship_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- The two parties in the relationship (A and B roles are directional for some types)
  party_id_a              UUID NOT NULL REFERENCES identity.party(party_id),
  party_id_b              UUID NOT NULL REFERENCES identity.party(party_id),

  relationship_type       TEXT NOT NULL,
  -- JOINT_ACCOUNT | AUTHORIZED_SIGNER | PARENT_SUBSIDIARY | BENEFICIAL_OWNER
  -- | TRUST_BENEFICIARY | GUARANTOR | POWER_OF_ATTORNEY | CORRESPONDENT_BANK

  -- Directional roles (who is A and who is B in the relationship)
  role_a                  TEXT,
  -- e.g., OWNER | PARENT | TRUSTEE | GRANTOR | GUARANTOR
  role_b                  TEXT,
  -- e.g., JOINT_HOLDER | SUBSIDIARY | BENEFICIARY | PRINCIPAL | GUARANTEED_PARTY

  -- Ownership / control percentage (for BENEFICIAL_OWNER, PARENT_SUBSIDIARY)
  ownership_percentage    NUMERIC(5,2),        -- e.g. 51.00 for 51% ownership

  -- Temporal scope
  effective_date          DATE NOT NULL DEFAULT CURRENT_DATE,
  expiry_date             DATE,                -- NULL = no end date

  -- Source and verification
  relationship_source     TEXT,
  -- CIF | KYB | MANUAL | OFAC_SCREENING | ADMIN_OVERRIDE
  verified                BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at             TIMESTAMPTZ,
  verified_by             TEXT,

  is_active               BOOLEAN NOT NULL DEFAULT TRUE,

  tenant_id               TEXT NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by              TEXT NOT NULL DEFAULT 'system',
  schema_version          TEXT NOT NULL DEFAULT '1.0',

  CONSTRAINT chk_relationship_type
    CHECK (relationship_type IN (
      'JOINT_ACCOUNT','AUTHORIZED_SIGNER','PARENT_SUBSIDIARY',
      'BENEFICIAL_OWNER','TRUST_BENEFICIARY','GUARANTOR',
      'POWER_OF_ATTORNEY','CORRESPONDENT_BANK'
    )),
  CONSTRAINT chk_no_self_relationship
    CHECK (party_id_a <> party_id_b),
  CONSTRAINT chk_ownership_pct
    CHECK (ownership_percentage IS NULL OR (ownership_percentage >= 0 AND ownership_percentage <= 100))
);

-- ---------------------------------------------------------------------------
-- 6. BILLER REGISTRY
--    Links a BillPay biller to its canonical identity.party record.
--    Enables cross-FI biller analytics and standardized biller identification.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.biller_registry (
  biller_registry_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Link to the canonical party for this biller
  party_id                UUID NOT NULL REFERENCES identity.party(party_id),

  -- Standardized biller identifiers
  biller_id               TEXT NOT NULL,
  -- Primary external biller ID (e.g. iPay biller_id, Payrailz biller_code)

  standard_biller_id      TEXT,
  -- Industry-standard ID (e.g. NACHA BillerXchange ID, Fiserv eBill ID)

  -- Biller classification
  biller_category         TEXT NOT NULL,
  -- UTILITIES | TELECOM | INSURANCE | MORTGAGE | AUTO_LOAN | CREDIT_CARD
  -- | GOVERNMENT | HEALTHCARE | SUBSCRIPTION | OTHER

  biller_category_code    TEXT,
  -- SIC or NAICS code for the biller industry

  -- Source / aggregator context
  aggregator_name         TEXT NOT NULL,
  -- IPAY | PAYRAILZ | BPS | CHECKFREE | OTHER

  aggregator_biller_code  TEXT,
  -- Aggregator-specific internal code

  -- Supported payment methods
  payment_methods         TEXT[] NOT NULL DEFAULT '{"CHECK","ACH"}',
  -- CHECK | ACH | RTP | CARD | FEDNOW

  -- Delivery details
  payable_to_name         TEXT,                -- Printed on paper checks ("AT&T Mobility")
  remittance_format       TEXT,                -- How to format the memo / remittance info
  account_number_format   TEXT,                -- Regex or mask for subscriber account numbers

  -- Biller's receiving FI (for electronic delivery)
  biller_fi_routing       TEXT,                -- ABA routing of biller's receiving bank
  biller_fi_name          TEXT,
  biller_fi_account_token TEXT,                -- Vault token → biller's receiving account (PCI)

  is_active               BOOLEAN NOT NULL DEFAULT TRUE,
  effective_date          DATE NOT NULL DEFAULT CURRENT_DATE,
  expiry_date             DATE,

  tenant_id               TEXT NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by              TEXT NOT NULL DEFAULT 'system',
  schema_version          TEXT NOT NULL DEFAULT '1.0',

  CONSTRAINT chk_biller_category
    CHECK (biller_category IN (
      'UTILITIES','TELECOM','INSURANCE','MORTGAGE','AUTO_LOAN','CREDIT_CARD',
      'GOVERNMENT','HEALTHCARE','SUBSCRIPTION','OTHER'
    )),
  CONSTRAINT uq_biller_aggregator
    UNIQUE (aggregator_name, biller_id, tenant_id)
);

-- ---------------------------------------------------------------------------
-- 7. PARTY RESOLUTION EVENT 
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_resolution_event (
  resolution_event_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_party_id         UUID NOT NULL REFERENCES identity.party(party_id),
  target_party_id         UUID REFERENCES identity.party(party_id),

  event_type              TEXT NOT NULL,
  -- MATCH_CANDIDATE | MATCH_CONFIRMED | MERGE | SPLIT | ALIAS_CREATED | SUPERSEDED | NEW_PARTY

  -- -----------------------------------------------------------------------
  -- BLOCK-AND-KEY RESOLUTION
  --
  -- Block key:  a fast-lookup field used to narrow the candidate set
  --             (e.g. routing_number, account_token_prefix, proxy_hash)
  -- Match rule: the deterministic rule applied within the block to confirm
  --             identity (e.g. EXACT_TOKEN | ROUTING_LAST4 | PROXY_EXACT)
  -- -----------------------------------------------------------------------
  resolution_method       TEXT NOT NULL,
  -- EXACT_TOKEN         — vault token matched exactly               (conf = 1.00)
  -- ROUTING_ACCOUNT     — routing + account composite match         (conf ≥ 0.95)
  -- PROXY_EXACT         — email/phone alias exact match             (conf ≥ 0.90)
  -- NAME_ROUTING        — name + routing number composite           (conf ≥ 0.80)
  -- MANUAL              — human-reviewed and confirmed
  -- ADMIN_OVERRIDE      — explicitly set by admin user
  -- NEW_PARTY           — no match found; new party record created

  block_key               TEXT,
  -- The blocking key that was used to narrow candidate set
  -- e.g. 'routing:021000021', 'proxy:hash:abc123', 'account_prefix:tok_4444'

  match_rule              TEXT,
  -- The specific rule that fired within the block
  -- e.g. 'EXACT_TOKEN:originator_account_token'
  --      'ROUTING_LAST4:odfi_routing+recv_acct_last4'
  --      'PROXY_EXACT:email'

  confidence_score        NUMERIC(5,4),        -- 0.0000–1.0000
  match_attributes        JSONB,
  -- Snapshot of the fields compared, their values, and match result
  -- e.g. {"routing": {"expected": "021000021", "actual": "021000021", "match": true},
  --        "last4":   {"expected": "4567", "actual": "4567", "match": true}}

  resolved_by             TEXT NOT NULL DEFAULT 'system',
  resolved_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes                   TEXT,

  CONSTRAINT chk_resolution_event_type
    CHECK (event_type IN ('MATCH_CANDIDATE','MATCH_CONFIRMED','MERGE','SPLIT',
                          'ALIAS_CREATED','SUPERSEDED','NEW_PARTY')),
  CONSTRAINT chk_resolution_method
    CHECK (resolution_method IN (
      'EXACT_TOKEN','ROUTING_ACCOUNT','PROXY_EXACT','NAME_ROUTING',
      'MANUAL','ADMIN_OVERRIDE','NEW_PARTY'
    ))
);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- party
CREATE INDEX IF NOT EXISTS idx_party_tenant_type
  ON identity.party (tenant_id, party_type);

CREATE INDEX IF NOT EXISTS idx_party_resolution
  ON identity.party (resolution_status, tenant_id);

-- party_account
CREATE INDEX IF NOT EXISTS idx_party_acct_party_id
  ON identity.party_account (party_id);

CREATE INDEX IF NOT EXISTS idx_party_acct_on_us
  ON identity.party_account (tenant_id, is_on_us);

CREATE INDEX IF NOT EXISTS idx_party_acct_routing
  ON identity.party_account (institution_routing_number)
  WHERE institution_routing_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_party_acct_swift_bic
  ON identity.party_account (institution_swift_bic)
  WHERE institution_swift_bic IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_party_acct_iban_country
  ON identity.party_account (institution_iban_country_code)
  WHERE institution_iban_country_code IS NOT NULL;

-- party_account_rail_ref
CREATE INDEX IF NOT EXISTS idx_rail_ref_account_rail
  ON identity.party_account_rail_ref (account_id, rail_type);

CREATE INDEX IF NOT EXISTS idx_rail_ref_plain_id
  ON identity.party_account_rail_ref (rail_identifier_plain)
  WHERE rail_identifier_plain IS NOT NULL;

-- party_address
CREATE INDEX IF NOT EXISTS idx_party_addr_party
  ON identity.party_address (party_id);

CREATE INDEX IF NOT EXISTS idx_party_addr_swift_bic
  ON identity.party_address (swift_bic)
  WHERE swift_bic IS NOT NULL;

-- party_relationship
CREATE INDEX IF NOT EXISTS idx_party_rel_a
  ON identity.party_relationship (party_id_a, relationship_type);

CREATE INDEX IF NOT EXISTS idx_party_rel_b
  ON identity.party_relationship (party_id_b, relationship_type);

CREATE INDEX IF NOT EXISTS idx_party_rel_active
  ON identity.party_relationship (tenant_id, relationship_type, is_active)
  WHERE is_active = TRUE;

-- biller_registry
CREATE INDEX IF NOT EXISTS idx_biller_party
  ON identity.biller_registry (party_id);

CREATE INDEX IF NOT EXISTS idx_biller_category
  ON identity.biller_registry (tenant_id, biller_category)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_biller_standard_id
  ON identity.biller_registry (standard_biller_id)
  WHERE standard_biller_id IS NOT NULL;

-- party_resolution_event — block-and-key lookup
CREATE INDEX IF NOT EXISTS idx_resolution_event_source
  ON identity.party_resolution_event (source_party_id, resolved_at DESC);

CREATE INDEX IF NOT EXISTS idx_resolution_block_key
  ON identity.party_resolution_event (block_key)
  WHERE block_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_resolution_match_rule
  ON identity.party_resolution_event (match_rule, confidence_score)
  WHERE match_rule IS NOT NULL;

-- =============================================================================
-- ROW-LEVEL SECURITY (template — enable per deployment)
-- =============================================================================
-- ALTER TABLE identity.party                  ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE identity.party_account          ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE identity.party_account_rail_ref ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE identity.party_address          ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE identity.party_relationship     ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE identity.biller_registry        ENABLE ROW LEVEL SECURITY;
--
-- CREATE POLICY tenant_isolation ON identity.party
--   USING (tenant_id = current_setting('app.tenant_id', true));
-- (repeat for each table above)

-- =============================================================================
-- COMMENTS
-- =============================================================================
COMMENT ON TABLE identity.party IS
  'Canonical party entity. Root resolution record for any person or legal '
  'entity that originates or receives payments. PII stored as vault tokens.';

COMMENT ON TABLE identity.party_account IS
  'Payment instrument for a party. is_on_us=TRUE = account at this FI tenant. '
  'institution_iban_token and institution_swift_bic for international '
  'wire accounts.';

COMMENT ON TABLE identity.party_address IS
  'Structured address. IBAN/BIC fields (swift_bic, correspondent_bank_bic, '
  'iban_token, iban_country_code, bank_name) to support SWIFT MT103 / ISO 20022 '
  'pacs.008 international wire address requirements.';

COMMENT ON TABLE identity.party_relationship IS
  'Typed relationship between two party records. Supports joint accounts, '
  'authorized signers, corporate hierarchies, beneficial ownership, and trust '
  'structures. Direction is A→B where role_a and role_b describe each side.';

COMMENT ON TABLE identity.biller_registry IS
  'Links BillPay biller IDs to canonical identity.party records. '
  'Enables cross-FI biller analytics and standardized biller identification '
  'across iPay, Payrailz, and BPS aggregators.';

COMMENT ON TABLE identity.party_resolution_event IS
  'Audit log of all identity resolution decisions. Replaces ML ensemble '
  'scoring with deterministic block-and-key resolution. New columns: block_key '
  '(narrowing key), match_rule (rule that fired within block), match_attributes '
  '(JSONB snapshot of compared fields).';

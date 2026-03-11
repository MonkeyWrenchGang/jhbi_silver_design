-- =============================================================================
-- JHBI Unified Payments Platform
-- Party Identity Schema  (PostgreSQL 14+)
-- Version: v2.0.0  |  2026-03-10
-- =============================================================================
-- Design goals:
--   1. Canonical identity for any originator or destination across all rails
--   2. On-us vs off-us classification with FI routing context
--   3. Cross-rail resolution: one party_id ties appearances on ACH, Wire, Zelle, etc.
--   4. PCI/PII fields are NEVER stored here — only token references
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS identity;

-- ---------------------------------------------------------------------------
-- 1. PARTY IDENTITY
--    The canonical "who" — a person or legal entity that can send or receive
--    payments on any rail. This is the root resolution entity.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party (
  -- Primary key
  party_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Party classification
  party_type            TEXT NOT NULL,         -- INDIVIDUAL | BUSINESS | BILLER | GOVERNMENT | FINANCIAL_INSTITUTION
  party_subtype         TEXT,                  -- e.g. SOLE_PROPRIETOR, LLC, NONPROFIT, CREDIT_UNION

  -- Display / resolved name (PII — stored as token reference, never raw)
  name_token            TEXT,                  -- Token resolving to legal name in vault
  display_name          TEXT,                  -- Non-sensitive short label (e.g. "Acme Corp")

  -- Tax / EIN / SSN — always tokenized, never raw
  tax_id_token          TEXT,                  -- Token for SSN / EIN / ITIN

  -- Geographic context (non-sensitive)
  country_code          CHAR(2) NOT NULL DEFAULT 'US',
  state_province        TEXT,

  -- Resolution confidence
  resolution_status     TEXT NOT NULL DEFAULT 'UNRESOLVED',
  -- UNRESOLVED | CANDIDATE | CONFIRMED | MERGED | SUPERSEDED
  resolution_confidence NUMERIC(5,4),          -- 0.0000–1.0000; set by identity-resolution service
  merged_into_party_id  UUID,                  -- If MERGED or SUPERSEDED, points to surviving party_id

  -- Tenancy (which FI "owns" this party record)
  tenant_id             TEXT NOT NULL,

  -- Audit
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by            TEXT NOT NULL DEFAULT 'system',
  schema_version        TEXT NOT NULL DEFAULT 'v2',

  CONSTRAINT chk_party_type
    CHECK (party_type IN ('INDIVIDUAL', 'BUSINESS', 'BILLER', 'GOVERNMENT', 'FINANCIAL_INSTITUTION')),
  CONSTRAINT chk_resolution_status
    CHECK (resolution_status IN ('UNRESOLVED', 'CANDIDATE', 'CONFIRMED', 'MERGED', 'SUPERSEDED')),
  CONSTRAINT chk_confidence_range
    CHECK (resolution_confidence IS NULL OR (resolution_confidence >= 0 AND resolution_confidence <= 1))
);

-- ---------------------------------------------------------------------------
-- 2. PARTY ACCOUNT
--    A specific payment instrument (account) associated with a party.
--    A party may have many accounts; an account may appear on many rails.
--    On-us vs off-us is determined here.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_account (
  -- Primary key
  account_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Link to canonical party
  party_id                UUID NOT NULL REFERENCES identity.party(party_id),

  -- Account classification
  account_type            TEXT NOT NULL,
  -- CHECKING | SAVINGS | MONEY_MARKET | LOAN | CARD | BILLER | PREPAID | WALLET | UNKNOWN

  account_subtype         TEXT,
  -- DDA | MMA | LOC | HELOC | CREDIT | DEBIT | PREPAID | etc.

  -- -----------------------------------------------------------------------
  -- ON-US vs OFF-US DETERMINATION
  -- is_on_us = TRUE  → this account is held at the FI identified by tenant_id
  -- is_on_us = FALSE → this account is held at an external institution
  -- -----------------------------------------------------------------------
  is_on_us                BOOLEAN NOT NULL DEFAULT FALSE,

  -- The holding financial institution (applies to both on-us and off-us)
  institution_routing_number  TEXT,            -- ABA routing number of account-holding FI
  institution_name            TEXT,            -- Human-readable name of FI
  institution_swift_bic       TEXT,            -- For international / wire (SWIFT BIC code)
  institution_country_code    CHAR(2) DEFAULT 'US',

  -- Account identifier — ALWAYS tokenized, never raw
  account_number_token    TEXT NOT NULL,       -- Token for DDA/account number in vault
  account_token_type      TEXT NOT NULL DEFAULT 'INTERNAL',
  -- INTERNAL | NETWORK | ALIAS | CARD_PAN | BILLER_REF

  -- Card-specific (if account_type = CARD)
  card_brand              TEXT,                -- VISA | MASTERCARD | AMEX | DISCOVER | OTHER
  card_last_four          TEXT,                -- Non-sensitive last 4 digits (display only)
  card_expiry_token       TEXT,                -- Token for expiry date in vault

  -- Wallet / alias identity (for Zelle, P2P)
  proxy_type              TEXT,                -- EMAIL | PHONE | ZELLE_TOKEN | ALIAS
  proxy_value_token       TEXT,                -- Token for the alias/proxy value in vault

  -- Account status
  account_status          TEXT NOT NULL DEFAULT 'ACTIVE',
  -- ACTIVE | CLOSED | SUSPENDED | BLOCKED | UNKNOWN

  -- Tenancy
  tenant_id               TEXT NOT NULL,

  -- Audit
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by              TEXT NOT NULL DEFAULT 'system',
  schema_version          TEXT NOT NULL DEFAULT 'v2',

  CONSTRAINT chk_account_type
    CHECK (account_type IN ('CHECKING','SAVINGS','MONEY_MARKET','LOAN','CARD','BILLER','PREPAID','WALLET','UNKNOWN')),
  CONSTRAINT chk_account_status
    CHECK (account_status IN ('ACTIVE','CLOSED','SUSPENDED','BLOCKED','UNKNOWN')),
  CONSTRAINT chk_token_type
    CHECK (account_token_type IN ('INTERNAL','NETWORK','ALIAS','CARD_PAN','BILLER_REF'))
);

-- ---------------------------------------------------------------------------
-- 3. PARTY ACCOUNT RAIL REFERENCE
--    How a given account is identified on each specific payment rail.
--    A single party_account may have different identifiers per rail
--    (e.g., an ABA routing + DDA on ACH, a card token on Visa rails, a
--    Zelle alias, a SWIFT BIC on Wire, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_account_rail_ref (
  rail_ref_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Link to account
  account_id              UUID NOT NULL REFERENCES identity.party_account(account_id),

  -- Which rail this reference applies to
  rail_type               TEXT NOT NULL,
  -- ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK | RDC | BILLPAY

  -- Rail-specific identifier (always tokenized for sensitive values)
  rail_identifier_type    TEXT NOT NULL,
  -- TRACE_NUMBER | ROUTING_ACCOUNT | SWIFT_BIC | IBAN | CARD_TOKEN |
  -- ZELLE_ALIAS | RTP_PARTICIPANT_ID | FEDNOW_PARTICIPANT_ID | BILLER_ID | CHECK_MICR

  rail_identifier_token   TEXT,                -- Tokenized value (for account numbers, card PANs)
  rail_identifier_plain   TEXT,                -- Non-sensitive value (e.g., routing number, participant ID)

  -- Rail participation context
  is_receiving_participant   BOOLEAN DEFAULT FALSE,  -- Can receive on this rail
  is_originating_participant BOOLEAN DEFAULT FALSE,  -- Can originate on this rail
  participant_status         TEXT DEFAULT 'ACTIVE',  -- ACTIVE | INACTIVE | SUSPENDED

  -- Tenancy
  tenant_id               TEXT NOT NULL,

  -- Audit
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  schema_version          TEXT NOT NULL DEFAULT 'v2',

  CONSTRAINT chk_rail_type
    CHECK (rail_type IN ('ACH','WIRE','CARD','ZELLE','RTP','FEDNOW','CHECK','RDC','BILLPAY')),
  CONSTRAINT uq_account_rail
    UNIQUE (account_id, rail_type, rail_identifier_type)
);

-- ---------------------------------------------------------------------------
-- 4. PARTY ADDRESS
--    Structured address for a party (PII — non-sensitive fields only stored
--    here; full address in vault if required).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_address (
  address_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  party_id                UUID NOT NULL REFERENCES identity.party(party_id),

  address_type            TEXT NOT NULL DEFAULT 'MAILING',
  -- MAILING | LEGAL | REGISTERED | BILLING | PHYSICAL

  -- Non-sensitive geographic context
  city                    TEXT,
  state_province          TEXT,
  postal_code             TEXT,
  country_code            CHAR(2) NOT NULL DEFAULT 'US',

  -- Sensitive lines stored as tokens
  address_line1_token     TEXT,               -- Token for street address line 1
  address_line2_token     TEXT,               -- Token for suite / apt

  is_primary              BOOLEAN NOT NULL DEFAULT TRUE,

  -- Tenancy & audit
  tenant_id               TEXT NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  schema_version          TEXT NOT NULL DEFAULT 'v2',

  CONSTRAINT chk_address_type
    CHECK (address_type IN ('MAILING','LEGAL','REGISTERED','BILLING','PHYSICAL'))
);

-- ---------------------------------------------------------------------------
-- 5. PARTY RESOLUTION LINK
--    Audit log of identity-resolution decisions (merge, split, alias).
--    Supports re-adjudication and explainability.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.party_resolution_event (
  resolution_event_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_party_id         UUID NOT NULL REFERENCES identity.party(party_id),
  target_party_id         UUID REFERENCES identity.party(party_id),

  event_type              TEXT NOT NULL,
  -- MATCH_CANDIDATE | MATCH_CONFIRMED | MERGE | SPLIT | ALIAS_CREATED | SUPERSEDED

  resolution_method       TEXT,
  -- EXACT_ACCOUNT | FUZZY_NAME | TOKEN_MATCH | MANUAL | ML_MODEL | ADMIN_OVERRIDE

  confidence_score        NUMERIC(5,4),
  match_attributes        JSONB,              -- Which fields drove the match decision

  resolved_by             TEXT NOT NULL DEFAULT 'system',
  resolved_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes                   TEXT,

  CONSTRAINT chk_resolution_event_type
    CHECK (event_type IN ('MATCH_CANDIDATE','MATCH_CONFIRMED','MERGE','SPLIT','ALIAS_CREATED','SUPERSEDED'))
);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- party lookups
CREATE INDEX IF NOT EXISTS idx_party_tenant_type
  ON identity.party (tenant_id, party_type);

CREATE INDEX IF NOT EXISTS idx_party_resolution
  ON identity.party (resolution_status, tenant_id);

-- party_account lookups
CREATE INDEX IF NOT EXISTS idx_party_acct_party_id
  ON identity.party_account (party_id);

CREATE INDEX IF NOT EXISTS idx_party_acct_on_us
  ON identity.party_account (tenant_id, is_on_us);

CREATE INDEX IF NOT EXISTS idx_party_acct_routing
  ON identity.party_account (institution_routing_number)
  WHERE institution_routing_number IS NOT NULL;

-- rail reference lookups
CREATE INDEX IF NOT EXISTS idx_rail_ref_account_rail
  ON identity.party_account_rail_ref (account_id, rail_type);

CREATE INDEX IF NOT EXISTS idx_rail_ref_plain_id
  ON identity.party_account_rail_ref (rail_identifier_plain)
  WHERE rail_identifier_plain IS NOT NULL;

-- address lookups
CREATE INDEX IF NOT EXISTS idx_party_addr_party
  ON identity.party_address (party_id);

-- resolution events
CREATE INDEX IF NOT EXISTS idx_resolution_event_source
  ON identity.party_resolution_event (source_party_id, resolved_at DESC);

-- =============================================================================
-- ROW-LEVEL SECURITY (template — enable per deployment)
-- =============================================================================
-- ALTER TABLE identity.party ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY tenant_isolation ON identity.party
--   USING (tenant_id = current_setting('app.tenant_id', true));
--
-- Repeat for party_account, party_account_rail_ref, party_address

-- =============================================================================
-- COMMENTS
-- =============================================================================
COMMENT ON TABLE identity.party IS
  'Canonical party entity. Represents any person or legal entity that '
  'originates or receives payments. PII stored as vault tokens only.';

COMMENT ON TABLE identity.party_account IS
  'Payment instrument associated with a party. is_on_us=TRUE means the '
  'account is held at the FI (tenant). institution_routing_number identifies '
  'the holding FI for on-us and off-us accounts.';

COMMENT ON TABLE identity.party_account_rail_ref IS
  'Per-rail identifier records for a party account. A single DDA account '
  'might appear as an ACH routing+account pair, a Zelle alias, and an RTP '
  'participant reference.';

COMMENT ON TABLE identity.party_address IS
  'Structured geographic address for a party. Sensitive street lines '
  'stored as vault tokens; city/state/postal stored in plain text.';

COMMENT ON TABLE identity.party_resolution_event IS
  'Audit log of all identity resolution decisions, supporting '
  'explainability, re-adjudication, and compliance review.';

-- =============================================================================
-- JHBI Unified Payments Platform
-- Party Identity Schema  v3.1.0  (BigQuery)
-- Date: 2026-03-10
-- =============================================================================
-- Synced with party_identity_v3.sql (PostgreSQL) + fixes:
--   + party: added is_active BOOL for soft-delete filtering
--   + party_account: added account_subtype, institution_country_code,
--     card_brand, card_last_four, card_expiry_token (were in PG, missing in BQ)
--   + party_account_rail_ref: replaced is_primary with is_receiving_participant /
--     is_originating_participant (directional flags from PG v3)
--   + party_relationship: renamed source → relationship_source (PG parity)
--   + biller_registry: added biller_category_code, aggregator_biller_code,
--     payable_to_name, biller_fi_name, effective_date, expiry_date (PG parity)
--   + party_resolution_event: fixed event_type enum to match PG v3, added notes
-- =============================================================================
-- Replace `your_project` with actual project ID.
-- BigQuery datasets created separately: CREATE SCHEMA `your_project.identity`.
-- All constraints NOT ENFORCED (BigQuery metadata only).
-- PCI/PII fields store vault tokens only — never raw values.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. PARTY  — root canonical entity
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party`
(
  party_id                STRING    NOT NULL  OPTIONS(description = "Canonical party identifier (UUID string)"),
  party_type              STRING    NOT NULL  OPTIONS(description = "INDIVIDUAL | BUSINESS | BILLER | GOVERNMENT | FINANCIAL_INSTITUTION"),
  party_subtype           STRING              OPTIONS(description = "LLC | SOLE_PROPRIETOR | NONPROFIT | CREDIT_UNION | CORRESPONDENT_BANK | …"),
  name_token              STRING              OPTIONS(description = "Vault token → legal name (PII — never raw)"),
  display_name            STRING              OPTIONS(description = "Non-sensitive short label for UI / reporting"),
  tax_id_token            STRING              OPTIONS(description = "Vault token → SSN / EIN / ITIN (PII — never raw)"),
  country_code            STRING    NOT NULL  OPTIONS(description = "ISO 3166-1 alpha-2. Default: US"),
  state_province          STRING              OPTIONS(description = "State or province code"),
  resolution_status       STRING    NOT NULL  OPTIONS(description = "UNRESOLVED | CANDIDATE | CONFIRMED | MERGED | SUPERSEDED"),
  resolution_confidence   NUMERIC             OPTIONS(description = "0.0000–1.0000; set by IR service"),
  merged_into_party_id    STRING              OPTIONS(description = "Surviving party_id when this record is MERGED"),
  is_active               BOOL      NOT NULL  OPTIONS(description = "FALSE = soft-deleted or superseded; DEFAULT TRUE"),
  tenant_id               STRING    NOT NULL  OPTIONS(description = "FI tenant owning this party record (RLS key)"),
  created_at              TIMESTAMP NOT NULL  OPTIONS(description = "Record creation timestamp"),
  updated_at              TIMESTAMP NOT NULL  OPTIONS(description = "Last update timestamp"),
  created_by              STRING    NOT NULL  OPTIONS(description = "Service or user that created this record"),
  schema_version          STRING    NOT NULL  OPTIONS(description = "Schema contract version (v3)"),

  CONSTRAINT pk_party PRIMARY KEY (party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, resolution_status, party_type
OPTIONS(description = "Root canonical entity for any person or legal entity that sends or receives payments. PII stored as vault tokens.");

-- ---------------------------------------------------------------------------
-- 2. PARTY ACCOUNT  — payment instrument attached to a party
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_account`
(
  account_id                      STRING    NOT NULL  OPTIONS(description = "Unique account identifier (UUID string)"),
  party_id                        STRING    NOT NULL  OPTIONS(description = "FK → identity.party"),
  account_type                    STRING    NOT NULL  OPTIONS(description = "CHECKING | SAVINGS | MONEY_MARKET | LOAN | CARD | BILLER | PREPAID | WALLET | TRUST | UNKNOWN"),
  account_subtype                 STRING              OPTIONS(description = "Free-form sub-classification (e.g. REWARD_VISA, HELOC, HSA)"),
  is_on_us                        BOOL      NOT NULL  OPTIONS(description = "TRUE = account held at this FI tenant"),

  -- Holding FI — domestic
  institution_routing_number      STRING              OPTIONS(description = "ABA 9-digit routing number of the holding FI"),
  institution_name                STRING              OPTIONS(description = "Human-readable FI name"),
  institution_country_code        STRING              OPTIONS(description = "ISO 3166-1 alpha-2 country of holding FI. Default: US"),

  -- Holding FI — international (v3)
  institution_swift_bic           STRING              OPTIONS(description = "SWIFT BIC for international accounts (e.g. CHASUS33)"),
  institution_iban_token          STRING              OPTIONS(description = "Vault token → IBAN (PCI — contains account number)"),
  institution_iban_country_code   STRING              OPTIONS(description = "Non-sensitive 2-char IBAN country prefix (e.g. GB, DE)"),

  -- Account identifier
  account_number_token            STRING    NOT NULL  OPTIONS(description = "Vault token → account / DDA number (PCI — never raw)"),
  account_token_type              STRING    NOT NULL  OPTIONS(description = "INTERNAL | NETWORK | ALIAS | CARD_PAN | BILLER_REF | IBAN"),

  -- Card-specific
  card_brand                      STRING              OPTIONS(description = "VISA | MASTERCARD | AMEX | DISCOVER | UNIONPAY | OTHER"),
  card_last_four                  STRING              OPTIONS(description = "Last 4 digits of PAN — non-sensitive display only"),
  card_expiry_token               STRING              OPTIONS(description = "Vault token → card expiry (PCI)"),

  -- Proxy / alias (Zelle, email, phone)
  proxy_type                      STRING              OPTIONS(description = "EMAIL | PHONE | ZELLE_TOKEN | ALIAS"),
  proxy_value_token               STRING              OPTIONS(description = "Vault token → email/phone alias (PII — never raw)"),

  account_status                  STRING    NOT NULL  OPTIONS(description = "ACTIVE | CLOSED | SUSPENDED | BLOCKED | UNKNOWN"),
  tenant_id                       STRING    NOT NULL  OPTIONS(description = "FI tenant (RLS key)"),
  created_at                      TIMESTAMP NOT NULL,
  updated_at                      TIMESTAMP NOT NULL,
  created_by                      STRING    NOT NULL  OPTIONS(description = "Service or user that created this record"),
  schema_version                  STRING    NOT NULL,

  CONSTRAINT pk_party_account PRIMARY KEY (account_id) NOT ENFORCED,
  CONSTRAINT fk_party_account_party FOREIGN KEY (party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, party_id, institution_routing_number
OPTIONS(description = "Payment instrument (account, card, wallet, proxy) attached to a party. Card fields and international IBAN/BIC added in v3.");

-- ---------------------------------------------------------------------------
-- 3. PARTY ACCOUNT RAIL REFERENCE  — per-rail identifiers for an account
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_account_rail_ref`
(
  rail_ref_id                 STRING    NOT NULL  OPTIONS(description = "Unique rail reference identifier"),
  account_id                  STRING    NOT NULL  OPTIONS(description = "FK → identity.party_account"),
  rail_type                   STRING    NOT NULL  OPTIONS(description = "ACH | WIRE | CARD | ZELLE | RTP | FEDNOW | CHECK | RDC | BILLPAY"),
  rail_identifier_type        STRING    NOT NULL  OPTIONS(description = "ROUTING_ACCOUNT | SWIFT_BIC | IBAN | CARD_TOKEN | ZELLE_ALIAS | RTP_PARTICIPANT_ID | FEDNOW_PARTICIPANT_ID | BILLER_ID | CHECK_MICR"),
  rail_identifier_token       STRING              OPTIONS(description = "Vault token for sensitive rail identifier (account numbers, card PANs, IBANs)"),
  rail_identifier_plain       STRING              OPTIONS(description = "Non-sensitive plain identifier (routing #, BIC, participant ID)"),
  is_receiving_participant    BOOL                OPTIONS(description = "Party can receive on this rail"),
  is_originating_participant  BOOL                OPTIONS(description = "Party can originate on this rail"),
  participant_status          STRING              OPTIONS(description = "ACTIVE | SUSPENDED | CLOSED"),
  tenant_id                   STRING    NOT NULL,
  created_at                  TIMESTAMP NOT NULL,
  updated_at                  TIMESTAMP NOT NULL,
  created_by                  STRING    NOT NULL,
  schema_version              STRING    NOT NULL,

  CONSTRAINT pk_rail_ref PRIMARY KEY (rail_ref_id) NOT ENFORCED,
  CONSTRAINT fk_rail_ref_account FOREIGN KEY (account_id) REFERENCES `your_project.identity.party_account`(account_id) NOT ENFORCED
)
CLUSTER BY tenant_id, account_id, rail_type
OPTIONS(description = "Per-rail identifiers for an account. Directional participant flags indicate origination and receiving capability per rail.");

-- ---------------------------------------------------------------------------
-- 4. PARTY ADDRESS  — physical and correspondent banking addresses
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_address`
(
  address_id              STRING    NOT NULL  OPTIONS(description = "Unique address identifier"),
  party_id                STRING    NOT NULL  OPTIONS(description = "FK → identity.party"),
  address_type            STRING    NOT NULL  OPTIONS(description = "MAILING | LEGAL | REGISTERED | BILLING | PHYSICAL | CORRESPONDENT"),
  city                    STRING              OPTIONS(description = "Non-sensitive"),
  state_province          STRING              OPTIONS(description = "Non-sensitive"),
  postal_code             STRING              OPTIONS(description = "Non-sensitive"),
  country_code            STRING    NOT NULL  OPTIONS(description = "ISO 3166-1 alpha-2"),
  address_line1_token     STRING              OPTIONS(description = "Vault token → street line 1 (PII)"),
  address_line2_token     STRING              OPTIONS(description = "Vault token → street line 2 (PII)"),

  -- International wire / SWIFT fields (v3)
  swift_bic               STRING              OPTIONS(description = "Receiving bank SWIFT BIC (MT103 field 57A)"),
  correspondent_bank_bic  STRING              OPTIONS(description = "Intermediary / correspondent bank BIC (MT103 field 56A)"),
  correspondent_bank_name STRING              OPTIONS(description = "Human-readable correspondent bank name"),
  iban_token              STRING              OPTIONS(description = "Vault token → IBAN (PCI — contains account number)"),
  iban_display_last_four  STRING              OPTIONS(description = "Last 4 chars of IBAN for display (non-sensitive)"),
  iban_country_code       STRING              OPTIONS(description = "Non-sensitive 2-char IBAN country prefix"),
  bank_name               STRING              OPTIONS(description = "Foreign receiving bank name"),
  bank_address_token      STRING              OPTIONS(description = "Vault token → full bank address (PII)"),

  is_primary              BOOL      NOT NULL  OPTIONS(description = "TRUE = primary address for this type"),
  tenant_id               STRING    NOT NULL,
  created_at              TIMESTAMP NOT NULL,
  updated_at              TIMESTAMP NOT NULL,
  created_by              STRING    NOT NULL,
  schema_version          STRING    NOT NULL,

  CONSTRAINT pk_party_address PRIMARY KEY (address_id) NOT ENFORCED,
  CONSTRAINT fk_party_address_party FOREIGN KEY (party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, party_id, address_type
OPTIONS(description = "Physical and correspondent banking addresses. IBAN/BIC fields follow ISO 20022 pacs.008 / SWIFT MT103.");

-- ---------------------------------------------------------------------------
-- 5. PARTY RELATIONSHIP  — typed links between two party records (v3 NEW)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_relationship`
(
  relationship_id         STRING    NOT NULL  OPTIONS(description = "Unique relationship identifier"),
  party_id_a              STRING    NOT NULL  OPTIONS(description = "FK → identity.party (party in role_a)"),
  party_id_b              STRING    NOT NULL  OPTIONS(description = "FK → identity.party (party in role_b)"),
  relationship_type       STRING    NOT NULL  OPTIONS(description = "JOINT_ACCOUNT | AUTHORIZED_SIGNER | PARENT_SUBSIDIARY | BENEFICIAL_OWNER | TRUST_BENEFICIARY | GUARANTOR | POWER_OF_ATTORNEY | CORRESPONDENT_BANK"),
  role_a                  STRING              OPTIONS(description = "Directional role for party_id_a (e.g. OWNER, PARENT, TRUSTEE)"),
  role_b                  STRING              OPTIONS(description = "Directional role for party_id_b (e.g. JOINT_HOLDER, SUBSIDIARY)"),
  ownership_percentage    NUMERIC             OPTIONS(description = "For BENEFICIAL_OWNER / PARENT_SUBSIDIARY (0–100)"),
  effective_date          DATE      NOT NULL  OPTIONS(description = "Date relationship begins"),
  expiry_date             DATE                OPTIONS(description = "Date relationship ends; NULL = ongoing"),
  relationship_source     STRING              OPTIONS(description = "CIF | KYB | MANUAL | OFAC_SCREENING | ADMIN_OVERRIDE"),
  verified                BOOL                OPTIONS(description = "Whether the relationship has been KYC/KYB verified"),
  verified_at             TIMESTAMP           OPTIONS(description = "When verification occurred"),
  verified_by             STRING              OPTIONS(description = "System or user that verified"),
  is_active               BOOL      NOT NULL  OPTIONS(description = "FALSE = soft-deleted"),
  tenant_id               STRING    NOT NULL,
  created_at              TIMESTAMP NOT NULL,
  updated_at              TIMESTAMP NOT NULL,
  created_by              STRING    NOT NULL,
  schema_version          STRING    NOT NULL,

  CONSTRAINT pk_party_relationship PRIMARY KEY (relationship_id) NOT ENFORCED,
  CONSTRAINT fk_rel_party_a FOREIGN KEY (party_id_a) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED,
  CONSTRAINT fk_rel_party_b FOREIGN KEY (party_id_b) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, relationship_type, party_id_a
OPTIONS(description = "Typed links between two party records. Supports joint accounts, authorized signers, corporate hierarchies, beneficial ownership, trusts, and guarantors.");

-- ---------------------------------------------------------------------------
-- 6. BILLER REGISTRY  — BillPay billers as first-class party records (v3 NEW)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.biller_registry`
(
  biller_registry_id      STRING        NOT NULL  OPTIONS(description = "Unique biller registry identifier"),
  party_id                STRING        NOT NULL  OPTIONS(description = "FK → identity.party (party_type = BILLER)"),
  biller_id               STRING        NOT NULL  OPTIONS(description = "Primary external biller ID from aggregator"),
  standard_biller_id      STRING                  OPTIONS(description = "Cross-FI constant: NACHA BillerXchange ID or equivalent"),
  biller_category         STRING        NOT NULL  OPTIONS(description = "UTILITIES | TELECOM | INSURANCE | MORTGAGE | AUTO_LOAN | CREDIT_CARD | GOVERNMENT | HEALTHCARE | SUBSCRIPTION | OTHER"),
  biller_category_code    STRING                  OPTIONS(description = "SIC or NAICS code for the biller industry"),
  aggregator_name         STRING        NOT NULL  OPTIONS(description = "IPAY | PAYRAILZ | BPS | CHECKFREE | OTHER"),
  aggregator_biller_code  STRING                  OPTIONS(description = "Aggregator-specific internal biller code"),
  payment_methods         ARRAY<STRING>           OPTIONS(description = "Accepted methods: CHECK | ACH | RTP | CARD | FEDNOW"),
  payable_to_name         STRING                  OPTIONS(description = "Name printed on paper checks (e.g. AT&T Mobility)"),
  biller_fi_routing       STRING                  OPTIONS(description = "ABA routing of biller's receiving bank"),
  biller_fi_name          STRING                  OPTIONS(description = "Human-readable name of biller's receiving bank"),
  biller_fi_account_token STRING                  OPTIONS(description = "Vault token → biller's receiving account (PCI)"),
  is_active               BOOL          NOT NULL  OPTIONS(description = "FALSE = soft-deleted"),
  effective_date          DATE          NOT NULL  OPTIONS(description = "Date biller record becomes effective"),
  expiry_date             DATE                    OPTIONS(description = "Date biller record expires; NULL = ongoing"),
  tenant_id               STRING        NOT NULL,
  created_at              TIMESTAMP     NOT NULL,
  updated_at              TIMESTAMP     NOT NULL,
  created_by              STRING        NOT NULL,
  schema_version          STRING        NOT NULL,

  CONSTRAINT pk_biller_registry PRIMARY KEY (biller_registry_id) NOT ENFORCED,
  CONSTRAINT fk_biller_party FOREIGN KEY (party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, biller_category, aggregator_name
OPTIONS(description = "Links BillPay biller IDs to canonical identity.party records. standard_biller_id is cross-FI constant for cross-tenant analytics.");

-- ---------------------------------------------------------------------------
-- 7. PARTY RESOLUTION EVENT  — audit log of all IR decisions (block-and-key)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_resolution_event`
(
  resolution_event_id     STRING    NOT NULL  OPTIONS(description = "Unique event identifier"),
  source_party_id         STRING    NOT NULL  OPTIONS(description = "FK → identity.party (source / candidate party)"),
  target_party_id         STRING              OPTIONS(description = "FK → identity.party (confirmed canonical party; NULL if NEW_PARTY)"),
  event_type              STRING    NOT NULL  OPTIONS(description = "MATCH_CANDIDATE | MATCH_CONFIRMED | MERGE | SPLIT | ALIAS_CREATED | SUPERSEDED | NEW_PARTY"),
  resolution_method       STRING    NOT NULL  OPTIONS(description = "EXACT_TOKEN | ROUTING_ACCOUNT | PROXY_EXACT | NAME_ROUTING | MANUAL | ADMIN_OVERRIDE | NEW_PARTY"),
  block_key               STRING              OPTIONS(description = "Blocking key used to narrow candidate set (e.g. routing:021000021, proxy:hash:abc123)"),
  match_rule              STRING              OPTIONS(description = "Specific rule that fired within the block (e.g. EXACT_TOKEN:originator_account_token)"),
  confidence_score        NUMERIC             OPTIONS(description = "0.0000–1.0000; 1.0 = exact, 0.0 = new party, NULL for admin override"),
  match_attributes        JSON                OPTIONS(description = "Snapshot of fields compared and match result per field"),
  resolved_by             STRING    NOT NULL  OPTIONS(description = "IR service name or user ID"),
  resolved_at             TIMESTAMP NOT NULL  OPTIONS(description = "When resolution occurred"),
  notes                   STRING              OPTIONS(description = "Free-text notes for MANUAL / ADMIN_OVERRIDE events"),
  tenant_id               STRING    NOT NULL,
  schema_version          STRING    NOT NULL,

  CONSTRAINT pk_resolution_event PRIMARY KEY (resolution_event_id) NOT ENFORCED,
  CONSTRAINT fk_res_source FOREIGN KEY (source_party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED,
  CONSTRAINT fk_res_target FOREIGN KEY (target_party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
PARTITION BY DATE(resolved_at)
CLUSTER BY tenant_id, resolution_method, event_type
OPTIONS(description = "Audit log of every identity resolution decision. block_key and match_rule live HERE — not on the fact table.");

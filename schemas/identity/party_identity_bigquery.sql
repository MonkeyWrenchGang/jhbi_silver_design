-- =============================================================================
-- JHBI Unified Payments Platform
-- Party Identity Schema  (BigQuery)
-- =============================================================================
-- Replace `your_project` and dataset names with actual deployment values.
-- BigQuery datasets are created separately (e.g., CREATE SCHEMA `your_project.identity`).
-- All constraints declared NOT ENFORCED (BigQuery does not enforce FK/PK/UNIQUE).
-- PCI and PII fields store vault tokens only — never raw values.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. PARTY  — root canonical entity
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party`
(
  party_id                STRING  NOT NULL OPTIONS(description = "Canonical party identifier (UUID string)"),
  party_type              STRING  NOT NULL OPTIONS(description = "INDIVIDUAL | BUSINESS | BILLER | GOVERNMENT | FINANCIAL_INSTITUTION"),
  party_subtype           STRING           OPTIONS(description = "LLC | SOLE_PROPRIETOR | NONPROFIT | CREDIT_UNION | CORRESPONDENT_BANK | etc."),
  name_token              STRING           OPTIONS(description = "Vault token → legal name (PII — never raw)"),
  display_name            STRING           OPTIONS(description = "Non-sensitive short label"),
  tax_id_token            STRING           OPTIONS(description = "Vault token → SSN / EIN / ITIN (PII — never raw)"),
  country_code            STRING  NOT NULL OPTIONS(description = "ISO-3166-1 alpha-2. Default: US"),
  state_province          STRING           OPTIONS(description = "State or province code"),
  resolution_status       STRING  NOT NULL OPTIONS(description = "UNRESOLVED | CANDIDATE | CONFIRMED | MERGED | SUPERSEDED"),
  resolution_confidence   NUMERIC          OPTIONS(description = "0.0000–1.0000; set by IR service"),
  merged_into_party_id    STRING           OPTIONS(description = "Surviving party_id when MERGED"),
  tenant_id               STRING  NOT NULL OPTIONS(description = "FI tenant owning this party record"),
  created_at              TIMESTAMP NOT NULL OPTIONS(description = "Record creation timestamp"),
  updated_at              TIMESTAMP NOT NULL OPTIONS(description = "Last update timestamp"),
  created_by              STRING  NOT NULL OPTIONS(description = "Service or user that created this record"),
  schema_version          STRING  NOT NULL OPTIONS(description = "Schema contract version"),

  CONSTRAINT pk_party PRIMARY KEY (party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, resolution_status
OPTIONS(
  description = "Root canonical entity for any person or legal entity that sends or receives payments."
);

-- ---------------------------------------------------------------------------
-- 2. PARTY ACCOUNT  — payment instrument attached to a party
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_account`
(
  account_id                      STRING  NOT NULL OPTIONS(description = "Unique account identifier (UUID string)"),
  party_id                        STRING  NOT NULL OPTIONS(description = "FK → identity.party"),
  account_type                    STRING  NOT NULL OPTIONS(description = "CHECKING | SAVINGS | CARD | BILLER | WALLET | LOAN | TRUST | OTHER"),
  is_on_us                        BOOL    NOT NULL OPTIONS(description = "TRUE = account held at this FI tenant"),
  institution_routing_number      STRING           OPTIONS(description = "ABA routing number of the holding FI"),
  institution_name                STRING           OPTIONS(description = "Human-readable FI name"),
  institution_swift_bic           STRING           OPTIONS(description = "SWIFT BIC for international accounts"),
  institution_iban_token          STRING           OPTIONS(description = "Vault token → IBAN (PCI — contains account number)"),
  institution_iban_country_code   STRING           OPTIONS(description = "Non-sensitive 2-char IBAN country prefix (e.g., GB, DE)"),
  account_number_token            STRING           OPTIONS(description = "Vault token → account number (PCI — never raw)"),
  account_token_type              STRING           OPTIONS(description = "INTERNAL | NETWORK | ALIAS | CARD_PAN | BILLER_REF | IBAN"),
  proxy_type                      STRING           OPTIONS(description = "EMAIL | PHONE | ZELLE_TOKEN (for P2P rails)"),
  proxy_value_token               STRING           OPTIONS(description = "Vault token → email/phone alias (PII)"),
  account_status                  STRING  NOT NULL OPTIONS(description = "ACTIVE | CLOSED | SUSPENDED | BLOCKED"),
  tenant_id                       STRING  NOT NULL OPTIONS(description = "FI tenant"),
  created_at                      TIMESTAMP NOT NULL,
  updated_at                      TIMESTAMP NOT NULL,
  schema_version                  STRING  NOT NULL,

  CONSTRAINT pk_party_account PRIMARY KEY (account_id) NOT ENFORCED,
  CONSTRAINT fk_party_account_party FOREIGN KEY (party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, party_id, institution_routing_number
OPTIONS(
  description = "Payment instrument (account, card, wallet, proxy) attached to a party."
);

-- ---------------------------------------------------------------------------
-- 3. PARTY ACCOUNT RAIL REFERENCE  — per-rail identifiers for an account
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_account_rail_ref`
(
  rail_ref_id             STRING  NOT NULL OPTIONS(description = "Unique rail reference identifier"),
  account_id              STRING  NOT NULL OPTIONS(description = "FK → identity.party_account"),
  rail_type               STRING  NOT NULL OPTIONS(description = "ACH | WIRE | ZELLE | RTP | FEDNOW | CARD | CHECK | BILLPAY"),
  rail_identifier_type    STRING  NOT NULL OPTIONS(description = "COMPANY_ID | RDFI | TOKEN | BIN | BILLER_CODE | etc."),
  rail_identifier_token   STRING           OPTIONS(description = "Vault token for sensitive rail identifier (PCI/PII)"),
  rail_identifier_plain   STRING           OPTIONS(description = "Non-sensitive rail identifier (e.g., ABA routing)"),
  is_primary              BOOL    NOT NULL OPTIONS(description = "TRUE = primary identifier for this rail"),
  tenant_id               STRING  NOT NULL,
  created_at              TIMESTAMP NOT NULL,
  schema_version          STRING  NOT NULL,

  CONSTRAINT pk_rail_ref PRIMARY KEY (rail_ref_id) NOT ENFORCED,
  CONSTRAINT fk_rail_ref_account FOREIGN KEY (account_id) REFERENCES `your_project.identity.party_account`(account_id) NOT ENFORCED
)
CLUSTER BY tenant_id, account_id, rail_type
OPTIONS(
  description = "Per-rail identifiers for an account (ACH company ID, card BIN, Zelle token, etc.)."
);

-- ---------------------------------------------------------------------------
-- 4. PARTY ADDRESS  — physical and correspondent banking addresses
--    IBAN/BIC fields align with SWIFT MT103 / ISO 20022 pacs.008
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_address`
(
  address_id              STRING  NOT NULL OPTIONS(description = "Unique address identifier"),
  party_id                STRING  NOT NULL OPTIONS(description = "FK → identity.party"),
  address_type            STRING  NOT NULL OPTIONS(description = "MAILING | LEGAL | BILLING | PHYSICAL | CORRESPONDENT"),

  -- Standard postal fields
  city                    STRING           OPTIONS(description = "Non-sensitive"),
  state_province          STRING           OPTIONS(description = "Non-sensitive"),
  postal_code             STRING           OPTIONS(description = "Non-sensitive"),
  country_code            STRING           OPTIONS(description = "ISO-3166-1 alpha-2"),
  address_line1_token     STRING           OPTIONS(description = "Vault token → street line 1 (PII)"),
  address_line2_token     STRING           OPTIONS(description = "Vault token → street line 2 (PII)"),

  -- International wire / SWIFT fields
  swift_bic               STRING           OPTIONS(description = "Receiving bank SWIFT BIC (MT103 field 57A)"),
  correspondent_bank_bic  STRING           OPTIONS(description = "Intermediary/correspondent bank BIC (MT103 field 56A)"),
  correspondent_bank_name STRING           OPTIONS(description = "Human-readable correspondent bank name"),
  iban_token              STRING           OPTIONS(description = "Vault token → IBAN (PCI — contains account number)"),
  iban_display_last_four  STRING           OPTIONS(description = "Last 4 chars of IBAN for display (non-sensitive)"),
  iban_country_code       STRING           OPTIONS(description = "Non-sensitive 2-char IBAN country prefix"),
  bank_name               STRING           OPTIONS(description = "Foreign receiving bank name"),
  bank_address_token      STRING           OPTIONS(description = "Vault token → full bank address (PII)"),

  is_primary              BOOL    NOT NULL OPTIONS(description = "TRUE = primary address for this type"),
  tenant_id               STRING  NOT NULL,
  created_at              TIMESTAMP NOT NULL,
  updated_at              TIMESTAMP NOT NULL,
  schema_version          STRING  NOT NULL,

  CONSTRAINT pk_party_address PRIMARY KEY (address_id) NOT ENFORCED,
  CONSTRAINT fk_party_address_party FOREIGN KEY (party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, party_id, address_type
OPTIONS(
  description = "Physical and correspondent banking addresses. IBAN/BIC fields follow ISO 20022 pacs.008 / SWIFT MT103."
);

-- ---------------------------------------------------------------------------
-- 5. PARTY RELATIONSHIP  — typed links between two party records
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_relationship`
(
  relationship_id         STRING  NOT NULL OPTIONS(description = "Unique relationship identifier"),
  party_id_a              STRING  NOT NULL OPTIONS(description = "FK → identity.party (party in role_a)"),
  party_id_b              STRING  NOT NULL OPTIONS(description = "FK → identity.party (party in role_b)"),
  relationship_type       STRING  NOT NULL OPTIONS(description = "JOINT_ACCOUNT | AUTHORIZED_SIGNER | PARENT_SUBSIDIARY | BENEFICIAL_OWNER | TRUST_BENEFICIARY | GUARANTOR | POWER_OF_ATTORNEY | CORRESPONDENT_BANK"),
  role_a                  STRING           OPTIONS(description = "Directional role for party_id_a (e.g., OWNER, PARENT, TRUSTEE)"),
  role_b                  STRING           OPTIONS(description = "Directional role for party_id_b (e.g., JOINT_HOLDER, SUBSIDIARY)"),
  ownership_percentage    NUMERIC          OPTIONS(description = "Applicable for BENEFICIAL_OWNER and PARENT_SUBSIDIARY (0–100)"),
  effective_date          DATE             OPTIONS(description = "Date relationship begins; NULL = from inception"),
  expiry_date             DATE             OPTIONS(description = "Date relationship ends; NULL = ongoing"),
  verified                BOOL             OPTIONS(description = "Whether the relationship has been verified"),
  verified_at             TIMESTAMP        OPTIONS(description = "When verification occurred"),
  verified_by             STRING           OPTIONS(description = "System or user that verified"),
  is_active               BOOL    NOT NULL OPTIONS(description = "FALSE = soft-deleted"),
  source                  STRING           OPTIONS(description = "KYB | MANUAL | ADMIN | SYSTEM | IMPORT"),
  tenant_id               STRING  NOT NULL,
  created_at              TIMESTAMP NOT NULL,
  updated_at              TIMESTAMP NOT NULL,
  schema_version          STRING  NOT NULL,

  CONSTRAINT pk_party_relationship PRIMARY KEY (relationship_id) NOT ENFORCED,
  CONSTRAINT fk_rel_party_a FOREIGN KEY (party_id_a) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED,
  CONSTRAINT fk_rel_party_b FOREIGN KEY (party_id_b) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, relationship_type, party_id_a
OPTIONS(
  description = "Typed links between two party records. Supports joint accounts, authorized signers, corporate hierarchies, beneficial ownership, trusts, and guarantors."
);

-- ---------------------------------------------------------------------------
-- 6. BILLER REGISTRY  — BillPay billers as first-class party records
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.biller_registry`
(
  biller_registry_id      STRING  NOT NULL OPTIONS(description = "Unique biller registry identifier"),
  party_id                STRING  NOT NULL OPTIONS(description = "FK → identity.party (party_type = BILLER)"),
  biller_id               STRING  NOT NULL OPTIONS(description = "Primary external biller ID from aggregator"),
  standard_biller_id      STRING           OPTIONS(description = "Cross-FI constant: NACHA BillerXchange or equivalent"),
  biller_category         STRING           OPTIONS(description = "UTILITIES | TELECOM | INSURANCE | MORTGAGE | AUTO_LOAN | CREDIT_CARD | GOVERNMENT | HEALTHCARE | SUBSCRIPTION | OTHER"),
  aggregator_name         STRING           OPTIONS(description = "IPAY | PAYRAILZ | BPS | CHECKFREE | OTHER"),
  payment_methods         ARRAY<STRING>    OPTIONS(description = "Accepted methods: CHECK | ACH | RTP | CARD | FEDNOW"),
  biller_fi_routing       STRING           OPTIONS(description = "ABA routing of biller's receiving bank"),
  biller_fi_account_token STRING           OPTIONS(description = "Vault token → biller's receiving account (PCI)"),
  is_active               BOOL    NOT NULL OPTIONS(description = "FALSE = soft-deleted"),
  tenant_id               STRING  NOT NULL,
  created_at              TIMESTAMP NOT NULL,
  updated_at              TIMESTAMP NOT NULL,
  schema_version          STRING  NOT NULL,

  CONSTRAINT pk_biller_registry PRIMARY KEY (biller_registry_id) NOT ENFORCED,
  CONSTRAINT fk_biller_party FOREIGN KEY (party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
CLUSTER BY tenant_id, biller_category, aggregator_name
OPTIONS(
  description = "Links BillPay biller IDs to canonical identity.party records. The standard_biller_id is cross-FI constant for cross-tenant analytics."
);

-- ---------------------------------------------------------------------------
-- 7. PARTY RESOLUTION EVENT  — audit log of all IR decisions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `your_project.identity.party_resolution_event`
(
  resolution_event_id     STRING    NOT NULL OPTIONS(description = "Unique event identifier"),
  source_party_id         STRING    NOT NULL OPTIONS(description = "FK → identity.party (source/candidate party)"),
  target_party_id         STRING             OPTIONS(description = "FK → identity.party (confirmed canonical party; NULL if NEW_PARTY)"),
  event_type              STRING    NOT NULL OPTIONS(description = "MATCH | MERGE | SPLIT | MANUAL_REVIEW | ADMIN_OVERRIDE | NEW_PARTY"),
  resolution_method       STRING    NOT NULL OPTIONS(description = "EXACT_TOKEN | ROUTING_ACCOUNT | PROXY_EXACT | NAME_ROUTING | MANUAL | ADMIN_OVERRIDE | NEW_PARTY"),
  block_key               STRING             OPTIONS(description = "Blocking key used to narrow candidate set (e.g., routing:021000021)"),
  match_rule              STRING             OPTIONS(description = "Specific rule that fired within the block"),
  confidence_score        NUMERIC            OPTIONS(description = "0.0000–1.0000; 1.0 = exact, NULL for NEW_PARTY"),
  match_attributes        JSON               OPTIONS(description = "Snapshot of fields compared and match result"),
  resolved_by             STRING    NOT NULL OPTIONS(description = "IR service name or user ID"),
  resolved_at             TIMESTAMP NOT NULL OPTIONS(description = "When resolution occurred"),
  tenant_id               STRING    NOT NULL,
  schema_version          STRING    NOT NULL,

  CONSTRAINT pk_resolution_event PRIMARY KEY (resolution_event_id) NOT ENFORCED,
  CONSTRAINT fk_res_source FOREIGN KEY (source_party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED,
  CONSTRAINT fk_res_target FOREIGN KEY (target_party_id) REFERENCES `your_project.identity.party`(party_id) NOT ENFORCED
)
PARTITION BY DATE(resolved_at)
CLUSTER BY tenant_id, resolution_method, event_type
OPTIONS(
  description = "Audit log of every identity resolution decision. One row per resolution attempt."
);

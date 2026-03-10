# JHBI Unified Payments Platform — Schema Documentation

Last updated: 2026-03-10

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Identity Schema](#identity-schema)
4. [Silver Layer](#silver-layer)
5. [Raw Layer](#raw-layer)
6. [Gold Layer](#gold-layer)
7. [Rail JSON Extensions](#rail-json-extensions)
8. [Source-to-Target Mapping](#source-to-target-mapping)
9. [Reference Tables](#reference-tables)
10. [On-Us / Off-Us Guide](#on-us--off-us-guide)
11. [Identity Resolution — Block and Key](#identity-resolution--block-and-key)
12. [FX / Multi-Currency](#fx--multi-currency)
13. [International Wires / IBAN and BIC](#international-wires--iban-and-bic)
14. [Party Relationships](#party-relationships)
15. [Biller Registry](#biller-registry)
16. [Security and PCI/PII](#security-and-pcipii)
17. [Deployment Guide](#deployment-guide)

---

## Overview

This schema supports the JHBI data-as-a-service platform, which normalizes payment transactions across Jack Henry's suite of payment products — iPay, EPS, Payrailz, and BPS — into a single queryable model.

The core idea is a three-layer medallion architecture. Raw tables capture source-faithful data from each payment rail. The silver layer (`lake.unified_transactions`) normalizes everything into one table with consistent field names, currency handling, and identity references. The gold layer aggregates from silver for reporting. The identity schema resolves parties across all rails and stores their canonical records separately so identity data doesn't get duplicated on every transaction row.

A few things worth knowing about the current design: FX fields (`fx_rate`, `original_currency_code`, `original_amount`, etc.) are first-class columns on `unified_transactions` rather than buried in the rail JSON blob, which makes cross-currency reporting much simpler. International wire addresses carry IBAN tokens and SWIFT BICs directly on `party_address` and `party_account`, following the ISO 20022 pacs.008 field layout. The identity resolution service is deterministic (block-and-key rules) rather than an ML model — this was a deliberate trade-off for auditability and operational simplicity.

Supported rails: ACH, Wire (Fedwire / SWIFT / CHIPS), Card (Debit / Credit), Zelle, RTP (TCH), FedNow, Check / RDC, BillPay.

---

## Architecture

```
Source Systems → Raw Layer → Silver Layer ↔ Identity Schema → Gold Layer
                                  ↕
                           Metadata / Lineage
```

Silver is the single source of truth. Identity enrichment happens asynchronously — transactions land with `originator_party_id = NULL` and the IR service fills that in after the fact. The gold layer aggregates from silver. Metadata tables track field-level lineage from source to target.

---

## Identity Schema

The `identity` schema provides canonical party resolution across all payment rails.

### identity.party

The root entity for any person or legal entity that sends or receives payments.

| Column | Type | Notes |
|---|---|---|
| party_id | UUID PK | Canonical party identifier |
| party_type | TEXT | INDIVIDUAL \| BUSINESS \| BILLER \| GOVERNMENT \| FINANCIAL_INSTITUTION |
| party_subtype | TEXT | LLC, SOLE_PROPRIETOR, NONPROFIT, CORRESPONDENT_BANK, etc. |
| name_token | TEXT | Vault token for legal name — never raw PII |
| display_name | TEXT | Non-sensitive short label |
| tax_id_token | TEXT | Vault token for SSN / EIN / ITIN |
| country_code | CHAR(2) | Default: US |
| resolution_status | TEXT | UNRESOLVED \| CANDIDATE \| CONFIRMED \| MERGED \| SUPERSEDED |
| resolution_confidence | NUMERIC(5,4) | 0.0–1.0; set by IR service |
| merged_into_party_id | UUID | Points to surviving party when MERGED |
| tenant_id | TEXT | FI tenant owning this party record |

### identity.party_account

A payment instrument associated with a party. Includes IBAN/BIC fields for international accounts.

| Column | Type | Notes |
|---|---|---|
| account_id | UUID PK | |
| party_id | UUID FK → party | |
| account_type | TEXT | CHECKING \| SAVINGS \| CARD \| BILLER \| WALLET \| etc. |
| **is_on_us** | **BOOLEAN** | **TRUE = account held at this FI tenant** |
| institution_routing_number | TEXT | ABA routing of the holding FI |
| institution_name | TEXT | Human-readable FI name |
| institution_swift_bic | TEXT | SWIFT BIC for international accounts |
| institution_iban_token | TEXT | Vault token → IBAN (PCI — contains account number) |
| institution_iban_country_code | CHAR(2) | Non-sensitive 2-char IBAN country prefix |
| account_number_token | TEXT | Vault token for account number — never raw PCI |
| account_token_type | TEXT | INTERNAL \| NETWORK \| ALIAS \| CARD_PAN \| BILLER_REF \| IBAN |
| proxy_type | TEXT | EMAIL \| PHONE \| ZELLE_TOKEN (for P2P rails) |
| proxy_value_token | TEXT | Vault token for email/phone alias |
| account_status | TEXT | ACTIVE \| CLOSED \| SUSPENDED \| BLOCKED |

### identity.party_account_rail_ref

Per-rail identifiers for an account (ACH company ID, card BIN, Zelle token, etc.). One row per rail per account.

### identity.party_address

Physical and correspondent banking addresses. The IBAN/BIC fields align with SWIFT MT103 / ISO 20022 pacs.008.

| Column | Type | Notes |
|---|---|---|
| address_id | UUID PK | |
| party_id | UUID FK → party | |
| address_type | TEXT | MAILING \| LEGAL \| BILLING \| PHYSICAL \| CORRESPONDENT |
| city / state_province / postal_code / country_code | TEXT/CHAR | Non-sensitive |
| address_line1_token / address_line2_token | TEXT | Vault tokens for street lines (PII) |
| swift_bic | TEXT | Receiving bank SWIFT BIC |
| correspondent_bank_bic | TEXT | Intermediary/correspondent bank BIC |
| correspondent_bank_name | TEXT | Human-readable correspondent bank name |
| iban_token | TEXT | Vault token → IBAN (PCI — contains account number) |
| iban_display_last_four | TEXT | Last 4 chars of IBAN for display (non-sensitive) |
| iban_country_code | CHAR(2) | Non-sensitive 2-char IBAN country prefix |
| bank_name | TEXT | Foreign receiving bank name |
| bank_address_token | TEXT | Vault token → full bank address |

### identity.party_relationship

Typed link between two party records. Used for joint accounts, beneficial ownership disclosures, corporate hierarchies, authorized signers, trusts, and guarantors.

| Column | Type | Notes |
|---|---|---|
| relationship_id | UUID PK | |
| party_id_a | UUID FK → party | Party in role_a |
| party_id_b | UUID FK → party | Party in role_b |
| relationship_type | TEXT | JOINT_ACCOUNT \| AUTHORIZED_SIGNER \| PARENT_SUBSIDIARY \| BENEFICIAL_OWNER \| TRUST_BENEFICIARY \| GUARANTOR \| POWER_OF_ATTORNEY \| CORRESPONDENT_BANK |
| role_a / role_b | TEXT | Directional role labels (e.g., OWNER / JOINT_HOLDER) |
| ownership_percentage | NUMERIC(5,2) | For BENEFICIAL_OWNER and PARENT_SUBSIDIARY |
| effective_date / expiry_date | DATE | Temporal scope; NULL expiry = ongoing |
| verified / verified_at / verified_by | BOOLEAN / TIMESTAMPTZ / TEXT | Verification state |
| is_active | BOOLEAN | Soft-delete flag |

### identity.biller_registry

Links BillPay biller IDs to canonical `identity.party` records. Each biller (AT&T, Duke Energy, etc.) gets one `party` record; this table extends it with biller-specific routing details.

| Column | Type | Notes |
|---|---|---|
| biller_registry_id | UUID PK | |
| party_id | UUID FK → party | The party record for this biller |
| biller_id | TEXT | Primary external biller ID |
| standard_biller_id | TEXT | Industry standard ID (NACHA BillerXchange, etc.) |
| biller_category | TEXT | UTILITIES \| TELECOM \| INSURANCE \| MORTGAGE \| AUTO_LOAN \| CREDIT_CARD \| GOVERNMENT \| HEALTHCARE \| SUBSCRIPTION \| OTHER |
| aggregator_name | TEXT | IPAY \| PAYRAILZ \| BPS \| CHECKFREE \| OTHER |
| payment_methods | TEXT[] | CHECK \| ACH \| RTP \| CARD \| FEDNOW |
| biller_fi_routing | TEXT | ABA routing of biller's receiving bank |
| biller_fi_account_token | TEXT | Vault token → biller's receiving account (PCI) |

### identity.party_resolution_event

Audit log for every identity match decision. One row per resolution attempt.

| Column | Type | Notes |
|---|---|---|
| resolution_method | TEXT | EXACT_TOKEN \| ROUTING_ACCOUNT \| PROXY_EXACT \| NAME_ROUTING \| MANUAL \| ADMIN_OVERRIDE \| NEW_PARTY |
| block_key | TEXT | Blocking key used to narrow candidate set |
| match_rule | TEXT | Specific rule that fired within the block |
| confidence_score | NUMERIC(5,4) | 0.0–1.0 |
| match_attributes | JSONB | Snapshot of fields compared and match result |

---

## Silver Layer

### lake.unified_transactions

The normalized transaction table. Every payment from every rail lands here after ETL. FX details, international routing, and identity resolution audit fields are all first-class columns — no need to parse the JSON blob for common queries.

**FX / Multi-Currency columns:**

| Column | Notes |
|---|---|
| `settlement_currency_code` | Currency in which settlement occurs at receiving FI |
| `original_currency_code` | Source currency before conversion (e.g., EUR) — NULL if same-currency |
| `original_amount` | Amount in original_currency_code — NULL if no conversion |
| `fx_rate` | Exchange rate: original_amount × fx_rate = amount |
| `fx_rate_source` | FEDWIRE \| SWIFT \| CHIPS \| INTERNAL_TREASURY \| VISA_RATE \| MASTERCARD_RATE \| CORRESPONDENT_BANK \| MANUAL |
| `fx_rate_timestamp` | When the rate was fixed/locked |
| `fx_charges_borne_by` | OUR \| BEN \| SHA (SWIFT charges field) |

**International routing:**

| Column | Notes |
|---|---|
| `originator_swift_bic` | Originator FI SWIFT BIC |
| `beneficiary_swift_bic` | Beneficiary FI SWIFT BIC |
| `originator_iban_country_code` | Non-sensitive IBAN country prefix |
| `beneficiary_iban_country_code` | Non-sensitive IBAN country prefix |

**Identity resolution audit:**

| Column | Notes |
|---|---|
| `originator_block_key` | Blocking key used during IR for originator |
| `beneficiary_block_key` | Blocking key used during IR for beneficiary |
| `originator_match_rule` | Rule that fired (EXACT_TOKEN, ROUTING_LAST4, etc.) |
| `beneficiary_match_rule` | Rule that fired for beneficiary |

**Key functions and views:**

`lake.v_transactions_with_parties` — joins `unified_transactions` to the identity schema; includes FX, SWIFT BIC, and block-and-key audit fields.

`lake.mark_identity_resolved(...)` — called by the IR service to write party IDs, resolution status, block key, and match rule back onto a transaction row.

---

## Raw Layer

Seven source-faithful tables, one per payment type. ETL workers read from these before writing to silver.

- `raw_ach` — ACH entries from iPay/EPS
- `raw_wire` — Wire transfers from EPS
- `raw_card` — Card transactions from Visa DPS / MC Connect
- `raw_zelle` — Zelle P2P from iPay / Payrailz
- `raw_rtp_fednow` — Instant payments from TCH RTP and FedNow gateways
- `raw_check_rdc` — Check and RDC from teller/mobile systems
- `raw_billpay` — Bill payments from iPay / Payrailz / BPS

---

## Gold Layer

### gold_by_payment_type

Pre-aggregated counts and amounts by tenant, payment type, and date. Includes `on_us_count`, `on_us_amount`, `off_us_count`, `off_us_amount`.

Consider adding `cross_currency_count` and `cross_currency_amount` columns here once FX reporting requirements are firmed up.

---

## Rail JSON Extensions

All rail-specific data lives in `unified_transactions.rail_details_json`. Each rail has a corresponding JSON schema in `schemas/rail_json_schemas/`.

**Common fields across all schemas:** `rail_schema_version`, `rail_type`, `is_on_us`, `on_us_settlement_type`, structured `return_details`, and FI routing fields.

**Wire (`wire.schema.json`)** carries `imad`, `omad`, `swift_uetr`, `chips_sequence_number`, a `foreign_exchange` object (the raw FX data, mirrored into the first-class columns on `unified_transactions`), `originator_bic`, `beneficiary_bic`, IBAN tokens, `regulatory_reporting` array, and `charges_borne_by`. See [International Wires / IBAN and BIC](#international-wires--iban-and-bic) for how these fields relate to the first-class columns.

---

## Source-to-Target Mapping

`metadata.source_to_target` is the authoritative lineage table. It records which source system field maps to which target column, the transformation applied, and the sensitivity classification (PCI / PII / non-sensitive).

---

## On-Us / Off-Us Guide

A transaction is on-us when both the originating and destination accounts reside at the same FI tenant. No external network message is needed; the FI settles internally.

### Detection Logic by Rail

```
ACH:     ODFI routing == RDFI routing
Wire:    Originator FI routing == Beneficiary FI routing
Zelle:   Sender FI routing == Receiver FI routing
RTP:     Instructing agent == Instructed agent routing
FedNow:  Instructing agent == Instructed agent routing
Card:    Issuer BIN FI == Acquirer FI (via ref_on_us_institutions)
Check:   Paying bank routing == Depositing bank routing
BillPay: Payer FI == Biller's FI (rare; biller must also be FI customer)
```

`is_on_us` is derived at ETL time by looking up both routing numbers in `ref_on_us_institutions`. The IR service does not touch this field.

---

## Identity Resolution — Block and Key

### How It Works

The IR service resolves parties using deterministic rules rather than an ML model. The approach has two steps: blocking (narrow the candidate set) and matching (apply rules in priority order).

**Step 1 — Block.** Compute a blocking key from the transaction's account token or routing number. This limits the search to a manageable candidate set. The block key is stored on `unified_transactions.originator_block_key` and `party_resolution_event.block_key`.

Example block keys:
- `routing:021000021` — all party accounts with this ABA routing number
- `proxy:hash:sha256(email@example.com)` — all accounts with this proxy hash
- `account_prefix:tok_4444` — accounts whose token starts with this prefix

**Step 2 — Match.** Within the block, apply rules in priority order:

| Priority | Rule | Confidence | Description |
|---|---|---|---|
| 1 | `EXACT_TOKEN` | 1.0000 | Vault token matches exactly |
| 2 | `ROUTING_ACCOUNT` | ≥ 0.9500 | ABA routing + account composite match |
| 3 | `PROXY_EXACT` | ≥ 0.9000 | Email or phone proxy exact match |
| 4 | `NAME_ROUTING` | ≥ 0.8000 | Name + routing number composite |
| — | `NEW_PARTY` | — | No match; create new party record |

**Step 3 — Resolve.** Call `lake.mark_identity_resolved()` with the block_key and match_rule. Every decision is logged to `identity.party_resolution_event`.

### Querying Resolution Quality

```sql
-- Distribution of match rules over the last 7 days
SELECT
  originator_match_rule,
  COUNT(*)                               AS txn_count,
  AVG(originator_resolution_confidence)  AS avg_confidence
FROM lake.unified_transactions
WHERE tenant_id = :tenant_id
  AND originator_match_rule IS NOT NULL
  AND transaction_ts >= now() - interval '7 days'
GROUP BY 1
ORDER BY txn_count DESC;
```

### Resolution Flow

1. Transaction arrives with `originator_account_token` and routing number populated; `originator_party_id` NULL; `originator_resolution_status = 'UNRESOLVED'`.
2. IR service polls via `idx_ut_ir_queue` (partial index on UNRESOLVED rows).
3. IR service computes `block_key`, fetches candidates from `identity.party_account`, applies rules in priority order.
4. IR service calls `lake.mark_identity_resolved()` with block_key and match_rule.
5. Decision is logged to `identity.party_resolution_event`.

---

## FX / Multi-Currency

FX details from international transactions are stored as first-class columns on `unified_transactions` rather than inside the rail JSON blob. This makes cross-currency queries straightforward.

### When FX Columns Are Populated

All four core FX columns (`original_currency_code`, `original_amount`, `fx_rate`, `fx_rate_source`) are populated together or all NULL. They are set when:
- `payment_type = 'WIRE'` and `payment_subtype = 'WIRE_INTERNATIONAL'`
- `payment_type = 'CARD'` with a foreign currency transaction
- Any rail where the originating currency differs from settlement currency

The `chk_fx_consistency` constraint enforces that `fx_rate` can only be set when `original_currency_code` is present and differs from `currency_code`.

### Cross-Currency Reporting Query

```sql
-- FX volume by currency pair and rail, last 30 days
SELECT
  payment_type,
  original_currency_code,
  currency_code           AS settlement_currency,
  COUNT(*)                AS txn_count,
  SUM(original_amount)    AS total_original_amount,
  SUM(amount)             AS total_settlement_amount,
  AVG(fx_rate)            AS avg_fx_rate
FROM lake.unified_transactions
WHERE tenant_id = :tenant_id
  AND original_currency_code IS NOT NULL
  AND transaction_ts >= now() - interval '30 days'
GROUP BY 1, 2, 3
ORDER BY txn_count DESC;
```

---

## International Wires / IBAN and BIC

### Where Fields Live

| Field | Location | Sensitivity |
|---|---|---|
| Originator SWIFT BIC | `unified_transactions.originator_swift_bic` | Non-sensitive |
| Beneficiary SWIFT BIC | `unified_transactions.beneficiary_swift_bic` | Non-sensitive |
| Originator IBAN | `identity.party_account.institution_iban_token` | PCI — tokenized |
| Beneficiary IBAN | `identity.party_address.iban_token` | PCI — tokenized |
| IBAN country code | `identity.party_address.iban_country_code` | Non-sensitive |
| Correspondent bank BIC | `identity.party_address.correspondent_bank_bic` | Non-sensitive |
| FX rate | `unified_transactions.fx_rate` | Non-sensitive |

### ISO 20022 / SWIFT MT103 Alignment

`identity.party_address` with `address_type = 'CORRESPONDENT'` maps to the ISO 20022 `CreditorAgent`/`IntermediaryAgent` structure and the SWIFT MT103 field 57A (Account with Institution).

---

## Party Relationships

### Use Cases

| Relationship Type | party_id_a role | party_id_b role | Use Case |
|---|---|---|---|
| JOINT_ACCOUNT | OWNER | JOINT_HOLDER | Two individuals share a DDA |
| AUTHORIZED_SIGNER | BUSINESS | INDIVIDUAL | Employee can originate on behalf of company |
| PARENT_SUBSIDIARY | PARENT | SUBSIDIARY | Corporate hierarchy; `ownership_percentage` set |
| BENEFICIAL_OWNER | BUSINESS | INDIVIDUAL | KYB/FinCEN UBO disclosure |
| TRUST_BENEFICIARY | TRUSTEE | BENEFICIARY | Trust account relationships |
| GUARANTOR | GUARANTOR | PRINCIPAL | Guarantee chain for loan payments |

### Finding All Authorized Signers for a Business

```sql
SELECT
  b.display_name   AS business_name,
  i.display_name   AS signer_name,
  r.role_b         AS signer_role,
  r.effective_date,
  r.expiry_date
FROM identity.party_relationship r
JOIN identity.party b ON b.party_id = r.party_id_a
JOIN identity.party i ON i.party_id = r.party_id_b
WHERE r.tenant_id          = :tenant_id
  AND r.relationship_type  = 'AUTHORIZED_SIGNER'
  AND r.is_active          = TRUE
  AND r.party_id_a         = :business_party_id;
```

---

## Biller Registry

Every BillPay biller is linked to an `identity.party` record with `party_type = 'BILLER'`. The `identity.biller_registry` table extends that party record with biller-specific payment routing details. The key value here is the `standard_biller_id` — a cross-FI constant that lets you find all transactions for a given biller regardless of which FI originated them.

### Finding All Transactions for a Biller Across All FIs

```sql
SELECT
  ut.tenant_id,
  ut.payment_type,
  ut.amount,
  ut.transaction_ts,
  br.biller_category,
  p.display_name       AS biller_name
FROM lake.unified_transactions ut
JOIN identity.party_account pa ON pa.account_id = ut.beneficiary_account_id
JOIN identity.biller_registry br ON br.party_id = pa.party_id
JOIN identity.party p           ON p.party_id   = pa.party_id
WHERE br.standard_biller_id = :standard_biller_id
  AND ut.transaction_ts >= now() - interval '30 days'
ORDER BY ut.transaction_ts DESC;
```

---

## Security and PCI/PII

**PCI fields (must be tokenized, never stored raw):** Account numbers, card PANs, IBANs, and routing+account combinations. In `unified_transactions`: `originator_account_token`, `beneficiary_account_token`. In identity: `party_account.account_number_token`, `party_account.institution_iban_token`, `party_address.iban_token`, `party_address.bank_address_token`, `biller_registry.biller_fi_account_token`. All `*_token` fields in rail JSON extensions.

**PII fields (tokenized or vault-stored):** Names, email addresses, phone numbers. In identity: `party.name_token`, `party.tax_id_token`, `party_address.address_line1_token`, `party_address.address_line2_token`, `party_account.proxy_value_token`.

**Row-Level Security:** All `lake`, `identity`, and `metadata` tables support tenant isolation via PostgreSQL RLS using `current_setting('app.tenant_id', true)`. Enable per deployment.

---

## Deployment Guide

### Order of Operations

```
1. Identity schema DDL       (schemas/identity/party_identity.sql)
2. Silver layer              (schemas/silver/unified_transactions.sql)
3. Source-to-target mapping  (schemas/metadata/source_to_target.sql)
4. Reference tables          (schemas/reference/*.sql)
5. Gold layer                (schemas/gold/gold_by_payment_type.sql)
6. Raw layer                 (schemas/raw/*.sql)
```

### ETL Workers

ETL workers should populate the FX columns (`original_currency_code`, `original_amount`, `fx_rate`, `fx_rate_source`, `fx_rate_timestamp`, `fx_charges_borne_by`) from wire and card FX source fields. Set `originator_swift_bic` / `beneficiary_swift_bic` for international transactions. Leave `originator_party_id` and `beneficiary_party_id` NULL on insert — the IR service fills those in asynchronously.

### IR Service

The IR service must compute a `block_key` for each unresolved party, fetch candidates from `identity.party_account` using the block key index, apply match rules in priority order, call `lake.mark_identity_resolved()`, and log every decision to `identity.party_resolution_event`.

### Schema Registry

Register all 8 JSON schemas at `https://jhbi/schemas/rail/<rail>.schema.json` before enabling validation in ingestion workers.

---

## References

- [Design Document](UNIFIED_PAYMENT_SCHEMA_DESIGN_DOCUMENT.md)
- [ERD](ERD.md)
- [Rail JSON Schemas](../schemas/rail_json_schemas/)
- [Identity DDL](../schemas/identity/party_identity.sql)
- [Silver Layer DDL](../schemas/silver/unified_transactions.sql)
- [Source-to-Target Mapping](../schemas/metadata/source_to_target.sql)

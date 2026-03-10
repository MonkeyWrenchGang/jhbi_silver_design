# JHBI Unified Payments Platform — Silver Design

Schema design and documentation for the JHBI unified payments data platform.

## Structure

```
schemas/
  identity/          Party identity schema — party, account, address, relationships, biller registry
  silver/            Unified transactions table (lake layer)
  gold/              Aggregated reporting tables
  raw/               Source-faithful staging tables (one per payment rail)
  reference/         Reference / lookup tables
  metadata/          Source-to-target field mapping
  rail_json_schemas/ JSON schemas for rail_details_json extensions (one per rail)

docs/
  SCHEMA_DOCUMENTATION.md   Full schema reference with query examples
  ERD.md                    Entity relationship diagram (Mermaid)

deliverables/
  JHBI_Payments_Schema_Design.pptx       Architecture presentation
  JHBI_Source_Target_Mapping.xlsx        Source-to-target mapping workbook
  JHBI_Unified_Payments_Design_Document.docx  Design document
```

## Target Database

Each schema directory contains both a PostgreSQL DDL file and a BigQuery DDL file (suffix `_bigquery.sql`). Replace `your_project` placeholders in BigQuery files with actual GCP project and dataset names.

## Supported Payment Rails

ACH · Wire (Fedwire / SWIFT / CHIPS) · Card · Zelle · RTP (TCH) · FedNow · Check / RDC · BillPay

## Key Design Points

- **Identity schema** — canonical party resolution across all rails using deterministic block-and-key matching (no ML model)
- **FX / multi-currency** — first-class columns on `unified_transactions` for cross-rail reporting without parsing JSON
- **IBAN / BIC** — international wire address fields on `party_address` and `party_account`, aligned with SWIFT MT103 / ISO 20022 pacs.008
- **Party relationships** — joint accounts, authorized signers, beneficial ownership, corporate hierarchies
- **Biller registry** — links BillPay billers to canonical party records for cross-FI biller analytics
- **PCI / PII** — all sensitive fields are vault tokens; never stored raw

-- Metadata Data Catalog Table Definition
-- Metadata Table

CREATE TABLE metadata_data_catalog (
    catalog_id BIGSERIAL NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    column_name VARCHAR(255) NOT NULL,
    data_type VARCHAR(50),
    nullable BOOLEAN,
    is_primary_key BOOLEAN DEFAULT FALSE,
    is_foreign_key BOOLEAN DEFAULT FALSE,
    is_pci BOOLEAN DEFAULT FALSE,
    is_pii BOOLEAN DEFAULT FALSE,
    description VARCHAR(1000),
    cdc_source_field VARCHAR(255),
    notes VARCHAR(1000),
    created_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP,
    PRIMARY KEY (catalog_id),
    UNIQUE (table_name, column_name)
);

CREATE INDEX idx_data_catalog_table ON metadata_data_catalog(table_name);
CREATE INDEX idx_data_catalog_pci_pii ON metadata_data_catalog(is_pci, is_pii) WHERE is_pci = TRUE OR is_pii = TRUE;

COMMENT ON TABLE metadata_data_catalog IS 'Metadata catalog for all tables and columns in the JHBI data platform';


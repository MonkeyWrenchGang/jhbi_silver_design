-- Metadata Bq Dataset Layout Table Definition
-- Metadata Table

CREATE TABLE metadata_bq_dataset_layout (
    layout_id BIGSERIAL NOT NULL,
    dataset_name VARCHAR(255) NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    layer VARCHAR(50) NOT NULL,
    description VARCHAR(1000),
    created_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (layout_id),
    UNIQUE (dataset_name, table_name)
);

COMMENT ON TABLE metadata_bq_dataset_layout IS 'BigQuery dataset and table layout metadata';


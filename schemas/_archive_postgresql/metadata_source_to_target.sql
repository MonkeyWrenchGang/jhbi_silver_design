-- Metadata Source To Target Table Definition
-- Metadata Table

CREATE TABLE metadata_source_to_target (
    mapping_id BIGSERIAL NOT NULL,
    source_system VARCHAR(100) NOT NULL,
    source_table VARCHAR(255) NOT NULL,
    source_field VARCHAR(255) NOT NULL,
    target_table VARCHAR(255) NOT NULL,
    target_field VARCHAR(255) NOT NULL,
    transformation_rule VARCHAR(500),
    data_type VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP,
    PRIMARY KEY (mapping_id)
);

CREATE INDEX idx_source_target_source ON metadata_source_to_target(source_system, source_table);
CREATE INDEX idx_source_target_target ON metadata_source_to_target(target_table);

COMMENT ON TABLE metadata_source_to_target IS 'Mapping between source systems and target tables/fields';


-- Deploy imgtg:1.000.0 to pg

BEGIN;

-- Create the extension
SELECT util.create_extension('citext');

-- Create the schema
CREATE SCHEMA IF NOT EXISTS imgtg;

-- Create the tables
CREATE TABLE IF NOT EXISTS imgtg.images (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sha256       BYTEA UNIQUE,              -- for dedup
  storage_key  TEXT NOT NULL,             
  mime_type    TEXT NOT NULL,
  width        INT, 
  height       INT,
  duration_ms  INT,                       
  taken_at     TIMESTAMPTZ,               
  uploader_id  UUID,                      
  metadata     JSONB,                    
  source_urls  TEXT[],                      -- array for upsert on sha256 conflict
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at   TIMESTAMPTZ
);

--use if images already have tags from their source
CREATE TABLE IF NOT EXISTS imgtg.image_raw_tags (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_id   UUID NOT NULL REFERENCES imgtg.images(id),
    tag        CITEXT NOT NULL,
    processed  BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT image_raw_tags_image_id_tag_unique UNIQUE (image_id, tag)
);

-- Function to trim whitespace from tag before update
CREATE OR REPLACE FUNCTION imgtg.trim_image_raw_tag()
RETURNS TRIGGER AS $$
BEGIN
    NEW.tag := trim(NEW.tag)
    RETURN NEW
END;
$$ LANGUAGE plpgsql;

-- BEFORE UPDATE trigger to trim tag field
SELECT util.create_trigger(
    'image_raw_tags_trim_tag_before_update', 
    'imgtg.image_raw_tags',
    'imgtg.trim_image_raw_tag',
    'BEFORE',
    'INSERT OR UPDATE'
);

CREATE TABLE IF NOT EXISTS imgtg.tags (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    namespace   TEXT NOT NULL DEFAULT 'base',
    name        CITEXT NOT NULL,
    parent_id   UUID REFERENCES imgtg.tags(id),
    description TEXT,
    CONSTRAINT tags_namespace_name_unique UNIQUE (namespace, name)
);

CREATE TABLE IF NOT EXISTS imgtg.tag_aliases (
    id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag_id    UUID NOT NULL REFERENCES imgtg.tags(id),
    alias     CITEXT NOT NULL,
    CONSTRAINT tag_aliases_alias_tag_id_unique UNIQUE (alias, tag_id)
);

CREATE TABLE IF NOT EXISTS imgtg.concepts (
    id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    concept  CITEXT NOT NULL,
    description TEXT,
    CONSTRAINT concepts_name_unique UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS imgtg.image_tags (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_id   UUID NOT NULL REFERENCES imgtg.images(id),
    tag_id     UUID NOT NULL REFERENCES imgtg.tags(id),
    concept_id UUID REFERENCES imgtg.concepts(id), --optional, for assocating tags like "small red car"
    tag_order  SMALLINT, --optional, for preserving order of tags in concept
    CONSTRAINT image_tags_image_id_tag_id_unique UNIQUE (image_id, tag_id)
);


COMMIT;

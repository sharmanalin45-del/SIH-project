-- Enable PostGIS Spatial Extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enum for Legal Stages under RFCTLARR / NH Act
DO $$ BEGIN
    CREATE TYPE legal_stage AS ENUM (
        'NOTIFICATION_11', 
        'OBJECTION_HEARING', 
        'AWARD_DECLARED', 
        'POSSESSION_TAKEN', 
        'COURT_STAY'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Core Land Parcels Table with ULPIN (Bhu-Aadhaar)
CREATE TABLE IF NOT EXISTS land_parcels (
    id SERIAL PRIMARY KEY,
    ulpin VARCHAR(14) UNIQUE NOT NULL,
    khasra_no VARCHAR(50) NOT NULL,
    owner_name VARCHAR(100) NOT NULL,
    area_sqm NUMERIC(10,2) NOT NULL,
    current_stage legal_stage DEFAULT 'NOTIFICATION_11',
    is_disputed BOOLEAN DEFAULT FALSE,
    boundary GEOMETRY(Polygon, 4326) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Milestone & Audit Trail
CREATE TABLE IF NOT EXISTS statutory_milestones (
    id SERIAL PRIMARY KEY,
    parcel_ulpin VARCHAR(14) REFERENCES land_parcels(ulpin) ON DELETE CASCADE,
    stage legal_stage NOT NULL,
    officer_id VARCHAR(50) NOT NULL,
    esign_hash VARCHAR(256),
    sla_deadline TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '14 days'),
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Spatial and Unique Indexing
CREATE INDEX IF NOT EXISTS idx_parcels_boundary ON land_parcels USING GIST(boundary);
CREATE INDEX IF NOT EXISTS idx_parcels_ulpin ON land_parcels(ulpin);

-- Sample Data Seed
INSERT INTO land_parcels (ulpin, khasra_no, owner_name, area_sqm, current_stage, is_disputed, boundary) VALUES
('12345678901234', '101/A', 'Ramesh Kumar', 450.50, 'NOTIFICATION_11', FALSE, ST_GeomFromText('POLYGON((75.787 26.912, 75.789 26.912, 75.789 26.914, 75.787 26.914, 75.787 26.912))', 4326)),
('12345678901235', '102/B', 'Sita Devi', 620.00, 'OBJECTION_HEARING', FALSE, ST_GeomFromText('POLYGON((75.789 26.912, 75.791 26.912, 75.791 26.914, 75.789 26.914, 75.789 26.912))', 4326)),
('12345678901236', '103/C', 'Vijay Singh', 310.20, 'COURT_STAY', TRUE, ST_GeomFromText('POLYGON((75.791 26.912, 75.793 26.912, 75.793 26.914, 75.791 26.914, 75.791 26.912))', 4326)),
('12345678901237', '104/D', 'Anita Sharma', 890.00, 'POSSESSION_TAKEN', FALSE, ST_GeomFromText('POLYGON((75.793 26.912, 75.795 26.912, 75.795 26.914, 75.793 26.914, 75.793 26.912))', 4326))
ON CONFLICT (ulpin) DO NOTHING;
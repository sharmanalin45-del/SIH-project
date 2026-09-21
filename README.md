# SIH 2026 - Real-Time National Land Acquisition System (SIH26016)

An event-driven WebGIS and workflow platform integrating PostGIS spatial tracking, statutory milestone compliance, and multi-act land acquisition legal management.

## Project Structure
- `/backend`: Python FastAPI application providing GeoJSON vector streaming and milestone APIs.
- `/frontend`: Responsive Leaflet.js dashboard displaying spatial parcels and officer controls.
- `/database`: PostGIS initialization script with ULPIN indexing and trigger structures.

## Quick Start (Local Setup)

### 1. Database Setup
Execute `database/schema.sql` inside your PostgreSQL instance:
```bash
sudo -u postgres psql -d land_acquisition_db -f database/schema.sql
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import asyncpg
import json
import os

app = FastAPI(
    title="SIH26016 National Land Acquisition API",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:SecretPassword123@localhost:5432/land_acquisition_db")

class StageUpdate(BaseModel):
    ulpin: str
    new_stage: str
    officer_id: str
    esign_hash: str

async def get_db_connection():
    try:
        return await asyncpg.connect(DATABASE_URL)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database Connection Failed: {str(e)}")

@app.get("/")
async def root():
    return {"status": "online", "system": "Real-Time National Land Acquisition Platform (SIH26016)"}

@app.get("/api/v1/parcels/geojson")
async def get_parcel_geojson():
    conn = await get_db_connection()
    try:
        query = """
            SELECT jsonb_build_object(
                'type', 'FeatureCollection',
                'features', COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'type', 'Feature',
                        'geometry', ST_AsGeoJSON(boundary)::jsonb,
                        'properties', jsonb_build_object(
                            'ulpin', ulpin,
                            'khasra_no', khasra_no,
                            'owner_name', owner_name,
                            'area_sqm', area_sqm,
                            'current_stage', current_stage,
                            'is_disputed', is_disputed
                        )
                    )
                ), '[]'::jsonb)
            ) FROM land_parcels;
        """
        result = await conn.fetchval(query)
        return json.loads(result)
    finally:
        await conn.close()

@app.post("/api/v1/parcels/update-stage")
async def update_stage(data: StageUpdate):
    conn = await get_db_connection()
    try:
        async with conn.transaction():
            status = await conn.execute(
                "UPDATE land_parcels SET current_stage = $1, updated_at = NOW() WHERE ulpin = $2",
                data.new_stage, data.ulpin
            )
            if status == "UPDATE 0":
                raise HTTPException(status_code=404, detail="ULPIN not found")
            
            await conn.execute(
                """INSERT INTO statutory_milestones (parcel_ulpin, stage, officer_id, esign_hash)
                   VALUES ($1, $2, $3, $4)""",
                data.ulpin, data.new_stage, data.officer_id, data.esign_hash
            )
        return {"status": "success", "ulpin": data.ulpin, "updated_stage": data.new_stage}
    finally:
        await conn.close()

@app.get("/api/v1/analytics/sla-risk")
async def get_sla_risk():
    conn = await get_db_connection()
    try:
        rows = await conn.fetch("""
            SELECT current_stage, COUNT(*) as total,
                   SUM(CASE WHEN is_disputed THEN 1 ELSE 0 END) as disputes
            FROM land_parcels GROUP BY current_stage;
        """)
        return [{"stage": r["current_stage"], "total_parcels": r["total"], "disputed": r["disputes"]} for r in rows]
    finally:
        await conn.close()
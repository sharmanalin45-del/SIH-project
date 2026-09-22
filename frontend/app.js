const API_BASE = "https://national-land-acquisition-system-zbgd.onrender.com";

const map = L.map('map').setView([26.913, 75.790], 15);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap contributors'
}).addTo(map);

let geoJsonLayer = null;

const STAGE_COLORS = {
    'NOTIFICATION_11': '#eab308',
    'OBJECTION_HEARING': '#f97316',
    'AWARD_DECLARED': '#3b82f6',
    'POSSESSION_TAKEN': '#22c55e',
    'COURT_STAY': '#ef4444'
};

async function loadMapData() {
    try {
        const response = await fetch(`${API_BASE}/api/v1/parcels/geojson`);
        if (!response.ok) throw new Error("API Offline");
        
        const data = await response.json();
        document.getElementById('api-status').innerText = "Backend Live (PostGIS Connected)";
        document.getElementById('api-status').style.background = "#16a34a";

        if (geoJsonLayer) map.removeLayer(geoJsonLayer);

        geoJsonLayer = L.geoJSON(data, {
            style: (feature) => ({
                color: feature.properties.is_disputed ? '#ef4444' : (STAGE_COLORS[feature.properties.current_stage] || '#64748b'),
                weight: 2,
                fillOpacity: 0.6
            }),
            onEachFeature: (feature, layer) => {
                const p = feature.properties;
                layer.bindPopup(`
                    <div style="font-size:12px;">
                        <b>ULPIN:</b> ${p.ulpin}<br/>
                        <b>Owner:</b> ${p.owner_name}<br/>
                        <b>Khasra:</b> ${p.khasra_no}<br/>
                        <b>Stage:</b> ${p.current_stage}<br/>
                        ${p.is_disputed ? '<span style="color:red;font-weight:bold;">⚠️ Court Stay</span>' : ''}
                    </div>
                `);
                layer.on('click', () => {
                    document.getElementById('ulpin-input').value = p.ulpin;
                });
            }
        }).addTo(map);
    } catch (err) {
        document.getElementById('api-status').innerText = "Backend Disconnected";
        document.getElementById('api-status').style.background = "#dc2626";
    }
}

document.getElementById('update-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = document.getElementById('submit-btn');
    btn.innerText = "Processing e-Sign...";
    btn.disabled = true;

    const payload = {
        ulpin: document.getElementById('ulpin-input').value,
        new_stage: document.getElementById('stage-input').value,
        officer_id: document.getElementById('officer-input').value,
        esign_hash: "SHA256-" + Math.random().toString(36).substring(2)
    };

    try {
        const res = await fetch(`${API_BASE}/api/v1/parcels/update-stage`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            document.getElementById('form-msg').innerText = "✅ Milestone Updated & Map Recolored!";
            document.getElementById('form-msg').style.color = "green";
            await loadMapData();
        } else {
            const err = await res.json();
            document.getElementById('form-msg').innerText = `❌ Error: ${err.detail}`;
            document.getElementById('form-msg').style.color = "red";
        }
    } catch (err) {
        document.getElementById('form-msg').innerText = "❌ Failed to connect to server.";
    } finally {
        btn.innerText = "e-Sign & Update Milestone";
        btn.disabled = false;
    }
});

loadMapData();
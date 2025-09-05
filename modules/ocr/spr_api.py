from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import uvicorn

app = 
  FastAPI(title="SPR API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    
  allow_credentials=True
)

@app.get("/")
async def root():
    return {"message": "SPR API Ativa", "status": "online"}

@app.get("/api/status")
async
   def status():
    return {
        "spr": "online",
        "whatsapp": "online",
        "api": "online",
        "timestamp": 
  datetime.now().isoformat()
    }

@app.get("/api/spr/status")
async def spr_status():
    return {"status": "online", "message": "SPR Sistema 
  Ativo"}

@app.get("/api/metrics")
async def metrics():
    return {"users": 10, "messages": 100, "active": True}

if __name__ == "__main__":
    
  uvicorn.run(app, host="0.0.0.0", port=3002)

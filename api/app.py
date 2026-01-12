from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/")
def read_root():
    return {
        "status": "OK", 
        "version": os.getenv("GIT_SHA", "dev"),
        "timestamp": os.getenv("BUILD_TIME", "local")
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)

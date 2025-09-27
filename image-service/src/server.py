
from pydantic import BaseModel
import os
from fastapi import FastAPI, HTTPException, Request, Path
from fastapi.responses import FileResponse, Response
from pathlib import Path as P
import mimetypes
import json

app = FastAPI()

SHA_IMAGE_DIR = P(os.environ["SHA_IMAGE_DIR"]).resolve()

if not SHA_IMAGE_DIR:
    raise ValueError("SHA_IMAGE_DIR is not set")

@app.get("/")
def read_root():
    return {"message": "Hello, World!"}

def sha_path(sha: str) -> P:
    # optional fan-out: aa/bb/<sha>
    p = (SHA_IMAGE_DIR / sha).resolve()
    if not str(p).startswith(str(SHA_IMAGE_DIR)):  # traversal guard
        raise HTTPException(403, "forbidden")
    return p

@app.get("/image/{sha}")
async def get_image(
    sha: str = Path(pattern=r"^[a-f0-9]{64}$"),  # 64-char hex
    request: Request = None,
):
    path = sha_path(sha)
    print(f"path: {path}")
    if not path.is_file():
        raise HTTPException(404)

    etag = f'"{sha}"'  # strong ETag using the sha
    if etag in (request.headers.get("if-none-match") or ""):
        return Response(status_code=304, headers={"ETag": etag})

    meta_path = path.with_suffix('.json')
    meta = {}
    if meta_path.is_file():
        try:
            with open(meta_path, "r", encoding="utf-8") as f:
                meta = json.load(f)
        except Exception:
            meta = {}

    media_type = meta.get("mimetype") or "application/octet-stream"
    headers = {
        "ETag": etag,
        "Cache-Control": "public, max-age=31536000, immutable",
    }
    return FileResponse(path, media_type=media_type, headers=headers)


@app.get("/image/{sha}/meta")
async def get_image_meta( sha: str = Path(pattern=r"^[a-f0-9]{64}$") ): 
    path = sha_path(sha)
    meta_path = path.with_suffix('.json')
    if not meta_path.is_file():
        raise HTTPException(404, detail="Meta not found") 
        try: 
            with open(meta_path, "r", encoding="utf-8") as f: meta = json.load(f) 
        except Exception: 
            raise HTTPException(500, detail="Failed to read meta") 
        return meta
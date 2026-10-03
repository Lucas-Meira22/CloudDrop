import logging
import os
import os

from typing import Annotated

import boto3  # type: ignore[reportMissingImports]
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import FastAPI, File, HTTPException, UploadFile
from prometheus_fastapi_instrumentator import Instrumentator

logger = logging.getLogger("uvicorn.error")

BUCKET_NAME = os.getenv("BUCKET_NAME")
REGION = os.getenv("REGION")

# SigV4 so pre-signed URLs work: buckets created after June 2020 reject SigV2 links
s3_client = boto3.client("s3", region_name=REGION, config=Config(signature_version="s3v4"))

app = FastAPI()

# Routes that call S3 are plain `def`, not `async def`: boto3 blocks while it waits
# for AWS, and FastAPI runs `def` routes in a thread pool so one slow S3 call can't
# freeze the event loop (and with it /healthz).


@app.post("/files")
def upload_file(file: Annotated[UploadFile, File()]):
    if not file.filename:
        raise HTTPException(status_code=400, detail="File must have a name")
    try:
        s3_client.upload_fileobj(file.file, BUCKET_NAME, file.filename)
    except ClientError, BotoCoreError:
        logger.exception("Upload of %s failed", file.filename)
        raise HTTPException(status_code=502, detail="Could not store the file") from None
    return {"filename": file.filename}


@app.get("/files")
def list_files():
    try:
        resp = s3_client.list_objects_v2(Bucket=BUCKET_NAME)
    except ClientError, BotoCoreError:
        logger.exception("Listing bucket failed")
        raise HTTPException(status_code=502, detail="Could not list files") from None
    return {"files": [o["Key"] for o in resp.get("Contents", [])]}


@app.get("/files/{name}")
def get_file_link(name: str):
    # generate_presigned_url never talks to S3, so check the object exists first;
    # otherwise we'd hand out a link that only fails when the user clicks it.
    try:
        s3_client.head_object(Bucket=BUCKET_NAME, Key=name)
    except ClientError as exc:
        if exc.response["Error"]["Code"] in ("404", "NoSuchKey"):
            raise HTTPException(status_code=404, detail="File not found") from None
        logger.exception("Looking up %s failed", name)
        raise HTTPException(status_code=502, detail="Could not look up the file") from None
    except BotoCoreError:
        logger.exception("Looking up %s failed", name)
        raise HTTPException(status_code=502, detail="Could not look up the file") from None

    url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET_NAME, "Key": name},
        ExpiresIn=300,  # seconds
    )
    return {"url": url}


@app.get("/healthz")
async def health_check():
    return {"status": "ok"}


# 503 tells Kubernetes to stop routing traffic to this pod until it's ready again.
@app.get("/readyz")
def readiness_check():
    if not BUCKET_NAME:
        raise HTTPException(status_code=503, detail="BUCKET_NAME is not set")
    try:
        s3_client.head_bucket(Bucket=BUCKET_NAME)
    except (ClientError, BotoCoreError) as exc:
        raise HTTPException(status_code=503, detail=f"S3 bucket not reachable: {exc}") from None
    return {"status": "ready"}


Instrumentator().instrument(app).expose(app)  # serves GET /metrics

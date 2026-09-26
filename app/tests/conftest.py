import os

import boto3
import pytest
from fastapi.testclient import TestClient
from moto import mock_aws

BUCKET = "clouddrop-test"
REGION = "us-east-1"

# main.py reads these and creates its S3 client at import time, so they must be
# set before it is imported. Fake credentials make sure a test can never reach
# real AWS (env vars win over ~/.aws / `aws login` in boto3's credential chain).
os.environ.update(
    BUCKET_NAME=BUCKET,
    REGION=REGION,
    AWS_ACCESS_KEY_ID="testing",
    AWS_SECRET_ACCESS_KEY="testing",
    AWS_SESSION_TOKEN="testing",
    AWS_DEFAULT_REGION=REGION,
)


@pytest.fixture(scope="session")
def aws():
    # One moto mock for the whole run: main.py (and its Prometheus metrics)
    # can only be imported once per process.
    with mock_aws():
        yield


@pytest.fixture
def s3(aws):
    """A fresh, empty fake bucket for every test."""
    client = boto3.client("s3", region_name=REGION)
    client.create_bucket(Bucket=BUCKET)
    yield client
    for obj in client.list_objects_v2(Bucket=BUCKET).get("Contents", []):
        client.delete_object(Bucket=BUCKET, Key=obj["Key"])
    client.delete_bucket(Bucket=BUCKET)


@pytest.fixture
def client(s3):
    import main

    return TestClient(main.app)

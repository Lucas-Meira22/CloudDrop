from urllib.parse import urlparse

from conftest import BUCKET


def test_healthz(client):
    resp = client.get("/healthz")

    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_readyz_when_bucket_exists(client):
    resp = client.get("/readyz")

    assert resp.status_code == 200
    assert resp.json() == {"status": "ready"}


def test_readyz_fails_when_bucket_missing(client, s3):
    s3.delete_bucket(Bucket=BUCKET)

    resp = client.get("/readyz")

    assert resp.status_code == 503
    s3.create_bucket(Bucket=BUCKET)  # the fixture's cleanup expects it


def test_readyz_fails_without_bucket_name(client, monkeypatch):
    import main

    monkeypatch.setattr(main, "BUCKET_NAME", None)

    resp = client.get("/readyz")

    assert resp.status_code == 503
    assert resp.json() == {"detail": "BUCKET_NAME is not set"}


def test_upload_stores_file_in_s3(client, s3):
    resp = client.post("/files", files={"file": ("hello.txt", b"hello clouddrop")})

    assert resp.status_code == 200
    assert resp.json() == {"filename": "hello.txt"}
    body = s3.get_object(Bucket=BUCKET, Key="hello.txt")["Body"].read()
    assert body == b"hello clouddrop"


def test_list_files(client, s3):
    assert client.get("/files").json() == {"files": []}

    s3.put_object(Bucket=BUCKET, Key="a.txt", Body=b"a")
    s3.put_object(Bucket=BUCKET, Key="b.txt", Body=b"b")

    resp = client.get("/files")
    assert resp.status_code == 200
    assert sorted(resp.json()["files"]) == ["a.txt", "b.txt"]


def test_get_file_returns_presigned_url(client, s3):
    s3.put_object(Bucket=BUCKET, Key="report.pdf", Body=b"%PDF")

    resp = client.get("/files/report.pdf")

    assert resp.status_code == 200
    url = urlparse(resp.json()["url"])
    assert BUCKET in url.netloc + url.path
    assert url.path.endswith("/report.pdf")
    assert "X-Amz-Signature" in url.query
    assert "X-Amz-Expires=300" in url.query


def test_get_missing_file_returns_404(client):
    resp = client.get("/files/does-not-exist.txt")

    assert resp.status_code == 404
    assert resp.json() == {"detail": "File not found"}


def test_upload_returns_502_when_s3_fails(client, s3):
    s3.delete_bucket(Bucket=BUCKET)  # S3 now answers NoSuchBucket

    resp = client.post("/files", files={"file": ("hello.txt", b"hi")})

    assert resp.status_code == 502
    assert resp.json() == {"detail": "Could not store the file"}
    s3.create_bucket(Bucket=BUCKET)  # the fixture's cleanup expects it


def test_list_returns_502_when_s3_fails(client, s3):
    s3.delete_bucket(Bucket=BUCKET)

    resp = client.get("/files")

    assert resp.status_code == 502
    s3.create_bucket(Bucket=BUCKET)


def test_metrics_exposed(client):
    client.get("/healthz")  # generate at least one request metric

    resp = client.get("/metrics")

    assert resp.status_code == 200
    assert "http_requests_total" in resp.text

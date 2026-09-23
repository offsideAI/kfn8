"""Object storage used by the operator pipeline. Private (sources, review, rejected) and public (published) are
separate buckets; nothing reaches public storage except through `publish`."""
from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol


@dataclass
class ObjectInfo:
    key: str
    size: int
    sha256: str


class Storage(Protocol):
    def put_if_absent(self, key: str, path: Path, sha256: str) -> bool: ...
    def head(self, key: str) -> ObjectInfo | None: ...
    def delete(self, key: str) -> None: ...


class LocalStorage:
    """Filesystem storage for tests and offline operator runs. Not a CDN; a Spaces smoke test is separate."""

    def __init__(self, root: Path):
        self.root = root
        root.mkdir(parents=True, exist_ok=True)
        self.fail_deletes = False

    def _p(self, key: str) -> Path:
        if key.startswith("/") or ".." in key.split("/"):
            raise ValueError(f"invalid key {key}")
        return self.root / key

    def put_if_absent(self, key: str, path: Path, sha256: str) -> bool:
        dest = self._p(key)
        if dest.exists():
            return False
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest.with_suffix(dest.suffix + ".part")
        tmp.write_bytes(path.read_bytes())
        tmp.rename(dest)
        return True

    def head(self, key: str) -> ObjectInfo | None:
        p = self._p(key)
        if not p.exists():
            return None
        return ObjectInfo(key, p.stat().st_size, hashlib.sha256(p.read_bytes()).hexdigest())

    def delete(self, key: str) -> None:
        if self.fail_deletes:
            raise OSError(f"simulated delete failure for {key}")
        self._p(key).unlink(missing_ok=True)


class S3Storage:
    """DigitalOcean Spaces (S3-compatible). Conditional writes via If-None-Match; SHA-256 kept in object metadata."""

    def __init__(self, bucket: str, *, endpoint: str, region: str, key: str, secret: str, public: bool):
        import boto3
        self.bucket, self.public = bucket, public
        self.s3 = boto3.client("s3", endpoint_url=endpoint, region_name=region, aws_access_key_id=key, aws_secret_access_key=secret)

    def put_if_absent(self, key: str, path: Path, sha256: str) -> bool:
        from botocore.exceptions import ClientError
        extra = {"Metadata": {"sha256": sha256}, "CacheControl": "public, max-age=31536000, immutable"}
        if self.public:
            extra["ACL"] = "public-read"
        try:
            with path.open("rb") as f:
                self.s3.put_object(Bucket=self.bucket, Key=key, Body=f, IfNoneMatch="*", **extra)
            return True
        except ClientError as e:
            if e.response.get("Error", {}).get("Code") in ("PreconditionFailed", "412"):
                return False
            raise

    def head(self, key: str) -> ObjectInfo | None:
        from botocore.exceptions import ClientError
        try:
            h = self.s3.head_object(Bucket=self.bucket, Key=key)
        except ClientError as e:
            if e.response.get("Error", {}).get("Code") in ("404", "NoSuchKey", "NotFound"):
                return None
            raise
        return ObjectInfo(key, h["ContentLength"], h.get("Metadata", {}).get("sha256", ""))

    def delete(self, key: str) -> None:
        self.s3.delete_object(Bucket=self.bucket, Key=key)


class CdnPurger(Protocol):
    def purge(self, keys: list[str]) -> None: ...


@dataclass
class RecordingPurger:
    """Test/offline purger: records purge requests. Not evidence that an edge cache was purged."""
    purged: list[str] = field(default_factory=list)
    fail: bool = False

    def purge(self, keys: list[str]) -> None:
        if self.fail:
            raise OSError("simulated CDN purge failure")
        self.purged.extend(keys)


class DigitalOceanPurger:
    def __init__(self, token: str, endpoint_id: str):
        self.token, self.endpoint_id = token, endpoint_id

    def purge(self, keys: list[str]) -> None:
        import json
        import urllib.request
        req = urllib.request.Request(f"https://api.digitalocean.com/v2/cdn/endpoints/{self.endpoint_id}/cache", method="DELETE",
                                     data=json.dumps({"files": keys}).encode(),
                                     headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=30) as r:
            if r.status not in (200, 204):
                raise OSError(f"CDN purge failed with HTTP {r.status}")

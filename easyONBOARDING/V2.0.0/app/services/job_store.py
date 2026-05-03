from __future__ import annotations

from datetime import UTC, datetime
import json
from pathlib import Path
import sqlite3
from typing import Any
from uuid import uuid4


def _utc_now_iso() -> str:
    return datetime.now(UTC).isoformat()


class JobStore:
    def __init__(self, database_path: Path) -> None:
        self.database_path = database_path

    def initialize(self) -> None:
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS jobs (
                    job_id TEXT PRIMARY KEY,
                    module TEXT NOT NULL,
                    action TEXT NOT NULL,
                    status TEXT NOT NULL,
                    detail TEXT NOT NULL,
                    requested_by TEXT NOT NULL,
                    correlation_id TEXT NOT NULL,
                    connector_name TEXT,
                    dry_run INTEGER NOT NULL,
                    success INTEGER,
                    exit_code INTEGER,
                    error_code TEXT,
                    started_at TEXT,
                    finished_at TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    contract_payload TEXT NOT NULL,
                    result_payload TEXT,
                    log_stdout_path TEXT,
                    log_stderr_path TEXT
                );

                CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_jobs_correlation_id ON jobs(correlation_id);
                """
            )

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(str(self.database_path))
        connection.row_factory = sqlite3.Row
        return connection

    def create_job(
        self,
        *,
        module: str,
        action: str,
        status: str,
        detail: str,
        requested_by: str,
        correlation_id: str,
        dry_run: bool,
        contract_payload: dict[str, Any],
        result_payload: dict[str, Any] | None = None,
        connector_name: str | None = None,
        success: bool | None = None,
        exit_code: int | None = None,
        error_code: str | None = None,
        started_at: str | None = None,
        finished_at: str | None = None,
        log_stdout_path: str | None = None,
        log_stderr_path: str | None = None,
    ) -> str:
        now = _utc_now_iso()
        job_id = f"JOB-{datetime.now(UTC):%Y%m%d-%H%M%S}-{uuid4().hex[:6].upper()}"

        with self._connect() as connection:
            connection.execute(
                """
                INSERT INTO jobs (
                    job_id, module, action, status, detail, requested_by, correlation_id,
                    connector_name, dry_run, success, exit_code, error_code,
                    started_at, finished_at, created_at, updated_at,
                    contract_payload, result_payload, log_stdout_path, log_stderr_path
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    job_id,
                    module,
                    action,
                    status,
                    detail,
                    requested_by,
                    correlation_id,
                    connector_name,
                    int(dry_run),
                    None if success is None else int(success),
                    exit_code,
                    error_code,
                    started_at,
                    finished_at,
                    now,
                    now,
                    json.dumps(contract_payload, ensure_ascii=False),
                    None if result_payload is None else json.dumps(result_payload, ensure_ascii=False),
                    log_stdout_path,
                    log_stderr_path,
                ),
            )
            connection.commit()

        return job_id

    def update_job(
        self,
        job_id: str,
        *,
        status: str,
        detail: str,
        success: bool | None = None,
        exit_code: int | None = None,
        result_payload: dict[str, Any] | None = None,
        error_code: str | None = None,
        started_at: str | None = None,
        finished_at: str | None = None,
        log_stdout_path: str | None = None,
        log_stderr_path: str | None = None,
    ) -> None:
        with self._connect() as connection:
            connection.execute(
                """
                UPDATE jobs
                SET status = ?,
                    detail = ?,
                    success = ?,
                    exit_code = ?,
                    error_code = ?,
                    started_at = COALESCE(?, started_at),
                    finished_at = COALESCE(?, finished_at),
                    updated_at = ?,
                    result_payload = ?,
                    log_stdout_path = COALESCE(?, log_stdout_path),
                    log_stderr_path = COALESCE(?, log_stderr_path)
                WHERE job_id = ?
                """,
                (
                    status,
                    detail,
                    None if success is None else int(success),
                    exit_code,
                    error_code,
                    started_at,
                    finished_at,
                    _utc_now_iso(),
                    None if result_payload is None else json.dumps(result_payload, ensure_ascii=False),
                    log_stdout_path,
                    log_stderr_path,
                    job_id,
                ),
            )
            connection.commit()

    def list_jobs(self, *, limit: int = 50) -> list[dict[str, Any]]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT job_id, module, action, status, detail, requested_by, correlation_id,
                       connector_name, dry_run, success, exit_code, error_code,
                       started_at, finished_at, created_at, updated_at
                FROM jobs
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()

        return [self._row_to_dict(row) for row in rows]

    def _row_to_dict(self, row: sqlite3.Row) -> dict[str, Any]:
        status = str(row["status"])
        return {
            "id": row["job_id"],
            "module": row["module"],
            "action": row["action"],
            "status": status,
            "status_tone": self._status_tone(status),
            "detail": row["detail"],
            "owner": row["requested_by"],
            "correlation_id": row["correlation_id"],
            "connector_name": row["connector_name"],
            "dry_run": bool(row["dry_run"]),
            "success": None if row["success"] is None else bool(row["success"]),
            "exit_code": row["exit_code"],
            "error_code": row["error_code"],
            "started_at": row["started_at"],
            "finished_at": row["finished_at"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    def _status_tone(self, status: str) -> str:
        normalized = status.lower()
        if normalized in {"completed", "dryrun"}:
            return "success"
        if normalized in {"running", "queued"}:
            return "warning"
        if normalized in {"timedout", "failed"}:
            return "danger"
        return "dark"
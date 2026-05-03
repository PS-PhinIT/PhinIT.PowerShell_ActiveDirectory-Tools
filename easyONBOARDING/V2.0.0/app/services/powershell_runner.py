from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
import json
from pathlib import Path
import subprocess
import tempfile
import time
from typing import Any


@dataclass(frozen=True)
class PowerShellExecutionResult:
    success: bool
    status: str
    message: str
    connector: str
    correlation_id: str
    exit_code: int | None
    stdout: str
    stderr: str
    warnings: list[str]
    errors: list[str]
    data: dict[str, Any]
    audit_delta: list[Any]
    follow_up_tasks: list[Any]
    duration_ms: int
    started_at: str
    finished_at: str
    log_stdout_path: str | None = None
    log_stderr_path: str | None = None

    @property
    def primary_error(self) -> str | None:
        return self.errors[0] if self.errors else None

    def to_payload(self) -> dict[str, Any]:
        return {
            "success": self.success,
            "status": self.status,
            "message": self.message,
            "connector": self.connector,
            "correlation_id": self.correlation_id,
            "exit_code": self.exit_code,
            "stdout": self.stdout,
            "stderr": self.stderr,
            "warnings": self.warnings,
            "errors": self.errors,
            "data": self.data,
            "audit_delta": self.audit_delta,
            "follow_up_tasks": self.follow_up_tasks,
            "duration_ms": self.duration_ms,
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "log_stdout_path": self.log_stdout_path,
            "log_stderr_path": self.log_stderr_path,
        }


class PowerShellRunner:
    """Vorbereiteter Runner für kontrollierte PowerShell-Connectoren.

    Die produktive Prozessausführung folgt im nächsten Ausbauschritt.
    Aktuell stellt diese Klasse die gemeinsamen Vertragsregeln bereit.
    """

    def __init__(self, executable: str = "powershell.exe") -> None:
        self.executable = executable

    def _default_output(
        self,
        *,
        message: str,
        errors: list[str] | None = None,
        warnings: list[str] | None = None,
        data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        return {
            "success": False,
            "message": message,
            "errors": errors or [],
            "warnings": warnings or [],
            "data": data or {},
            "audit_delta": [],
            "follow_up_tasks": [],
        }

    def build_command(
        self,
        connector_path: Path,
        input_json_path: Path,
        connector_name: str,
    ) -> list[str]:
        return [
            self.executable,
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(connector_path),
            "-InputJsonPath",
            str(input_json_path),
            "-ConnectorName",
            connector_name,
        ]

    def create_contract_payload(
        self,
        module: str,
        action: str,
        requested_by: str,
        payload: dict[str, Any],
        *,
        correlation_id: str,
        dry_run: bool = False,
    ) -> dict[str, Any]:
        return {
            "module": module,
            "action": action,
            "requested_by": requested_by,
            "correlation_id": correlation_id,
            "dry_run": dry_run,
            "payload": payload,
        }

    def normalize_output(self, stdout: str, *, stderr: str = "", exit_code: int | None = None) -> dict[str, Any]:
        if not stdout.strip():
            message = "PowerShell connector returned no output."
            if stderr.strip():
                message = f"{message} STDERR: {stderr.strip()}"
            return self._default_output(message=message, errors=["empty_output"])

        try:
            parsed = json.loads(stdout)
        except json.JSONDecodeError as exc:
            return self._default_output(
                message="PowerShell connector returned invalid JSON output.",
                errors=["invalid_json_output", str(exc)],
                warnings=[stderr.strip()] if stderr.strip() else [],
            )

        if not isinstance(parsed, dict):
            return self._default_output(
                message="PowerShell connector returned an unexpected JSON structure.",
                errors=["unexpected_json_structure"],
            )

        parsed.setdefault("warnings", [])
        parsed.setdefault("errors", [])
        parsed.setdefault("data", {})
        parsed.setdefault("audit_delta", [])
        parsed.setdefault("follow_up_tasks", [])
        parsed.setdefault("success", False)
        parsed.setdefault("message", f"PowerShell connector finished with exit code {exit_code}.")
        return parsed

    def _write_execution_logs(
        self,
        *,
        log_dir: Path | None,
        correlation_id: str,
        connector_name: str,
        stdout: str,
        stderr: str,
    ) -> tuple[str | None, str | None]:
        if log_dir is None:
            return None, None

        log_dir.mkdir(parents=True, exist_ok=True)
        safe_prefix = f"{correlation_id or 'NO-CORR'}_{connector_name.replace('.', '_')}"
        stdout_path = log_dir / f"{safe_prefix}_stdout.log"
        stderr_path = log_dir / f"{safe_prefix}_stderr.log"
        stdout_path.write_text(stdout or "", encoding="utf-8")
        stderr_path.write_text(stderr or "", encoding="utf-8")
        return str(stdout_path), str(stderr_path)

    def run_connector(
        self,
        connector_path: Path,
        contract_payload: dict[str, Any],
        *,
        connector_name: str,
        timeout_seconds: int,
        log_dir: Path | None = None,
    ) -> PowerShellExecutionResult:
        started_at = datetime.now(UTC)
        correlation_id = str(contract_payload.get("correlation_id", ""))
        start_perf = time.perf_counter()

        if not connector_path.is_file():
            finished_at = datetime.now(UTC)
            duration_ms = int((time.perf_counter() - start_perf) * 1000)
            stdout_log, stderr_log = self._write_execution_logs(
                log_dir=log_dir,
                correlation_id=correlation_id,
                connector_name=connector_name,
                stdout="",
                stderr="",
            )
            return PowerShellExecutionResult(
                success=False,
                status="Failed",
                message="PowerShell connector file was not found.",
                connector=connector_name,
                correlation_id=correlation_id,
                exit_code=None,
                stdout="",
                stderr="",
                warnings=[],
                errors=["connector_not_found"],
                data={},
                audit_delta=[],
                follow_up_tasks=[],
                duration_ms=duration_ms,
                started_at=started_at.isoformat(),
                finished_at=finished_at.isoformat(),
                log_stdout_path=stdout_log,
                log_stderr_path=stderr_log,
            )

        with tempfile.TemporaryDirectory(prefix="easyonb-") as temp_dir_name:
            temp_dir = Path(temp_dir_name)
            input_json_path = temp_dir / "input.json"
            input_json_path.write_text(json.dumps(contract_payload, indent=2, ensure_ascii=False), encoding="utf-8")
            command = self.build_command(connector_path, input_json_path, connector_name)

            try:
                completed = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=timeout_seconds,
                    check=False,
                )
                stdout = completed.stdout or ""
                stderr = completed.stderr or ""
                normalized = self.normalize_output(stdout, stderr=stderr, exit_code=completed.returncode)
                success = bool(normalized.get("success", False)) and completed.returncode == 0
                status = "Completed" if success else "Failed"
                message = str(normalized.get("message") or stderr.strip() or "PowerShell connector failed.")
                exit_code = completed.returncode
            except subprocess.TimeoutExpired as exc:
                stdout = exc.stdout or ""
                stderr = exc.stderr or ""
                normalized = self._default_output(
                    message=f"PowerShell connector exceeded timeout of {timeout_seconds} seconds.",
                    errors=["timeout"],
                    warnings=[stderr.strip()] if stderr and stderr.strip() else [],
                )
                success = False
                status = "TimedOut"
                message = normalized["message"]
                exit_code = None

            finished_at = datetime.now(UTC)
            duration_ms = int(normalized.get("duration_ms") or ((time.perf_counter() - start_perf) * 1000))
            stdout_log, stderr_log = self._write_execution_logs(
                log_dir=log_dir,
                correlation_id=correlation_id,
                connector_name=connector_name,
                stdout=stdout,
                stderr=stderr,
            )

        return PowerShellExecutionResult(
            success=success,
            status=status,
            message=message,
            connector=connector_name,
            correlation_id=correlation_id,
            exit_code=exit_code,
            stdout=stdout,
            stderr=stderr,
            warnings=list(normalized.get("warnings", [])),
            errors=list(normalized.get("errors", [])),
            data=dict(normalized.get("data", {})),
            audit_delta=list(normalized.get("audit_delta", [])),
            follow_up_tasks=list(normalized.get("follow_up_tasks", [])),
            duration_ms=duration_ms,
            started_at=started_at.isoformat(),
            finished_at=finished_at.isoformat(),
            log_stdout_path=stdout_log,
            log_stderr_path=stderr_log,
        )

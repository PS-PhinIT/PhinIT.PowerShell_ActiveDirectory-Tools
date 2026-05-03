from __future__ import annotations

from uuid import uuid4

from app.core.settings import Settings
from app.services.job_store import JobStore
from app.services.powershell_runner import PowerShellExecutionResult, PowerShellRunner


class DirectorySearchService:
    def __init__(self, *, settings: Settings, runner: PowerShellRunner, job_store: JobStore) -> None:
        self.settings = settings
        self.runner = runner
        self.job_store = job_store
        self.connector_name = "ad.user.search"

    def search_users(self, search_term: str, *, requested_by: str = "web-ui") -> dict[str, object]:
        normalized_search_term = search_term.strip()
        if len(normalized_search_term) < 2:
            raise ValueError("Bitte mindestens 2 Zeichen für die Benutzersuche eingeben.")

        contract = self.runner.create_contract_payload(
            module="Directory.Users",
            action="search",
            requested_by=requested_by,
            payload={
                "search_term": normalized_search_term,
                "max_results": self.settings.ad_user_search_max_results,
            },
            correlation_id=f"USR-{uuid4().hex[:10].upper()}",
            dry_run=False,
        )

        job_id = self.job_store.create_job(
            module=contract["module"],
            action=contract["action"],
            status="Running",
            detail=f"AD-Benutzersuche für '{normalized_search_term}' gestartet.",
            requested_by=requested_by,
            correlation_id=contract["correlation_id"],
            dry_run=False,
            contract_payload=contract,
            connector_name=self.connector_name,
            started_at=None,
        )

        execution = self.runner.run_connector(
            self.settings.ad_user_search_connector,
            contract,
            connector_name=self.connector_name,
            timeout_seconds=self.settings.powershell_connector_timeout_seconds,
            log_dir=self.settings.runner_logs_dir,
        )

        self.job_store.update_job(
            job_id,
            status=execution.status,
            detail=execution.message,
            success=execution.success,
            exit_code=execution.exit_code,
            result_payload=execution.to_payload(),
            error_code=execution.primary_error,
            started_at=execution.started_at,
            finished_at=execution.finished_at,
            log_stdout_path=execution.log_stdout_path,
            log_stderr_path=execution.log_stderr_path,
        )

        users = execution.data.get("users", []) if isinstance(execution.data, dict) else []
        return self._build_response(job_id=job_id, search_term=normalized_search_term, execution=execution, users=users)

    def _build_response(
        self,
        *,
        job_id: str,
        search_term: str,
        execution: PowerShellExecutionResult,
        users: list[object],
    ) -> dict[str, object]:
        return {
            "job_id": job_id,
            "status": execution.status,
            "success": execution.success,
            "message": execution.message,
            "warnings": execution.warnings,
            "errors": execution.errors,
            "correlation_id": execution.correlation_id,
            "exit_code": execution.exit_code,
            "duration_ms": execution.duration_ms,
            "count": len(users),
            "search_term": search_term,
            "users": users,
        }
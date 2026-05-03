from __future__ import annotations

import re
from collections.abc import Mapping
from datetime import date
from typing import Any

from pydantic import BaseModel, ConfigDict, ValidationError, field_validator, model_validator

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

ONBOARDING_ROLE_PACKAGES: list[dict[str, str]] = [
    {
        "value": "standard-user",
        "label": "Standard User",
        "detail": "AD-Basis, M365-Mailbox, Standardgruppen und Arbeitsplatz.",
    },
    {
        "value": "sales-user",
        "label": "Sales & Customer Care",
        "detail": "CRM, Telefonie, Shared Mailboxes und mobile Kommunikation.",
    },
    {
        "value": "finance-user",
        "label": "Finance & Backoffice",
        "detail": "ERP-nahe Berechtigungen, File Shares und revisionsnahe Abläufe.",
    },
    {
        "value": "it-admin",
        "label": "IT Admin",
        "detail": "Erweiterte Admin-Gruppen mit gesondertem Review im Dry-Run.",
    },
]

OFFBOARDING_EXIT_TYPES: list[dict[str, str]] = [
    {
        "value": "standard",
        "label": "Regulärer Austritt",
        "detail": "Geplante Übergabe mit kontrollierter Abschaltung zum Austrittstermin.",
    },
    {
        "value": "immediate",
        "label": "Sofortiger Austritt",
        "detail": "Zugänge unmittelbar sperren und sensible Objekte priorisieren.",
    },
    {
        "value": "internal-transfer",
        "label": "Interner Wechsel",
        "detail": "Identität bleibt bestehen, Rollen und Zielzustände werden angepasst.",
    },
]


def checkbox_to_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "on", "yes", "ja"}


def onboarding_form_defaults() -> dict[str, Any]:
    return {
        "given_name": "",
        "family_name": "",
        "primary_mail": "",
        "department": "",
        "location": "",
        "start_date": "",
        "manager_display_name": "",
        "role_package": "standard-user",
        "needs_mailbox": True,
        "needs_phone": False,
        "needs_device": True,
        "generate_welcome_letter": True,
    }


def offboarding_form_defaults() -> dict[str, Any]:
    return {
        "display_name": "",
        "primary_mail": "",
        "department": "",
        "exit_date": "",
        "manager_display_name": "",
        "exit_type": "standard",
        "forward_mail_to": "",
        "mailbox_access_delegate": "",
        "disable_sign_in_immediately": False,
        "collect_assets": True,
        "wipe_mobile_device": False,
        "preserve_home_drive": True,
    }


class OnboardingRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    given_name: str
    family_name: str
    primary_mail: str
    department: str
    location: str
    start_date: date
    manager_display_name: str
    role_package: str
    needs_mailbox: bool = False
    needs_phone: bool = False
    needs_device: bool = False
    generate_welcome_letter: bool = False

    @field_validator("given_name", "family_name", "department", "location", "manager_display_name")
    @classmethod
    def validate_required_text(cls, value: str) -> str:
        if len(value.strip()) < 2:
            raise ValueError("Bitte mindestens 2 Zeichen eingeben.")
        if len(value.strip()) > 120:
            raise ValueError("Bitte maximal 120 Zeichen verwenden.")
        return value.strip()

    @field_validator("primary_mail")
    @classmethod
    def validate_primary_mail(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Bitte eine gültige E-Mail-Adresse angeben.")
        return normalized

    @field_validator("start_date")
    @classmethod
    def validate_start_date(cls, value: date) -> date:
        if value < date.today():
            raise ValueError("Das Startdatum darf nicht in der Vergangenheit liegen.")
        return value

    @field_validator("role_package")
    @classmethod
    def validate_role_package(cls, value: str) -> str:
        allowed_values = {item["value"] for item in ONBOARDING_ROLE_PACKAGES}
        if value not in allowed_values:
            raise ValueError("Bitte ein gültiges Rollenpaket auswählen.")
        return value


class OffboardingRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    display_name: str
    primary_mail: str
    department: str
    exit_date: date
    manager_display_name: str
    exit_type: str
    forward_mail_to: str = ""
    mailbox_access_delegate: str = ""
    disable_sign_in_immediately: bool = False
    collect_assets: bool = False
    wipe_mobile_device: bool = False
    preserve_home_drive: bool = False

    @field_validator("display_name", "department", "manager_display_name")
    @classmethod
    def validate_required_text(cls, value: str) -> str:
        if len(value.strip()) < 2:
            raise ValueError("Bitte mindestens 2 Zeichen eingeben.")
        if len(value.strip()) > 120:
            raise ValueError("Bitte maximal 120 Zeichen verwenden.")
        return value.strip()

    @field_validator("primary_mail")
    @classmethod
    def validate_primary_mail(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Bitte eine gültige E-Mail-Adresse angeben.")
        return normalized

    @field_validator("forward_mail_to")
    @classmethod
    def validate_forward_mail_to(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized and not EMAIL_PATTERN.match(normalized):
            raise ValueError("Bitte eine gültige Weiterleitungsadresse angeben.")
        return normalized

    @field_validator("exit_type")
    @classmethod
    def validate_exit_type(cls, value: str) -> str:
        allowed_values = {item["value"] for item in OFFBOARDING_EXIT_TYPES}
        if value not in allowed_values:
            raise ValueError("Bitte eine gültige Austrittsart auswählen.")
        return value

    @model_validator(mode="after")
    def validate_combination(self) -> "OffboardingRequest":
        if self.exit_type == "immediate" and not self.disable_sign_in_immediately:
            raise ValueError("Bei einem Sofort-Austritt muss die Sofortsperre aktiviert sein.")

        if self.forward_mail_to and self.forward_mail_to == self.primary_mail:
            raise ValueError("Die Weiterleitung darf nicht auf das gleiche Postfach zeigen.")

        return self


def _build_error_map(exc: ValidationError) -> tuple[dict[str, list[str]], list[str]]:
    field_errors: dict[str, list[str]] = {}
    form_errors: list[str] = []

    for error in exc.errors():
        loc = error.get("loc", ())
        message = str(error.get("msg", "Ungültiger Wert."))
        field_name = str(loc[-1]) if loc else "__all__"

        if field_name == "__all__":
            form_errors.append(message)
            continue

        field_errors.setdefault(field_name, []).append(message)

    return field_errors, form_errors


def _coerce_form_values(values: Mapping[str, Any], defaults: dict[str, Any]) -> dict[str, Any]:
    merged = defaults.copy()
    merged.update(values)
    return merged


def parse_onboarding_form(form_data: Mapping[str, Any]) -> tuple[OnboardingRequest | None, dict[str, Any], dict[str, list[str]], list[str]]:
    raw_values = {
        "given_name": form_data.get("given_name", ""),
        "family_name": form_data.get("family_name", ""),
        "primary_mail": form_data.get("primary_mail", ""),
        "department": form_data.get("department", ""),
        "location": form_data.get("location", ""),
        "start_date": form_data.get("start_date", ""),
        "manager_display_name": form_data.get("manager_display_name", ""),
        "role_package": form_data.get("role_package", onboarding_form_defaults()["role_package"]),
        "needs_mailbox": checkbox_to_bool(form_data.get("needs_mailbox")),
        "needs_phone": checkbox_to_bool(form_data.get("needs_phone")),
        "needs_device": checkbox_to_bool(form_data.get("needs_device")),
        "generate_welcome_letter": checkbox_to_bool(form_data.get("generate_welcome_letter")),
    }
    form_values = _coerce_form_values(raw_values, onboarding_form_defaults())

    try:
        model = OnboardingRequest.model_validate(raw_values)
    except ValidationError as exc:
        field_errors, form_errors = _build_error_map(exc)
        return None, form_values, field_errors, form_errors

    return model, form_values, {}, []


def parse_offboarding_form(form_data: Mapping[str, Any]) -> tuple[OffboardingRequest | None, dict[str, Any], dict[str, list[str]], list[str]]:
    raw_values = {
        "display_name": form_data.get("display_name", ""),
        "primary_mail": form_data.get("primary_mail", ""),
        "department": form_data.get("department", ""),
        "exit_date": form_data.get("exit_date", ""),
        "manager_display_name": form_data.get("manager_display_name", ""),
        "exit_type": form_data.get("exit_type", offboarding_form_defaults()["exit_type"]),
        "forward_mail_to": form_data.get("forward_mail_to", ""),
        "mailbox_access_delegate": form_data.get("mailbox_access_delegate", ""),
        "disable_sign_in_immediately": checkbox_to_bool(form_data.get("disable_sign_in_immediately")),
        "collect_assets": checkbox_to_bool(form_data.get("collect_assets")),
        "wipe_mobile_device": checkbox_to_bool(form_data.get("wipe_mobile_device")),
        "preserve_home_drive": checkbox_to_bool(form_data.get("preserve_home_drive")),
    }
    form_values = _coerce_form_values(raw_values, offboarding_form_defaults())

    try:
        model = OffboardingRequest.model_validate(raw_values)
    except ValidationError as exc:
        field_errors, form_errors = _build_error_map(exc)
        return None, form_values, field_errors, form_errors

    return model, form_values, {}, []
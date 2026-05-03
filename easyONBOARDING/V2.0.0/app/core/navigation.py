from dataclasses import dataclass


@dataclass(frozen=True)
class NavigationItem:
    title: str
    path: str
    icon: str


PRIMARY_NAVIGATION: tuple[NavigationItem, ...] = (
    NavigationItem("Dashboard", "/dashboard", "bi-speedometer2"),
    NavigationItem("Benutzer", "/users", "bi-people"),
    NavigationItem("Onboarding", "/processes/onboarding", "bi-person-plus"),
    NavigationItem("Offboarding", "/processes/offboarding", "bi-person-dash"),
    NavigationItem("Dokumentation", "/documentation", "bi-journal-text"),
    NavigationItem("Jobs", "/jobs", "bi-list-check"),
    NavigationItem("Einstellungen", "/settings", "bi-sliders"),
)


def build_primary_navigation(current_path: str) -> list[dict[str, str | bool]]:
    items: list[dict[str, str | bool]] = []

    for item in PRIMARY_NAVIGATION:
        is_active = current_path == item.path or (
            item.path != "/dashboard" and current_path.startswith(item.path)
        )
        items.append(
            {
                "title": item.title,
                "path": item.path,
                "icon": item.icon,
                "is_active": is_active,
            }
        )

    return items

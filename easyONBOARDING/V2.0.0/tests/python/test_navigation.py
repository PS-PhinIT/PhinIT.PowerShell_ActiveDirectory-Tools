from app.core.navigation import build_primary_navigation


def test_navigation_marks_matching_path_as_active() -> None:
    items = build_primary_navigation("/processes/onboarding")
    onboarding_item = next(item for item in items if item["path"] == "/processes/onboarding")
    users_item = next(item for item in items if item["path"] == "/users")

    assert onboarding_item["is_active"] is True
    assert users_item["is_active"] is False

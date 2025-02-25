import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch

from app.core.config import settings
from app.models import Message


@pytest.fixture
def superuser_token_headers(client: TestClient) -> dict[str, str]:
    login_data = {
        "username": settings.FIRST_SUPERUSER,
        "password": settings.FIRST_SUPERUSER_PASSWORD,
    }
    response = client.post(f"{settings.API_V1_STR}/login/access-token", data=login_data)
    tokens = response.json()
    a_token = tokens["access_token"]
    headers = {"Authorization": f"Bearer {a_token}"}
    return headers


def test_email(client: TestClient, superuser_token_headers: dict[str, str]) -> None:
    email_to = "test@example.com"
    with patch("app.utils.send_email") as mock_send_email:
        response = client.post(
            f"{settings.API_V1_STR}/utils/test-email/",
            headers=superuser_token_headers,
            json={"email_to": email_to},
        )
        assert response.status_code == 201
        assert response.json() == {"message": "Test email sent"}
        mock_send_email.assert_called_once_with(
            email_to=email_to,
            subject=f"{settings.PROJECT_NAME} - Test email",
            html_content=Message(
                message="Test email sent"
            ).html_content,
        )


def test_health_check(client: TestClient) -> None:
    response = client.get(f"{settings.API_V1_STR}/utils/health-check/")
    assert response.status_code == 200
    assert response.json() is True

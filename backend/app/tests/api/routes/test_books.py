import uuid
from datetime import datetime, timedelta

from fastapi.testclient import TestClient
from sqlmodel import Session

from app.core.config import settings
from app.models import BookCreate, BookUpdate
from app.tests.utils.book import create_random_book
from app.tests.utils.restaurant import create_random_restaurant


def test_read_books_superuser(client: TestClient, superuser_token_headers: dict[str, str], db: Session) -> None:
    create_random_book(db)
    create_random_book(db)
    response = client.get(
        f"{settings.API_V1_STR}/books/",
        headers=superuser_token_headers,
    )
    assert response.status_code == 200
    content = response.json()
    assert len(content["data"]) >= 2


def test_read_books_normal_user(client: TestClient, normal_user_token_headers: dict[str, str], db: Session) -> None:
    create_random_book(db)
    create_random_book(db)
    response = client.get(
        f"{settings.API_V1_STR}/books/",
        headers=normal_user_token_headers,
    )
    assert response.status_code == 200
    content = response.json()
    assert len(content["data"]) >= 0


def test_read_book(client: TestClient, superuser_token_headers: dict[str, str], db: Session) -> None:
    book = create_random_book(db)
    response = client.get(
        f"{settings.API_V1_STR}/books/{book.id}",
        headers=superuser_token_headers,
    )
    assert response.status_code == 200
    content = response.json()
    assert content["id"] == str(book.id)


def test_read_book_not_found(client: TestClient, superuser_token_headers: dict[str, str]) -> None:
    response = client.get(
        f"{settings.API_V1_STR}/books/{uuid.uuid4()}",
        headers=superuser_token_headers,
    )
    assert response.status_code == 404
    content = response.json()
    assert content["detail"] == "Book not found"


def test_read_book_not_enough_permissions(client: TestClient, normal_user_token_headers: dict[str, str], db: Session) -> None:
    book = create_random_book(db)
    response = client.get(
        f"{settings.API_V1_STR}/books/{book.id}",
        headers=normal_user_token_headers,
    )
    assert response.status_code == 400
    content = response.json()
    assert content["detail"] == "Not enough permissions"


def test_create_book(client: TestClient, superuser_token_headers: dict[str, str], db: Session) -> None:
    restaurant = create_random_restaurant(db)
    data = {
        "restaurant_id": str(restaurant.id),
        "reserved_for": (datetime.utcnow() + timedelta(hours=3)).isoformat()
    }
    response = client.post(
        f"{settings.API_V1_STR}/books/",
        headers=superuser_token_headers,
        json=data,
    )
    assert response.status_code == 200
    content = response.json()
    assert content["restaurant_id"] == data["restaurant_id"]
    assert "id" in content
    assert "owner_id" in content


def test_create_book_restaurant_not_found(client: TestClient, superuser_token_headers: dict[str, str]) -> None:
    data = {
        "restaurant_id": str(uuid.uuid4()),
        "reserved_for": (datetime.utcnow() + timedelta(hours=3)).isoformat()
    }
    response = client.post(
        f"{settings.API_V1_STR}/books/",
        headers=superuser_token_headers,
        json=data,
    )
    assert response.status_code == 404
    content = response.json()
    assert content["detail"] == "Restaurant not found"


def test_create_book_invalid_time(client: TestClient, superuser_token_headers: dict[str, str], db: Session) -> None:
    restaurant = create_random_restaurant(db)
    data = {
        "restaurant_id": str(restaurant.id),
        "reserved_for": (datetime.utcnow() - timedelta(hours=1)).isoformat()
    }
    response = client.post(
        f"{settings.API_V1_STR}/books/",
        headers=superuser_token_headers,
        json=data,
    )
    assert response.status_code == 400
    content = response.json()
    assert content["detail"] == "A reserva deve ser feita em um horário futuro"


def test_update_book(client: TestClient, superuser_token_headers: dict[str, str], db: Session) -> None:
    book = create_random_book(db)
    restaurant = create_random_restaurant(db)
    data = {
        "restaurant_id": str(restaurant.id),
        "reserved_for": (datetime.utcnow() + timedelta(hours=3)).isoformat()
    }
    response = client.put(
        f"{settings.API_V1_STR}/books/{book.id}",
        headers=superuser_token_headers,
        json=data,
    )
    assert response.status_code == 200
    content = response.json()
    assert content["restaurant_id"] == data["restaurant_id"]
    assert content["id"] == str(book.id)


def test_update_book_not_found(client: TestClient, superuser_token_headers: dict[str, str]) -> None:
    data = {
        "restaurant_id": str(uuid.uuid4()),
        "reserved_for": (datetime.utcnow() + timedelta(hours=3)).isoformat()
    }
    response = client.put(
        f"{settings.API_V1_STR}/books/{uuid.uuid4()}",
        headers=superuser_token_headers,
        json=data,
    )
    assert response.status_code == 404
    content = response.json()
    assert content["detail"] == "Book not found"


def test_update_book_not_enough_permissions(client: TestClient, normal_user_token_headers: dict[str, str], db: Session) -> None:
    book = create_random_book(db)
    restaurant = create_random_restaurant(db)
    data = {
        "restaurant_id": str(restaurant.id),
        "reserved_for": (datetime.utcnow() + timedelta(hours=3)).isoformat()
    }
    response = client.put(
        f"{settings.API_V1_STR}/books/{book.id}",
        headers=normal_user_token_headers,
        json=data,
    )
    assert response.status_code == 400
    content = response.json()
    assert content["detail"] == "Not enough permissions"


def test_delete_book(client: TestClient, superuser_token_headers: dict[str, str], db: Session) -> None:
    book = create_random_book(db)
    response = client.delete(
        f"{settings.API_V1_STR}/books/{book.id}",
        headers=superuser_token_headers,
    )
    assert response.status_code == 200
    content = response.json()
    assert content["message"] == "Book deleted successfully"


def test_delete_book_not_found(client: TestClient, superuser_token_headers: dict[str, str]) -> None:
    response = client.delete(
        f"{settings.API_V1_STR}/books/{uuid.uuid4()}",
        headers=superuser_token_headers,
    )
    assert response.status_code == 404
    content = response.json()
    assert content["detail"] == "Book not found"


def test_delete_book_not_enough_permissions(client: TestClient, normal_user_token_headers: dict[str, str], db: Session) -> None:
    book = create_random_book(db)
    response = client.delete(
        f"{settings.API_V1_STR}/books/{book.id}",
        headers=normal_user_token_headers,
    )
    assert response.status_code == 400
    content = response.json()
    assert content["detail"] == "Not enough permissions"

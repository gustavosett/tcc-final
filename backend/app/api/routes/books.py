import uuid
from typing import Any
from datetime import datetime, timedelta
import pytz

from fastapi import APIRouter, HTTPException
from sqlmodel import func, select

from app.api.deps import CurrentUser, SessionDep
from app.models import Book, BookCreate, BookPublic, BooksPublic, BookUpdate, Message, Restaurant

router = APIRouter()


@router.get("/", response_model=BooksPublic)
def read_books(
    session: SessionDep, current_user: CurrentUser, skip: int = 0, limit: int = 100
) -> Any:
    """
    Retrieve books.
    """

    if current_user.is_superuser:
        count_statement = select(func.count()).select_from(Book)
        count = session.exec(count_statement).one()
        statement = select(Book).offset(skip).limit(limit)
        books = session.exec(statement).all()
    else:
        count_statement = (
            select(func.count())
            .select_from(Book)
            .where(Book.owner_id == current_user.id)
        )
        count = session.exec(count_statement).one()
        statement = (
            select(Book)
            .where(Book.owner_id == current_user.id)
            .offset(skip)
            .limit(limit)
        )
        books = session.exec(statement).all()

    return BooksPublic(data=books, count=count)


@router.get("/{id}", response_model=BookPublic)
def read_book(session: SessionDep, current_user: CurrentUser, id: uuid.UUID) -> Any:
    """
    Get book by ID.
    """
    book = session.get(Book, id)
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    if not current_user.is_superuser and (book.owner_id != current_user.id):
        raise HTTPException(status_code=400, detail="Not enough permissions")
    return book


@router.post("/", response_model=BookPublic)
def create_book(
    *, session: SessionDep, current_user: CurrentUser, book_in: BookCreate
) -> Any:
    """
    Create new book.
    """
    restaurant = session.get(Restaurant, book_in.restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    
    # definindo os fusos horários
    fuso_sao_paulo = pytz.timezone('America/Sao_Paulo')
    fuso_utc = pytz.utc

    # obtendo o horário atual em UTC
    current_utc = datetime.utcnow().replace(tzinfo=fuso_utc)

    # convertendo o horário da reserva de São Paulo para UTC
    book_time_sao_paulo = book_in.reserved_for.replace(tzinfo=fuso_sao_paulo)
    book_time_utc = book_time_sao_paulo.astimezone(fuso_utc)

    # verificando se a reserva é para um horário futuro
    if current_utc > book_time_utc:
        raise HTTPException(
            status_code=400, detail="A reserva deve ser feita em um horário futuro"
        )
    
    # verificando se a reserva está sendo feita com pelo menos 2 horas de antecedência
    diferenca_tempo = book_time_utc - current_utc
    if diferenca_tempo < timedelta(hours=2):
        raise HTTPException(
            status_code=400, detail="A reserva deve ser feita com 2 horas de antecedência"
        )
    
    book = Book.model_validate(book_in, update={"owner_id": current_user.id})
    if restaurant.book_price <= 0:
        book.active = True
    session.add(book)
    session.commit()
    session.refresh(book)
    return book


@router.put("/{id}", response_model=BookPublic)
def update_book(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    id: uuid.UUID,
    book_in: BookUpdate,
) -> Any:
    """
    Update an book.
    """
    book = session.get(Book, id)
    restaurant = session.get(Restaurant, book_in.restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    if not current_user.is_superuser and (book.owner_id != current_user.id):
        raise HTTPException(status_code=400, detail="Not enough permissions")
    update_dict = book_in.model_dump(exclude_unset=True)
    book.sqlmodel_update(update_dict)
    session.add(book)
    session.commit()
    session.refresh(book)
    return book


@router.delete("/{id}")
def delete_book(
    session: SessionDep, current_user: CurrentUser, id: uuid.UUID
) -> Message:
    """
    Delete an book.
    """
    book = session.get(Book, id)
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    if not current_user.is_superuser and (book.owner_id != current_user.id):
        raise HTTPException(status_code=400, detail="Not enough permissions")
    session.delete(book)
    session.commit()
    return Message(message="Book deleted successfully")

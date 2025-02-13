from datetime import datetime, time
from enum import Enum
from typing import Optional
import uuid

from pydantic import EmailStr
from sqlmodel import Field, Relationship, SQLModel
from pydantic_br import CPFDigits

class WeekEnum(str, Enum):
    Monday = "monday"
    Tuesday = "tuesday"
    Wednesday = "wednesday"
    Thursday = "thursday"
    Friday = "friday"
    Saturday = "saturday"
    Sunday = "sunday"

# Shared properties
class UserBase(SQLModel):
    email: EmailStr = Field(unique=True, index=True, max_length=255)
    cpf: str
    is_active: bool = True
    is_superuser: bool = False
    full_name: str | None = Field(default=None, max_length=255)


# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str = Field(min_length=8, max_length=40)
    cpf: CPFDigits


class UserRegister(SQLModel):
    email: EmailStr = Field(max_length=255)
    password: str = Field(min_length=8, max_length=40)
    full_name: str | None = Field(default=None, max_length=255)
    cpf: CPFDigits


# Properties to receive via API on update, all are optional
class UserUpdate(UserBase):
    email: EmailStr | None = Field(default=None, max_length=255)
    password: str | None = Field(default=None, min_length=8, max_length=40)


class UserUpdateMe(SQLModel):
    full_name: str | None = Field(default=None, max_length=255)
    email: EmailStr | None = Field(default=None, max_length=255)


class UpdatePassword(SQLModel):
    current_password: str = Field(min_length=8, max_length=40)
    new_password: str = Field(min_length=8, max_length=40)


# Database model, database table inferred from class name
class User(UserBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    hashed_password: str
    items: list["Item"] = Relationship(back_populates="owner", cascade_delete=True)
    restaurants: list["Restaurant"] = Relationship(back_populates="owner", cascade_delete=True)
    books: list["Book"] = Relationship(back_populates="user", cascade_delete=True)
    payments: list["Payment"] = Relationship(back_populates="user", cascade_delete=True)


# Properties to return via API, id is always required
class UserPublic(UserBase):
    id: uuid.UUID
    
class UserMe(UserPublic):
    restaurants: list["RestaurantPublic"]
    books: list["BookPublic"]
    payments: list["PaymentPublic"]


class UsersPublic(SQLModel):
    data: list[UserPublic]
    count: int

class RestaurantBase(SQLModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)
    address: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=255)
    image: str | None = Field(default=None)
    book_price: int = 0

class RestaurantCreate(RestaurantBase):
    pass

class RestaurantUpdate(RestaurantBase):
    pass
    
class Restaurant(RestaurantBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    rating: float = 5.0
    owner_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    owner: User | None = Relationship(back_populates="restaurants")
    items: list["Item"] = Relationship(back_populates="restaurant", cascade_delete=True)
    books: list["Book"] = Relationship(back_populates="restaurant", cascade_delete=True)
    operating_date_times: list["OperatingDateTime"] = Relationship(back_populates="restaurant", cascade_delete=True)

class RestaurantPublic(RestaurantBase):
    id: uuid.UUID
    owner_id: uuid.UUID
    rating: float = 5.0

class RestaurantFull(RestaurantPublic):
    items: list["ItemPublic"]
    books: list["BookPublic"] # yeah i know it'll show all user's books
    operating_date_times: list["OperatingDateTime"]

class RestaurantsPublic(SQLModel):
    data: list[RestaurantPublic]
    count: int

class OperatingDateTimeBase(SQLModel):
    restaurant_id: uuid.UUID
    day_of_week: WeekEnum
    open_time: time
    close_time: time
    
class OperatingDateTimeCreate(SQLModel):
    day_of_week: WeekEnum
    open_time: time
    close_time: time

class OperatingDateTimeUpdate(OperatingDateTimeCreate):
    pass

class OperatingDateTime(OperatingDateTimeBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    restaurant_id: uuid.UUID = Field(
        foreign_key="restaurant.id", nullable=False, ondelete="CASCADE"
    )
    restaurant: Restaurant | None = Relationship(back_populates="operating_date_times")

# Shared properties
class ItemBase(SQLModel):
    restaurant_id: uuid.UUID
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)
    image: str | None = Field(default=None)
    rating: float = 5.0


# Properties to receive on item creation
class ItemCreate(ItemBase):
    pass


# Properties to receive on item update
class ItemUpdate(ItemBase):
    title: str | None = Field(default=None, min_length=1, max_length=255)  # type: ignore


# Database model, database table inferred from class name
class Item(ItemBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    title: str = Field(max_length=255)
    restaurant_id: uuid.UUID = Field(
        foreign_key="restaurant.id", nullable=False, ondelete="CASCADE"
    )
    owner_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    owner: User | None = Relationship(back_populates="items")
    restaurant: Restaurant | None = Relationship(back_populates="items")


# Properties to return via API, id is always required
class ItemPublic(ItemBase):
    id: uuid.UUID
    owner_id: uuid.UUID


class ItemsPublic(SQLModel):
    data: list[ItemPublic]
    count: int
    
class BookBase(SQLModel):
    restaurant_id: uuid.UUID
    people_quantity: int = Field(ge=1, le=20)
    reserved_for: datetime

class BookCreate(BookBase):
    pass

class BookUpdate(BookBase):
    pass

class Book(BookBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    restaurant_id: uuid.UUID = Field(
        foreign_key="restaurant.id", nullable=False, ondelete="CASCADE"
    )
    owner_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    active: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    user: User | None = Relationship(back_populates="books")
    restaurant: Restaurant | None = Relationship(back_populates="books")
    payments: list["Payment"] = Relationship(back_populates="book", cascade_delete=True)

class BookPublic(BookBase):
    id: uuid.UUID
    owner_id: uuid.UUID
    active: bool
    created_at: datetime

class BooksPublic(SQLModel):
    data: list[BookPublic]
    count: int
    
class PaymentBase(SQLModel):
    book_id: uuid.UUID
    owner_id: uuid.UUID
    payment_type: str = Field(default="pix") # pix, credit_card, debit_card

class PaymentCreate(PaymentBase):
    pass

class PaymentUpdate(PaymentBase):
    status: str = Field(default="pending") # pending, paid, cancelled, failed

class Payment(PaymentBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    value: int
    status: str = Field(default="pending") # pending, paid, cancelled, failed
    token: str | None = Field(default=None)
    book_id: uuid.UUID = Field(
        foreign_key="book.id", nullable=False
    )
    owner_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False
    )
    created_at: datetime = Field(default_factory=datetime.utcnow)
    book: Book | None = Relationship(back_populates="payments")
    user: User | None = Relationship(back_populates="payments")

class Calendario(SQLModel):
    criacao: datetime
    expiracao: int

class Local(SQLModel):
    id: Optional[int] = None
    location: Optional[str] = None
    tipoCob: Optional[str] = None

class Devedor(SQLModel):
    cnpj: Optional[str] = None
    nome: Optional[str] = None

class Valor(SQLModel):
    original: Optional[str] = None

class Charge(SQLModel):
    txid: str
    calendario: Optional[Calendario] = None
    revisao: Optional[int] = None
    loc: Optional[Local] = None
    location: Optional[str] = None
    status: Optional[str] = None
    devedor: Optional[Devedor] = None
    valor: Optional[Valor] = None
    chave: Optional[str] = None
    solicitacaoPagador: Optional[str] = None
    pixCopiaECola: Optional[str] = None

class PaymentPublic(PaymentBase):
    id: uuid.UUID
    value: int
    status: str = Field(default="pending") # pending, paid, canceled
    created_at: datetime
    
class PaymentCharge(PaymentPublic):
    charge: Optional[Charge] = None

class PaymentsPublic(SQLModel):
    data: list[PaymentPublic]
    count: int
    
# Generic message
class Message(SQLModel):
    message: str


# JSON payload containing access token
class Token(SQLModel):
    access_token: str
    token_type: str = "bearer"


# Contents of JWT token
class TokenPayload(SQLModel):
    sub: str | None = None


class NewPassword(SQLModel):
    token: str
    new_password: str = Field(min_length=8, max_length=40)

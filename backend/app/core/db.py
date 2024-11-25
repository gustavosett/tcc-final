from sqlmodel import Session, create_engine, select

from app import crud
from app.core.config import settings
from app.models import * # noqa

engine = create_engine(str(settings.SQLALCHEMY_DATABASE_URI))

def init_db(session: Session) -> None:
    user = session.exec(
        select(User).where(User.email == settings.FIRST_SUPERUSER)
    ).first()
    if not user:
        user_in = UserCreate(
            email=settings.FIRST_SUPERUSER,
            password=settings.FIRST_SUPERUSER_PASSWORD,
            is_superuser=True,
            cpf="12345678909",
        )
        user = crud.create_user(session=session, user_create=user_in)

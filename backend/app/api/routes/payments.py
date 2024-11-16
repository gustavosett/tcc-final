from datetime import datetime, timedelta
import uuid
from typing import Any, Union

from app.payment import create_immediate_charge, detail_charge
from fastapi import APIRouter, HTTPException
from sqlmodel import func, select

from app.api.deps import CurrentUser, SessionDep
from app.models import Book, Charge, Payment, PaymentCreate, PaymentCharge, PaymentPublic, PaymentsPublic, PaymentUpdate, Message, Restaurant
from app.core.config import settings

router = APIRouter()


@router.get("/", response_model=PaymentsPublic)
def read_payments(
    session: SessionDep, current_user: CurrentUser, skip: int = 0, limit: int = 100
) -> Any:
    """
    Retrieve payments.
    """

    if current_user.is_superuser:
        count_statement = select(func.count()).select_from(Payment)
        count = session.exec(count_statement).one()
        statement = select(Payment).offset(skip).limit(limit)
        payments = session.exec(statement).all()
    else:
        count_statement = (
            select(func.count())
            .select_from(Payment)
            .where(Payment.owner_id == current_user.id)
        )
        count = session.exec(count_statement).one()
        statement = (
            select(Payment)
            .where(Payment.owner_id == current_user.id)
            .offset(skip)
            .limit(limit)
        )
        payments = session.exec(statement).all()

    return PaymentsPublic(data=payments, count=count)


@router.get("/{id}", response_model=PaymentCharge)
def read_payment(
    session: SessionDep, current_user: CurrentUser, id: uuid.UUID
) -> Any:
    """
    Get payment by ID.
    """
    payment = session.get(Payment, id)
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    book = session.get(Book, payment.book_id)
    
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")

    if not current_user.is_superuser and (payment.owner_id != current_user.id):
        raise HTTPException(status_code=400, detail="Not enough permissions")

    if not payment.token:
        return PaymentCharge.model_validate(payment, update={"charge": None})
    
    charge_data = detail_charge(payment.token)
    new_status = "pending"
    changed = False

    if not charge_data:
        new_status = "failed"
    else:
        charge: Charge = Charge(**charge_data)
        match charge.status:
            case "CONCLUIDA":
                new_status = "paid"
                book.active = True
                session.add(book)
            case "REMOVIDA_PELO_USUARIO_RECEBEDOR" | "REMOVIDA_PELO_PSP":
                new_status = "cancelled"
        # check if charge has expired
        if charge.status == "ATIVA" and new_status == "pending" and charge.calendario != None and payment.status != "cancelled":
            criacao: datetime = charge.calendario.criacao
            expiracao: int = charge.calendario.expiracao
            if criacao and expiracao:
                now = datetime.now(criacao.tzinfo)
                expiration = criacao + timedelta(seconds=expiracao)
                if now > expiration:
                    new_status = "cancelled"

    # update payment status if it has changed
    if payment.status != new_status and payment.status != "cancelled":
        payment.status = new_status
        changed = True

    if changed:
        session.add(payment)
        session.commit()
        session.refresh(payment)

    # create PaymentCharge with updated charge
    payment_charge = PaymentCharge.model_validate(payment, update={"charge": charge if charge else None})

    return payment_charge


@router.post("/", response_model=PaymentCharge)
def create_payment(
    *, session: SessionDep, current_user: CurrentUser, payment_in: PaymentCreate
) -> Any:
    """
    Create new payment.
    """
    book = session.get(Book, payment_in.book_id)
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    restaurant = session.get(Restaurant, book.restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=500, detail="Restaurant not found")
    if restaurant.book_price <= 0:
        raise HTTPException(status_code=400, detail="Restaurant book price is invalid")
    if not current_user.cpf:
        raise HTTPException(status_code=400, detail="User CPF is invalid")
    if not current_user.full_name:
        raise HTTPException(status_code=400, detail="User full name is invalid")
        
    payment = Payment.model_validate(payment_in, update={"owner_id": current_user.id, "value": restaurant.book_price})
    charge_data: dict = create_immediate_charge(
        # expiration=360,
        expiration=30,
        cpf=str(current_user.cpf),
        name=str(current_user.full_name),
        value=int(restaurant.book_price),
        key=str(settings.EFIPAY_EVP_KEY),
        description=f"booking in {restaurant.name}",
    ) # type: ignore
    if not isinstance(charge_data, dict) or not charge_data:
        print(charge_data)
        raise HTTPException(status_code=500, detail="Create payment failed")
    try:
        charge = Charge(**charge_data)
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="Create payment failed")
    payment.token = charge.txid
    # session.add(charge)
    session.add(payment)
    session.commit()
    session.refresh(payment)
    # session.refresh(charge)
    response = PaymentCharge.model_validate(payment)
    response.charge = charge
    return response


@router.put("/{id}", response_model=PaymentPublic)
def update_payment(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    id: uuid.UUID,
    payment_in: PaymentUpdate,
) -> Any:
    """
    Update an payment.
    """
    payment = session.get(Payment, id)
    book = session.get(Book, payment_in.book_id)
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if not current_user.is_superuser:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    update_dict = payment_in.model_dump(exclude_unset=True)
    payment.sqlmodel_update(update_dict)
    session.add(payment)
    session.commit()
    session.refresh(payment)
    return payment


@router.delete("/{id}")
def delete_payment(
    session: SessionDep, current_user: CurrentUser, id: uuid.UUID
) -> Message:
    """
    Delete an payment.
    """
    payment = session.get(Payment, id)
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if not current_user.is_superuser and (payment.owner_id != current_user.id):
        raise HTTPException(status_code=400, detail="Not enough permissions")
    session.delete(payment)
    session.commit()
    return Message(message="Payment deleted successfully")

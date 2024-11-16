from datetime import datetime
import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import func, select

from app.api.deps import CurrentUser, SessionDep
from app.models import (
    OperatingDateTime,
    OperatingDateTimeCreate,
    OperatingDateTimeUpdate,
    OperatingDateTimeBase,
    Restaurant,
    RestaurantCreate,
    RestaurantFull,
    RestaurantPublic,
    RestaurantsPublic,
    RestaurantUpdate,
    Message,
    WeekEnum,
)

router = APIRouter()


@router.get("/", response_model=RestaurantsPublic)
def read_restaurants(
    # session: SessionDep, skip: int = 0, limit: int = 100, only_open: bool = True
    session: SessionDep, skip: int = 0, limit: int = 100, only_open: bool = False # change this later
) -> Any:
    """
    Retrieve restaurants.
    """
    if only_open:
        # Obtenha o dia e a hora atuais
        current_datetime = datetime.now()
        current_day_of_week = current_datetime.strftime('%A')  # Exemplo: 'Monday'
        current_time_str = current_datetime.strftime('%H:%M')  # Exemplo: '14:30'

        # Base da consulta para restaurantes abertos
        base_query = (
            select(Restaurant)
            .join(OperatingDateTime, Restaurant.id == OperatingDateTime.restaurant_id)
            .where(
                OperatingDateTime.day_of_week == current_day_of_week,
                OperatingDateTime.open_time <= current_time_str,
                OperatingDateTime.close_time > current_time_str,
            )
            .distinct()
        )
        # Adicione offset e limit à consulta principal
        statement = base_query.offset(skip).limit(limit)

    else:
        statement = select(Restaurant).offset(skip).limit(limit)

    restaurants = session.exec(statement).all()
    return RestaurantsPublic(data=restaurants, count=len(restaurants))


@router.get("/{id}", response_model=RestaurantFull)
def read_restaurant(session: SessionDep, id: uuid.UUID) -> Any:
    """
    Get restaurant by ID.
    """
    restaurant = session.get(Restaurant, id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant


@router.post("/", response_model=RestaurantPublic)
def create_restaurant(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    restaurant_in: RestaurantCreate
) -> Any:
    """
    Create new restaurant.
    """
    restaurant = Restaurant.model_validate(restaurant_in, update={"owner_id": current_user.id})
    session.add(restaurant)
    session.commit()
    session.refresh(restaurant)
    return restaurant


@router.put("/{id}", response_model=RestaurantPublic)
def update_restaurant(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    id: uuid.UUID,
    restaurant_in: RestaurantUpdate,
) -> Any:
    """
    Update a restaurant.
    """
    restaurant = session.get(Restaurant, id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
        raise HTTPException(status_code=403, detail="Not enough permissions")
    update_dict = restaurant_in.model_dump(exclude_unset=True)
    restaurant.sqlmodel_update(update_dict)
    session.add(restaurant)
    session.commit()
    session.refresh(restaurant)
    return restaurant


@router.delete("/{id}")
def delete_restaurant(
    session: SessionDep, current_user: CurrentUser, id: uuid.UUID
) -> Message:
    """
    Delete a restaurant.
    """
    restaurant = session.get(Restaurant, id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
        raise HTTPException(status_code=403, detail="Not enough permissions")
    session.delete(restaurant)
    session.commit()
    return Message(message="Restaurant deleted successfully")

# Rotas para gerenciar OperatingDateTime

@router.get("/{restaurant_id}/operating_date_times/", response_model=list[OperatingDateTimeBase])
def get_operating_date_times(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    restaurant_id: uuid.UUID,
) -> Any:
    """
    Get all operating date times for a restaurant.
    """
    restaurant = session.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
        raise HTTPException(status_code=403, detail="Not enough permissions")
    operating_times = session.exec(
        select(OperatingDateTime).where(OperatingDateTime.restaurant_id == restaurant_id)
    ).all()
    return operating_times


@router.post("/{restaurant_id}/operating_date_times/", response_model=OperatingDateTimeBase)
def create_operating_date_time(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    restaurant_id: uuid.UUID,
    operating_time_in: OperatingDateTimeCreate,
) -> Any:
    """
    Create a new operating date time for a restaurant.
    """
    restaurant = session.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
        raise HTTPException(status_code=403, detail="Not enough permissions")
    # check if it has an existing operating time for the same day:
    existing_operating_time = session.exec(
        select(OperatingDateTime)
        .where(
            OperatingDateTime.restaurant_id == restaurant_id,
            OperatingDateTime.day_of_week == operating_time_in.day_of_week,
        )
    ).first()
    if existing_operating_time:
        raise HTTPException(
            status_code=400, detail="Operating date time for this day already exists"
        )
    
    operating_time = OperatingDateTime.model_validate(
        operating_time_in, update={"restaurant_id": restaurant_id}
    )
    session.add(operating_time)
    session.commit()
    session.refresh(operating_time)
    return operating_time


@router.put("/{restaurant_id}/operating_date_times/", response_model=OperatingDateTimeBase)
def update_operating_date_time(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    restaurant_id: uuid.UUID,
    operating_time_in: OperatingDateTimeUpdate,
) -> Any:
    """
    Update an operating date time for a restaurant.
    """
    restaurant = session.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
        raise HTTPException(status_code=403, detail="Not enough permissions")
    # operating_time = session.get(OperatingDateTime, id)
    # get by weekday instead of id:
    operating_time = session.exec(
        select(OperatingDateTime)
        .where(
            OperatingDateTime.restaurant_id == restaurant_id,
            OperatingDateTime.day_of_week == operating_time_in.day_of_week,
        ),
    ).first()
    if not operating_time:
        raise HTTPException(status_code=404, detail="Operating date time not found")
    update_dict = operating_time_in.model_dump(exclude_unset=True)
    operating_time.sqlmodel_update(update_dict)
    session.add(operating_time)
    session.commit()
    session.refresh(operating_time)
    return operating_time


@router.delete("/{restaurant_id}/operating_date_times")
def delete_operating_date_time(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    restaurant_id: uuid.UUID,
    week_day: WeekEnum,
) -> Message:
    """
    Delete an operating date time for a restaurant.
    """
    restaurant = session.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
        raise HTTPException(status_code=403, detail="Not enough permissions")
    # operating_time = session.get(OperatingDateTime, id)
    # get by weekday instead of id:
    operating_time = session.exec(
        select(OperatingDateTime)
        .where(
            OperatingDateTime.restaurant_id == restaurant_id,
            OperatingDateTime.day_of_week == week_day,
        ),
    ).first()
    if not operating_time:
        raise HTTPException(status_code=404, detail="Operating date time not found")
    session.delete(operating_time)
    session.commit()
    return Message(message="Operating date time deleted successfully")

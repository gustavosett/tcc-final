from datetime import datetime
import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import func, select
from sqlalchemy import or_, case, literal_column

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

# DO NOT CHANGE THIS FUNCTION ORDER, IT WILL BREAK THE SERVER(I don't know why)
@router.get("/search", response_model=RestaurantsPublic)
def search_restaurants(
    *, session: SessionDep, query: str, skip: int = 0, limit: int = 100
) -> Any:
    """
    Search for restaurants based on a query string.
    """
    if not query.strip():
        raise HTTPException(status_code=400, detail="Query string is empty")
    query_words = query.strip().split()

    # initialize the relevance column
    relevance = literal_column("0")
    search_conditions = []
    
    for word in query_words:
        like_pattern = f"%{word}%"

        # add search conditions
        condition = or_(
            Restaurant.name.ilike(like_pattern),
            Restaurant.description.ilike(like_pattern),
            Restaurant.address.ilike(like_pattern),
        )
        search_conditions.append(condition)

        # add weights
        # TODO: change the weights to be configurable
        relevance += case(
            (Restaurant.name.ilike(like_pattern), literal_column("3")),
            else_=literal_column("0")
        )
        relevance += case(
            (Restaurant.description.ilike(like_pattern), literal_column("2")),
            else_=literal_column("0")
        )
        relevance += case(
            (Restaurant.address.ilike(like_pattern), literal_column("1")),
            else_=literal_column("0")
        )

    #combine all search conditions
    combined_condition = or_(*search_conditions)

    # build the query statement
    statement = (
        select(Restaurant, relevance.label('relevance'))
        .where(combined_condition)
        .order_by(relevance.desc())
        .offset(skip)
        .limit(limit)
    )

    results = session.exec(statement).all()
    restaurants = [result[0] for result in results]
    count_statement = select(func.count()).select_from(
        select(Restaurant.id).where(combined_condition).subquery()
    )
    count = session.exec(count_statement).one()

    return RestaurantsPublic(data=restaurants, count=count)

@router.get("/", response_model=RestaurantsPublic)
def read_restaurants(
    # session: SessionDep, skip: int = 0, limit: int = 100, only_open: bool = True
    session: SessionDep, skip: int = 0, limit: int = 100, only_open: bool = False # TODO: change this later
) -> Any:
    """
    Retrieve restaurants.
    """
    if only_open:
        current_datetime = datetime.now()
        current_day_of_week = current_datetime.strftime('%A')  # Exemplo: 'Monday'
        current_time_str = current_datetime.strftime('%H:%M')  # Exemplo: '14:30'

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

        count_subquery = base_query.alias()
        count_statement = select(func.count()).select_from(count_subquery)
        count = session.exec(count_statement).one()

        statement = base_query.offset(skip).limit(limit)

    else:
        count_statement = select(func.count()).select_from(Restaurant)
        count = session.exec(count_statement).one()

        statement = select(Restaurant).offset(skip).limit(limit)

    restaurants = session.exec(statement).all()
    return RestaurantsPublic(data=restaurants, count=count)


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

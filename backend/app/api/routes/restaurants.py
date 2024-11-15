import uuid
from typing import Any

from fastapi import APIRouter, HTTPException
from sqlmodel import func, select

from app.api.deps import CurrentUser, SessionDep
from app.models import Restaurant, RestaurantCreate, RestaurantFull, RestaurantPublic, RestaurantsPublic, RestaurantUpdate, Message

router = APIRouter()


@router.get("/", response_model=RestaurantsPublic)
def read_restaurants(
    session: SessionDep, skip: int = 0, limit: int = 100
) -> Any:
    """
    Retrieve restaurants.
    """
    count_statement = (
        select(func.count())
        .select_from(Restaurant)
        # .where(Restaurant.owner_id == current_user.id)
    )
    count = session.exec(count_statement).one()
    statement = (
        select(Restaurant)
        # .where(Restaurant.owner_id == current_user.id)
        .offset(skip)
        .limit(limit)
    )
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
    # if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
    #     raise HTTPException(status_code=400, detail="Not enough permissions")
    return restaurant


@router.post("/", response_model=RestaurantPublic)
def create_restaurant(
    *, session: SessionDep, current_user: CurrentUser, restaurant_in: RestaurantCreate
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
    Update an restaurant.
    """
    restaurant = session.get(Restaurant, id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
        raise HTTPException(status_code=400, detail="Not enough permissions")
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
    Delete an restaurant.
    """
    restaurant = session.get(Restaurant, id)
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not current_user.is_superuser and (restaurant.owner_id != current_user.id):
        raise HTTPException(status_code=400, detail="Not enough permissions")
    session.delete(restaurant)
    session.commit()
    return Message(message="Restaurant deleted successfully")

import uuid
import requests
from datetime import time
from sqlmodel import Session
from app.models import User, Restaurant, Item, OperatingDateTime, WeekEnum
from faker import Faker
from duckduckgo_search import DDGS
import random
from app.core.db import engine

def fetch_image_urls(queries, results_per_query=1, salts=None):
    ddgs = DDGS()
    image_urls = []
    for query in queries:
        if salts:
            query += f" {random.choice(salts)}"
        images = ddgs.images(
            keywords=query,
            max_results=results_per_query,
        )
        image_urls.extend([image['image'] for image in images if 'image' in image])
    return image_urls

def is_image_valid(url):
    try:
        response = requests.get(url, timeout=0.4)
        return response.status_code == 200 and 'image' in response.headers['Content-Type'] and url.endswith(('jpg', 'jpeg', 'png'))
    except:
        return False

def validate_image_urls(image_urls):
    valid_urls = []
    for url in image_urls:
        if is_image_valid(url):
            valid_urls.append(url)
    return valid_urls

def populate_database():
    fake = Faker('pt_BR')
    with Session(engine) as session:
        default_user = User(
            id=uuid.uuid4(),
            email=f"usuario{random.randint(1, 1000)}@exemplo{random.randint(1, 1000)}.com",
            cpf=fake.cpf(),
            hashed_password="senha_hash",
            full_name="Usuário Padrão",
            is_active=True,
            is_superuser=False
        )
        session.add(default_user)
        session.commit()
        session.refresh(default_user)

        dias_semana = [
            WeekEnum.Monday,
            WeekEnum.Tuesday,
            WeekEnum.Wednesday,
            WeekEnum.Thursday,
            WeekEnum.Friday,
            WeekEnum.Saturday
        ]

        num_restaurantes = 400
        num_pratos_por_restaurante = 25

        restaurant_queries = list(set([random.choice(['restaurante', 'fachada de restaurante', 'interior de restaurante']) for _ in range(50)]))
        restaurant_salts = ["japonês", "americano", "italiano", "francês", "brasileiro", "mexicano", "chinês", "fast food", "gourmet"]

        print("Carregando imagens de restaurantes...")
        restaurant_image_urls = fetch_image_urls(restaurant_queries, results_per_query=10, salts=restaurant_salts)
        restaurant_image_urls = list(set(restaurant_image_urls))
        restaurant_image_urls = validate_image_urls(restaurant_image_urls)

        if not restaurant_image_urls:
            restaurant_image_urls = ["https://via.placeholder.com/1000x1000.png?text=No+Image+Available"]

        dish_queries = list(set([random.choice(['prato de comida', 'comida', 'prato gourmet', 'culinária', 'hambúrguer', 'pizza', 'massa', 'sushi', 'sashimi', 'tacos', 'burritos', 'comida chinesa', 'comida japonesa', 'comida italiana', 'comida brasileira', 'comida mexicana']) for _ in range(100)]))
        dish_salts = ["japonês", "americano", "italiano", "francês", "brasileiro", "mexicano", "chinês", "fast food", "gourmet"]

        print("Carregando imagens de pratos...")
        dish_image_urls = fetch_image_urls(dish_queries, results_per_query=25, salts=dish_salts)
        dish_image_urls = list(set(dish_image_urls))
        dish_image_urls = validate_image_urls(dish_image_urls)

        if not dish_image_urls:
            dish_image_urls = ["https://via.placeholder.com/1000x1000.png?text=No+Image+Available"]

        while len(restaurant_image_urls) < num_restaurantes:
            restaurant_image_urls *= 2
        while len(dish_image_urls) < num_restaurantes * num_pratos_por_restaurante:
            dish_image_urls *= 2

        dish_image_iter = iter(dish_image_urls)

        for i in range(num_restaurantes):
            nome_restaurante = fake.company()
            descricao_restaurante = fake.catch_phrase()
            endereco_restaurante = fake.address()
            telefone_restaurante = fake.phone_number()

            imagem_restaurante = restaurant_image_urls[i % len(restaurant_image_urls)]

            prefix = random.choice(["Restaurante", "Bar", "Cantina", "Churrascaria", "Pizzaria"])
            restaurant = Restaurant(
                id=uuid.uuid4(),
                name=f"{prefix} {nome_restaurante}",
                description=descricao_restaurante,
                address=endereco_restaurante,
                phone=telefone_restaurante,
                image=imagem_restaurante,
                book_price=random.randint(10, 100),
                rating=round(random.uniform(3.5, 5.0), 1),
                owner_id=default_user.id
            )
            session.add(restaurant)
            session.commit()
            session.refresh(restaurant)

            for dia in dias_semana:
                operating_time = OperatingDateTime(
                    id=uuid.uuid4(),
                    restaurant_id=restaurant.id,
                    day_of_week=dia,
                    open_time=time(random.randint(8, 11), 0),
                    close_time=time(random.randint(20, 23), 0)
                )
                session.add(operating_time)

            for _ in range(num_pratos_por_restaurante):
                nome_prato = fake.word().capitalize()
                descricao_prato = fake.sentence()
                imagem_prato = next(dish_image_iter, None)
                if imagem_prato is None:
                    imagem_prato = random.choice(dish_image_urls)

                item = Item(
                    id=uuid.uuid4(),
                    restaurant_id=restaurant.id,
                    owner_id=default_user.id,
                    title=nome_prato,
                    description=descricao_prato,
                    image=imagem_prato,
                    rating=round(random.uniform(3.5, 5.0), 1)
                )
                session.add(item)

            session.commit()

            print(f"Restaurante '{nome_restaurante}' adicionado com sucesso.")

        print("Banco de dados populado com sucesso!")

if __name__ == "__main__":
    populate_database()

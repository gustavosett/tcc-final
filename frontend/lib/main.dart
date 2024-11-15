import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para conversão de JSON
import 'package:shared_preferences/shared_preferences.dart'; // Para armazenamento local
import 'package:cached_network_image/cached_network_image.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String urlBackend = 'http://10.0.2.2:8000';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MesApp',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const MyHomePage(title: 'MesApp'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    SearchPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<String> _titles = ['Início', 'Pesquisa', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Pesquisa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Restaurant> restaurants = [];
  int skip = 0;
  final int limit = 10;
  bool isLoading = false;
  bool hasMore = true;
  bool isInitialLoading = true;
  String? errorMessage;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        _fetchRestaurants();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchRestaurants() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url =
        '${MyApp.urlBackend}/api/v1/restaurants/?skip=$skip&limit=$limit';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        List<dynamic> data = responseData['data'] as List<dynamic>;
        int count = responseData['count'] as int;

        List<Restaurant> fetchedRestaurants =
            data.map((item) => Restaurant.fromJson(item)).toList();

        setState(() {
          skip += limit;
          restaurants.addAll(fetchedRestaurants);
          hasMore = restaurants.length < count;
          isLoading = false;
          isInitialLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Erro ao carregar restaurantes. Tente novamente.';
          isLoading = false;
          isInitialLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erro de rede. Verifique sua conexão.';
        isLoading = false;
        isInitialLoading = false;
      });
    }
  }

  Future<void> _refreshRestaurants() async {
    setState(() {
      restaurants.clear();
      skip = 0;
      hasMore = true;
      isInitialLoading = true;
    });
    await _fetchRestaurants();
  }

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading && restaurants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && restaurants.isEmpty) {
      return Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshRestaurants,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: restaurants.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == restaurants.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final restaurant = restaurants[index];
          return RestaurantListItem(
            restaurant: restaurant,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      RestaurantDetailPage(restaurant: restaurant),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Página de Pesquisa',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}

// Modelos de Dados

class Item {
  final String restaurantId;
  final String title;
  final String description;
  final String image;
  final double rating;
  final String id;
  final String ownerId;

  Item({
    required this.restaurantId,
    required this.title,
    required this.description,
    required this.image,
    required this.rating,
    required this.id,
    required this.ownerId,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      restaurantId: json['restaurant_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
    );
  }
}

class User {
  final String email;
  final String cpf;
  final bool isActive;
  final bool isSuperuser;
  final String? fullName;
  final String id;
  final List<Restaurant> restaurants;
  final List<Book> books;

  User({
    required this.email,
    required this.cpf,
    required this.isActive,
    required this.isSuperuser,
    required this.fullName,
    required this.id,
    required this.restaurants,
    required this.books,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    var restaurantsJson = json['restaurants'] as List? ?? [];
    var booksJson = json['books'] as List? ?? [];

    List<Restaurant> restaurantList =
        restaurantsJson.map((i) => Restaurant.fromJson(i)).toList();
    List<Book> bookList = booksJson.map((i) => Book.fromJson(i)).toList();

    return User(
      email: json['email'] ?? '',
      cpf: json['cpf'] ?? '',
      isActive: json['is_active'] ?? false,
      isSuperuser: json['is_superuser'] ?? false,
      fullName: json['full_name'],
      id: json['id'] ?? '',
      restaurants: restaurantList,
      books: bookList,
    );
  }
}

class Restaurant {
  final String name;
  final String description;
  final String address;
  final String phone;
  final String image;
  final double rating;
  final int bookPrice;
  final String id;
  final String ownerId;
  final List<Item> items;
  final List<Book> books;

  Restaurant({
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.image,
    required this.rating,
    required this.bookPrice,
    required this.id,
    required this.ownerId,
    required this.items,
    required this.books,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    var itemsJson = json['items'] as List? ?? [];
    var booksJson = json['books'] as List? ?? [];

    List<Item> itemList = itemsJson.map((i) => Item.fromJson(i)).toList();
    List<Book> bookList = booksJson.map((i) => Book.fromJson(i)).toList();

    return Restaurant(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      image: json['image'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      bookPrice: json['book_price'] ?? 0,
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      items: itemList,
      books: bookList,
    );
  }
}

class RestaurantDetailPage extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailPage({Key? key, required this.restaurant})
      : super(key: key);

  @override
  _RestaurantDetailPageState createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  Restaurant? restaurantDetails;
  bool isLoading = true;
  String? errorMessage;
  String? accessToken;

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
    _fetchRestaurantDetails();
  }

  Future<void> _loadAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      accessToken = prefs.getString('access_token');
    });
  }

  Future<void> _fetchRestaurantDetails() async {
    final url =
        '${MyApp.urlBackend}/api/v1/restaurants/${widget.restaurant.id}';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'accept': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          restaurantDetails = Restaurant.fromJson(responseData);
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          errorMessage = 'Restaurante não encontrado.';
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Erro ao carregar detalhes do restaurante.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erro de rede. Verifique sua conexão.';
        isLoading = false;
      });
    }
  }

  void _onScheduleButtonPressed() {
    if (accessToken != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BookingPage(restaurantId: widget.restaurant.id),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Carregando...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erro'),
        ),
        body: Center(
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final restaurant = restaurantDetails!;

    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant.name),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            CachedNetworkImage(
              imageUrl: restaurant.image.isNotEmpty
                  ? restaurant.image
                  : 'https://via.placeholder.com/600x200',
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.restaurant, color: Colors.grey, size: 100),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Text(restaurant.address),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16),
                      const SizedBox(width: 4),
                      Text(restaurant.phone),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('${restaurant.rating}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onScheduleButtonPressed,
                      child: const Text('Agendar'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Itens do Menu',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  restaurant.items.isEmpty
                      ? const Text('Nenhum item disponível.')
                      : SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: restaurant.items.length,
                            itemBuilder: (context, index) {
                              final item = restaurant.items[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: item.image.isNotEmpty
                                            ? item.image
                                            : 'https://via.placeholder.com/80',
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.fastfood,
                                              color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.title,
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantListItem extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantListItem({
    Key? key,
    required this.restaurant,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Imagem do Restaurante
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: restaurant.image.isNotEmpty
                      ? restaurant.image
                      : 'https://via.placeholder.com/60',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Informações do Restaurante
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome do Restaurante
                    Text(
                      restaurant.name.isNotEmpty
                          ? restaurant.name
                          : 'Sem Nome',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Descrição do Restaurante
                    Text(
                      restaurant.description.isNotEmpty
                          ? restaurant.description
                          : 'Sem Descrição',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Avaliação do Restaurante
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('${restaurant.rating}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Book {
  final String restaurantId;
  final int peopleQuantity;
  final DateTime reservedFor;
  final String id;
  final String ownerId;
  final bool active;
  final DateTime createdAt;

  Book({
    required this.restaurantId,
    required this.peopleQuantity,
    required this.reservedFor,
    required this.id,
    required this.ownerId,
    required this.active,
    required this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      restaurantId: json['restaurant_id'] ?? '',
      peopleQuantity: json['people_quantity'] ?? 0,
      reservedFor:
          DateTime.tryParse(json['reserved_for'] ?? '') ?? DateTime.now(),
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      active: json['active'] ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class BookingPage extends StatefulWidget {
  final String restaurantId;

  const BookingPage({Key? key, required this.restaurantId}) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  int _peopleQuantity = 1;
  DateTime? _reservedFor;
  bool isLoading = false;
  String? errorMessage;

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_reservedFor == null) {
      setState(() {
        errorMessage = 'Por favor, selecione a data e hora da reserva.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    if (accessToken == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthPage()),
      );
      return;
    }

    final url = '${MyApp.urlBackend}/api/v1/books/';

    final body = jsonEncode({
      'restaurant_id': widget.restaurantId,
      'people_quantity': _peopleQuantity,
      'reserved_for': _reservedFor!.toUtc().toIso8601String(),
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        Book newBook = Book.fromJson(responseData);

        if (!newBook.active) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PaymentPage(book: newBook)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reserva realizada com sucesso!')),
          );
          Navigator.pop(context);
        }
      } else {
        setState(() {
          errorMessage = 'Erro ao fazer a reserva. Tente novamente.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erro de rede. Verifique sua conexão.';
        isLoading = false;
      });
    }
  }

  Future<void> _selectDateTime() async {
    DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );

      if (pickedTime != null) {
        setState(() {
          _reservedFor = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Reserva'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _peopleQuantity.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de Pessoas',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira a quantidade de pessoas.';
                        }
                        int? quantity = int.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Quantidade inválida.';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          _peopleQuantity = int.tryParse(value) ?? 1;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _reservedFor == null
                                ? 'Data e Hora não selecionadas'
                                : 'Reservado para: ${_reservedFor!.toLocal()}',
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _selectDateTime,
                          child: const Text('Selecionar Data e Hora'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null)
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submitBooking,
                      child: const Text('Confirmar Reserva'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class PaymentPage extends StatelessWidget {
  final Book book;

  const PaymentPage({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Aqui você pode implementar a lógica de pagamento
    // Para simplificar, vamos apenas exibir uma mensagem

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Pagamento Necessário',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Sua reserva para ${book.peopleQuantity} pessoas em ${book.reservedFor.toLocal()} requer pagamento.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Implementar lógica de pagamento aqui
                // Após o pagamento, você pode atualizar o estado da reserva

                // Por agora, vamos simular o pagamento e voltar para a página inicial
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pagamento realizado com sucesso!')),
                );
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text('Pagar Agora'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? accessToken;
  User? user;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndFetchProfile();
  }

  Future<void> _loadAccessTokenAndFetchProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      accessToken = token;
    });

    await _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (accessToken == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final url = '${MyApp.urlBackend}/api/v1/users/me';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        try {
          User parsedUser = User.fromJson(responseData);
          setState(() {
            user = parsedUser;
            isLoading = false;
          });
        } catch (e) {
          setState(() {
            errorMessage = 'Erro ao processar os dados do usuário.';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Sessão expirada. Por favor, faça login novamente.';
          isLoading = false;
          accessToken = null;
        });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('access_token');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erro de rede. Tente novamente mais tarde.';
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    setState(() {
      accessToken = null;
      user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (accessToken == null) {
      return const AuthPage();
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _logout();
              },
              child: const Text('Fazer Login'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: user == null
          ? const Center(child: Text('Nenhum dado de usuário disponível.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informações Básicas do Usuário
                Text(
                  'Nome: ${user!.fullName ?? 'Não fornecido'}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Email: ${user!.email}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'CPF: ${user!.cpf}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                // Lista de Restaurantes
                const Text(
                  'Seus Restaurantes',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                user!.restaurants.isEmpty
                    ? const Text('Você ainda não possui restaurantes.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: user!.restaurants.length,
                        itemBuilder: (context, index) {
                          final restaurant = user!.restaurants[index];
                          return Card(
                            child: ListTile(
                              leading: CachedNetworkImage(
                                imageUrl: restaurant.image.isNotEmpty
                                    ? restaurant.image
                                    : 'https://via.placeholder.com/50',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[200],
                                  child: const Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.restaurant),
                              ),
                              title: Text(restaurant.name),
                              subtitle: Text(restaurant.description),
                              onTap: () {
                                // Ação ao tocar no restaurante
                              },
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 32),
                // Lista de Reservas
                const Text(
                  'Suas Reservas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                user!.books.isEmpty
                    ? const Text('Você ainda não possui reservas.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: user!.books.length,
                        itemBuilder: (context, index) {
                          final book = user!.books[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.book_online),
                              title: Text('Reserva ID: ${book.id}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Restaurante ID: ${book.restaurantId}'),
                                  Text('Pessoas: ${book.peopleQuantity}'),
                                  Text(
                                      'Reservado para: ${book.reservedFor.toLocal()}'),
                                  Text(
                                      'Ativa: ${book.active ? 'Sim' : 'Não'}'),
                                ],
                              ),
                              onTap: () {
                                // Ação ao tocar na reserva
                              },
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 24),
                // Botão de Logout
                Center(
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool showLogin = false;

  void toggleForm() {
    setState(() {
      showLogin = !showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return showLogin
        ? LoginForm(toggleForm: toggleForm)
        : SignupForm(toggleForm: toggleForm);
  }
}

class SignupForm extends StatefulWidget {
  final VoidCallback toggleForm;

  const SignupForm({super.key, required this.toggleForm});

  @override
  _SignupFormState createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _cpfController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = '${MyApp.urlBackend}/api/v1/users/signup';

    final body = jsonEncode({
      'email': _emailController.text,
      'password': _passwordController.text,
      'full_name':
          _fullNameController.text.isEmpty ? null : _fullNameController.text,
      'cpf': _cpfController.text,
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro realizado com sucesso!')),
        );
        widget.toggleForm();
      } else if (response.statusCode == 400) {
        final responseData = jsonDecode(response.body);
        setState(() {
          errorMessage = responseData['detail'] ?? 'Erro desconhecido';
        });
      } else {
        setState(() {
          errorMessage = 'Erro no servidor. Tente novamente mais tarde.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erro de rede. Verifique sua conexão.';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Campo de Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                          .hasMatch(value)) {
                        return 'Por favor, insira um email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // Campo de Senha
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira sua senha';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter pelo menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // Campo de Nome Completo
                  TextFormField(
                    controller: _fullNameController,
                    decoration:
                        const InputDecoration(labelText: 'Nome Completo'),
                  ),
                  const SizedBox(height: 8),
                  // Campo de CPF
                  TextFormField(
                    controller: _cpfController,
                    decoration: const InputDecoration(labelText: 'CPF'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu CPF';
                      }
                      if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                        return 'CPF inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Botão de Registro
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _signup,
                          child: const Text('Registrar'),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.toggleForm,
                    child: const Text('Já tem uma conta? Faça login'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final VoidCallback toggleForm;

  const LoginForm({super.key, required this.toggleForm});

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(); // Email
  final _passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = '${MyApp.urlBackend}/api/v1/login/access-token';

    final body = {
      'username': _usernameController.text,
      'password': _passwordController.text,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String accessToken = responseData['access_token'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);

        setState(() {
          isLoading = false;
        });

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MyHomePage(title: 'MesApp')),
        );
      } else if (response.statusCode == 400) {
        final responseData = jsonDecode(response.body);
        setState(() {
          errorMessage = responseData['detail'] ?? 'Erro desconhecido';
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Erro no servidor. Tente novamente mais tarde.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erro de rede. Verifique sua conexão.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Campo de Email
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                          .hasMatch(value)) {
                        return 'Por favor, insira um email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // Campo de Senha
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira sua senha';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Botão de Login
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _login,
                          child: const Text('Entrar'),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.toggleForm,
                    child: const Text('Não tem uma conta? Registre-se'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

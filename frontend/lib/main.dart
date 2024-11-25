import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Para gerar QR Codes
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final MaterialColor primaryColor = Colors.deepPurple;
  final Color accentColor = Colors.deepPurpleAccent;
  final Color backgroundColor = Colors.white;

  const MyApp({super.key});

  static const String urlBackend = 'http://192.168.0.4:8000';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MesApp',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: primaryColor,
          accentColor: accentColor,
          backgroundColor: backgroundColor,
        ),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            color: Colors.white, // Define a cor do texto do título como branco
            fontSize: 20, // Define o tamanho da fonte, se desejar
            fontWeight: FontWeight.bold, // Outros estilos opcionais
          ),
          iconTheme: IconThemeData(
            color:
                Colors.white, // Define a cor dos ícones no AppBar como branco
          ),
          backgroundColor: Colors
              .deepPurple, // Define a cor de fundo do AppBar, se necessário
          elevation: 0, // Remove a sombra abaixo do AppBar, se preferir
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: const [Locale('pt', 'BR')],
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
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Restaurant> restaurants = [];
  int skip = 0;
  final int limit = 10;
  bool isLoading = false;
  bool hasMore = true;
  bool isInitialLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!isLoading &&
              hasMore &&
              scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
            _fetchRestaurants();
          }
          return false;
        },
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: restaurants.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == restaurants.length) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final restaurant = restaurants[index];
                  return RestaurantCard(
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
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem do Restaurante
            Expanded(
              child: CachedNetworkImage(
                imageUrl: restaurant.image.isNotEmpty
                    ? restaurant.image
                    : 'https://via.placeholder.com/150',
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.restaurant,
                      color: Colors.grey, size: 80),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do Restaurante
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Avaliação e Endereço
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('${restaurant.rating}'),
                      const Spacer(),
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Descrição
                  Text(
                    restaurant.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
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

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  List<Restaurant> restaurants = [];
  bool isLoading = false;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _searchRestaurants(String query) async {
    if (query.isEmpty) {
      setState(() {
        restaurants = [];
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final encodedQuery = Uri.encodeComponent(query);
    final url = '${MyApp.urlBackend}/api/v1/restaurants/search?query=$encodedQuery&skip=0&limit=100';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<dynamic> data = responseData['data'] as List<dynamic>;
        
        setState(() {
          restaurants = data.map((item) => Restaurant.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Erro ao buscar restaurantes. Tente novamente.';
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchRestaurants(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar restaurantes...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),
        Expanded(
          child: isLoading 
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : restaurants.isEmpty
                ? const Center(child: Text(
                  'Nenhum restaurante encontrado. 😅',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    ),
                ))
                : GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: restaurants.length,
                    itemBuilder: (context, index) {
                      return RestaurantCard(
                        restaurant: restaurants[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RestaurantDetailPage(
                                restaurant: restaurants[index],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
        ),
      ],
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
      title: utf8.decode(json['title']?.toString().codeUnits ?? []),
      description: utf8.decode(json['description']?.toString().codeUnits ?? []),
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
      fullName: json['full_name'] != null
          ? utf8.decode(json['full_name'].toString().codeUnits)
          : null,
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
      name: utf8.decode(json['name']?.toString().codeUnits ?? []),
      description: utf8.decode(json['description']?.toString().codeUnits ?? []),
      address: utf8.decode(json['address']?.toString().codeUnits ?? []),
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

// Modelo Charge
class Charge {
  final String txid;
  final Calendario calendario;
  final int revisao;
  final Loc loc;
  final String location;
  final String status;
  final Devedor devedor;
  final Valor valor;
  final String chave;
  final String solicitacaoPagador;
  final String pixCopiaECola;

  Charge({
    required this.txid,
    required this.calendario,
    required this.revisao,
    required this.loc,
    required this.location,
    required this.status,
    required this.devedor,
    required this.valor,
    required this.chave,
    required this.solicitacaoPagador,
    required this.pixCopiaECola,
  });

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      txid: json['txid'] ?? '',
      calendario: Calendario.fromJson(json['calendario']),
      revisao: json['revisao'] ?? 0,
      loc: Loc.fromJson(json['loc']),
      location: json['location'] ?? '',
      status: json['status'] ?? '',
      devedor: Devedor.fromJson(json['devedor']),
      valor: Valor.fromJson(json['valor']),
      chave: json['chave'] ?? '',
      solicitacaoPagador:
          utf8.decode((json['solicitacaoPagador'] ?? '').toString().codeUnits),
      pixCopiaECola:
          utf8.decode((json['pixCopiaECola'] ?? '').toString().codeUnits),
    );
  }
}

class Calendario {
  final String criacao;
  final int expiracao;

  Calendario({required this.criacao, required this.expiracao});

  factory Calendario.fromJson(Map<String, dynamic> json) {
    return Calendario(
      criacao: json['criacao'] ?? '',
      expiracao: json['expiracao'] ?? 0,
    );
  }
}

class Loc {
  final int id;
  final String location;
  final String tipoCob;

  Loc({required this.id, required this.location, required this.tipoCob});

  factory Loc.fromJson(Map<String, dynamic> json) {
    return Loc(
      id: json['id'] ?? 0,
      location: json['location'] ?? '',
      tipoCob: json['tipoCob'] ?? '',
    );
  }
}

class Devedor {
  final String? cnpj;
  final String nome;

  Devedor({this.cnpj, required this.nome});

  factory Devedor.fromJson(Map<String, dynamic> json) {
    return Devedor(
      cnpj: json['cnpj'],
      nome: json['nome'] ?? '',
    );
  }
}

class Valor {
  final String original;

  Valor({required this.original});

  factory Valor.fromJson(Map<String, dynamic> json) {
    return Valor(
      original: json['original'] ?? '',
    );
  }
}

// Modelo Payment
class Payment {
  final String bookId;
  final String ownerId;
  final String paymentType;
  final String id;
  final double value;
  final String status;
  final DateTime createdAt;
  final Charge? charge;

  Payment({
    required this.bookId,
    required this.ownerId,
    required this.paymentType,
    required this.id,
    required this.value,
    required this.status,
    required this.createdAt,
    this.charge,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      bookId: json['book_id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      paymentType:
          utf8.decode((json['payment_type'] ?? '').toString().codeUnits),
      id: json['id'] ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      status: utf8.decode((json['status'] ?? '').toString().codeUnits),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      charge: json['charge'] != null ? Charge.fromJson(json['charge']) : null,
    );
  }
}

class RestaurantDetailPage extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailPage({super.key, required this.restaurant});

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

  void _onReserveButtonPressed() {
    if (accessToken != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingPage(restaurantId: widget.restaurant.id),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color.fromARGB(255, 183, 58, 58);

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erro'),
          backgroundColor: primaryColor,
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
      extendBodyBehindAppBar: true, // Permite que o corpo fique atrás da AppBar
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Transparente para sobrepor a imagem
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Ícones brancos
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem de Capa
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: restaurant.image.isNotEmpty
                      ? restaurant.image
                      : 'https://via.placeholder.com/600x400',
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant,
                        color: Colors.grey, size: 100),
                  ),
                ),
                // Gradiente para melhorar a legibilidade do texto
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                // Informações do Restaurante na Imagem
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    restaurant.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Informações Básicas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avaliação e Tipo de Culinária
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${restaurant.rating}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 16),
                      // Tipo de Culinária (se disponível)
                      if (restaurant.description.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.restaurant_menu, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              restaurant.description,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Endereço
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Telefone
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.phone,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Botão de Reserva
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onReserveButtonPressed,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Reserve Agora'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Galeria de Pratos
                  const Text(
                    'Conheça nossos pratos',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  restaurant.items.isEmpty
                      ? const Text('Nenhum item disponível.')
                      : SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: restaurant.items.length,
                            itemBuilder: (context, index) {
                              final item = restaurant.items[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: DishCard(item: item),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 24),
                  // Descrição Detalhada
                  const Text(
                    'Sobre o Restaurante',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DishCard extends StatelessWidget {
  final Item item;

  const DishCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Ação ao tocar no prato (pode exibir detalhes do prato)
      },
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem do Prato
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: item.image.isNotEmpty
                    ? item.image
                    : 'https://via.placeholder.com/150',
                width: 160,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 160,
                  height: 120,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 160,
                  height: 120,
                  color: Colors.grey[300],
                  child:
                      const Icon(Icons.fastfood, color: Colors.grey, size: 50),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Nome do Prato
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // Descrição do Prato
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ],
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
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class BookingPage extends StatefulWidget {
  final String restaurantId;

  const BookingPage({super.key, required this.restaurantId});

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  int _peopleQuantity = 2;
  DateTime? _reservedFor;
  bool isLoading = false;
  String? errorMessage;
  Restaurant? restaurantDetails;
  String? accessToken;
  TextEditingController _dateTimeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
    _fetchRestaurantDetails();
    _dateTimeController = TextEditingController();
  }

  @override
  void dispose() {
    _dateTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      accessToken = prefs.getString('access_token');
    });
  }

  Future<void> _fetchRestaurantDetails() async {
    final url = '${MyApp.urlBackend}/api/v1/restaurants/${widget.restaurantId}';

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
        });
      } else {
        setState(() {
          errorMessage = 'Erro ao carregar detalhes do restaurante.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erro de rede. Verifique sua conexão.';
      });
    }
  }

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

    const url = '${MyApp.urlBackend}/api/v1/books/';

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
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        setState(() {
          // errorMessage = 'Erro ao fazer a reserva. Tente novamente.';
          // use error message instead:
          errorMessage = response.statusCode == 400
              ? utf8.decode(
                  jsonDecode(response.body)['detail'].toString().codeUnits)
              : 'Erro ao fazer a reserva. Tente novamente.';
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
      locale: const Locale('pt', 'BR'),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 19, minute: 0),
        // use 24h format:
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
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
          _dateTimeController.text =
              DateFormat('dd/MM/yyyy HH:mm').format(_reservedFor!);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (restaurantDetails == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Imagem de Fundo
          CachedNetworkImage(
            imageUrl: restaurantDetails!.image.isNotEmpty
                ? restaurantDetails!.image
                : 'https://via.placeholder.com/600x800',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[300],
              child:
                  const Icon(Icons.restaurant, color: Colors.grey, size: 100),
            ),
          ),
          // Gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Conteúdo
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do Restaurante
                  Text(
                    'Reservar uma mesa em ${restaurantDetails!.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Formulário de Reserva
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Seleção de Data e Hora
                          GestureDetector(
                            onTap: _selectDateTime,
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _dateTimeController,
                                decoration: const InputDecoration(
                                  labelText: 'Data e Hora',
                                  prefixIcon:
                                      Icon(Icons.calendar_today_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                readOnly: true,
                                onTap: _selectDateTime,
                                validator: (value) {
                                  if (_reservedFor == null) {
                                    return 'Por favor, selecione a data e hora.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Seleção de Quantidade de Pessoas
                          TextFormField(
                            initialValue: _peopleQuantity.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Quantidade de Pessoas',
                              prefixIcon: Icon(Icons.people_outline),
                              border: OutlineInputBorder(),
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
                          // Mensagem de Erro
                          if (errorMessage != null)
                            Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          const SizedBox(height: 16),
                          // Botão de Confirmar Reserva
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submitBooking,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontSize: 18),
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text('Confirmar Reserva'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  final Book book;

  const PaymentPage({super.key, required this.book});

  @override
  PaymentPageState createState() => PaymentPageState();
}

class PaymentPageState extends State<PaymentPage>
    with SingleTickerProviderStateMixin {
  Payment? payment;
  bool isLoading = true;
  String? errorMessage;
  String? accessToken;

  // Timer
  Timer? _timer;
  int _secondsRemaining = 0;

  // Controlador de animação para efeitos visuais
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadAccessToken();

    // Inicializa o controlador de animação
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancela o timer se não for nulo
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      accessToken = prefs.getString('access_token');
    });
    _createPayment();
  }

  Future<void> _createPayment() async {
    setState(() {
      isLoading = true;
      _secondsRemaining = 0;
      errorMessage = null;
    });

    if (accessToken == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthPage()),
      );
      return;
    }

    const url = '${MyApp.urlBackend}/api/v1/payments/';

    final body = jsonEncode({
      'book_id': widget.book.id,
      'owner_id': widget.book.ownerId,
      'payment_type': 'pix',
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        Payment newPayment = Payment.fromJson(responseData);

        setState(() {
          payment = newPayment;
          isLoading = false;
          _startTimer();
          _animationController.forward(); // Inicia a animação
        });
      } else {
        setState(() {
          errorMessage = 'Erro ao criar pagamento. Tente novamente.';
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

  void _startTimer() {
    if (payment?.charge?.calendario.expiracao != null) {
      DateTime creationTime =
          DateTime.parse(payment!.charge!.calendario.criacao);
      int expirationSeconds = payment!.charge!.calendario.expiracao;

      DateTime expirationTime =
          creationTime.add(Duration(seconds: expirationSeconds));
      _secondsRemaining = expirationTime.difference(DateTime.now()).inSeconds;

      if (_secondsRemaining <= 0) {
        setState(() {
          _secondsRemaining = 0;
        });
        return;
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          setState(() {
            _secondsRemaining--;
          });
        } else {
          timer.cancel();
          setState(() {
            _secondsRemaining = 0;
            // Aqui podemos atualizar a UI para refletir que o QR Code expirou
          });
        }
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _checkPaymentStatus() async {
    if (payment == null) return;

    final url = '${MyApp.urlBackend}/api/v1/payments/${payment!.id}';

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
        final status = responseData['status'];

        if (status == 'cancelled') {
          // Tempo esgotado para criar nova chave
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Pagamento cancelado. Por favor, gere um novo QRCode.')),
          );
        } else if (status == 'paid') {
          // Liberar usuário
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Pagamento confirmado! Sua reserva foi agendada.')),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (status == 'pending') {
          // Status pendente, manter o usuário na página
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Pagamento ainda pendente. Aguarde a confirmação.')),
          );
        } else if (status == 'failed') {
          // Mostrar mensagem para contato com suporte
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Falha no pagamento'),
              content: const Text(
                  'Entre em contato com o suporte para resolver o problema.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Status desconhecido
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Status de pagamento desconhecido. Tente novamente.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao verificar status do pagamento.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro de rede. Tente novamente mais tarde.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Paleta de cores personalizada
    const Color primaryColor = Colors.deepPurple;
    const Color accentColor = Colors.deepPurpleAccent;
    const Color backgroundColor = Colors.white;

    if (isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Pagamento'),
          backgroundColor: primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null || payment == null || payment!.charge == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Pagamento'),
          backgroundColor: primaryColor,
        ),
        body: Center(
          child: Text(
            errorMessage ?? 'Erro desconhecido.',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final charge = payment!.charge!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Pagamento via Pix'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Título
            Text(
              'Confirme sua reserva com uma taxa de R\$${charge.valor.original}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Escaneie o QR Code ou copie o código abaixo',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Timer
            if (_secondsRemaining > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Expira em: ${_formatDuration(_secondsRemaining)}',
                  style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 24),
            // QR Code com estilo personalizado e animação
            Stack(
              alignment: Alignment.center,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOutBack,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[300]!,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: charge.pixCopiaECola,
                      version: QrVersions.auto,
                      size: 250.0,
                      gapless: false,
                      // Logo centralizado no QR Code
                      embeddedImage: const AssetImage(
                          'assets/logo-center-qrcode.png'), // Certifique-se de ter esse asset
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(55, 55),
                      ),
                    ),
                  ),
                ),
                // Efeito de desfoque quando o tempo expira
                if (_secondsRemaining == 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock_outline,
                            color: Color.fromARGB(255, 0, 0, 0),
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Botão para copiar código ou gerar novo QR Code
            ElevatedButton.icon(
              onPressed: _secondsRemaining > 0
                  ? () {
                      Clipboard.setData(
                          ClipboardData(text: charge.pixCopiaECola));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Código copiado para a área de transferência'),
                        ),
                      );
                    }
                  : () {
                      // Gerar novo QR Code
                      _createPayment();
                    },
              icon: Icon(_secondsRemaining > 0 ? Icons.copy : Icons.refresh),
              label: Text(_secondsRemaining > 0
                  ? 'Copiar código Pix'
                  : 'Gerar novo QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 5,
                shadowColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            // Código Copia e Cola ou mensagem quando expirado
            Expanded(
              child: SingleChildScrollView(
                child: _secondsRemaining > 0
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          charge.pixCopiaECola,
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Text(
                        'O tempo para o pagamento expirou. Por favor, gere um novo QR Code.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
            const SizedBox(height: 24),
            // Instruções adicionais
            Text(
              'Após o pagamento, a confirmação será automática.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Botão para verificar o status do pagamento
            ElevatedButton(
              onPressed: _checkPaymentStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 5,
                shadowColor: Colors.grey[50],
              ),
              child: const Text('Já paguei'),
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

  // Mapa para armazenar nomes de restaurantes com base no ID
  Map<String, String> restaurantNames = {};

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndFetchProfile();
  }

  Future<void> _loadAccessTokenAndFetchProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');

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

    const url = '${MyApp.urlBackend}/api/v1/users/me';

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
          });
          // Após obter o usuário, busque os nomes dos restaurantes das reservas futuras
          await _fetchRestaurantNamesForBookings();
          setState(() {
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

  Future<void> _fetchRestaurantNamesForBookings() async {
    if (user == null || user!.books.isEmpty) return;

    // Filtrar reservas futuras
    List<Book> futureBookings = user!.books
        .where((book) => book.reservedFor.isAfter(DateTime.now()))
        .toList();

    // Obter IDs únicos dos restaurantes das reservas futuras
    Set<String> restaurantIds =
        futureBookings.map((book) => book.restaurantId).toSet();

    for (String restaurantId in restaurantIds) {
      final url = '${MyApp.urlBackend}/api/v1/restaurants/$restaurantId';

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
          Restaurant restaurant = Restaurant.fromJson(responseData);
          restaurantNames[restaurantId] = restaurant.name;
        } else {
          restaurantNames[restaurantId] = 'Restaurante Desconhecido';
        }
      } catch (e) {
        restaurantNames[restaurantId] = 'Restaurante Desconhecido';
      }
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

    // Extrair o primeiro nome
    String firstName = user!.fullName != null && user!.fullName!.isNotEmpty
        ? user!.fullName!.split(' ')[0]
        : 'Usuário';

    // Filtrar reservas futuras
    List<Book> futureBookings = user!.books
        .where((book) => book.reservedFor.isAfter(DateTime.now()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: user == null
          ? const Center(child: Text('Nenhum dado de usuário disponível.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Saudação Simplificada
                Text(
                  'Olá, $firstName!',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                // Lista de Reservas Futuras
                const Text(
                  'Suas Próximas Reservas',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                futureBookings.isEmpty
                  ? const Text('Você não possui reservas futuras.')
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: futureBookings.length,
                    itemBuilder: (context, index) {
                      final book = futureBookings[index];
                      String restaurantName =
                        restaurantNames[book.restaurantId] ??
                          'Restaurante';

                      // Formatar data e hora
                      String formattedDate = DateFormat('dd/MM/yyyy')
                        .format(book.reservedFor.toLocal());
                      String formattedTime = DateFormat('HH:mm')
                        .format(book.reservedFor.toLocal());

                      return Card(
                      child: ListTile(
                        leading: const Icon(Icons.restaurant_menu),
                        title: Text('Reserva no $restaurantName'),
                        subtitle: Text(
                          'Às $formattedTime, dia $formattedDate, para ${book.peopleQuantity} pessoa(s)'),
                        trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: book.active ? Colors.green[100] : Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          book.active ? 'Confirmada' : 'Pendente',
                          style: TextStyle(
                          color: book.active ? Colors.green[900] : Colors.orange[900],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          ),
                        ),
                        ),
                        onTap: () {
                        // Ação ao tocar na reserva
                        },
                      ),
                      );
                    },
                    ),
                const SizedBox(height: 32),
                // Lista de Restaurantes
                const Text(
                  'Seus Restaurantes',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                user!.restaurants.isEmpty
                    ? const Text('Você não possui restaurantes.')
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
        ? SignupForm(toggleForm: toggleForm)
        : LoginForm(toggleForm: toggleForm);
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

    const url = '${MyApp.urlBackend}/api/v1/users/signup';

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
        if (!mounted) return;
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
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
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
  LoginFormState createState() => LoginFormState();
}

class LoginFormState extends State<LoginForm> {
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

    const url = '${MyApp.urlBackend}/api/v1/login/access-token';

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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String accessToken = responseData['access_token'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);

        setState(() {
          isLoading = false;
        });

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const MyHomePage(title: 'MesApp')),
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
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
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

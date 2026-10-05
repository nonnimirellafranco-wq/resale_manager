import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
void main() {
  runApp(const ResaleManagerApp());
}

class ResaleManagerApp extends StatelessWidget {
  const ResaleManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Resale Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff5f6fa),
      ),
      home: const MainScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELLO OGGETTO
// -----------------------------------------------------------------------------
class SellingPlatform {
  String platform;
  double askingPrice;
  String status;
  String logoPath;

  SellingPlatform({
    required this.platform,
    required this.askingPrice,
    this.status = 'Attivo',
    this.logoPath = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'askingPrice': askingPrice,
      'status': status,
      'logoPath': logoPath,
    };
  }

  factory SellingPlatform.fromJson(Map<String, dynamic> json) {
    return SellingPlatform(
      platform: json['platform'] ?? '',
      askingPrice: (json['askingPrice'] ?? 0).toDouble(),
      status: json['status'] ?? 'Attivo',
      logoPath: json['logoPath'] ?? '',
    );
  }
}
class ResaleItem {
  String name;
  String category;
  double purchasePrice;
  double extraCosts;
  double salePrice;
  double fees;
  double shipping;
  String status;
  DateTime purchaseDate;
  DateTime? saleDate;
  String platform;
  String purchaseLocation;
  List<String> imagePaths;
  List<SellingPlatform> sellingPlatforms;
  ResaleItem({
    required this.name,
    required this.category,
    required this.purchasePrice,
    this.extraCosts = 0,
    this.salePrice = 0,
    this.fees = 0,
    this.shipping = 0,
    this.status = 'Da mettere in vendita',
    required this.purchaseDate,
    this.saleDate,
    this.platform = '',
    this.purchaseLocation = '',
    this.imagePaths = const [],
    this.sellingPlatforms = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'purchasePrice': purchasePrice,
      'extraCosts': extraCosts,
      'salePrice': salePrice,
      'fees': fees,
      'shipping': shipping,
      'status': status,
      'purchaseDate': purchaseDate.toIso8601String(),
      'saleDate': saleDate?.toIso8601String(),
      'platform': platform,
      'purchaseLocation': purchaseLocation,
      'imagePaths': imagePaths,
      'sellingPlatforms': sellingPlatforms.map((e) => e.toJson()).toList(),
    };
  }

  factory ResaleItem.fromJson(Map<String, dynamic> json) {
    return ResaleItem(
      name: json['name'] ?? '',
      category: json['category'] ?? 'Altro',
      purchasePrice: (json['purchasePrice'] ?? 0).toDouble(),
      extraCosts: (json['extraCosts'] ?? 0).toDouble(),
      salePrice: (json['salePrice'] ?? 0).toDouble(),
      fees: (json['fees'] ?? 0).toDouble(),
      shipping: (json['shipping'] ?? 0).toDouble(),
      status: json['status'] ?? 'Da mettere in vendita',
      purchaseDate: DateTime.parse(json['purchaseDate']),
      saleDate: json['saleDate'] != null
          ? DateTime.parse(json['saleDate'])
          : null,
      platform: json['platform'] ?? '',
      purchaseLocation: json['purchaseLocation'] ?? '',
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
      sellingPlatforms: (json['sellingPlatforms'] as List? ?? [])
          .map(
            (e) => SellingPlatform.fromJson(
          Map<String, dynamic>.from(e),
        ),
      )
          .toList(),
    );
  }

  double get totalCost => purchasePrice + extraCosts;

  double get netSale =>
      salePrice > 0 ? salePrice - fees - shipping : 0;

  double get profit => netSale - totalCost;

  int get daysInInventory =>
      DateTime.now().difference(purchaseDate).inDays;
}
// -----------------------------------------------------------------------------
// OPPORTUNITÀ / LIMBO
// -----------------------------------------------------------------------------

class Opportunity {
  String name;
  String category;
  double askingPrice;
  String source;
  String notes;
  String status;
  DateTime dateAdded;
  List<String> imagePaths;

  Opportunity({
    required this.name,
    required this.category,
    this.askingPrice = 0,
    this.source = '',
    this.notes = '',
    this.status = 'Da valutare',
    required this.dateAdded,
    this.imagePaths = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'askingPrice': askingPrice,
      'source': source,
      'notes': notes,
      'status': status,
      'dateAdded': dateAdded.toIso8601String(),
      'imagePaths': imagePaths,
    };
  }

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    return Opportunity(
      name: json['name'] ?? '',
      category: json['category'] ?? 'Altro',
      askingPrice: (json['askingPrice'] ?? 0).toDouble(),
      source: json['source'] ?? '',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'Da valutare',
      dateAdded: DateTime.parse(json['dateAdded']),
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
    );
  }
}
// -----------------------------------------------------------------------------
// SPESE GENERALI
// -----------------------------------------------------------------------------

class GeneralExpense {
  String description;
  double amount;
  DateTime date;

  GeneralExpense({
    required this.description,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory GeneralExpense.fromJson(Map<String, dynamic> json) {
    return GeneralExpense(
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: DateTime.parse(json['date']),
    );
  }
}

final List<GeneralExpense> generalExpenses = [];

Future<void> saveGeneralExpenses() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/resale_general_expenses.json');

  final data = generalExpenses
      .map((expense) => expense.toJson())
      .toList();

  await file.writeAsString(
    jsonEncode(data),
    flush: true,
  );
}

Future<void> loadGeneralExpenses() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/resale_general_expenses.json');

  if (!await file.exists()) return;

  try {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    if (decoded is! List) return;

    generalExpenses
      ..clear()
      ..addAll(
        decoded.map(
              (entry) => GeneralExpense.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        ),
      );
  } catch (_) {
    // Mantiene le spese vuote se il file non è leggibile.
  }
}
final List<Opportunity> opportunities = [];

Future<void> saveOpportunities() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/resale_opportunities.json');

  final data = opportunities
      .map((opportunity) => opportunity.toJson())
      .toList();

  await file.writeAsString(
    jsonEncode(data),
    flush: true,
  );
}

Future<void> loadOpportunities() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/resale_opportunities.json');

  if (!await file.exists()) return;

  final content = await file.readAsString();
  final decoded = jsonDecode(content) as List;

  opportunities
    ..clear()
    ..addAll(
      decoded.map(
            (entry) => Opportunity.fromJson(
          Map<String, dynamic>.from(entry),
        ),
      ),
    );
}
// -----------------------------------------------------------------------------
// DATI DEMO
// -----------------------------------------------------------------------------

final List<ResaleItem> items = [];
Future<void> saveItems() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/resale_items.json');

  final data = items.map((item) => item.toJson()).toList();

  await file.writeAsString(jsonEncode(data));
}

Future<void> loadItems() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/resale_items.json');

  if (!await file.exists()) return;

  final content = await file.readAsString();
  final decoded = jsonDecode(content) as List;

  items
    ..clear()
    ..addAll(
      decoded.map(
            (entry) => ResaleItem.fromJson(
          Map<String, dynamic>.from(entry),
        ),
      ),
    );
}
// -----------------------------------------------------------------------------
// SCHERMATA PRINCIPALE
// -----------------------------------------------------------------------------

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  String? profilePhoto;
  @override
  void initState() {
    super.initState();
    _loadSavedItems();
    _loadProfilePhoto();
  }

  Future<void> _loadSavedItems() async {
    await loadItems();
    await loadOpportunities();
    await loadGeneralExpenses();
    await loadCategories();
    await loadSellingPlatforms();
    if (!mounted) return;

    setState(() {});
  }
  Future<void> _loadProfilePhoto() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/profile.json');

    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is! Map) return;

      final foto = decoded['fotoProfilo']?.toString() ?? '';

      if (!mounted) return;

      setState(() {
        profilePhoto = foto.isNotEmpty ? foto : null;
      });
    } catch (_) {
      // Mantiene l'icona predefinita se il profilo non è leggibile.
    }
  }
  final List<String> titles = [
    'Dashboard',
    'Opportunità',
    'Acquisti',
    'Inventario',
    'Vendite',
    'Analisi',
  ];

  @override
  Widget build(BuildContext context) {

    final screens = [
      DashboardScreen(onAdd: _addItem),
      OpportunitiesScreen(
        onChanged: () => setState(() {}),
      ),
      PurchasesScreen(
        onAdd: _addItem,
        onChanged: () => setState(() {}),
      ),
      InventoryScreen(
        onChanged: () => setState(() {}),
      ),
      SalesScreen(
        onChanged: () => setState(() {}),
      ),
      AnalysisScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/resale_manager_logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 10),
            const Text(
              'Resale Manager',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
              profilePhoto != null && profilePhoto!.isNotEmpty
                  ? FileImage(File(profilePhoto!))
                  : null,
              child: profilePhoto == null || profilePhoto!.isEmpty
                  ? const Icon(
                Icons.person_outline,
                size: 20,
              )
                  : null,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              if (value == 'profilo') {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                )
                    .then((_) {
                  _loadProfilePhoto();
                });
              }

              if (value == 'backup') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BackupScreen(),
                  ),
                );
              }
              if (value == 'impostazioni') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsListsScreen(),
                  ),
                );
              }
              if (value == 'info') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InfoScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profilo',
                child: Text('Profilo'),
              ),
              PopupMenuItem(
                value: 'impostazioni',
                child: Text('Impostazioni'),
              ),
              PopupMenuItem(
                value: 'backup',
                child: Text('Backup e ripristino'),
              ),
              PopupMenuItem(
                value: 'info',
                child: Text('Informazioni'),
              ),
            ],
          ),
        ],
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: screens[selectedIndex],
      floatingActionButton: selectedIndex == 1
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(
            MaterialPageRoute(
              builder: (_) => const NewPurchaseScreen(),
            ),
          )
              .then((result) {
            if (result is Opportunity) {
              setState(() {});
            }
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuovo acquisto'),
      )
          : selectedIndex == 2 || selectedIndex == 3
          ? FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo acquisto'),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Opportunità',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Acquisti',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.euro_outlined),
            selectedIcon: Icon(Icons.euro),
            label: 'Vendite',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analisi',
          ),
        ],
      ),
    );
  }

  void _addItem() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => const NewPurchaseScreen(),
      ),
    )
        .then((result) {
      if (result is ResaleItem) {
        setState(() {
          items.add(result);
        });

        saveItems();
      } else if (result is Opportunity) {
        setState(() {
          opportunities.add(result);
        });

        saveOpportunities();
      }
    });
  }
}

// -----------------------------------------------------------------------------
// DASHBOARD
// -----------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  final VoidCallback onAdd;

  const DashboardScreen({
    super.key,
    required this.onAdd,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedYear = DateTime.now().year;
  @override
  Widget build(BuildContext context) {
    final yearStart = DateTime(selectedYear, 1, 1);
    final nextYearStart = DateTime(selectedYear + 1, 1, 1);

    final yearPurchases = items.where(
          (item) =>
      !item.purchaseDate.isBefore(yearStart) &&
          item.purchaseDate.isBefore(nextYearStart),
    );

    final yearSales = items.where(
          (item) =>
      item.status == 'Venduto' &&
          item.saleDate != null &&
          !item.saleDate!.isBefore(yearStart) &&
          item.saleDate!.isBefore(nextYearStart),
    );

    final yearPurchaseTotal = yearPurchases.fold<double>(
      0,
          (sum, item) => sum + item.totalCost,
    );

    final yearSalesTotal = yearSales.fold<double>(
      0,
          (sum, item) => sum + item.salePrice,
    );

    final yearFees = yearSales.fold<double>(
      0,
          (sum, item) => sum + item.fees,
    );

    final yearShipping = yearSales.fold<double>(
      0,
          (sum, item) => sum + item.shipping,
    );

    final yearGeneralExpenses = generalExpenses
        .where(
          (expense) =>
      !expense.date.isBefore(yearStart) &&
          expense.date.isBefore(nextYearStart),
    )
        .fold<double>(
      0,
          (sum, expense) => sum + expense.amount,
    );

    final yearResult =
        yearSalesTotal -
            yearPurchaseTotal -
            yearFees -
            yearShipping -
            yearGeneralExpenses;
    final invested = items.fold<double>(
      0,
          (sum, item) => sum + item.totalCost,
    );

    final realizedProfit = items
        .where((item) => item.status == 'Venduto')
        .fold<double>(
      0,
          (sum, item) => sum + item.profit,
    );

    final potentialValue = items
        .where((item) => item.status != 'Venduto')
        .fold<double>(
      0,
          (sum, item) => sum + item.salePrice,
    );

    final oldItems =
    items.where((item) => item.daysInInventory > 60 && item.status != 'Venduto');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          const SizedBox(height: 18),

          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),


          Row(
            children: [
              const Text(
                'Anno:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<int>(
                value: selectedYear,
                items: List.generate(
                  7,
                      (index) {
                    final year = DateTime.now().year - index;

                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text('$year'),
                    );
                  },
                ),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedYear = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Padding(
                padding: EdgeInsets.all(9),
                child: Text(
                  'NUOVO ACQUISTO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          SectionTitle(
            title: 'Riepilogo $selectedYear',
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _AnnualSummaryCard(
                  title: 'Vendite',
                  value: yearSalesTotal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AnnualSummaryCard(
                  title: 'Acquisti',
                  value: yearPurchaseTotal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _AnnualSummaryCard(
                  title: 'Spese generali',
                  value: yearGeneralExpenses,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AnnualSummaryCard(
                  title: 'Commissioni',
                  value: yearFees,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _AnnualSummaryCard(
                  title: 'Spedizioni',
                  value: yearShipping,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AnnualSummaryCard(
                  title: 'RISULTATO',
                  value: yearResult,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 116,
            children: [

              MetricCard(
                title: 'Capitale immobilizzato',
                value: '€ ${items.where((item) => item.status != 'Venduto').fold<double>(
                  0,
                      (sum, item) => sum + item.totalCost,
                ).toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_outlined,
              ),
              MetricCard(
                title: 'Oggetti in stock',
                value: '${items.where((item) => item.status != 'Venduto').length}',
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),



          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('⚠️ Da controllare'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: oldItems.isEmpty
                            ? const Text(
                          'Nessun oggetto critico.\n'
                              'Per ora non risultano articoli fermi da troppo tempo.',
                        )
                            : ListView(
                          shrinkWrap: true,
                          children: oldItems
                              .map(
                                (item) => AlertCard(
                              item: item,
                            ),
                          )
                              .toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CHIUDI'),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.warning_amber_outlined),
              label: Text(
                oldItems.isEmpty
                    ? 'DA CONTROLLARE — NESSUN ELEMENTO'
                    : 'DA CONTROLLARE — ${oldItems.length} ELEMENTI',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GeneralExpensesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Padding(
                padding: EdgeInsets.all(9),
                child: Text(
                  'SPESE GENERALI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );




  }
}
final List<String> purchaseLocations = [
  'eBay',
  'Subito',
  'Mercatino Arcore',
  'Mercatino Bernareggio',
  'Mercatino Monza',
  'Mercatino Busnago',
  'Negozio',
  'Privato',
  'Asta',
  'Altro',
];
final List<String> sellingPlatformNames = [
  'eBay',
  'Subito',
  'Vinted',
  'Wallapop',
  'Chrono24',
  'Facebook Marketplace',
];
final Map<String, String> sellingPlatformLogos = {
  'eBay': 'https://www.ebay.it/favicon.ico',
  'Subito': 'https://www.subito.it/favicon.ico',
  'Vinted': 'https://www.vinted.it/favicon.ico',
  'Wallapop': 'https://es.wallapop.com/favicon.ico',
  'Chrono24':
  'https://www.google.com/s2/favicons?domain=chrono24.com&sz=64',
  'Facebook Marketplace': 'https://www.facebook.com/favicon.ico',
};
final List<String> categories = [];

Future<void> saveCategories() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/resale_categories.json');

  await file.writeAsString(
    jsonEncode(categories),
    flush: true,
  );
}

Future<void> loadCategories() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/resale_categories.json');

  if (!await file.exists()) return;

  try {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    if (decoded is! List) return;

    categories
      ..clear()
      ..addAll(
        decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty),
      );
  } catch (_) {
    // Mantiene le categorie predefinite se il file non è leggibile.
  }
}
// -----------------------------------------------------------------------------
// CREA BACKUP
// -----------------------------------------------------------------------------

Future<File> createBackupZip() async {
  final appDir = await getApplicationDocumentsDirectory();

  final archive = Archive();

  // ---------------------------------------------------------------------------
  // DATI JSON
  // ---------------------------------------------------------------------------

  final jsonFiles = [
    'resale_items.json',
    'resale_opportunities.json',
    'resale_general_expenses.json',
    'resale_categories.json',
    'purchase_locations.json',
    'selling_platforms.json',
    'profile.json',
  ];

  for (final fileName in jsonFiles) {
    final file = File('${appDir.path}/$fileName');

    if (await file.exists()) {
      final bytes = await file.readAsBytes();

      archive.addFile(
        ArchiveFile(
          fileName,
          bytes.length,
          bytes,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // FOTO DEGLI OGGETTI
  // ---------------------------------------------------------------------------

  final imagePaths = <String>{};

  for (final item in items) {
    imagePaths.addAll(item.imagePaths);
  }

  for (final opportunity in opportunities) {
    imagePaths.addAll(opportunity.imagePaths);
  }
  final profileFile = File('${appDir.path}/profile.json');

  if (await profileFile.exists()) {
    try {
      final profileContent = await profileFile.readAsString();
      final profileData = jsonDecode(profileContent);

      if (profileData is Map) {
        final profilePhoto = profileData['fotoProfilo']?.toString() ?? '';

        if (profilePhoto.isNotEmpty) {
          imagePaths.add(profilePhoto);
        }
      }
    } catch (_) {
      // Ignora eventuali errori nella lettura del profilo.
    }
  }
  for (final imagePath in imagePaths) {
    final imageFile = File(imagePath);

    if (!await imageFile.exists()) continue;

    final bytes = await imageFile.readAsBytes();

    archive.addFile(
      ArchiveFile(
        'images/${imageFile.uri.pathSegments.last}',
        bytes.length,
        bytes,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CREAZIONE ZIP
  // ---------------------------------------------------------------------------

  final zipData = ZipEncoder().encode(archive);

  if (zipData == null) {
    throw Exception('Impossibile creare il backup.');
  }

  final backupName =
      'resale_manager_backup_${DateTime.now().millisecondsSinceEpoch}.zip';

  final backupFile = File('${appDir.path}/$backupName');

  await backupFile.writeAsBytes(
    zipData,
    flush: true,
  );

  return backupFile;
}
// -----------------------------------------------------------------------------
// RIPRISTINA BACKUP
// -----------------------------------------------------------------------------

Future<void> restoreBackupZip(File backupFile) async {
  final appDir = await getApplicationDocumentsDirectory();

  final bytes = await backupFile.readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);

  final jsonFileNames = [
    'resale_items.json',
    'resale_opportunities.json',
    'resale_general_expenses.json',
    'resale_categories.json',
    'purchase_locations.json',
    'selling_platforms.json',
    'profile.json',
  ];

  for (final entry in archive) {
    if (!entry.isFile) continue;

    final fileName = entry.name;

    // -------------------------------------------------------------------------
    // FOTO
    // -------------------------------------------------------------------------

    if (fileName.startsWith('images/')) {
      final imageName = fileName.substring('images/'.length);

      if (imageName.isEmpty) continue;

      final imageFile = File('${appDir.path}/$imageName');

      final entryBytes = entry.readBytes();

      if (entryBytes == null) continue;

      await imageFile.writeAsBytes(
        entryBytes.toList(),
        flush: true,
      );

      continue;
    }

    // -------------------------------------------------------------------------
    // DATI JSON
    // -------------------------------------------------------------------------

    if (!jsonFileNames.contains(fileName)) continue;

    final jsonFile = File('${appDir.path}/$fileName');

    final entryBytes = entry.readBytes();

    if (entryBytes == null) continue;

    var content = String.fromCharCodes(entryBytes);

    // Le immagini nel backup vengono salvate nella cartella
    // "images/". Qui aggiorniamo i percorsi presenti nei JSON
    // con il nuovo percorso locale dell'app.
    if (fileName == 'resale_items.json' ||
        fileName == 'resale_opportunities.json') {
      final decoded = jsonDecode(content);

      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;

          final imagePaths = item['imagePaths'];

          if (imagePaths is List) {
            item['imagePaths'] = imagePaths.map((path) {
              final originalPath = path.toString();
              final imageName = originalPath.split('/').last;

              return '${appDir.path}/$imageName';
            }).toList();
          }
        }

        content = jsonEncode(decoded);
      }
    }
    if (fileName == 'profile.json') {
      final decoded = jsonDecode(content);

      if (decoded is Map) {
        final originalPhoto =
            decoded['fotoProfilo']?.toString() ?? '';

        if (originalPhoto.isNotEmpty) {
          final imageName = originalPhoto.split('/').last;

          decoded['fotoProfilo'] =
          '${appDir.path}/$imageName';
        }

        content = jsonEncode(decoded);
      }
    }
    await jsonFile.writeAsString(
      content,
      flush: true,
    );
  }

  // ---------------------------------------------------------------------------
  // RICARICA I DATI NELLE LISTE DELL'APP
  // ---------------------------------------------------------------------------

  await loadItems();
  await loadOpportunities();
  await loadGeneralExpenses();
  await loadCategories();
  await loadPurchaseLocations();
  await loadSellingPlatforms();
}
Future<void> savePurchaseLocations() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/purchase_locations.json');

  await file.writeAsString(
    jsonEncode(purchaseLocations),
    flush: true,
  );
}

Future<void> loadPurchaseLocations() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/purchase_locations.json');

  if (!await file.exists()) return;

  try {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    if (decoded is! List) return;

    purchaseLocations
      ..clear()
      ..addAll(
        decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty),
      );
  } catch (_) {
    // Mantiene i luoghi predefiniti se il file non è leggibile.
  }
}
Future<void> saveSellingPlatforms() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/selling_platforms.json');

  final data = sellingPlatformNames.map((name) {
    return {
      'name': name,
      'logoPath': sellingPlatformLogos[name] ?? '',
    };
  }).toList();

  await file.writeAsString(
    jsonEncode(data),
    flush: true,
  );
}
Future<void> loadSellingPlatforms() async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File('${appDir.path}/selling_platforms.json');

  if (!await file.exists()) return;

  try {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    if (decoded is! List) return;

    sellingPlatformNames.clear();

    for (final entry in decoded) {
      if (entry is String) {
        sellingPlatformNames.add(entry);
      } else if (entry is Map) {
        final name = entry['name']?.toString() ?? '';

        if (name.isEmpty) continue;

        sellingPlatformNames.add(name);

        final logoPath = entry['logoPath']?.toString() ?? '';

        if (logoPath.isNotEmpty) {
          sellingPlatformLogos[name] = logoPath;
        }
      }
    }
  } catch (_) {
    // Mantiene le piattaforme predefinite se il file non è leggibile.
  }
}
// -----------------------------------------------------------------------------
// GESTIONE CATEGORIE E LUOGHI
// -----------------------------------------------------------------------------

class SettingsListsScreen extends StatefulWidget {
  const SettingsListsScreen({super.key});

  @override
  State<SettingsListsScreen> createState() => _SettingsListsScreenState();
}

class _SettingsListsScreenState extends State<SettingsListsScreen> {
  String? _selectedSection;
  Future<void> _addCategory() async {
    String text = '';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nuova categoria'),
          content: TextField(
            autofocus: true,
            onChanged: (value) {
              text = value;
            },
            decoration: const InputDecoration(
              labelText: 'Nome categoria',
              hintText: 'Es. Fotografia',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('ANNULLA'),
            ),
            FilledButton(
              onPressed: () {
                final name = text.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, name);
                }
              },
              child: const Text('AGGIUNGI'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    final name = result.trim();

    if (categories.contains(name)) return;

    setState(() {
      categories.add(name);
    });

    await saveCategories();
  }

  Future<void> _addLocation() async {
    String text = '';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nuovo luogo di acquisto'),
          content: TextField(
            autofocus: true,
            onChanged: (value) {
              text = value;
            },
            decoration: const InputDecoration(
              labelText: 'Nome del luogo',
              hintText: 'Es. Mercatino Seregno',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('ANNULLA'),
            ),
            FilledButton(
              onPressed: () {
                final name = text.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, name);
                }
              },
              child: const Text('AGGIUNGI'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    final name = result.trim();

    if (purchaseLocations.contains(name)) return;

    setState(() {
      purchaseLocations.add(name);
    });

    await savePurchaseLocations();
  }
  Future<void> _addSellingPlatform() async {
    String text = '';
    XFile? logoImage;

    final picker = ImagePicker();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nuova piattaforma di vendita'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (value) {
                      text = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Nome piattaforma',
                      hintText: 'Es. Etsy',
                    ),
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );

                      if (image == null) return;

                      setDialogState(() {
                        logoImage = image;
                      });
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      logoImage == null
                          ? 'SCEGLI LOGO'
                          : 'LOGO SELEZIONATO',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('ANNULLA'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = text.trim();

                    if (name.isNotEmpty) {
                      Navigator.pop(dialogContext, name);
                    }
                  },
                  child: const Text('AGGIUNGI'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    final name = result.trim();

    if (sellingPlatformNames.contains(name)) return;

    if (logoImage != null) {
      final appDir = await getApplicationDocumentsDirectory();

      final extension = logoImage!.path.split('.').last;

      final savedPath =
          '${appDir.path}/platform_logo_${DateTime.now().microsecondsSinceEpoch}.$extension';

      await File(logoImage!.path).copy(savedPath);

      sellingPlatformLogos[name] = savedPath;
    }

    setState(() {
      sellingPlatformNames.add(name);
    });

    await saveSellingPlatforms();
  }
  Future<void> _deleteCategory(String category) async {
    if (category == 'Altro') return;

    setState(() {
      categories.remove(category);
    });

    await saveCategories();
  }

  Future<void> _deleteLocation(String location) async {
    if (location == 'Altro') return;

    setState(() {
      purchaseLocations.remove(location);
    });

    await savePurchaseLocations();
  }

  @override
  void initState() {
    super.initState();

    Future.wait([
      loadCategories(),
      loadPurchaseLocations(),
      loadSellingPlatforms(),
    ]).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMainMenu = _selectedSection == null;

    String title = 'Impostazioni';

    if (_selectedSection == 'categorie') {
      title = 'Categorie';
    } else if (_selectedSection == 'luoghi') {
      title = 'Luoghi di acquisto';
    } else if (_selectedSection == 'piattaforme') {
      title = 'Piattaforme di vendita';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: isMainMenu
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedSection = null;
            });
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isMainMenu) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text(
                  'Categorie',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Gestisci le categorie degli oggetti',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedSection = 'categorie';
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text(
                  'Luoghi di acquisto',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Gestisci i luoghi dove acquisti',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedSection = 'luoghi';
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text(
                  'Piattaforme di vendita',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Gestisci le piattaforme dove vendi',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedSection = 'piattaforme';
                  });
                },
              ),
            ),
          ],

          if (_selectedSection == 'categorie') ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Categorie',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('NUOVA'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: categories.map((category) {
                  return ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(category),
                    trailing: category == 'Altro'
                        ? null
                        : IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      onPressed: () {
                        _deleteCategory(category);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (_selectedSection == 'luoghi') ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Luoghi di acquisto',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addLocation,
                  icon: const Icon(Icons.add),
                  label: const Text('NUOVO'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: purchaseLocations.map((location) {
                  return ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                    ),
                    title: Text(location),
                    trailing: location == 'Altro'
                        ? null
                        : IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      onPressed: () {
                        _deleteLocation(location);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (_selectedSection == 'piattaforme') ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Piattaforme di vendita',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addSellingPlatform,
                  icon: const Icon(Icons.add),
                  label: const Text('NUOVA'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: sellingPlatformNames.map((platform) {
                  final logoPath =
                      sellingPlatformLogos[platform] ?? '';

                  return ListTile(
                    leading: logoPath.isEmpty
                        ? const Icon(
                      Icons.storefront_outlined,
                    )
                        : logoPath.startsWith('http')
                        ? Image.network(
                      logoPath,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) {
                        return const Icon(
                          Icons.storefront_outlined,
                        );
                      },
                    )
                        : Image.file(
                      File(logoPath),
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) {
                        return const Icon(
                          Icons.storefront_outlined,
                        );
                      },
                    ),
                    title: Text(platform),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      onPressed: () {
                        setState(() {
                          sellingPlatformNames.remove(platform);
                        });
                        saveSellingPlatforms();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SPESE GENERALI - SCHERMATA
// -----------------------------------------------------------------------------

class GeneralExpensesScreen extends StatefulWidget {
  const GeneralExpensesScreen({super.key});

  @override
  State<GeneralExpensesScreen> createState() =>
      _GeneralExpensesScreenState();
}

class _GeneralExpensesScreenState extends State<GeneralExpensesScreen> {
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = [...generalExpenses]
      ..sort((a, b) => b.date.compareTo(a.date));

    final total = expenses.fold<double>(
      0,
          (sum, expense) => sum + expense.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spese generali'),
      ),
      body: expenses.isEmpty
          ? const Center(
        child: Text('Nessuna spesa generale registrata.'),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text(
                    'Totale spese',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '€ ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...expenses.map(
                (expense) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.inventory_2_outlined,
                ),
                title: Text(expense.description),
                subtitle: Text(
                  '${expense.date.day.toString().padLeft(2, '0')}/'
                      '${expense.date.month.toString().padLeft(2, '0')}/'
                      '${expense.date.year}',
                ),
                trailing: Text(
                  '€ ${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Nuova spesa'),
      ),
    );
  }

  Future<void> _addExpense() async {
    descriptionController.clear();
    amountController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nuova spesa generale'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  hintText: 'Es. Scotch e pluriball',
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Importo',
                  prefixText: '€ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('ANNULLA'),
            ),
            FilledButton(
              onPressed: () async {
                final description =
                descriptionController.text.trim();

                final amount = double.tryParse(
                  amountController.text.replaceAll(',', '.'),
                );

                if (description.isEmpty ||
                    amount == null ||
                    amount <= 0) {
                  return;
                }

                generalExpenses.add(
                  GeneralExpense(
                    description: description,
                    amount: amount,
                    date: DateTime.now(),
                  ),
                );

                await saveGeneralExpenses();

                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext, true);
              },
              child: const Text('SALVA'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }
}
// -----------------------------------------------------------------------------
// NUOVO ACQUISTO
// -----------------------------------------------------------------------------

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  XFile? selectedImage;
  List<XFile> selectedImages = [];

  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final extraController = TextEditingController();
  final purchaseLocationController = TextEditingController();

  String? category;
  String tipo = 'Acquisto';

  @override
  void initState() {
    super.initState();
    _loadPurchaseLocations();
  }

  Future<void> _loadPurchaseLocations() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/purchase_locations.json');

    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is! List) return;

      purchaseLocations
        ..clear()
        ..addAll(
          decoded.map((e) => e.toString()).where((e) => e.isNotEmpty),
        );

      if (!mounted) return;

      setState(() {});
    } catch (_) {
      // Mantiene i luoghi già presenti se il file non è leggibile.
    }
  }

  Future<void> _savePurchaseLocations() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/purchase_locations.json');

    await file.writeAsString(
      jsonEncode(purchaseLocations),
      flush: true,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    extraController.dispose();
    purchaseLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo acquisto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () async {
                final ImagePicker picker = ImagePicker();

                final image = await picker.pickImage(
                  source: ImageSource.camera,
                );

                if (image != null) {
                  setState(() {
                    selectedImages.add(image);
                    selectedImage = image;
                  });
                }
              },
              child: Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.indigo.shade100,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    selectedImages.isNotEmpty
                        ? SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Image.file(
                              File(selectedImages[index].path),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) {
                                return const SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    )
                        : const Icon(
                      Icons.camera_alt_outlined,
                      size: 55,
                      color: Colors.indigo,
                    ),
                    if (selectedImage == null) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Scatta una foto dell’oggetto',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'L’assistente potrà identificarlo e stimarne il valore',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();

                  final images = await picker.pickMultiImage();

                  if (images.isNotEmpty) {
                    setState(() {
                      selectedImages.addAll(images);
                      selectedImage = selectedImages.last;
                    });
                  }
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('IMPORTA DALLA GALLERIA'),
              ),
            ),

            const SizedBox(height: 25),
            DropdownButtonFormField<String>(
              initialValue: tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                prefixIcon: Icon(Icons.swap_vert),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'Acquisto',
                  child: Text('Acquisto'),
                ),

                    DropdownMenuItem<String>(
                      value: 'Da valutare',
                      child: Text('Opportunità'),
                    ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  tipo = value;
                });
              },
            ),

            const SizedBox(height: 15),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
                hintText: 'Es. Orient Mako XL',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            // LUOGO DI ACQUISTO
            Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                  purchaseLocations.contains(
                    purchaseLocationController.text,
                  )
                      ? purchaseLocationController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Luogo di acquisto',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: purchaseLocations.map((location) {
                    return DropdownMenuItem<String>(
                      value: location,
                      child: Text(location),
                    );
                  }).toList(),
                  onChanged: (value) {
                    purchaseLocationController.text = value ?? '';
                    setState(() {});
                  },
                ),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      String newLocationText = '';

                      final newLocation = await showDialog<String>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text(
                              'Nuovo luogo di acquisto',
                            ),
                            content: TextField(
                              autofocus: true,
                              onChanged: (value) {
                                newLocationText = value;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Nome del luogo',
                                hintText: 'Es. Mercatino Seregno',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: const Text('ANNULLA'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  final name =
                                  newLocationText.trim();

                                  if (name.isNotEmpty) {
                                    Navigator.pop(
                                      dialogContext,
                                      name,
                                    );
                                  }
                                },
                                child: const Text('AGGIUNGI'),
                              ),
                            ],
                          );
                        },
                      );

                      if (!mounted) return;

                      if (newLocation != null &&
                          newLocation.isNotEmpty) {
                        if (!purchaseLocations.contains(newLocation)) {
                          purchaseLocations.add(newLocation);
                          await _savePurchaseLocations();
                        }

                        await Future<void>.delayed(Duration.zero);

                        if (!mounted) return;

                        setState(() {
                          purchaseLocationController.text = newLocation;
                        });


                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nuovo luogo'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // CATEGORIA
            DropdownButtonFormField<String>(
              initialValue:
              categories.contains(category) ? category : null,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: categories.map((categoryName) {
                return DropdownMenuItem<String>(
                  value: categoryName,
                  child: Text(categoryName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  category = value;
                });
              },
            ),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final controller = TextEditingController();

                  final newCategory = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: const Text('Nuova categoria'),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Nome categoria',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('ANNULLA'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final value =
                              controller.text.trim();

                              if (value.isNotEmpty) {
                                Navigator.pop(
                                  dialogContext,
                                  value,
                                );
                              }
                            },
                            child: const Text('AGGIUNGI'),
                          ),
                        ],
                      );
                    },
                  );

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    controller.dispose();
                  });

                  if (!context.mounted) return;

                  if (newCategory != null &&
                      newCategory.isNotEmpty) {
                    if (!categories.contains(newCategory)) {
                      categories.add(newCategory);
                      await saveCategories();
                    }

                    await Future<void>.delayed(Duration.zero);

                    if (!context.mounted) return;

                    setState(() {
                      category = newCategory;
                    });
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuova categoria'),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: priceController,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Prezzo',
                prefixText: '€ ',
                prefixIcon: Icon(Icons.euro),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: extraController,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Costi extra iniziali',
                hintText: 'Riparazione, batteria, pulizia...',
                prefixText: '€ ',
                prefixIcon: Icon(Icons.build_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Puoi fotografare l’oggetto e aggiungere le foto alla scheda '
                          'per conservarne una documentazione completa.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    tipo == 'Da valutare' ? 'SALVA OPPORTUNITÀ' : 'SALVA ACQUISTO',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = nameController.text.trim();

    if (name.isEmpty ||
        priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Inserisci almeno descrizione e prezzo.',
          ),
        ),
      );
      return;
    }

    final purchasePrice =
        double.tryParse(
          priceController.text.replaceAll(',', '.'),
        ) ??
            0;

    final extra =
        double.tryParse(
          extraController.text.replaceAll(',', '.'),
        ) ??
            0;

    final appDir =
    await getApplicationDocumentsDirectory();

    final savedImagePaths = <String>[];

    for (var i = 0; i < selectedImages.length; i++) {
      final image = selectedImages[i];
      final extension = image.path.split('.').last;

      final savedPath =
          '${appDir.path}/photo_${DateTime.now().microsecondsSinceEpoch}_$i.$extension';

      await File(image.path).copy(savedPath);
      savedImagePaths.add(savedPath);
    }
    if (tipo == 'Da valutare') {
      final opportunity = Opportunity(
        name: nameController.text.trim(),
        category: category ?? '',
        askingPrice: double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
        source: purchaseLocationController.text.trim(),

        status: 'Da valutare',
        dateAdded: DateTime.now(),

      );

      if (!mounted) return;
      Navigator.of(context).pop(opportunity);
      return;
    }
    final item = ResaleItem(
      name: name,
      category: category ?? '',
      purchaseLocation:
      purchaseLocationController.text,
      imagePaths: savedImagePaths,
      purchasePrice: purchasePrice,
      extraCosts: extra,
      purchaseDate: DateTime.now(),
    );

    if (!mounted) return;

    Navigator.of(context).pop(item);
  }
}


// -----------------------------------------------------------------------------
// OPPORTUNITÀ
// -----------------------------------------------------------------------------

class OpportunitiesScreen extends StatelessWidget {
  final VoidCallback? onChanged;

  const OpportunitiesScreen({
    super.key,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Opportunità',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${opportunities.length} oggetti da valutare',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),

        if (opportunities.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(
                    Icons.search_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Nessuna opportunità',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Qui compariranno gli oggetti interessanti\n'
                        'che non hai ancora acquistato.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

        ...opportunities.map(
              (opportunity) => _OpportunityCard(
            opportunity: opportunity,
            onChanged: onChanged,
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SCHEDA OPPORTUNITÀ
// -----------------------------------------------------------------------------

class _OpportunityCard extends StatelessWidget {
  final Opportunity opportunity;
  final VoidCallback? onChanged;

  const _OpportunityCard({
    required this.opportunity,
    this.onChanged,
  });
  Future<void> _showEditOpportunityDialog(BuildContext context) async {
    final nameController = TextEditingController(
      text: opportunity.name,
    );

    final askingPriceController = TextEditingController(
      text: opportunity.askingPrice > 0
          ? opportunity.askingPrice.toString()
          : '',
    );

    final notesController = TextEditingController(
      text: opportunity.notes,
    );

    String editedCategory = opportunity.category;

    String editedSource = opportunity.source;

    final ImagePicker picker = ImagePicker();
    final List<XFile> newImages = [];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifica opportunità'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: categories.contains(editedCategory)
                          ? editedCategory
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        ...categories.toSet().map(
                              (categoryName) => DropdownMenuItem<String>(
                            value: categoryName,
                            child: Text(categoryName),
                          ),
                        ),

                      ],
                      onChanged: (value) async {
                        if (value == null) return;

                        if (value == '__NUOVA_CATEGORIA__') {
                          final controller = TextEditingController();

                          final newCategory = await showDialog<String>(
                            context: context,
                            builder: (categoryDialogContext) {
                              return AlertDialog(
                                title: const Text('Nuova categoria'),
                                content: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome categoria',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(categoryDialogContext);
                                    },
                                    child: const Text('ANNULLA'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      final value = controller.text.trim();

                                      if (value.isEmpty) return;

                                      Navigator.pop(
                                        categoryDialogContext,
                                        value,
                                      );
                                    },
                                    child: const Text('AGGIUNGI'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (newCategory == null || newCategory.isEmpty) {
                            controller.dispose();
                            return;
                          }

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.dispose();
                          });

                          if (!categories.contains(newCategory)) {
                            categories.add(newCategory);
                            await saveCategories();
                          }

                          setDialogState(() {
                            editedCategory = newCategory;
                          });

                          return;
                        }

                        setDialogState(() {
                          editedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: askingPriceController,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prezzo richiesto',
                        prefixText: '€ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue:
                      purchaseLocations.contains(editedSource)
                          ? editedSource
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Dove l’hai trovato?',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        ...purchaseLocations.map(
                              (location) => DropdownMenuItem<String>(
                            value: location,
                            child: Text(location),
                          ),
                        ),

                      ],
                      onChanged: (value) async {
                        if (value == null) return;

                        if (value == '__NUOVO_LUOGO__') {
                          final controller =
                          TextEditingController();

                          final newLocation =
                          await showDialog<String>(
                            context: context,
                            builder: (locationDialogContext) {
                              return AlertDialog(
                                title: const Text('Nuovo luogo'),
                                content: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome del luogo',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(
                                        locationDialogContext,
                                      );
                                    },
                                    child: const Text('ANNULLA'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      final value =
                                      controller.text.trim();

                                      if (value.isEmpty) return;

                                      Navigator.pop(
                                        locationDialogContext,
                                        value,
                                      );
                                    },
                                    child: const Text('AGGIUNGI'),
                                  ),
                                ],
                              );
                            },
                          );

                          controller.dispose();

                          if (newLocation == null ||
                              newLocation.isEmpty) {
                            return;
                          }

                          if (!purchaseLocations
                              .contains(newLocation)) {
                            purchaseLocations.add(newLocation);
                            final appDir = await getApplicationDocumentsDirectory();
                            final file = File('${appDir.path}/purchase_locations.json');

                            await file.writeAsString(
                              jsonEncode(purchaseLocations),
                              flush: true,
                            );
                          }

                          setDialogState(() {
                            editedSource = newLocation;
                          });

                          return;
                        }

                        setDialogState(() {
                          editedSource = value;
                        });
                      },
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Foto',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (opportunity.imagePaths.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Foto presenti',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (newImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: newImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding:
                              const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius:
                                BorderRadius.circular(8),
                                child: Image.file(
                                  File(newImages[index].path),
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final image =
                              await picker.pickImage(
                                source: ImageSource.camera,
                              );

                              if (image == null) return;

                              setDialogState(() {
                                newImages.add(image);
                              });
                            },
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                            ),
                            label: const Text('FOTO'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final images =
                              await picker.pickMultiImage();

                              if (images.isEmpty) return;

                              setDialogState(() {
                                newImages.addAll(images);
                              });
                            },
                            icon: const Icon(
                              Icons.photo_library_outlined,
                            ),
                            label: const Text('GALLERIA'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('ANNULLA'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    if (name.isEmpty) return;

                    final askingPrice = double.tryParse(
                      askingPriceController.text
                          .replaceAll(',', '.'),
                    ) ??
                        0;

                    final appDir =
                    await getApplicationDocumentsDirectory();

                    for (var i = 0; i < newImages.length; i++) {
                      final image = newImages[i];
                      final extension =
                          image.path.split('.').last;

                      final savedPath =
                          '${appDir.path}/opportunity_${DateTime.now().microsecondsSinceEpoch}_$i.$extension';

                      await File(image.path).copy(savedPath);
                      opportunity.imagePaths.add(savedPath);
                    }

                    opportunity.name = name;
                    opportunity.category = editedCategory;
                    opportunity.askingPrice = askingPrice;
                    opportunity.source = editedSource;

                    opportunity.notes =
                        notesController.text.trim();

                    if (!dialogContext.mounted) return;

                    await saveOpportunities();

                    if (!context.mounted) return;

                    Navigator.pop(dialogContext);

                    onChanged?.call();

                  },
                  child: const Text('SALVA MODIFICHE'),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      askingPriceController.dispose();
      notesController.dispose();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (opportunity.imagePaths.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: opportunity.imagePaths.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(opportunity.imagePaths[index]),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (opportunity.imagePaths.isNotEmpty)
              const SizedBox(height: 12),

            Text(
              opportunity.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(opportunity.category),
              ],
            ),

            const SizedBox(height: 6),

            if (opportunity.askingPrice > 0)
              Row(
                children: [
                  Icon(
                    Icons.euro,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Prezzo richiesto: € ${opportunity.askingPrice.toStringAsFixed(2)}',
                  ),
                ],
              ),

            if (opportunity.source.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(opportunity.source),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),



            if (opportunity.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  opportunity.notes,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _showEditOpportunityDialog(context);
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text('MODIFICA'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('Scartare opportunità?'),
                            content: Text(
                              'Vuoi eliminare "${opportunity.name}" '
                                  'dal Limbo?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext, false);
                                },
                                child: const Text('ANNULLA'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext, true);
                                },
                                child: const Text(
                                  'SCARTA',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirm != true) return;

                      opportunities.remove(opportunity);
                      await saveOpportunities();

                      onChanged?.call();
                    },
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text(
                        'SCARTA',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final priceController = TextEditingController(
                        text: opportunity.askingPrice > 0
                            ? opportunity.askingPrice.toString()
                            : '',
                      );

                      final purchasePrice = await showDialog<double>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('Acquista oggetto'),
                            content: TextField(
                              controller: priceController,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Prezzo effettivamente pagato',
                                prefixText: '€ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: const Text('ANNULLA'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  final price = double.tryParse(
                                    priceController.text.replaceAll(',', '.'),
                                  );

                                  if (price == null || price < 0) {
                                    return;
                                  }

                                  Navigator.pop(dialogContext, price);
                                },
                                child: const Text(
                                  'ACQUISTA',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        priceController.dispose();
                      });

                      if (purchasePrice == null) return;

                      final item = ResaleItem(
                        name: opportunity.name,
                        category: opportunity.category,
                        purchasePrice: purchasePrice,
                        purchaseDate: DateTime.now(),
                        purchaseLocation: opportunity.source,
                        imagePaths: List<String>.from(
                          opportunity.imagePaths,
                        ),
                      );

                      items.add(item);
                      opportunities.remove(opportunity);

                      await saveItems();
                      await saveOpportunities();



                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Oggetto acquistato e spostato negli Acquisti.',
                          ),
                        ),

                      );
                      onChanged?.call();
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text('ACQUISTA'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// ACQUISTI
// -----------------------------------------------------------------------------

class PurchasesScreen extends StatefulWidget {
  final VoidCallback onAdd;
  final VoidCallback? onChanged;

  const PurchasesScreen({
    super.key,
    required this.onAdd,
    this.onChanged,
  });

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String selectedCategory = 'Tutte';

  @override
  Widget build(BuildContext context) {
    final purchases = items.where(
          (item) =>
      item.status == 'Da mettere in vendita' &&
          (selectedCategory == 'Tutte' ||
              item.category == selectedCategory),
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tutti i tuoi acquisti',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${purchases.length} oggetti registrati',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          initialValue: selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Categoria',
            prefixIcon: Icon(Icons.category_outlined),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: 'Tutte',
              child: Text('Tutte'),
            ),
            ...categories.map((categoryName) {
              return DropdownMenuItem<String>(
                value: categoryName,
                child: Text(categoryName),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedCategory = value;
            });
          },
        ),

        const SizedBox(height: 15),

        ...purchases.map(
              (item) => ItemCard(
            item: item,
                onChanged: widget.onChanged,
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// INVENTARIO
// -----------------------------------------------------------------------------

class InventoryScreen extends StatefulWidget {
  final VoidCallback? onChanged;

  const InventoryScreen({
    super.key,
    this.onChanged,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String selectedCategory = 'Tutte';
  String selectedSellingPlatform = 'Tutte';
  @override
  Widget build(BuildContext context) {
    final active = items.where(
          (item) =>
      item.status == 'In vendita' &&
          (selectedCategory == 'Tutte' ||
              item.category == selectedCategory) &&
          (selectedSellingPlatform == 'Tutte' ||
              item.sellingPlatforms.any(
                    (platform) =>
                platform.platform == selectedSellingPlatform &&
                    platform.status == 'Attivo',
              )),
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Inventario attuale',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${active.length} oggetti ancora da vendere',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          initialValue: selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Categoria',
            prefixIcon: Icon(Icons.category_outlined),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: 'Tutte',
              child: Text('Tutte'),
            ),
            ...categories.map((categoryName) {
              return DropdownMenuItem<String>(
                value: categoryName,
                child: Text(categoryName),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedCategory = value;
            });
          },
        ),
        const SizedBox(height: 15),

        DropdownButtonFormField<String>(
          initialValue: selectedSellingPlatform,
          decoration: const InputDecoration(
            labelText: 'Piattaforma di vendita',
            prefixIcon: Icon(Icons.storefront_outlined),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: 'Tutte',
              child: Text('Tutte'),
            ),
            ...sellingPlatformNames.map((platformName) {
              return DropdownMenuItem<String>(
                value: platformName,
                child: Text(platformName),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedSellingPlatform = value;
            });
          },
        ),
        const SizedBox(height: 15),

        ...active.map(
              (item) => ItemCard(
            item: item,
                onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// VENDITE
// -----------------------------------------------------------------------------

class SalesScreen extends StatefulWidget {
  final VoidCallback? onChanged;

  const SalesScreen({
    super.key,
    this.onChanged,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String selectedCategory = 'Tutte';
  String selectedSellingPlatform = 'Tutte';

  @override
  Widget build(BuildContext context) {    final soldItems = items.where(
        (item) =>
    item.status == 'Venduto' &&
        (selectedCategory == 'Tutte' ||
            item.category == selectedCategory) &&
        (selectedSellingPlatform == 'Tutte' ||
            item.sellingPlatforms.any(
                  (platform) =>
              platform.platform == selectedSellingPlatform &&
                  platform.status == 'Venduto',
            )),
  ).toList();

    final totalProfit = soldItems.fold<double>(
      0,
          (sum, item) => sum + item.profit,
    );

    // Raggruppa le vendite per anno e mese.
    final Map<String, List<ResaleItem>> salesByMonth = {};

    for (final item in soldItems) {
      // Le nuove vendite hanno saleDate.
      // Per eventuali vecchi dati senza saleDate usiamo purchaseDate
      // come fallback, così l'oggetto non scompare dall'archivio.
      final date = item.saleDate ?? item.purchaseDate;

      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';

      salesByMonth.putIfAbsent(key, () => []);
      salesByMonth[key]!.add(item);
    }

    // Mesi più recenti per primi.
    final monthKeys = salesByMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final Map<int, List<String>> salesByYear = {};

    for (final key in monthKeys) {
      final year = int.parse(key.substring(0, 4));
      salesByYear.putIfAbsent(year, () => []);
      salesByYear[year]!.add(key);
    }

    final years = salesByYear.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    const monthNames = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendite'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Riepilogo vendite
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profitto realizzato',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '€${totalProfit.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${soldItems.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'vendute',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: 'Tutte',
                  child: Text('Tutte'),
                ),
                ...categories.map((categoryName) {
                  return DropdownMenuItem<String>(
                    value: categoryName,
                    child: Text(categoryName),
                  );
                }),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: selectedSellingPlatform,
              decoration: const InputDecoration(
                labelText: 'Piattaforma di vendita',
                prefixIcon: Icon(Icons.storefront_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: 'Tutte',
                  child: Text('Tutte'),
                ),
                ...sellingPlatformNames.map((platformName) {
                  return DropdownMenuItem<String>(
                    value: platformName,
                    child: Text(platformName),
                  );
                }),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedSellingPlatform = value;
                });
              },
            ),
            const SizedBox(height: 15),

            const Text(
              'Archivio vendite',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: soldItems.isEmpty
                  ? const InfoCard(
                icon: Icons.sell_outlined,
                title: 'Nessuna vendita',
                text: 'Gli oggetti venduti compariranno qui.',
              )
                  : ListView(
                children: [
                  ...years.map(
                        (year) {
                      final months = salesByYear[year]!;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          initiallyExpanded: year == years.first,
                          title: Text(
                            '$year',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          children: [
                            ...months.asMap().entries.map(
                                  (entry) {
                                final monthIndex = entry.key;
                                final key = entry.value;
                                final monthNumber =
                                int.parse(key.substring(5, 7));
                                final monthItems = salesByMonth[key]!;

                                monthItems.sort(
                                      (a, b) {
                                    final dateA =
                                        a.saleDate ?? a.purchaseDate;
                                    final dateB =
                                        b.saleDate ?? b.purchaseDate;
                                    return dateB.compareTo(dateA);
                                  },
                                );

                                return ExpansionTile(
                                  initiallyExpanded:
                                  year == years.first &&
                                      monthIndex == 0,
                                  title: Text(
                                    '${monthNames[monthNumber - 1]} '
                                        '(${monthItems.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  children: [
                                    ...monthItems.map(
                                          (item) => ItemCard(
                                        item: item,
                                            onChanged: widget.onChanged,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ANALISI
// -----------------------------------------------------------------------------

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int selectedYear = DateTime.now().year;
  String selectedSellingPlatform = 'Tutte';
  @override
  Widget build(BuildContext context) {    final totalItems = items.length;
  final yearStart = DateTime(selectedYear, 1, 1);
  final nextYearStart = DateTime(selectedYear + 1, 1, 1);
    final toSell = items
        .where((item) => item.status == 'Da mettere in vendita')
        .toList();

    final inSale = items
        .where((item) => item.status == 'In vendita')
        .toList();

  final sold = items
      .where(
        (item) =>
    item.status == 'Venduto' &&
        item.saleDate != null &&
        !item.saleDate!.isBefore(yearStart) &&
        item.saleDate!.isBefore(nextYearStart) &&
        (selectedSellingPlatform == 'Tutte' ||
            item.sellingPlatforms.any(
                  (platform) =>
              platform.platform == selectedSellingPlatform &&
                  platform.status == 'Venduto',
            )),
  )
      .toList();

    // Tutto il capitale speso per acquistare gli oggetti.
  final yearPurchases = items.where(
        (item) =>
    !item.purchaseDate.isBefore(yearStart) &&
        item.purchaseDate.isBefore(nextYearStart),
  );

  final totalInvested = yearPurchases.fold<double>(
    0,
        (sum, item) => sum + item.totalCost,
  );

    // Capitale ancora immobilizzato negli oggetti non venduti.
    final capitalInStock = items
        .where((item) => item.status != 'Venduto')
        .fold<double>(
      0,
          (sum, item) => sum + item.totalCost,
    );

    // Incasso lordo delle vendite.
    final totalRevenue = sold.fold<double>(
      0,
          (sum, item) => sum + item.salePrice,
    );

    final totalFees = sold.fold<double>(
      0,
          (sum, item) => sum + item.fees,
    );

    final totalShipping = sold.fold<double>(
      0,
          (sum, item) => sum + item.shipping,
    );
  final yearGeneralExpenses = generalExpenses
      .where(
        (expense) =>
    !expense.date.isBefore(yearStart) &&
        expense.date.isBefore(nextYearStart),
  )
      .fold<double>(
    0,
        (sum, expense) => sum + expense.amount,
  );
    // Incasso netto dopo commissioni e spedizioni.
    final totalNetRevenue = sold.fold<double>(
      0,
          (sum, item) => sum + item.netSale,
    );

    // Utile effettivamente realizzato.
  final totalProfitBeforeGeneralExpenses = sold.fold<double>(
    0,
        (sum, item) => sum + item.profit,
  );

  final totalProfit =
      totalProfitBeforeGeneralExpenses - yearGeneralExpenses;
    final costOfSoldItems = sold.fold<double>(
      0,
          (sum, item) => sum + item.totalCost,
    );

    final roiSales = costOfSoldItems > 0
        ? (totalProfit / costOfSoldItems) * 100
        : 0;
  final returnOnTotalCapital = capitalInStock + costOfSoldItems > 0
      ? (totalProfit / (capitalInStock + costOfSoldItems)) * 100
      : 0;
    final averageProfit = sold.isNotEmpty
        ? totalProfit / sold.length
        : 0;
    final soldWithDate = sold
        .where((item) => item.saleDate != null)
        .toList();

    final averageSaleDays = soldWithDate.isNotEmpty
        ? soldWithDate.fold<int>(
      0,
          (sum, item) =>
      sum + item.saleDate!.difference(item.purchaseDate).inDays,
    ) /
        soldWithDate.length
        : 0;
    final categoryProfits     = <String, double>{};

    for (final item in sold) {
      categoryProfits[item.category] =
          (categoryProfits[item.category] ?? 0) + item.profit;
    }
    final categorySales = <String, int>{};

    for (final item in sold) {
      categorySales[item.category] =
          (categorySales[item.category] ?? 0) + 1;
    }
    final bestCategoryEntry = categoryProfits.isNotEmpty
        ? categoryProfits.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
    )
        : null;

    final bestCategorySales =
    bestCategoryEntry != null
        ? categorySales[bestCategoryEntry.key] ?? 0
        : 0;

    final bestCategoryAverageProfit =
    bestCategorySales > 0
        ? bestCategoryEntry!.value / bestCategorySales
        : 0;
    final categoryCapital = <String, double>{};

    for (final item in items.where((item) => item.status != 'Venduto')) {
      categoryCapital[item.category] =
          (categoryCapital[item.category] ?? 0) + item.totalCost;
    }
    final highestCapitalEntry = categoryCapital.isNotEmpty
        ? categoryCapital.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
    )
        : null;
    final categorySummary = <String, Map<String, dynamic>>{};

    for (final item in sold) {
      final category = item.category;

      if (!categorySummary.containsKey(category)) {
        categorySummary[category] = {
          'sales': 0,
          'profit': 0.0,
        };
      }

      categorySummary[category]!['sales'] =
          (categorySummary[category]!['sales'] as int) + 1;

      categorySummary[category]!['profit'] =
          (categorySummary[category]!['profit'] as double) + item.profit;
    }
    final mostProfitableItem = sold.isNotEmpty
        ? sold.reduce(
          (a, b) => a.profit > b.profit ? a : b,
    )
        : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Analisi del business',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Visione d’insieme di acquisti, inventario e vendite.',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: selectedYear > 2020
                  ? () {
                setState(() {
                  selectedYear--;
                });
              }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '$selectedYear',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: selectedYear < DateTime.now().year
                  ? () {
                setState(() {
                  selectedYear++;
                });
              }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 10),

        DropdownButtonFormField<String>(
          initialValue: selectedSellingPlatform,
          decoration: const InputDecoration(
            labelText: 'Piattaforma di vendita',
            prefixIcon: Icon(Icons.storefront_outlined),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: 'Tutte',
              child: Text('Tutte'),
            ),
            ...sellingPlatformNames.map((platformName) {
              return DropdownMenuItem<String>(
                value: platformName,
                child: Text(platformName),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedSellingPlatform = value;
            });
          },
        ),

        const SizedBox(height: 10),
        const SizedBox(height: 10),

// ------------------------------------------------------------
// RIEPILOGO GENERALE
// ------------------------------------------------------------

        const SectionTitle(
          title: 'Situazione generale',
        ),

        const SizedBox(height: 10),

        AnalysisRow(
          title: 'Oggetti acquistati',
          value: '${yearPurchases.length}',
        ),

        AnalysisRow(
          title: 'Da mettere in vendita',
          value: '${toSell.length}',
        ),

        AnalysisRow(
          title: 'Attualmente in vendita',
          value: '${inSale.length}',
        ),

        AnalysisRow(
          title: 'Oggetti venduti',
          value: '${sold.length}',
        ),

        AnalysisRow(
          title: 'Acquisti dell’anno',
          value: '€ ${totalInvested.toStringAsFixed(2)}',
        ),

        AnalysisRow(
          title: 'Capitale ancora immobilizzato',
          value: '€ ${capitalInStock.toStringAsFixed(2)}',
        ),

        const SizedBox(height: 25),

        // ------------------------------------------------------------
        // VENDITE
        // ------------------------------------------------------------

        const SectionTitle(
          title: 'Vendite',
        ),

        const SizedBox(height: 10),

        AnalysisRow(
          title: 'Incasso lordo',
          value: '€ ${totalRevenue.toStringAsFixed(2)}',
        ),

        AnalysisRow(
          title: 'Commissioni',
          value: '€ ${totalFees.toStringAsFixed(2)}',
        ),

        AnalysisRow(
          title: 'Spedizioni',
          value: '€ ${totalShipping.toStringAsFixed(2)}',
        ),
        AnalysisRow(
          title: 'Spese generali',
          value: '€ ${yearGeneralExpenses.toStringAsFixed(2)}',
        ),
        AnalysisRow(
          title: 'Incasso netto',
          value: '€ ${totalNetRevenue.toStringAsFixed(2)}',
        ),

        AnalysisRow(
          title: 'Utile netto dopo spese',
          value: '€ ${totalProfit.toStringAsFixed(2)}',
        ),
        AnalysisRow(
          title: 'Margine medio per vendita',
          value: '€ ${averageProfit.toStringAsFixed(2)}',
        ),
        AnalysisRow(
          title: 'Tempo medio di vendita',
          value: '${averageSaleDays.toStringAsFixed(1)} giorni',
        ),
        AnalysisRow(
          title: 'ROI sulle vendite',
          value: '${roiSales.toStringAsFixed(1)}%',
        ),

        AnalysisRow(
          title: 'Rendimento sul capitale totale',
          value: '${returnOnTotalCapital.toStringAsFixed(1)}%',
        ),
        const SizedBox(height: 25),
        const SectionTitle(
          title: 'Analisi per categoria',
        ),

        const SizedBox(height: 10),

        ...categorySummary.entries.map((entry) {
          final category = entry.key;
          final sales = entry.value['sales'] as int;
          final profit = entry.value['profit'] as double;

          final average = sales > 0
              ? profit / sales
              : 0;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$sales ${sales == 1 ? 'vendita' : 'vendite'}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Utile totale: € ${profit.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Margine medio: € ${average.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          );
        }),

        InfoCard(
          icon: Icons.auto_graph,
          title: 'Categoria più redditizia',
          text: bestCategoryEntry != null
              ? '${bestCategoryEntry!.key} — $bestCategorySales ${bestCategorySales == 1 ? 'vendita' : 'vendite'} — € ${bestCategoryAverageProfit.toStringAsFixed(2)} di margine medio'
              : 'Nessuna vendita disponibile.',
        ),
        InfoCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Capitale più immobilizzato',
          text: highestCapitalEntry != null
              ? '${highestCapitalEntry!.key} — € ${highestCapitalEntry.value.toStringAsFixed(2)}'
              : 'Nessun capitale immobilizzato.',
        ),
        InfoCard(
          icon: Icons.emoji_events_outlined,
          title: 'Oggetto più redditizio',
          text: mostProfitableItem != null
              ? '${mostProfitableItem!.name} — € ${mostProfitableItem!.profit.toStringAsFixed(2)} di utile'
              : 'Nessuna vendita disponibile.',
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ASSISTENTE
// -----------------------------------------------------------------------------
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistente Resale'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 48,
                color: Colors.indigo,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Assistente Resale',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Questa sezione sarà dedicata agli strumenti di supporto '
                  'per la gestione e l’analisi del tuo business.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 30),

            const InfoCard(
              icon: Icons.auto_graph,
              title: 'In sviluppo',
              text:
              'Le funzioni dell’assistente verranno aggiunte nelle '
                  'prossime versioni di Resale Manager.',
            ),
          ],
        ),
      ),
    );
  }
}



// -----------------------------------------------------------------------------
// WIDGET
// -----------------------------------------------------------------------------

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Colors.indigo,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class SellingPlatformBadge extends StatelessWidget {
  final SellingPlatform platform;

  const SellingPlatformBadge({
    super.key,
    required this.platform,
  });

  String? _logoUrl(String platformName) {
    final configuredLogo = sellingPlatformLogos[platformName];

    if (configuredLogo != null && configuredLogo.isNotEmpty) {
      return configuredLogo;
    }

    switch (platformName.toLowerCase()) {
      case 'facebook marketplace':
        return 'https://www.facebook.com/favicon.ico';
      case 'ebay':
        return 'https://www.ebay.it/favicon.ico';
      case 'subito':
        return 'https://www.subito.it/favicon.ico';
      case 'vinted':
        return 'https://www.vinted.it/favicon.ico';
      case 'wallapop':
        return 'https://es.wallapop.com/favicon.ico';
      case 'chrono24':
        return 'https://www.google.com/s2/favicons?domain=chrono24.com&sz=64';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = platform.logoPath.isNotEmpty
        ? platform.logoPath
        : _logoUrl(platform.platform);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logoUrl != null)
            logoUrl.startsWith('http')
                ? Image.network(
              logoUrl,
              width: 16,
              height: 16,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.storefront_outlined,
                  size: 16,
                );
              },
            )
                : Image.file(
              File(logoUrl),
              width: 16,
              height: 16,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.storefront_outlined,
                  size: 16,
                );
              },
            )
          else
            const Icon(
              Icons.storefront_outlined,
              size: 16,
            ),

          const SizedBox(width: 4),

          Text(
            '€${platform.askingPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
class ItemCard extends StatelessWidget {
  final ResaleItem item;
  final VoidCallback? onChanged;

  const ItemCard({
    super.key,
    required this.item,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cardContext = context;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
builder: (dialogContext) {
return StatefulBuilder(
builder: (context, setDialogState) {
return AlertDialog(
title: Text(item.name),
                  content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    Text('Categoria: ${item.category}'),
                    const SizedBox(height: 8),
                    Text('Luogo di acquisto: ${item.purchaseLocation}'),
                    const SizedBox(height: 8),
                            if (item.imagePaths.isNotEmpty) ...[
                              SizedBox(
                                height: 90,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: item.imagePaths.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (imageContext) {
                                                return Dialog(
                                                  child: InteractiveViewer(
                                                    child: Image.file(
                                                      File(item.imagePaths[index]),
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                          child: Image.file(
                                            File(item.imagePaths[index]),
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                    Text(
                      'Prezzo pagato: €${item.purchasePrice.toStringAsFixed(2)}',
                    ),
                    Text(
                      'Costi extra: €${item.extraCosts.toStringAsFixed(2)}',
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Costo totale: €${item.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      item.salePrice > 0
                          ? 'Prezzo di vendita: €${item.salePrice.toStringAsFixed(2)}'
                          : 'Prezzo di vendita: non impostato',
                    ),

                            if (item.status == 'Venduto') ...[
                              const SizedBox(height: 12),

                              const Text(
                                'Riepilogo vendita',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Costo totale: €${item.totalCost.toStringAsFixed(2)}',
                              ),

                              Text(
                                'Prezzo di vendita: €${item.salePrice.toStringAsFixed(2)}',
                              ),

                              Text(
                                'Commissioni: €${item.fees.toStringAsFixed(2)}',
                              ),

                              Text(
                                'Spedizione: €${item.shipping.toStringAsFixed(2)}',
                              ),

                              Text(
                                'Guadagno / perdita: €${item.profit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                'Venduto su: ${item.sellingPlatforms.where(
                                      (platform) => platform.status == 'Venduto',
                                ).map(
                                      (platform) => platform.platform,
                                ).join(', ')}',
                              ),
                            ],

                    const SizedBox(height: 8),

                    Text('Stato: ${item.status}'),
                          ],
                        ),
                      ),
                  ),
                actions: [
                  if (item.status == 'Da mettere in vendita')
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _showSellDialog(context);
                      },
                      icon: const Icon(Icons.sell),
                      label: const Text('METTI IN VENDITA'),
                    ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _showSellDialog(context);
                    },
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('MODIFICA VENDITE'),
                  ),

                  if (item.status == 'In vendita')
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _showSaleDialog(context);
                      },
                      icon: const Icon(Icons.euro),
                      label: const Text('SEGNA COME VENDUTO'),
                    ),

                  FilledButton.icon(
                    onPressed: () {
                      _showEditDialog(
                        context,
                        onSaved: () {
                          setDialogState(() {});
                        },
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('MODIFICA'),
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('CHIUDI'),
                  ),
                ],
);
},
);
},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.category,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Costo: €${item.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                    if (item.status == 'Venduto') ...[
                      const SizedBox(height: 6),

                      Text(
                        'Venduto: €${item.salePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      Text(
                        'Commissioni: €${item.fees.toStringAsFixed(2)} · '
                            'Spedizione: €${item.shipping.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                        ),
                      ),

                      Text(
                        'Guadagno / perdita: €${item.profit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        'Su: ${item.sellingPlatforms.where(
                              (platform) => platform.status == 'Venduto',
                        ).map(
                              (platform) => platform.platform,
                        ).join(', ')}',
                        style: const TextStyle(
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (item.status == 'In vendita' &&
                        item.sellingPlatforms.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.sellingPlatforms
                            .where((platform) => platform.status == 'Attivo')
                            .map(
                              (platform) => SellingPlatformBadge(
                            platform: platform,
                          ),
                        )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: item.status),
                  const SizedBox(height: 6),

                  if (item.status == 'Venduto')
                    Text(
                      '+€${item.profit.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showEditDialog(
      BuildContext context, {
        VoidCallback? onSaved,
      }) {
    final nameController = TextEditingController(text: item.name);
    final locationController =
    TextEditingController(text: item.purchaseLocation);
    final purchasePriceController =
    TextEditingController(text: item.purchasePrice.toString());
    final extraController =
    TextEditingController(text: item.extraCosts.toString());
    final salePriceController =
    TextEditingController(text: item.salePrice.toString());
    final feesController =
    TextEditingController(text: item.fees.toString());
    final shippingController =
    TextEditingController(text: item.shipping.toString());

    String editedCategory = item.category;
    List<SellingPlatform> editedSellingPlatforms =
    List<SellingPlatform>.from(item.sellingPlatforms);
    bool samePriceForAllPlatforms = true;
    double commonPlatformPrice = 0;
    final ImagePicker picker = ImagePicker();
    final List<XFile> newImages = [];
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifica oggetto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.imagePaths.isNotEmpty || newImages.isNotEmpty) ...[
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...item.imagePaths.asMap().entries.map(
                                  (entry) {
                                final index = entry.key;
                                final path = entry.value;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(path),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          cacheWidth: 180,
                                          cacheHeight: 180,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const SizedBox(
                                              width: 90,
                                              height: 90,
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                                size: 35,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              item.imagePaths.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(3),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            ...newImages.map(
                                  (image) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(image.path),
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final image = await picker.pickImage(
                                source: ImageSource.camera,
                              );

                              if (image != null) {
                                setDialogState(() {
                                  newImages.add(image);
                                });
                              }
                            },
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'FOTOCAMERA',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final images = await picker.pickMultiImage();

                              if (images.isNotEmpty) {
                                setDialogState(() {
                                  newImages.addAll(images);
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'GALLERIA',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: categories.contains(editedCategory)
                          ? editedCategory
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        ...categories.toSet().map(
                              (categoryName) => DropdownMenuItem<String>(
                            value: categoryName,
                            child: Text(categoryName),
                          ),
                        ),

                      ],
                      onChanged: (value) async {
                        if (value == null) return;

                        if (value == '__NUOVA_CATEGORIA__') {
                          final controller = TextEditingController();

                          final newCategory = await showDialog<String>(
                            context: context,
                            builder: (categoryDialogContext) {
                              return AlertDialog(
                                title: const Text('Nuova categoria'),
                                content: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome categoria',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(categoryDialogContext);
                                    },
                                    child: const Text('ANNULLA'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      final value = controller.text.trim();

                                      if (value.isEmpty) return;

                                      Navigator.pop(
                                        categoryDialogContext,
                                        value,
                                      );
                                    },
                                    child: const Text('AGGIUNGI'),
                                  ),
                                ],
                              );
                            },
                          );

                          controller.dispose();

                          if (!context.mounted ||
                              newCategory == null ||
                              newCategory.isEmpty) {
                            return;
                          }

                          if (!categories.contains(newCategory)) {
                            categories.add(newCategory);
                            await saveCategories();
                          }

                          setDialogState(() {
                            editedCategory = newCategory;
                          });

                          return;
                        }

                        setDialogState(() {
                          editedCategory = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue:
                      purchaseLocations.contains(locationController.text)
                          ? locationController.text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Luogo di acquisto',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        ...purchaseLocations.toSet().map(
                              (locationName) => DropdownMenuItem<String>(
                            value: locationName,
                            child: Text(locationName),
                          ),
                        ),

                      ],
                      onChanged: (value) async {
                        if (value == null) return;



                        setDialogState(() {
                          locationController.text = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: purchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prezzo pagato',
                        prefixText: '€ ',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: extraController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Costi extra',
                        prefixText: '€ ',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    if (item.status == 'Venduto') ...[
                      const SizedBox(height: 20),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Dati vendita',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: salePriceController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Prezzo di vendita',
                          prefixText: '€ ',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: feesController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Commissioni',
                          prefixText: '€ ',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: shippingController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Spedizione',
                          prefixText: '€ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('ANNULLA'),
                ),

                FilledButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();

                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Inserisci una descrizione valida.',
                          ),
                        ),
                      );
                      return;
                    }

                    item.name = newName;
                    item.category = editedCategory;
                    item.purchaseLocation =
                        locationController.text.trim();

                    item.purchasePrice = double.tryParse(
                      purchasePriceController.text
                          .replaceAll(',', '.'),
                    ) ??
                        item.purchasePrice;

                    item.extraCosts = double.tryParse(
                      extraController.text.replaceAll(',', '.'),
                    ) ??
                        item.extraCosts;
                    if (newImages.isNotEmpty) {
                      final appDir = await getApplicationDocumentsDirectory();

                      for (var i = 0; i < newImages.length; i++) {
                        final image = newImages[i];
                        final extension = image.path.split('.').last;

                        final savedPath =
                            '${appDir.path}/photo_${DateTime.now().microsecondsSinceEpoch}_$i.$extension';

                        await File(image.path).copy(savedPath);
                        item.imagePaths.add(savedPath);
                      }
                    }
                    if (item.status == 'Venduto') {
                      item.salePrice = double.tryParse(
                        salePriceController.text
                            .replaceAll(',', '.'),
                      ) ??
                          item.salePrice;

                      item.fees = double.tryParse(
                        feesController.text.replaceAll(',', '.'),
                      ) ??
                          item.fees;

                      item.shipping = double.tryParse(
                        shippingController.text.replaceAll(',', '.'),
                      ) ??
                          item.shipping;
                    }
                    item.sellingPlatforms = List<SellingPlatform>.from(
                      editedSellingPlatforms,
                    );
                    await saveItems();
                    Navigator.pop(dialogContext);
                    onSaved?.call();
                    onChanged?.call();
                  },
                  child: const Text('SALVA MODIFICHE'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showSellDialog(BuildContext context) {
    List<SellingPlatform> editedPlatforms =
    List<SellingPlatform>.from(item.sellingPlatforms);

    bool samePriceForAll = true;

    double commonPrice = editedPlatforms.isNotEmpty
        ? editedPlatforms.first.askingPrice
        : 0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Metti in vendita'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seleziona le piattaforme:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ...sellingPlatformNames.map(
                          (platformName) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: editedPlatforms.any(
                              (platform) =>
                          platform.platform == platformName,
                        ),
                        title: Text(platformName),
                        onChanged: (selected) {
                          setDialogState(() {
                            if (selected == true) {
                              editedPlatforms.add(
                                SellingPlatform(
                                  platform: platformName,
                                  askingPrice: commonPrice,
                                  logoPath: sellingPlatformLogos[platformName] ?? '',
                                ),
                              );
                            } else {
                              editedPlatforms.removeWhere(
                                    (platform) =>
                                platform.platform == platformName,
                              );
                            }
                          });
                        },
                      ),
                    ),

                    if (editedPlatforms.isNotEmpty) ...[
                      const SizedBox(height: 12),

                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        groupValue: samePriceForAll,
                        title: const Text(
                          'Stesso prezzo per tutte',
                        ),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            samePriceForAll = value;
                          });
                        },
                      ),

                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        groupValue: samePriceForAll,
                        title: const Text(
                          'Prezzi diversi',
                        ),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            samePriceForAll = value;
                          });
                        },
                      ),

                      const SizedBox(height: 8),

                      if (samePriceForAll)
                        TextField(
                          keyboardType:
                          const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Prezzo',
                            prefixText: '€ ',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(
                            text: commonPrice == 0
                                ? ''
                                : commonPrice.toStringAsFixed(2),
                          ),
                          onChanged: (value) {
                            commonPrice =
                                double.tryParse(
                                  value.replaceAll(',', '.'),
                                ) ??
                                    0;

                            for (final platform
                            in editedPlatforms) {
                              platform.askingPrice = commonPrice;
                            }
                          },
                        ),

                      if (!samePriceForAll)
                        ...editedPlatforms.map(
                              (platform) => Padding(
                            padding:
                            const EdgeInsets.only(bottom: 10),
                            child: TextField(
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                'Prezzo ${platform.platform}',
                                prefixText: '€ ',
                                border:
                                const OutlineInputBorder(),
                              ),
                              controller: TextEditingController(
                                text: platform.askingPrice == 0
                                    ? ''
                                    : platform.askingPrice
                                    .toStringAsFixed(2),
                              ),
                              onChanged: (value) {
                                platform.askingPrice =
                                    double.tryParse(
                                      value.replaceAll(',', '.'),
                                    ) ??
                                        0;
                              },
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('ANNULLA'),
                ),
                FilledButton(
                  onPressed: editedPlatforms.isEmpty
                      ? null
                      : () async {
                    item.sellingPlatforms =
                    List<SellingPlatform>.from(
                      editedPlatforms,
                    );

                    item.status = 'In vendita';

                    await saveItems();

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);

                    onChanged?.call();
                  },
                  child: const Text('SALVA E METTI IN VENDITA'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showSaleDialog(BuildContext context) {
    double salePrice = item.salePrice;
    double fees = item.fees;
    double shipping = item.shipping;
    String? soldPlatform;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Segna come venduto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: soldPlatform,
                  decoration: const InputDecoration(
                    labelText: 'Piattaforma di vendita',
                    border: OutlineInputBorder(),
                  ),
                  items: sellingPlatformNames.map((platform) {
                    return DropdownMenuItem<String>(
                      value: platform,
                      child: Text(platform),
                    );
                  }).toList(),
                  onChanged: (value) {
                    soldPlatform = value;
                  },
                ),

                const SizedBox(height: 12),
                TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Prezzo di vendita',
                    prefixText: '€ ',
                    border: const OutlineInputBorder(),
                    hintText: item.salePrice > 0
                        ? item.salePrice.toString()
                        : null,
                  ),
                  onChanged: (value) {
                    salePrice =
                        double.tryParse(value.replaceAll(',', '.')) ?? 0;
                  },
                ),

                const SizedBox(height: 12),

                TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Commissioni',
                    prefixText: '€ ',
                    border: const OutlineInputBorder(),
                    hintText: item.fees > 0
                        ? item.fees.toString()
                        : null,
                  ),
                  onChanged: (value) {
                    fees =
                        double.tryParse(value.replaceAll(',', '.')) ?? 0;
                  },
                ),

                const SizedBox(height: 12),

                TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Spedizione',
                    prefixText: '€ ',
                    border: const OutlineInputBorder(),
                    hintText: item.shipping > 0
                        ? item.shipping.toString()
                        : null,
                  ),
                  onChanged: (value) {
                    shipping =
                        double.tryParse(value.replaceAll(',', '.')) ?? 0;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('ANNULLA'),
            ),

            FilledButton(
              onPressed: () {
                if (salePrice <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Inserisci un prezzo di vendita valido.',
                      ),
                    ),
                  );
                  return;
                }
                item.salePrice = salePrice;
                item.fees = fees;
                item.shipping = shipping;
                item.status = 'Venduto';
                if (soldPlatform != null) {
                  item.sellingPlatforms = item.sellingPlatforms.map((platform) {
                    return SellingPlatform(
                      platform: platform.platform,
                      askingPrice: platform.askingPrice,
                      status: platform.platform == soldPlatform
                          ? 'Venduto'
                          : 'Non venduto',
                      logoPath: platform.logoPath,
                    );
                  }).toList();
                }
                item.saleDate = DateTime.now();
                Navigator.pop(dialogContext);
                saveItems();
                onChanged?.call();
              },
              child: const Text('CONFERMA VENDITA'),
            ),
          ],
        );
      },
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final parentContext = context;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final ResaleItem item;

  const AlertCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 0,
        ),
        leading: const Icon(
          Icons.warning_amber_outlined,
          size: 20,
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Fermo da ${item.daysInInventory} giorni',
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
        ),
      ),
    );
  }
}

class AssistantCard extends StatelessWidget {
  final VoidCallback onTap;

  const AssistantCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 38,
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistente Resale',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Analizza acquisti, prezzi e oggetti fermi.',
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class AssistantAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  const AssistantAction({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(text),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class AnalysisRow extends StatelessWidget {
  final String title;
  final String value;

  const AnalysisRow({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnualSummaryCard extends StatelessWidget {
  final String title;
  final double value;

  const _AnnualSummaryCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '€ ${value.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
// -----------------------------------------------------------------------------
// PROFILO
// -----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nomeController = TextEditingController();
  final negozioController = TextEditingController();
  final emailController = TextEditingController();
  final telefonoController = TextEditingController();

  String? fotoProfilo;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    nomeController.dispose();
    negozioController.dispose();
    emailController.dispose();
    telefonoController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/profile.json');

    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is! Map) return;

      nomeController.text = decoded['nome']?.toString() ?? '';
      negozioController.text = decoded['negozio']?.toString() ?? '';
      emailController.text = decoded['email']?.toString() ?? '';
      telefonoController.text = decoded['telefono']?.toString() ?? '';

      final foto = decoded['fotoProfilo']?.toString() ?? '';

      if (foto.isNotEmpty) {
        setState(() {
          fotoProfilo = foto;
        });
      } else {
        setState(() {});
      }
    } catch (_) {
      // Mantiene il profilo vuoto se il file non è leggibile.
    }
  }

  Future<void> _saveProfile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/profile.json');

    final data = {
      'nome': nomeController.text.trim(),
      'negozio': negozioController.text.trim(),
      'email': emailController.text.trim(),
      'telefono': telefonoController.text.trim(),
      'fotoProfilo': fotoProfilo ?? '',
    };

    await file.writeAsString(
      jsonEncode(data),
      flush: true,
    );
  }
  Future<void> _saveProfilePhoto() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/profile.json');

    Map<String, dynamic> data = {
      'nome': nomeController.text.trim(),
      'negozio': negozioController.text.trim(),
      'email': emailController.text.trim(),
      'telefono': telefonoController.text.trim(),
      'fotoProfilo': fotoProfilo ?? '',
    };

    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);

        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
          data['fotoProfilo'] = fotoProfilo ?? '';
        }
      } catch (_) {
        // Mantiene i dati correnti se il file non è leggibile.
      }
    }

    await file.writeAsString(
      jsonEncode(data),
      flush: true,
    );
  }
  Future<void> _choosePhoto() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    final appDir = await getApplicationDocumentsDirectory();

    final extension = image.path.split('.').last;

    final savedPath =
        '${appDir.path}/profile_photo_${DateTime.now().microsecondsSinceEpoch}.$extension';

    await File(image.path).copy(savedPath);

    setState(() {
      fotoProfilo = savedPath;
    });

    await _saveProfilePhoto();
  }

  Future<void> _editProfile() async {
    nomeController.text = nomeController.text.trim();
    negozioController.text = negozioController.text.trim();
    emailController.text = emailController.text.trim();
    telefonoController.text = telefonoController.text.trim();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Modifica profilo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: negozioController,
                  decoration: const InputDecoration(
                    labelText: 'Negozio / Attività',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('ANNULLA'),
            ),
            FilledButton(
              onPressed: () async {
                await _saveProfile();

                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);

                setState(() {});
              },
              child: const Text('SALVA'),
            ),
          ],
        );
      },
    );
  }

  Widget _profileImage() {
    if (fotoProfilo != null && fotoProfilo!.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(fotoProfilo!),
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person,
              size: 50,
            );
          },
        ),
      );
    }

    return const Icon(
      Icons.person,
      size: 50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profilo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifica profilo',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _choosePhoto,
              child: CircleAvatar(
                radius: 48,
                child: _profileImage(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Tocca la foto per modificarla',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Nome'),
              subtitle: Text(
                nomeController.text.isEmpty
                    ? 'Non impostato'
                    : nomeController.text,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Negozio / Attività'),
              subtitle: Text(
                negozioController.text.isEmpty
                    ? 'Non impostato'
                    : negozioController.text,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(
                emailController.text.isEmpty
                    ? 'Non impostata'
                    : emailController.text,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Telefono'),
              subtitle: Text(
                telefonoController.text.isEmpty
                    ? 'Non impostato'
                    : telefonoController.text,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('App'),
              subtitle: Text('Resale Manager'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.workspace_premium_outlined),
              title: Text('Piano'),
              subtitle: Text('Free'),
            ),
          ),
        ],
      ),
    );
  }
}
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Informazioni',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Image.asset(
              'assets/images/resale_manager_logo.png',
              width: 110,
              height: 110,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Resale Manager',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Il tuo gestore personale per il reselling',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Versione'),
              subtitle: const Text('Resale Manager'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.code_outlined),
              title: const Text('Sviluppatore'),
              subtitle: const Text('FD AppLab'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.apps_outlined),
              title: const Text('Applicazione'),
              subtitle: const Text(
                'Gestione acquisti, inventario, vendite e analisi',
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '© FD AppLab',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// -----------------------------------------------------------------------------
// BACKUP E RIPRISTINO
// -----------------------------------------------------------------------------

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Backup e ripristino',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Crea backup'),
              subtitle: const Text(
                'Salva tutti i dati di Resale Manager',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                try {
                  final backupFile = await createBackupZip();

                  final savePath = await FilePicker.saveFile(
                    fileName: backupFile.uri.pathSegments.last,
                    bytes: await backupFile.readAsBytes(),
                  );

                  if (savePath == null) return;

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup salvato correttamente.'),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Errore nel salvataggio del backup: $e'),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Ripristina backup'),
              subtitle: const Text(
                'Recupera i dati da un backup precedente',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                try {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['zip'],
                  );

                  if (result == null || result.single.path == null) {
                    return;
                  }

                  final backupFile = File(result.single.path!);

                  await restoreBackupZip(backupFile);

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup ripristinato correttamente.'),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Errore nel ripristino del backup: $e',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 25),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Il backup comprenderà gli acquisti, '
                          'le opportunità, le spese, le categorie, '
                          'i luoghi di acquisto e le foto degli oggetti.',
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
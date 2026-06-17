import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/bar_service.dart';
import 'core/utils/image_utils.dart';
import 'data/database.dart';
import 'data/flavor_data.dart';
import 'services/firestore_sync_service.dart';
import 'services/purchase_service.dart';
import 'services/auth_service.dart';
import 'services/user_sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/cocktail_detail_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/my_bar_screen.dart';
import 'screens/my_bar_tab_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/back_bar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final purchaseService = PurchaseService();
  await purchaseService.init();

  final authService = AuthService();
  authService.setPurchaseService(purchaseService);

  final database = await initDatabase();
  final userSyncService = UserSyncService(database);
  authService.setUserSyncService(userSyncService);

  // Link any already-signed-in Firebase user to RevenueCat on startup.
  final existingUser = authService.currentUser;
  if (existingUser != null && !existingUser.isAnonymous) {
    await purchaseService.loginUser(existingUser.uid);
    await userSyncService.pullFromFirestore(existingUser.uid);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: purchaseService),
        ChangeNotifierProvider.value(value: authService),
      ],
      child: CocktailSpecsApp(database: database),
    ),
  );
}

Future<AppDatabase> initDatabase() async {
  return AppDatabase();
}

class CocktailSpecsApp extends StatelessWidget {
  final AppDatabase database;

  const CocktailSpecsApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Bar Bible',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(
        onReady: () => FirestoreSyncService(database).syncIfNeeded(),
        child: MainNavigationScreen(database: database),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final AppDatabase database;

  const MainNavigationScreen({super.key, required this.database});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const int _homeTabIndex = 0;
  static const int _browseTabIndex = 1;
  static const int _backBarTabIndex = 2; // ignore: unused_field
  static const int _myBarTabIndex = 3;
  static const int _settingsTabIndex = 4; // ignore: unused_field

  int _selectedIndex = _homeTabIndex;
  String _activeBarName = 'My Bar';
  late final BarService _barService;

  // GlobalKeys to reach tab states for cross-tab refresh
  final _myBarTabKey = GlobalKey<MyBarTabScreenState>();
  final _myBarKey = GlobalKey<MyBarScreenState>();
  Timer? _barChangedDebounceTimer;

  @override
  void initState() {
    super.initState();
    _barService = BarService(widget.database);
    _loadActiveBarName();
  }

  List<Widget> _buildScreens() {
    return [
      HomeScreen(
        database: widget.database,
        activeBarName: _activeBarName,
        onNavigateToBrowse: () => _onTabTapped(_browseTabIndex),
        onNavigateToFinder: () {
          _onTabTapped(_myBarTabIndex);
          _myBarTabKey.currentState?.switchToCocktails();
        },
        onSwitchBar: _switchBarFromPill,
      ),
      CocktailsListScreen(database: widget.database),
      BackBarScreen(database: widget.database),
      MyBarTabScreen(
        key: _myBarTabKey,
        database: widget.database,
        activeBarName: _activeBarName,
        myBarKey: _myBarKey,
        onBarSwitched: _switchBarFromPill,
        onBarChanged: _onBarChanged,
      ),
      SettingsScreen(database: widget.database),
    ];
  }

  Future<void> _loadActiveBarName() async {
    final bar = await widget.database.getDefaultSavedBar();
    if (mounted && bar != null) {
      setState(() => _activeBarName = bar.name);
    }
  }

  /// Called when the Bar Context Pill selects a different bar.
  Future<void> _switchBarFromPill(int barId) async {
    await _barService.setDefaultBar(barId);
    await _loadActiveBarName();
    _myBarTabKey.currentState?.refreshAllFinders();
    await _myBarKey.currentState?.loadData();
  }

  void _onTabTapped(int index) {
    // Refresh My Bar tabs when navigating to them from elsewhere.
    if (index == _myBarTabIndex && _selectedIndex != _myBarTabIndex) {
      _myBarKey.currentState?.loadData();
      _myBarTabKey.currentState?.refreshAllFinders();
    }
    setState(() => _selectedIndex = index);
  }

  /// Called by My Bar whenever an ingredient is toggled or bar is switched.
  void _onBarChanged() {
    _barChangedDebounceTimer?.cancel();
    _barChangedDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _loadActiveBarName();
      // Cocktail/Shot/Mocktail finder tabs — keep them all in sync.
      _myBarTabKey.currentState?.refreshAllFinders();
    });
  }

  @override
  void dispose() {
    _barChangedDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _buildScreens()),
      extendBody: true,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryDark.withValues(alpha: 0.0),
            AppTheme.primaryDark.withValues(alpha: 0.8),
            AppTheme.primaryDark,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.surfaceLight.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.accentGold,
          unselectedItemColor: AppTheme.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home, size: 24),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.menu_book_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.menu_book, size: 24),
              ),
              label: 'Browse',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.lock_open_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.lock_open, size: 24),
              ),
              label: 'Back Bar',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.liquor_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.liquor, size: 24),
              ),
              label: 'My Bar',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings, size: 24),
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Browse Tab (Cocktails List) ─────────────────────────────────────────────

class CocktailsListScreen extends StatefulWidget {
  final AppDatabase database;

  const CocktailsListScreen({super.key, required this.database});

  @override
  State<CocktailsListScreen> createState() => _CocktailsListScreenState();
}

class _CocktailsListScreenState extends State<CocktailsListScreen>
    with SingleTickerProviderStateMixin {
  List<Cocktail> allCocktails = [];
  List<Cocktail> filteredCocktails = [];
  bool isLoading = true;

  String searchQuery = '';
  Set<String> selectedSpirits = {};
  Set<String> selectedFlavors = {};
  Set<int> selectedDifficulties = {};
  String sortBy = 'alphabetical';
  String premiumFilter = 'all'; // 'all', 'free', 'premium'

  late final TabController _tabController;
  static const _categoryValues = ['cocktail', 'mocktail', 'shot'];
  static const _categoryLabels = ['Cocktails', 'Mocktails', 'Shots'];
  static const _categoryLabelsSingular = ['Cocktail', 'Mocktail', 'Shot'];

  String get _activeCategory => _categoryValues[_tabController.index];
  String get _activeLabel => _categoryLabels[_tabController.index];
  String get _activeLabelSingular => _categoryLabelsSingular[_tabController.index];

  final List<String> spirits = [
    'Gin', 'Vodka', 'Rum', 'Bourbon', 'Whiskey', 'Brandy', 'Cognac', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _applyFilters();
    });
    _loadCocktails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCocktails() async {
    final cocktails = await widget.database
        .select(widget.database.cocktails)
        .get();
    setState(() {
      allCocktails = cocktails;
      filteredCocktails = cocktails;
      isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      filteredCocktails = allCocktails.where((cocktail) {
        if (cocktail.category != _activeCategory) return false;
        if (searchQuery.isNotEmpty &&
            !cocktail.name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
        if (selectedSpirits.isNotEmpty &&
            !selectedSpirits.contains(cocktail.baseSpirit)) {
          return false;
        }
        if (selectedFlavors.isNotEmpty) {
          final tags = parseCocktailTags(cocktail.tags);
          final matchesAny = selectedFlavors.any((label) {
            final chip = kFlavorChips.firstWhere(
              (c) => c.label == label,
              orElse: () => FlavorChip(label: label, aliases: {label}),
            );
            return cocktailHasFlavorTag(tags, chip.aliases);
          });
          if (!matchesAny) return false;
        }
        if (selectedDifficulties.isNotEmpty &&
            !selectedDifficulties.contains(cocktail.difficulty)) {
          return false;
        }
        if (premiumFilter == 'free' && cocktail.isPremium) return false;
        if (premiumFilter == 'premium' && !cocktail.isPremium) return false;
        return true;
      }).toList();

      switch (sortBy) {
        case 'alphabetical':
          filteredCocktails.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'difficulty':
          filteredCocktails.sort(
            (a, b) => a.difficulty.compareTo(b.difficulty),
          );
          break;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      selectedSpirits.clear();
      selectedFlavors.clear();
      selectedDifficulties.clear();
      filteredCocktails = allCocktails;
    });
    _applyFilters();
  }

  bool get hasActiveFilters =>
      selectedSpirits.isNotEmpty ||
      selectedFlavors.isNotEmpty ||
      selectedDifficulties.isNotEmpty;

  int _getActiveFilterCount() {
    return selectedSpirits.length +
        selectedFlavors.length +
        selectedDifficulties.length;
  }

  void _showFiltersSheet() {
    final tempSpirits = Set<String>.from(selectedSpirits);
    final tempFlavors = Set<String>.from(selectedFlavors);
    final tempDifficulties = Set<int>.from(selectedDifficulties);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'FILTERS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: AppTheme.accentGold,
                    ),
                  ),
                  const Spacer(),
                  if (tempSpirits.isNotEmpty ||
                      tempFlavors.isNotEmpty ||
                      tempDifficulties.isNotEmpty)
                    GestureDetector(
                      onTap: () => setModalState(() {
                        tempSpirits.clear();
                        tempFlavors.clear();
                        tempDifficulties.clear();
                      }),
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.accentGold.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _FilterSection(
                label: 'SPIRIT',
                children: spirits
                    .map(
                      (s) => _FilterChipMulti(
                        label: s,
                        isSelected: tempSpirits.contains(s),
                        onTap: () => setModalState(
                          () => tempSpirits.contains(s)
                              ? tempSpirits.remove(s)
                              : tempSpirits.add(s),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'FLAVOR',
                children: kFlavorChips
                    .map(
                      (chip) => _FilterChipMulti(
                        label: chip.label,
                        isSelected: tempFlavors.contains(chip.label),
                        onTap: () => setModalState(
                          () => tempFlavors.contains(chip.label)
                              ? tempFlavors.remove(chip.label)
                              : tempFlavors.add(chip.label),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'DIFFICULTY',
                children: [1, 2, 3, 4, 5]
                    .map(
                      (d) => _FilterChipMulti(
                        label: '$d\u2605',
                        isSelected: tempDifficulties.contains(d),
                        onTap: () => setModalState(
                          () => tempDifficulties.contains(d)
                              ? tempDifficulties.remove(d)
                              : tempDifficulties.add(d),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedSpirits = tempSpirits;
                    selectedFlavors = tempFlavors;
                    selectedDifficulties = tempDifficulties;
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'APPLY FILTERS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // Pinned: BROWSE title
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book,
                                color: AppTheme.accentGold,
                                size: 32,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'BROWSE',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Padding(
                            padding: EdgeInsets.only(left: 44),
                            child: Text(
                              'Drinks Reference Library',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Collapsing: search + filters + pills + count
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search $_activeLabel...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            setState(() => searchQuery = '');
                                            _applyFilters();
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (value) {
                                  searchQuery = value;
                                  _applyFilters();
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _showFiltersSheet,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasActiveFilters
                                          ? AppTheme.accentGold
                                          : AppTheme.surfaceDark,
                                      foregroundColor: hasActiveFilters
                                          ? AppTheme.primaryDark
                                          : AppTheme.textPrimary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: hasActiveFilters
                                              ? AppTheme.accentGold
                                              : AppTheme.surfaceLight,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.filter_list, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          hasActiveFilters
                                              ? 'FILTERS (${_getActiveFilterCount()})'
                                              : 'FILTERS',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  DropdownButton<String>(
                                    value: sortBy,
                                    dropdownColor: AppTheme.surfaceDark,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                    underline: Container(),
                                    icon: const Icon(
                                      Icons.sort,
                                      color: AppTheme.textSecondary,
                                      size: 18,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'alphabetical',
                                        child: Text('A\u2013Z'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'difficulty',
                                        child: Text('Difficulty'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() => sortBy = value!);
                                      _applyFilters();
                                    },
                                  ),
                                ],
                              ),
                              if (hasActiveFilters) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...selectedSpirits.map(
                                      (s) => _ActiveFilterPill(
                                        label: s,
                                        onRemove: () {
                                          setState(() => selectedSpirits.remove(s));
                                          _applyFilters();
                                        },
                                      ),
                                    ),
                                    ...selectedFlavors.map(
                                      (f) => _ActiveFilterPill(
                                        label: f,
                                        onRemove: () {
                                          setState(() => selectedFlavors.remove(f));
                                          _applyFilters();
                                        },
                                      ),
                                    ),
                                    ...selectedDifficulties.map(
                                      (d) => _ActiveFilterPill(
                                        label: '$d\u2605',
                                        onRemove: () {
                                          setState(
                                            () => selectedDifficulties.remove(d),
                                          );
                                          _applyFilters();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Row(
                            children: [
                              _PremiumFilterPill(
                                label: 'All',
                                selected: premiumFilter == 'all',
                                onTap: () { setState(() => premiumFilter = 'all'); _applyFilters(); },
                              ),
                              const SizedBox(width: 8),
                              _PremiumFilterPill(
                                label: 'Free',
                                selected: premiumFilter == 'free',
                                onTap: () { setState(() => premiumFilter = 'free'); _applyFilters(); },
                              ),
                              const SizedBox(width: 8),
                              _PremiumFilterPill(
                                label: 'Premium',
                                selected: premiumFilter == 'premium',
                                onTap: () { setState(() => premiumFilter = 'premium'); _applyFilters(); },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                color: AppTheme.accentGold,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${filteredCocktails.length} ${filteredCocktails.length == 1 ? _activeLabelSingular : _activeLabel}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
                body: Column(
                  children: [
                    // Pinned TabBar inside body
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryDark,
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppTheme.accentGold,
                        indicatorWeight: 2,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelColor: AppTheme.accentGold,
                        unselectedLabelColor: AppTheme.textSecondary,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: const [
                          Tab(text: 'Cocktails'),
                          Tab(text: 'Mocktails'),
                          Tab(text: 'Shots'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredCocktails.isEmpty
                          ? _EmptyState(
                              hasFilters: hasActiveFilters,
                              onClear: _clearFilters,
                              label: _activeLabel.toUpperCase(),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                top: 8,
                                bottom: 100,
                              ),
                              itemCount: filteredCocktails.length,
                              itemBuilder: (context, index) {
                                final cocktail = filteredCocktails[index];
                                return _CocktailCard(
                                  cocktail: cocktail,
                                  onTap: () {
                                    final purchaseService = context.read<PurchaseService>();
                                    if (cocktail.isPremium && !purchaseService.isPremium) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const PaywallScreen(),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CocktailDetailScreen(
                                          database: widget.database,
                                          cocktail: cocktail,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _FilterSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _FilterSection({required this.label, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: AppTheme.accentGold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _FilterChipMulti extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChipMulti({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentGold : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accentGold : AppTheme.surfaceLight,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterPill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveFilterPill({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentGold,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _CocktailCard extends StatefulWidget {
  final Cocktail cocktail;
  final VoidCallback onTap;
  const _CocktailCard({required this.cocktail, required this.onTap});
  @override
  State<_CocktailCard> createState() => _CocktailCardState();
}

class _CocktailCardState extends State<_CocktailCard> {
  String? _resolvedImagePath;
  @override
  void initState() {
    super.initState();
    _resolveImagePath();
  }

  Future<void> _resolveImagePath() async {
    // Prefer network URL
    if (widget.cocktail.imageUrl != null && widget.cocktail.imageUrl!.isNotEmpty) {
      if (mounted) setState(() => _resolvedImagePath = widget.cocktail.imageUrl);
      return;
    }
    final basePath =
        widget.cocktail.imagePath ??
        ImageUtils.generateBasePathFromName(widget.cocktail.name);
    final resolved = await ImageUtils.findCocktailImage(basePath);
    if (mounted) setState(() => _resolvedImagePath = resolved);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Consumer<PurchaseService>(
            builder: (context, purchaseService, _) {
              final isLocked = widget.cocktail.isPremium && !purchaseService.isPremium;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLocked
                        ? AppTheme.accentGold.withValues(alpha: 0.4)
                        : AppTheme.surfaceLight,
                    width: isLocked ? 1.0 : 0.5,
                  ),
                ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      _resolvedImagePath != null
                          ? (_resolvedImagePath!.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: _resolvedImagePath!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _imageFallback(),
                                )
                              : Image.asset(
                                  _resolvedImagePath!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _imageFallback(),
                                ))
                          : _imageFallback(),
                      if (isLocked)
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.35),
                              child: const Center(
                                child: Icon(
                                  Icons.lock,
                                  color: AppTheme.accentGold,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.cocktail.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLocked) ...
                            [
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.accentGold.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.accentGold,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            widget.cocktail.baseSpirit.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentGold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppTheme.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.cocktail.method.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.cocktail.glass,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '\u2605' * widget.cocktail.difficulty,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.accentGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<PurchaseService>(
                      builder: (context, purchaseService, _) {
                        if (widget.cocktail.isPremium && !purchaseService.isPremium) {
                          return const Icon(
                            Icons.lock,
                            size: 14,
                            color: AppTheme.textSecondary,
                          );
                        }
                        return const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppTheme.textSecondary,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.local_bar, color: AppTheme.accentGold),
  );
}

class _PremiumFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PremiumFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.accentGold.withValues(alpha: 0.5)
                : AppTheme.surfaceLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppTheme.accentGold : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  final String label;
  const _EmptyState({
    required this.hasFilters,
    required this.onClear,
    this.label = 'COCKTAILS',
  });
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'NO $label FOUND',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onClear, child: const Text('CLEAR FILTERS')),
          ],
        ],
      ),
    );
  }
}

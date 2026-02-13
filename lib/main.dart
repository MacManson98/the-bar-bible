import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'core/theme/app_theme.dart';
import 'core/utils/image_utils.dart';
import 'data/database.dart';
import 'screens/home_screen.dart';
import 'screens/cocktail_detail_screen.dart';
import 'screens/finder_screen.dart';
import 'screens/my_bar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = await initDatabase();
  
  runApp(CocktailSpecsApp(database: database));
}

Future<AppDatabase> initDatabase() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dbFolder.path, 'cocktails.db');
  
  if (!await File(dbPath).exists()) {
    final data = await rootBundle.load('assets/databases/cocktails.db');
    await File(dbPath).writeAsBytes(data.buffer.asUint8List());
  }
  
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
      home: MainNavigationScreen(database: database),
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
  int _selectedIndex = 0;
  
  // GlobalKey to reach Finder state for My Bar communication
  final _finderKey = GlobalKey<FinderScreenState>();
  
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        database: widget.database,
        onNavigateToBrowse: () => _onTabTapped(1),
        onNavigateToFinder: () => _onTabTapped(2),
      ),
      CocktailsListScreen(database: widget.database),
      FinderScreen(
        key: _finderKey,
        database: widget.database,
        onNavigateToMyBar: () => _onTabTapped(3),
      ),
      MyBarScreen(
        database: widget.database,
        onBarChanged: _onBarChanged,
        onNavigateToFinder: () => _onTabTapped(2),
      ),
    ];
  }

  void _onTabTapped(int index) {
    // If switching TO Finder, refresh it (bar may have changed)
    if (index == 2 && _selectedIndex != 2) {
      _finderKey.currentState?.loadBarAndMatch();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Called by My Bar whenever an ingredient is toggled.
  void _onBarChanged() {
    // If Finder is the active tab, refresh immediately.
    // Otherwise it will refresh when user switches to Finder tab.
    if (_selectedIndex == 2) {
      _finderKey.currentState?.loadBarAndMatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
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
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
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
                child: Icon(Icons.search_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.search, size: 24),
              ),
              label: 'Finder',
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

class _CocktailsListScreenState extends State<CocktailsListScreen> {
  List<Cocktail> allCocktails = [];
  List<Cocktail> filteredCocktails = [];
  bool isLoading = true;
  
  String searchQuery = '';
  Set<String> selectedSpirits = {};
  Set<String> selectedMethods = {};
  Set<int> selectedDifficulties = {};
  String sortBy = 'alphabetical';
  
  final List<String> spirits = ['Gin', 'Vodka', 'Rum', 'Bourbon', 'Whiskey', 'Brandy', 'Cognac', 'Other'];
  final List<String> methods = ['shake', 'stir', 'build'];

  @override
  void initState() {
    super.initState();
    _loadCocktails();
  }

  Future<void> _loadCocktails() async {
    final cocktails = await widget.database.select(widget.database.cocktails).get();
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
        if (searchQuery.isNotEmpty &&
            !cocktail.name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
        if (selectedSpirits.isNotEmpty &&
            !selectedSpirits.contains(cocktail.baseSpirit)) {
          return false;
        }
        if (selectedMethods.isNotEmpty &&
            !selectedMethods.contains(cocktail.method)) {
          return false;
        }
        if (selectedDifficulties.isNotEmpty &&
            !selectedDifficulties.contains(cocktail.difficulty)) {
          return false;
        }
        return true;
      }).toList();

      switch (sortBy) {
        case 'alphabetical':
          filteredCocktails.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'difficulty':
          filteredCocktails.sort((a, b) => a.difficulty.compareTo(b.difficulty));
          break;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      selectedSpirits.clear();
      selectedMethods.clear();
      selectedDifficulties.clear();
      filteredCocktails = allCocktails;
    });
    _applyFilters();
  }

  bool get hasActiveFilters =>
      selectedSpirits.isNotEmpty ||
      selectedMethods.isNotEmpty ||
      selectedDifficulties.isNotEmpty;

  int _getActiveFilterCount() {
    return selectedSpirits.length + selectedMethods.length + selectedDifficulties.length;
  }

  void _showFiltersSheet() {
    final tempSpirits = Set<String>.from(selectedSpirits);
    final tempMethods = Set<String>.from(selectedMethods);
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('FILTERS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const Spacer(),
                  if (tempSpirits.isNotEmpty || tempMethods.isNotEmpty || tempDifficulties.isNotEmpty)
                    TextButton(
                      onPressed: () => setModalState(() { tempSpirits.clear(); tempMethods.clear(); tempDifficulties.clear(); }),
                      child: const Text('CLEAR ALL', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _FilterSection(label: 'SPIRIT', children: spirits.map((s) => _FilterChipMulti(label: s, isSelected: tempSpirits.contains(s), onTap: () => setModalState(() => tempSpirits.contains(s) ? tempSpirits.remove(s) : tempSpirits.add(s)))).toList()),
              const SizedBox(height: 16),
              _FilterSection(label: 'METHOD', children: methods.map((m) => _FilterChipMulti(label: m.toUpperCase(), isSelected: tempMethods.contains(m), onTap: () => setModalState(() => tempMethods.contains(m) ? tempMethods.remove(m) : tempMethods.add(m)))).toList()),
              const SizedBox(height: 16),
              _FilterSection(label: 'DIFFICULTY', children: [1,2,3,4,5].map((d) => _FilterChipMulti(label: '$d\u2605', isSelected: tempDifficulties.contains(d), onTap: () => setModalState(() => tempDifficulties.contains(d) ? tempDifficulties.remove(d) : tempDifficulties.add(d)))).toList()),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () { setState(() { selectedSpirits = tempSpirits; selectedMethods = tempMethods; selectedDifficulties = tempDifficulties; }); _applyFilters(); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: AppTheme.primaryDark, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('APPLY FILTERS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1))),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.menu_book, color: AppTheme.accentGold, size: 32),
                          SizedBox(width: 12),
                          Text('BROWSE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ]),
                        SizedBox(height: 4),
                        Padding(padding: EdgeInsets.only(left: 44), child: Text('Cocktail Reference Library', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, letterSpacing: 1))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search cocktails...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { setState(() => searchQuery = ''); _applyFilters(); }) : null,
                          ),
                          onChanged: (value) { searchQuery = value; _applyFilters(); },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _showFiltersSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasActiveFilters ? AppTheme.accentGold : AppTheme.surfaceDark,
                                foregroundColor: hasActiveFilters ? AppTheme.primaryDark : AppTheme.textPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: hasActiveFilters ? AppTheme.accentGold : AppTheme.surfaceLight)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.filter_list, size: 20),
                                const SizedBox(width: 8),
                                Text(hasActiveFilters ? 'FILTERS (${_getActiveFilterCount()})' : 'FILTERS', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ]),
                            ),
                            const Spacer(),
                            DropdownButton<String>(
                              value: sortBy, dropdownColor: AppTheme.surfaceDark,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              underline: Container(), icon: const Icon(Icons.sort, color: AppTheme.textSecondary, size: 18),
                              items: const [DropdownMenuItem(value: 'alphabetical', child: Text('A\u2013Z')), DropdownMenuItem(value: 'difficulty', child: Text('Difficulty'))],
                              onChanged: (value) { setState(() => sortBy = value!); _applyFilters(); },
                            ),
                          ],
                        ),
                        if (hasActiveFilters) ...[
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            ...selectedSpirits.map((s) => _ActiveFilterPill(label: s, onRemove: () { setState(() => selectedSpirits.remove(s)); _applyFilters(); })),
                            ...selectedMethods.map((m) => _ActiveFilterPill(label: m.toUpperCase(), onRemove: () { setState(() => selectedMethods.remove(m)); _applyFilters(); })),
                            ...selectedDifficulties.map((d) => _ActiveFilterPill(label: '$d\u2605', onRemove: () { setState(() => selectedDifficulties.remove(d)); _applyFilters(); })),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      Container(width: 4, height: 16, color: AppTheme.accentGold),
                      const SizedBox(width: 12),
                      Text('${filteredCocktails.length} ${filteredCocktails.length == 1 ? 'Cocktail' : 'Cocktails'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredCocktails.isEmpty
                        ? _EmptyState(hasFilters: hasActiveFilters, onClear: _clearFilters)
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 100),
                            itemCount: filteredCocktails.length,
                            itemBuilder: (context, index) {
                              final cocktail = filteredCocktails[index];
                              return _CocktailCard(cocktail: cocktail, onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => CocktailDetailScreen(database: widget.database, cocktail: cocktail)));
                              });
                            },
                          ),
                  ),
                ],
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.accentGold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: children),
    ]);
  }
}

class _FilterChipMulti extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChipMulti({required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? AppTheme.accentGold : AppTheme.surfaceDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? AppTheme.accentGold : AppTheme.surfaceLight, width: 1.5)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary)),
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
      decoration: BoxDecoration(color: AppTheme.accentGold, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryDark)),
        const SizedBox(width: 6),
        InkWell(onTap: onRemove, child: const Icon(Icons.close, size: 14, color: AppTheme.primaryDark)),
      ]),
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
    final basePath = widget.cocktail.imagePath ?? ImageUtils.generateBasePathFromName(widget.cocktail.name);
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
          onTap: widget.onTap, borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.surfaceLight)),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _resolvedImagePath != null
                    ? Image.asset(_resolvedImagePath!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageFallback())
                    : _imageFallback(),
              ),
              const SizedBox(width: 12),
              Container(width: 4, height: 60, decoration: BoxDecoration(color: AppTheme.accentGold, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.cocktail.name.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                Row(children: [
                  Text(widget.cocktail.baseSpirit.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentGold, letterSpacing: 0.5)),
                  Container(margin: const EdgeInsets.symmetric(horizontal: 8), width: 3, height: 3, decoration: const BoxDecoration(color: AppTheme.textSecondary, shape: BoxShape.circle)),
                  Expanded(child: Text(widget.cocktail.method.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Text(widget.cocktail.glass, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
              Column(children: [
                Text('\u2605' * widget.cocktail.difficulty, style: const TextStyle(fontSize: 14, color: AppTheme.accentGold)),
                const SizedBox(height: 8),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
  Widget _imageFallback() => Container(width: 60, height: 60, decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.local_bar, color: AppTheme.accentGold));
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyState({required this.hasFilters, required this.onClear});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
      const SizedBox(height: 16),
      const Text('NO COCKTAILS FOUND', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
      if (hasFilters) ...[const SizedBox(height: 16), TextButton(onPressed: onClear, child: const Text('CLEAR FILTERS'))],
    ]));
  }
}

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'data/database.dart';
import 'data/seed_data.dart';
import 'screens/cocktail_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/builder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = AppDatabase();
  await SeedData.seedDatabase(database);
  
  runApp(CocktailSpecsApp(database: database));
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
      themeMode: ThemeMode.dark, // Default to dark
      debugShowCheckedModeBanner: false,
      home: HomeScreen(database: database),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AppDatabase database;
  
  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      CocktailsListScreen(database: widget.database),
      BuilderScreen(database: widget.database),
      CollectionsScreen(
        database: widget.database,
        onSwitchToTab: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
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
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.accentGold,
          unselectedItemColor: AppTheme.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 11,
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
                child: Icon(Icons.local_bar, size: 24),
              ),
              label: 'Cocktails',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.science, size: 24),
              ),
              label: 'Builder',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.collections_bookmark, size: 24),
              ),
              label: 'Collections',
            ),
            BottomNavigationBarItem(
              icon: Padding(
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
  Set<String> selectedSpirits = {};  // Changed to Set for multi-select
  Set<String> selectedMethods = {};  // Changed to Set for multi-select
  Set<int> selectedDifficulties = {};  // Changed to Set for multi-select
  
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
  }

  void _applyFilters() {
    setState(() {
      filteredCocktails = allCocktails.where((cocktail) {
        // Search filter
        if (searchQuery.isNotEmpty &&
            !cocktail.name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
        
        // Spirit filter (OR logic - show if ANY selected spirit matches)
        if (selectedSpirits.isNotEmpty &&
            !selectedSpirits.contains(cocktail.baseSpirit)) {
          return false;
        }
        
        // Method filter (OR logic - show if ANY selected method matches)
        if (selectedMethods.isNotEmpty &&
            !selectedMethods.contains(cocktail.method)) {
          return false;
        }
        
        // Difficulty filter (OR logic - show if ANY selected difficulty matches)
        if (selectedDifficulties.isNotEmpty &&
            !selectedDifficulties.contains(cocktail.difficulty)) {
          return false;
        }
        
        return true;
      }).toList();
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
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedSpirits.isNotEmpty ||
      selectedMethods.isNotEmpty ||
      selectedDifficulties.isNotEmpty;

  int _getActiveFilterCount() {
    return selectedSpirits.length + selectedMethods.length + selectedDifficulties.length;
  }

  void _showFiltersSheet() {
    // Create temporary filter state
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
                  const Text(
                    'FILTERS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (tempSpirits.isNotEmpty || tempMethods.isNotEmpty || tempDifficulties.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSpirits.clear();
                          tempMethods.clear();
                          tempDifficulties.clear();
                        });
                      },
                      child: const Text(
                        'CLEAR ALL',
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Spirit Filter
              _FilterSection(
                label: 'SPIRIT',
                children: spirits.map((spirit) => _FilterChipMulti(
                  label: spirit,
                  isSelected: tempSpirits.contains(spirit),
                  onTap: () {
                    setModalState(() {
                      if (tempSpirits.contains(spirit)) {
                        tempSpirits.remove(spirit);
                      } else {
                        tempSpirits.add(spirit);
                      }
                    });
                  },
                )).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Method Filter
              _FilterSection(
                label: 'METHOD',
                children: methods.map((method) => _FilterChipMulti(
                  label: method.toUpperCase(),
                  isSelected: tempMethods.contains(method),
                  onTap: () {
                    setModalState(() {
                      if (tempMethods.contains(method)) {
                        tempMethods.remove(method);
                      } else {
                        tempMethods.add(method);
                      }
                    });
                  },
                )).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Difficulty Filter
              _FilterSection(
                label: 'DIFFICULTY',
                children: [1, 2, 3, 4, 5].map((diff) => _FilterChipMulti(
                  label: '$diff★',
                  isSelected: tempDifficulties.contains(diff),
                  onTap: () {
                    setModalState(() {
                      if (tempDifficulties.contains(diff)) {
                        tempDifficulties.remove(diff);
                      } else {
                        tempDifficulties.add(diff);
                      }
                    });
                  },
                )).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Apply Button
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedSpirits = tempSpirits;
                    selectedMethods = tempMethods;
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand Header
                  Container(
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
                              'THE BAR BIBLE',
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
                            'Essential Cocktail Reference',
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
                  
                  // Search and Filters
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Search
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search cocktails...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: hasActiveFilters
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearFilters,
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            searchQuery = value;
                            _applyFilters();
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Single Filters Button
                        ElevatedButton(
                          onPressed: _showFiltersSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasActiveFilters ? AppTheme.accentGold : AppTheme.surfaceDark,
                            foregroundColor: hasActiveFilters ? AppTheme.primaryDark : AppTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: hasActiveFilters ? AppTheme.accentGold : AppTheme.surfaceLight,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.filter_list, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                hasActiveFilters ? 'FILTERS (${_getActiveFilterCount()})' : 'FILTERS',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Active Filter Pills
                        if (hasActiveFilters) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...selectedSpirits.map((spirit) => _ActiveFilterPill(
                                label: spirit,
                                onRemove: () {
                                  setState(() {
                                    selectedSpirits.remove(spirit);
                                  });
                                  _applyFilters();
                                },
                              )),
                              ...selectedMethods.map((method) => _ActiveFilterPill(
                                label: method.toUpperCase(),
                                onRemove: () {
                                  setState(() {
                                    selectedMethods.remove(method);
                                  });
                                  _applyFilters();
                                },
                              )),
                              ...selectedDifficulties.map((diff) => _ActiveFilterPill(
                                label: '$diff★',
                                onRemove: () {
                                  setState(() {
                                    selectedDifficulties.remove(diff);
                                  });
                                  _applyFilters();
                                },
                              )),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Results count
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
                          '${filteredCocktails.length} ${filteredCocktails.length == 1 ? 'Cocktail' : 'Cocktails'}',
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
                  
                  // List
                  Expanded(
                    child: filteredCocktails.isEmpty
                        ? _EmptyState(hasFilters: hasActiveFilters, onClear: _clearFilters)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: filteredCocktails.length,
                            itemBuilder: (context, index) {
                              final cocktail = filteredCocktails[index];
                              return _CocktailCard(
                                cocktail: cocktail,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CocktailDetailScreen(
                                        database: widget.database,
                                        cocktail: cocktail,
                                      ),
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

class _FilterSection extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _FilterSection({
    required this.label,
    required this.children,
  });

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
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

  const _ActiveFilterPill({
    required this.label,
    required this.onRemove,
  });

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

class _CocktailCard extends StatelessWidget {
  final Cocktail cocktail;
  final VoidCallback onTap;

  const _CocktailCard({
    required this.cocktail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Row(
              children: [
                // Cocktail Image Thumbnail
                if (cocktail.imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      cocktail.imagePath!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_bar,
                            color: AppTheme.accentGold,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_bar,
                      color: AppTheme.accentGold,
                    ),
                  ),
                const SizedBox(width: 12),
                
                // Gold accent bar
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cocktail.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            cocktail.baseSpirit.toUpperCase(),
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
                          Text(
                            cocktail.method.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cocktail.glass,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Difficulty
                Column(
                  children: [
                    Text(
                      '★' * cocktail.difficulty,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.accentGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;

  const _EmptyState({
    required this.hasFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'NO COCKTAILS FOUND',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClear,
              child: const Text('CLEAR FILTERS'),
            ),
          ],
        ],
      ),
    );
  }
}

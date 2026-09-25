import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';
import 'my_bar_screen.dart';
import 'finder_screen.dart';

class MyBarTabScreen extends StatefulWidget {
  final AppDatabase database;

  const MyBarTabScreen({
    super.key,
    required this.database,
  });

  @override
  State<MyBarTabScreen> createState() => MyBarTabScreenState();
}

class MyBarTabScreenState extends State<MyBarTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void switchToIngredients() => _tabController.animateTo(0);
  void switchToCocktails() => _tabController.animateTo(1);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ColoredBox(
      color: AppTheme.primaryDark,
      child: Column(
        children: [
          SizedBox(height: topPadding),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: MyBarScreen(
                    database: widget.database,
                    onNavigateToFinder: switchToCocktails,
                  ),
                ),
                MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: FinderScreen(
                    database: widget.database,
                    categoryFilter: 'cocktail',
                    onNavigateToMyBar: switchToIngredients,
                  ),
                ),
                MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: FinderScreen(
                    database: widget.database,
                    categoryFilter: 'mocktail',
                    onNavigateToMyBar: switchToIngredients,
                  ),
                ),
                MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: FinderScreen(
                    database: widget.database,
                    categoryFilter: 'shot',
                    onNavigateToMyBar: switchToIngredients,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
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
          Tab(text: 'Ingredients'),
          Tab(text: 'Cocktails'),
          Tab(text: 'Mocktails'),
          Tab(text: 'Shots'),
        ],
      ),
    );
  }
}

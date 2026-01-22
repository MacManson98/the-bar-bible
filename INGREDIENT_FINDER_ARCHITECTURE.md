# 🏗️ Component Architecture

## Widget Hierarchy

```
BuilderScreen (StatefulWidget)
│
├─── SafeArea
│    └─── Column
│         ├─── _buildHeader()
│         │    └─── (Header with menu, title, substitutions toggle)
│         │
│         ├─── _buildSearchBar()
│         │    └─── TextField (for typing individual ingredients)
│         │         └─── _buildCategorizedDropdown() [when typing]
│         │
│         ├─── _buildSelectedIngredientsChips() [if ingredients selected]
│         │    └─── Wrap of Chips (gold chips showing selected items)
│         │
│         ├─── _buildQuickAddSection() [if no ingredients selected]  ⬅️ MODIFIED
│         │    └─── OutlinedButton "SELECT MULTIPLE INGREDIENTS"
│         │         └─── onPressed: _showQuickAddDialog()  ⬅️ NEW
│         │
│         ├─── _buildResultsHeader() [if ingredients selected]
│         │    └─── (Results count and sort dropdown)
│         │
│         └─── _buildResultsList()
│              └─── (Cocktail matches with perfect/close sections)
│
│
└─── _showQuickAddDialog() calls:  ⬅️ NEW METHOD
     └─── showModalBottomSheet()
          └─── _QuickAddBottomSheet ⬅️ NEW WIDGET
```

## _QuickAddBottomSheet Component Breakdown

```
_QuickAddBottomSheet (StatefulWidget)  ⬅️ NEW COMPONENT
│
└─── _QuickAddBottomSheetState (State)
     │
     │  STATE VARIABLES:
     │  ├─ tempSelectedIds: Set<int> (temporary selections)
     │  ├─ searchQuery: String (search text)
     │  └─ selectedCategory: String (filter selection)
     │
     └─── DraggableScrollableSheet
          └─── Container (dark background, rounded top)
               └─── Column
                    │
                    ├─── Handle Bar (drag indicator)
                    │
                    ├─── Header Row
                    │    ├─ "SELECT INGREDIENTS" title
                    │    └─ "X selected" counter
                    │
                    ├─── Search TextField
                    │    ├─ Magnifying glass icon
                    │    ├─ "Search ingredients..." hint
                    │    └─ Clear button (if text entered)
                    │
                    ├─── Category Filter Chips (horizontal scroll)
                    │    ├─ _buildCategoryChip('All', '📋')
                    │    ├─ _buildCategoryChip('Spirits', '🥃')
                    │    ├─ _buildCategoryChip('Liqueurs', '🍷')
                    │    ├─ _buildCategoryChip('Citrus', '🍋')
                    │    ├─ _buildCategoryChip('Syrups', '🍯')
                    │    ├─ _buildCategoryChip('Mixers', '🥤')
                    │    ├─ _buildCategoryChip('Bitters', '💧')
                    │    ├─ _buildCategoryChip('Garnish', '🌿')
                    │    └─ _buildCategoryChip('Other', '📦')
                    │
                    ├─── Divider
                    │
                    ├─── Ingredients List (scrollable, EXPANDED)
                    │    └─── ListView (grouped by category)
                    │         ├─ Category 1 Header ("🥃 SPIRITS")
                    │         ├─ CheckboxListTile (Vodka)
                    │         ├─ CheckboxListTile (Gin)
                    │         ├─ CheckboxListTile (White Rum)
                    │         ├─ ...
                    │         ├─ Category 2 Header ("🍋 CITRUS")
                    │         ├─ CheckboxListTile (Lime Juice)
                    │         └─ ...
                    │
                    └─── Bottom Action Bar
                         └─── Row
                              ├─ OutlinedButton "CANCEL"
                              │   └─ Navigator.pop() (no changes)
                              │
                              └─ ElevatedButton "ADD X INGREDIENTS"
                                  └─ onIngredientsSelected(tempSelectedIds)
                                      ├─ setState() on parent
                                      └─ Navigator.pop()
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                       BuilderScreen                              │
│                                                                  │
│  STATE:                                                          │
│  • selectedIngredientIds: Set<int>  ← Current selections       │
│  • allIngredients: List<Ingredient> ← Full database            │
│                                                                  │
└──────────────────────────────┬──────────────────────────────────┘
                                │
                                │ User taps button
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│              _showQuickAddDialog() METHOD                        │
│                                                                  │
│  showModalBottomSheet(                                          │
│    builder: (context) => _QuickAddBottomSheet(                 │
│      allIngredients: allIngredients,          ← Pass in        │
│      selectedIngredientIds: selectedIngredientIds, ← Pass in   │
│      onIngredientsSelected: (newIds) {       ← Callback        │
│        setState(() {                                            │
│          selectedIngredientIds = newIds;     ← Update parent   │
│          currentBar = null;                                     │
│        });                                                      │
│        _findMatchingCocktails();             ← Refresh results │
│      },                                                         │
│    ),                                                           │
│  );                                                             │
│                                                                  │
└──────────────────────────────┬──────────────────────────────────┘
                                │
                                │ Sheet opens
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│              _QuickAddBottomSheet                                │
│                                                                  │
│  RECEIVES:                                                       │
│  • allIngredients (from parent)                                 │
│  • selectedIngredientIds (from parent)                          │
│  • onIngredientsSelected callback                               │
│                                                                  │
│  CREATES LOCAL STATE:                                           │
│  • tempSelectedIds = Set.from(selectedIngredientIds)           │
│    ↑ Copy of selections for temporary editing                  │
│                                                                  │
│  USER INTERACTIONS:                                             │
│  ┌───────────────────────────────────────────────────┐         │
│  │ Search: "rum"                                      │         │
│  │   ↓                                                │         │
│  │ setState(() => searchQuery = "rum")               │         │
│  │   ↓                                                │         │
│  │ filteredIngredients getter recalculates            │         │
│  │   ↓                                                │         │
│  │ UI rebuilds showing only rums                      │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                  │
│  ┌───────────────────────────────────────────────────┐         │
│  │ Tap category filter: "Spirits"                     │         │
│  │   ↓                                                │         │
│  │ setState(() => selectedCategory = "Spirits")      │         │
│  │   ↓                                                │         │
│  │ filteredIngredients getter recalculates            │         │
│  │   ↓                                                │         │
│  │ UI rebuilds showing only spirits                   │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                  │
│  ┌───────────────────────────────────────────────────┐         │
│  │ Check "Vodka" checkbox                             │         │
│  │   ↓                                                │         │
│  │ setState(() => tempSelectedIds.add(vodkaId))      │         │
│  │   ↓                                                │         │
│  │ UI rebuilds:                                       │         │
│  │   • Checkbox becomes checked                       │         │
│  │   • Text turns gold and bold                       │         │
│  │   • Counter updates: "5 selected"                  │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                  │
│  ┌───────────────────────────────────────────────────┐         │
│  │ Tap "CANCEL" button                                │         │
│  │   ↓                                                │         │
│  │ Navigator.pop(context)                             │         │
│  │   ↓                                                │         │
│  │ Sheet closes, tempSelectedIds discarded            │         │
│  │ Parent state unchanged ✓                           │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                  │
│  ┌───────────────────────────────────────────────────┐         │
│  │ Tap "ADD X INGREDIENTS" button                     │         │
│  │   ↓                                                │         │
│  │ widget.onIngredientsSelected(tempSelectedIds)     │         │
│  │   ↓                                                │         │
│  │ Callback executes in parent BuilderScreen:        │         │
│  │   • setState() updates selectedIngredientIds      │         │
│  │   • currentBar = null                              │         │
│  │   • _findMatchingCocktails() runs                 │         │
│  │   ↓                                                │         │
│  │ Navigator.pop(context)                             │         │
│  │   ↓                                                │         │
│  │ Sheet closes                                       │         │
│  │   ↓                                                │         │
│  │ Parent rebuilds with new selections ✓              │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Filtering Logic Flow

```
filteredIngredients GETTER
│
├─ START with: widget.allIngredients (all ~200 ingredients)
│
├─ FILTER STEP 1: Category Filter
│  │
│  ├─ IF selectedCategory == 'All'
│  │  └─ Keep all ingredients
│  │
│  └─ ELSE (e.g., selectedCategory == 'Spirits')
│     └─ Filter to only: ingredients.where(i => i.category == 'Spirits')
│
├─ FILTER STEP 2: Search Filter
│  │
│  ├─ IF searchQuery.isEmpty
│  │  └─ Keep current filtered list
│  │
│  └─ ELSE (e.g., searchQuery == "rum")
│     └─ Further filter: where(i => i.name.toLowerCase().contains("rum"))
│
└─ RETURN: Final filtered list

THEN: Grouping happens in build()
│
└─ Group filtered ingredients by category
   └─ Create Map<String, List<Ingredient>>
      └─ Used to render category headers + checkboxes
```

## State Management Summary

### BuilderScreen State (Parent)
- **selectedIngredientIds**: The REAL selections (what's actually active)
- **allIngredients**: Full database of ingredients
- **Persists across**: Sheet opening/closing

### _QuickAddBottomSheet State (Child)
- **tempSelectedIds**: TEMPORARY selections (during editing)
- **searchQuery**: Current search text
- **selectedCategory**: Current category filter
- **Lifecycle**: 
  - CREATED when sheet opens (copies selectedIngredientIds)
  - MODIFIED as user interacts
  - APPLIED when "ADD" is pressed (via callback)
  - DISCARDED when "CANCEL" is pressed or sheet closes

### Key Design Decision
Using **tempSelectedIds** allows:
1. ✅ User can experiment with selections
2. ✅ Changes don't affect parent until confirmed
3. ✅ Cancel button truly cancels (discards temp state)
4. ✅ No unwanted cocktail result updates while browsing
5. ✅ Single state update when user commits (better performance)

---

This architecture ensures a smooth UX with proper separation of concerns and predictable state management! 🎯

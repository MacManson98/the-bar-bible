# 🧹 CLEANUP - OBSOLETE FILES TO DELETE

## Files to DELETE (Obsolete from ingredient-based approach):

### 1. **bar_setup_quick_screen.dart** ❌
- The "Professional Bar / Well-Stocked / Home Bar" preset screen
- No longer needed with taste-based onboarding
- DELETE IT

### 2. **home_screen_NEW.dart** ❌
- Backup/test file
- Not used anywhere
- DELETE IT

### 3. **missing_ingredient_section.dart** ❌
- Widget for "1 ingredient away" upsell
- Meaningless without exact ingredient tracking
- DELETE IT

### 4. **recommendation_service.dart** ❌  
- Old ingredient-based recommendation logic
- Replaced by `taste_profile_service.dart`
- DELETE IT

## Imports to REMOVE from home_screen.dart:

```dart
// REMOVE THESE:
import '../widgets/missing_ingredient_section.dart';
import 'builder_screen.dart';
import 'bar_setup_quick_screen.dart';
```

## Methods to REMOVE from home_screen.dart:

If these still exist:
- `_openBarInventory()`
- `_showQuickSetup()`
- `_buildBarSetupUpsell()`

## Files to KEEP:

✅ **taste_profile_onboarding_screen.dart** - New swipeable cards
✅ **taste_profile_service.dart** - New taste-based recommendations
✅ **home_screen.dart** - Updated for taste-based flow
✅ **bartenders_choice_card.dart** - Still used for hero card
✅ **cocktail_scroll_section.dart** - Still used for horizontal scroll
✅ **builder_screen.dart** - Keep for future ingredient tracking feature
✅ **cocktail_detail_screen.dart** - Core functionality
✅ **collections_screen.dart** - Core functionality
✅ **community_screen.dart** - Core functionality
✅ **settings_screen.dart** - Core functionality
✅ **favorite_button.dart** - Core functionality
✅ **add_cocktails_dialog.dart** - Admin functionality

## Summary:

**DELETE 4 files:**
1. bar_setup_quick_screen.dart
2. home_screen_NEW.dart
3. missing_ingredient_section.dart
4. recommendation_service.dart

**CLEAN 1 file:**
- home_screen.dart (remove unused imports)

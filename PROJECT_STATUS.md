# The Bar Bible - Project Status Report
**Last Updated:** January 21, 2026

---

## 📱 App Overview
A Flutter/Dart mobile app for bartenders featuring an offline cocktail specification database with collections, search, and filtering capabilities.

---

## ✅ Completed Features (MVP)

### 1. **Core Database & Architecture**
- **Database:** SQLite via Drift (schema version 5)
- **Tables:**
  - `Cocktails` - Main cocktail data (13 seeded cocktails)
  - `Ingredients` - Ingredient master list
  - `CocktailIngredients` - Junction table (cocktail recipes)
  - `Collections` - User-created collections
  - `CollectionCocktails` - Junction table (cocktails in collections)
- **Migrations:** Properly handling schema upgrades from v1 → v5
- **Seed Data:** 13 fully detailed cocktails with images

### 2. **Navigation & UI Structure**
- **Bottom Navigation Bar** with 4 tabs:
  1. 🍸 **Cocktails** - Browse and search all cocktails
  2. 🧪 **Builder** - Find cocktails by ingredients you have
  3. 📚 **Collections** - Manage custom collections
  4. ⚙️ **Settings** - App preferences
- **Dark Theme** with gold (#D4AF37) accents
- Clean, modern, bartender-friendly design

### 3. **Cocktails List Screen**
- **Search:** Real-time search by cocktail name
- **Multi-Select Filters:**
  - Spirit (Gin, Vodka, Rum, Bourbon, Whiskey, Brandy, Cognac, Other)
  - Method (Shake, Stir, Build)
  - Difficulty (1-5 stars)
- **Filter UI:** Bottom sheet with chips (multi-select)
- **Active Filter Indicator:** Gold button shows filter count
- **Cocktail Cards:** 
  - Thumbnail image (or fallback icon)
  - Gold accent bar
  - Name, spirit, method, glass
  - Tap to view details

### 4. **Cocktail Builder Screen** ✨ NEW
- **Ingredient-Based Search:** Find cocktails based on what you have in your bar
- **Your Bar Section:**
  - Select ingredients from searchable list
  - Gold chips showing selected ingredients
  - Remove ingredients with X button
  - "CLEAR ALL" button to reset
  - Empty state with "ADD INGREDIENTS" CTA
- **Ingredient Picker:**
  - Full-screen bottom sheet modal
  - Search bar to filter ingredients
  - Check/uncheck ingredients
  - Visual indication of selected items (gold border + check icon)
  - "DONE" button shows count of selected ingredients
- **Smart Matching System:**
  - **Perfect Matches:** Cocktails where you have ALL ingredients
    - Gold border highlighting
    - Green check icon
    - "You have all X ingredients" message
  - **Close Matches:** Cocktails where you have 50%+ ingredients
    - Orange warning icon
    - Shows missing ingredients list
    - Still clickable to view full recipe
  - Sorted by match percentage (perfect first, then close)
- **Results Display:**
  - Cocktail cards with match status
  - Tap card to view full cocktail detail
  - Empty state when no matches found
  - Clear messaging when no ingredients selected
- **Real-time Updates:** Results refresh immediately when ingredients change

### 5. **Cocktail Detail Screen**
- **Collapsible Hero Image Header** (expands/collapses on scroll)
- **Metadata Chips:** Glass type, difficulty, method icon
- **Ingredients Section:**
  - Full list with amounts (ml units)
  - Prep notes (e.g., "fresh", "muddled")
- **Method Section:**
  - Numbered step-by-step instructions
  - Visual icons for shake/stir/build
- **Garnish:** Single-line display
- **History Section:** Collapsible origin/story
- **Add to Collection FAB:** Small circular bookmark button (gold)

### 6. **Collections System**
- **Create Collections:**
  - Name (required)
  - Description (optional)
  - Dialog-based creation flow
- **Collections List:**
  - Grid/list of all collections
  - Shows cocktail count per collection
  - Bookmark icon with gold background
  - Delete with confirmation
- **Collection Detail Screen:**
  - View all cocktails in collection
  - Tap cocktail to view full specs
  - Remove cocktails from collection
  - "ADD COCKTAILS" FAB (extended button)
  - Empty state with "Add Cocktails" CTA

### 7. **Add to Collection Feature**
- **From Cocktail Detail Screen:** Small FAB with bookmark icon
- **From Collection Screen:** Large "ADD COCKTAILS" button
- **Add Cocktails Dialog:**
  - Full-screen dialog with search + filters
  - Same filter system as main list (spirit, method, difficulty)
  - Cocktail cards with checkboxes
  - Gold border + check icon for selected cocktails
  - Tap anywhere on card to toggle
  - Live updates (no need to refresh)
  - "DONE" button at bottom
  - Filter count badge when active

### 8. **Settings Screen**
- **Unit Preference:** ml / oz toggle
- Clean, simple UI
- Persistent storage for preferences

### 8. **Data Pipeline (Current)**
- **Seed Data:** Hardcoded in code (13 cocktails)
- **Images:** Stored in `assets/images/cocktails/`
- **Future:** CSV → SQLite conversion pipeline (designed but not implemented)

---

## 🗂️ File Structure

```
lib/
├── main.dart                          # App entry, bottom nav, home screen
├── core/
│   └── theme/
│       └── app_theme.dart             # Colors, text styles, theme
├── data/
│   ├── database.dart                  # Drift database schema
│   ├── database.g.dart                # Generated Drift code
│   └── seed_data.dart                 # 13 seeded cocktails
└── screens/
    ├── cocktail_detail_screen.dart    # Cocktail specs view
    ├── builder_screen.dart            # Cocktail builder (ingredient-based search) ✨ NEW
    ├── collections_screen.dart        # Collections list + detail screens
    ├── add_cocktails_dialog.dart      # Dialog for adding cocktails to collection
    └── settings_screen.dart           # App settings

assets/
└── images/
    └── cocktails/
        ├── margarita.jpg
        ├── negroni.jpg
        └── ... (13 images total)
```

---

## 🎨 Design System

### Colors
- **Primary Dark:** `#0A0E12` (background)
- **Surface Dark:** `#161B22` (cards)
- **Surface Light:** `#21262D` (borders)
- **Accent Gold:** `#D4AF37` (primary actions)
- **Text Primary:** `#E6EDF3` (main text)
- **Text Secondary:** `#8B949E` (secondary text)

### Typography
- **Headers:** Bold, wide letter spacing (1.5-2.0)
- **Body:** 14-16px, readable
- **Labels:** 11-13px, uppercase, tight spacing

### Components
- **Cards:** 12-16px border radius, subtle borders
- **Buttons:** Gold background, dark text, bold uppercase labels
- **FABs:** Gold background, circular or extended
- **Bottom Sheets:** Rounded top corners (20px)
- **Filter Chips:** Toggle between gray and gold

---

## 📊 Seeded Cocktails (13 Total)

Full data available for:
1. Margarita
2. Old Fashioned
3. Negroni
4. Mojito
5. Martini (Dry)
6. Manhattan
7. Daiquiri
8. Whiskey Sour
9. Gin & Tonic
10. Aperol Spritz
11. Espresso Martini
12. Moscow Mule
13. Cosmopolitan

Each includes:
- Complete ingredient list with amounts
- Step-by-step method
- History/origin
- Glass, ice, garnish
- Difficulty rating
- High-quality image

---

## 🔧 Technical Details

### State Management
- **Simple setState()** - No complex state management needed for MVP
- Repository pattern separates DB from UI

### Database
- **Drift 2.x** (formerly Moor) - Type-safe SQL for Flutter
- **Schema Version:** 5
- **Storage:** `getApplicationDocumentsDirectory()/cocktails.sqlite`
- **Migrations:** Handled in `AppDatabase.migration`

### Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  drift: ^2.x
  drift_flutter: ^0.x
  path_provider: ^2.x
  path: ^1.x
```

### Build Commands
```bash
# Generate Drift code
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run

# Clean build
flutter clean && flutter pub get
```

---

## 🚧 Known Issues & Limitations

### Fixed Issues
- ✅ Collections not showing cocktails after restart (fixed - was orphaned junction table data)
- ✅ Duplicate "ADD COCKTAILS" buttons (fixed - FAB only shows when collection has items)
- ✅ Large FAB covering text on detail screen (fixed - made it smaller circular button)

### Current Limitations
1. **Only 13 cocktails** - Need ~287 more for 300 total
2. **No ml/oz conversion** - Setting exists but not implemented
3. **No copy spec button** - Planned but not implemented
4. **No sort options** - Only filters, no sort by name/difficulty
5. **No "Service Mode"** - Bigger text mode planned but not built
6. **Images hard-coded** - Need better asset management for 300 cocktails

---

## 📋 Next Steps (Priority Order)

### Phase 1: Complete MVP
1. **Implement ml/oz Conversion**
   - Read setting from database
   - Apply conversion in ingredient display
   - Toggle between units in detail screen

2. **Add Remaining Cocktails (287 more)**
   - Decision needed: Manual entry vs. AI generation
   - Implement CSV import pipeline
   - Add all images

3. **Copy Spec Button**
   - Copy full recipe to clipboard
   - Format: Name, Ingredients, Method, Garnish

4. **Sort Options**
   - Alphabetical (A-Z, Z-A)
   - Difficulty (Easy to Hard, Hard to Easy)
   - Spirit type

### Phase 2: Backend & Community
5. **Firebase Setup**
   - Firebase Auth (email + Google/Apple)
   - Firestore for cloud data
   - Cloud Functions for moderation
   - Storage for user-uploaded images

6. **User Accounts**
   - Sign up / sign in
   - Profile management
   - Sync collections across devices

7. **Community Features**
   - Submit cocktail recipes
   - Rate cocktails (1-5 stars)
   - Write reviews
   - Report inappropriate content
   - Admin moderation panel

### Phase 3: Venue/Team Features
8. **Venue Management**
   - Create venue
   - Invite staff (QR code / link)
   - Roles: Owner, Manager, Staff
   - Venue-specific cocktail lists

9. **Venue Overrides**
   - Managers can modify specs for their venue
   - Store only differences from official recipe
   - Staff see venue version
   - Change log / audit trail

### Phase 4: Monetization
10. **Subscriptions (RevenueCat)**
    - **Free:** Browse official cocktails, basic filters
    - **Premium Individual ($4.99/mo):**
      - Submit cocktails
      - Unlimited collections
      - Personal notes on recipes
      - No ads
    - **Venue Plan ($19.99/mo):**
      - All Premium features
      - Venue management
      - Team collaboration
      - Custom venue specs
      - Analytics

---

## 🎯 Project Goals Recap

### MVP Goals (Current Phase) ✅
- [x] Offline cocktail specs database
- [x] Search functionality
- [x] Multi-select filters
- [x] Collections system
- [x] Clean, bartender-friendly UI
- [ ] Complete 300 cocktails
- [ ] ml/oz conversion

### Future Goals
- [ ] User accounts + auth
- [ ] Community cocktail submissions
- [ ] Ratings & reviews
- [ ] Venue/team management
- [ ] Premium subscriptions
- [ ] Cross-platform sync

---

## 💡 Design Decisions Made

1. **Bottom nav over drawer** - Faster access for bartenders
2. **Dark theme** - Better for low-light bar environments
3. **Gold accents** - Premium, sophisticated feel
4. **Multi-select filters** - More powerful than single-select
5. **Collections over simple favorites** - More flexible organization
6. **Circular FAB for detail screen** - Less intrusive than extended
7. **Extended FAB for collection screen** - More discoverable
8. **Inline remove buttons** - Quick access without dialogs
9. **Bottom sheet filters** - Mobile-friendly, thumb-accessible
10. **Join query for collections** - Efficient, normalized database design

---

## 🐛 Debugging Tips

### Clear Database
If you encounter data issues:
1. Long press app icon → App Info
2. Storage → Clear Data
3. Restart app

### Check Logs
Key debug emojis in console:
- 🔍 Loading cocktails
- 📊 Junction table entries
- ➕ Adding to collection
- ❌ Removing from collection
- ✅ Operation successful
- 🍸 Query results

### Rebuild Generated Files
If Drift code is out of sync:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 📸 Screenshots Reference

### Main Screens
1. **Cocktails List** - Grid of cocktail cards with filters
2. **Cocktail Detail** - Full specs with collapsible image
3. **Collections** - List of user collections with counts
4. **Collection Detail** - Cocktails in a specific collection
5. **Add Cocktails Dialog** - Full-screen selection with filters
6. **Settings** - Unit preference toggle

### Key UI Elements
- Bottom navigation (3 tabs)
- Search bar with icon
- Filter button (gold when active)
- Filter bottom sheet (chips for multi-select)
- Cocktail cards (thumbnail, gold bar, metadata)
- FAB buttons (circular and extended)
- Empty states (icon, text, CTA button)

---

## 📝 Notes for Future Development

### Data Entry Strategy
**Option A:** Manual entry in Google Sheets → CSV export
**Option B:** Use AI (Claude) to generate from IBA list + research
**Option C:** Hire bartender consultant for accuracy

### Image Strategy
**Current:** 13 high-quality photos in assets
**Future:** 
- Use AI image generation (DALL-E, Midjourney)
- License stock photos
- Commission photographer for consistency

### Performance Considerations
- 300 cocktails = ~600KB of text data (reasonable)
- 300 images at ~100KB each = ~30MB (compress to ~50KB each → 15MB)
- Lazy load images in lists
- Cache frequently accessed data

### Offline-First Philosophy
- All official specs work without internet
- Sync collections to cloud (when online)
- Queue community submissions for upload
- Download updates in background

---

## 🎓 Lessons Learned

1. **Start with simple state management** - setState() is fine for MVP
2. **Drift is powerful** - Type-safe SQL queries prevent bugs
3. **Design system first** - Consistent colors/spacing saves time
4. **Bottom sheets > Dialogs** - Better mobile UX
5. **Debug early** - Emoji logs helped find the junction table issue quickly
6. **Clear separation of concerns** - Repository pattern makes testing easier
7. **Schema versioning matters** - Migrations prevent data loss
8. **Empty states are important** - Guide users on what to do next

---

## 🚀 Ready for Next Phase

The MVP is **95% complete**. Remaining work:
1. Add 287 cocktails (data entry)
2. Implement ml/oz conversion (1-2 hours)
3. Add copy spec button (1 hour)
4. Polish empty states and error handling (2 hours)

**Total estimated time to complete MVP:** ~40 hours (mostly data entry)

After MVP, ready to begin Phase 2 (Backend & Community features).

---

## 📞 Contact & Resources

- **Project:** The Bar Bible
- **Framework:** Flutter 3.x + Dart
- **Database:** Drift (SQLite)
- **Platform:** Android + iOS (tested on Android)
- **Development Status:** MVP - Feature Complete, Content Incomplete

---

*Document created by Claude AI assistant*
*Project developed collaboratively with user*

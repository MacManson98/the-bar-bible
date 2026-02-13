#!/usr/bin/env python3
"""
Export cocktails from NocoDB to SQLite database.
Includes automatic cleanup: duplicate merging, category normalisation,
and ingredient name canonicalisation.

Usage:
  python export_cocktails.py [output_path]
  
  Default output: ./cocktails.db
"""
import sqlite3
import requests
import sys
import re

NOCODB_URL = "http://192.168.1.212:8080"
NOCODB_TOKEN = "lGgTK2mOKnXzrK7FBZdqSKxzzvGDqyMM6kp5J-ir"
PROJECT_ID = "p9s2ae5d7585acx"
COCKTAILS_TABLE = "mzp7a52otwqom4u"
INGREDIENTS_TABLE = "mx2b4ltaj61s5da"

# ═══════════════════════════════════════════════════════
# CLEANUP RULES — edit these when you add/change data
# ═══════════════════════════════════════════════════════

# Ingredient name canonicalisation: maps variant names → canonical name.
# Both the key and the recipes referencing it will use the canonical name.
NAME_FIXES = {
    'Angostura bitters': 'Angostura Bitters',
    'Lemon juice':       'Lemon Juice',
    'Marachino Luxardo': 'Maraschino Luxardo',
    'Bitter Campari':    'Campari',
    'Fernet':            'Fernet Branca',
    'Sweet Red Vermouth':'Sweet Vermouth',
    'Maraschino luxardo':'Maraschino Luxardo',
}

# Category overrides: ingredient name → correct category.
# Applied AFTER name canonicalisation.
CATEGORY_OVERRIDES = {
    # Citrus (split from Juices)
    'Lemon Juice':      'Citrus',
    'Lime Juice':       'Citrus',
    'Grapefruit Juice': 'Citrus',

    # Juices (keep these as Juices, not Citrus)
    'Cranberry Juice':                'Juices',
    'Freshly Squeezed Orange Juice':  'Juices',
    'Orange juice':                   'Juices',
    'Pineapple Juice':                'Juices',
    'Tomato Juice':                   'Juices',

    # Spirits (from Other / wrong category)
    "Gosling\u2019s Rum":         'Spirits',
    "Gosling's Rum":              'Spirits',
    'Ron Profundo Havana Club': 'Spirits',
    'Ron Smoky Havana Club':    'Spirits',
    'Ginger Ale':               'Mixers',  # was in Spirits!

    # Liqueurs (merge Vermouth category + fix Others)
    'Sweet Vermouth':    'Liqueurs',
    'Dry Vermouth':      'Liqueurs',
    'Absinthe':          'Liqueurs',
    'Fernet Branca':     'Liqueurs',
    'Frangelico':        'Liqueurs',
    'Lillet Blanc':      'Liqueurs',
    'Green Chartreuse':  'Liqueurs',
    'Campari':           'Liqueurs',
    'Grand Marnier':     'Liqueurs',
    'Falernum':          'Liqueurs',
    'Maraschino Luxardo':'Liqueurs',

    # Sweeteners (sugars + syrups + honey)
    'Sugar':             'Sweeteners',
    'Sugar Cube':        'Sweeteners',
    'Superfine Sugar':   'Sweeteners',
    'White Cane Sugar':  'Sweeteners',
    'Honey':             'Sweeteners',
    'Raw Honey':         'Sweeteners',
    'Honey Syrup':       'Sweeteners',
    'Sugar Syrup':       'Sweeteners',
    'Raspberry Syrup':   'Sweeteners',
    'Passionfruit Syrup':'Sweeteners',

    # Garnish
    'Basil Leaves':      'Garnish',
    'Gengibre Slice':    'Garnish',
    'Lime':              'Garnish',

    # Coffee
    'Hot Coffee':        'Coffee',
    'Strong Espresso':   'Coffee',

    # Other (keep)
    'Egg White':            'Other',
    'Fresh Cream':          'Other',
    'Passionfruit Puree':   'Other',
    'White Peach Puree':    'Other',
    'Celery Salt':          'Other',
    'Pepper':               'Other',
    'Tabasco':              'Other',
    'Worcestershire Sauce': 'Other',

    # Mixers
    'Champagne':  'Mixers',
    'Prosecco':   'Mixers',
}


def fetch_nocodb_table(table_id):
    """Fetch all records from a NocoDB table with pagination"""
    headers = {"xc-token": NOCODB_TOKEN}
    url = f"{NOCODB_URL}/api/v2/tables/{table_id}/records"
    
    all_records = []
    offset = 0
    limit = 100
    
    while True:
        response = requests.get(url, headers=headers, params={"limit": limit, "offset": offset})
        if response.status_code != 200:
            print(f"❌ Error: {response.status_code} - {response.text}")
            return []
        data = response.json()
        records = data.get('list', [])
        if not records:
            break
        all_records.extend(records)
        print(f"  Fetched {len(records)} records (total: {len(all_records)})")
        offset += limit
        if len(records) < limit:
            break
    
    return all_records


def canonicalise_ingredient(name):
    """Apply name fixes to get the canonical ingredient name."""
    name = name.strip()
    return NAME_FIXES.get(name, name)


def resolve_category(ingredient_name, raw_category):
    """Determine the correct category for an ingredient."""
    # Override takes priority
    if ingredient_name in CATEGORY_OVERRIDES:
        return CATEGORY_OVERRIDES[ingredient_name]
    # Otherwise use what NocoDB says
    return raw_category.strip() if raw_category else 'Other'


def generate_image_path(cocktail_name):
    """Generate image path from cocktail name (no extension)."""
    clean_name = re.sub(r'[^a-z0-9]', '', cocktail_name.lower())
    return f"assets/images/cocktails/{clean_name}"


def create_database(output_path):
    """Create SQLite database from NocoDB data"""
    
    print("🚀 Fetching cocktails...")
    cocktails_data = fetch_nocodb_table(COCKTAILS_TABLE)
    print(f"✅ Got {len(cocktails_data)} cocktails\n")
    
    print("🚀 Fetching ingredients...")
    ingredients_data = fetch_nocodb_table(INGREDIENTS_TABLE)
    print(f"✅ Got {len(ingredients_data)} ingredient entries\n")
    
    if not cocktails_data:
        print("❌ No cocktails fetched! Check API token and table ID")
        return
    
    if not ingredients_data:
        print("❌ No ingredients fetched! Check table ID")
        return
    
    # ── Pre-process ingredients: canonicalise names, resolve categories ──
    print("🧹 Cleaning ingredient data...")
    
    unique_ingredients = {}  # canonical_name → category
    relationships = []
    dupes_fixed = 0
    cats_fixed = 0
    
    for ing in ingredients_data:
        raw_name = ing.get('ingredient_name', '').strip()
        amount_ml = ing.get('amount_ml')
        raw_category = ing.get('category', 'Other')
        
        if not raw_name or not amount_ml:
            continue
        
        # Canonicalise name
        canonical_name = canonicalise_ingredient(raw_name)
        if canonical_name != raw_name:
            dupes_fixed += 1
        
        # Resolve category
        category = resolve_category(canonical_name, raw_category)
        if category != raw_category.strip():
            cats_fixed += 1
        
        # Track unique ingredients (first category wins, but overrides always win)
        if canonical_name not in unique_ingredients:
            unique_ingredients[canonical_name] = category
        elif canonical_name in CATEGORY_OVERRIDES:
            unique_ingredients[canonical_name] = CATEGORY_OVERRIDES[canonical_name]
        
        # Track relationships
        relationships.append({
            'cocktail_id': ing.get('cocktail_id'),
            'ingredient_name': canonical_name,
            'amount': amount_ml,
            'prep_note': ing.get('prep_note', '')
        })
    
    print(f"  Fixed {dupes_fixed} duplicate name references")
    print(f"  Fixed {cats_fixed} category assignments")
    print(f"  {len(unique_ingredients)} unique ingredients")
    print(f"  {len(relationships)} relationships\n")
    
    # ── Validation report ──
    print("📋 Category breakdown:")
    from collections import defaultdict
    by_cat = defaultdict(list)
    for name, cat in sorted(unique_ingredients.items()):
        by_cat[cat].append(name)
    for cat in sorted(by_cat.keys()):
        print(f"  {cat:14s} ({len(by_cat[cat])}): {', '.join(sorted(by_cat[cat]))}")
    print()
    
    # ── Create database ──
    print("🔨 Creating database...")
    conn = sqlite3.connect(output_path)
    cursor = conn.cursor()
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS cocktails (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            method TEXT NOT NULL,
            method_instructions TEXT,
            glass TEXT NOT NULL,
            difficulty INTEGER NOT NULL,
            base_spirit TEXT NOT NULL,
            ice TEXT,
            garnish TEXT,
            tags TEXT,
            history TEXT,
            tasting_notes TEXT,
            image_path TEXT
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL DEFAULT 'Other'
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS cocktail_ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cocktail_id INTEGER NOT NULL,
            ingredient_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            unit TEXT NOT NULL,
            prep_note TEXT,
            FOREIGN KEY (cocktail_id) REFERENCES cocktails(id),
            FOREIGN KEY (ingredient_id) REFERENCES ingredients(id)
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS favorites (
            cocktail_id INTEGER PRIMARY KEY,
            favorited_at INTEGER NOT NULL,
            FOREIGN KEY (cocktail_id) REFERENCES cocktails(id) ON DELETE CASCADE
        )
    ''')
    
    print("✅ Tables created\n")
    
    # ── Insert cocktails ──
    print("🍸 Inserting cocktails...")
    cocktail_map = {}
    
    for c in cocktails_data:
        name = c.get('name', '').strip()
        if not name:
            continue
        
        image_path = generate_image_path(name)
        
        cursor.execute('''
            INSERT INTO cocktails (name, method, method_instructions, glass, difficulty, base_spirit, ice, garnish, tags, history, tasting_notes, image_path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            name,
            c.get('method', ''),
            c.get('method_instructions', ''),
            c.get('glass', ''),
            int(c.get('difficulty', 2)),
            c.get('base_spirit', ''),
            c.get('ice', ''),
            c.get('garnish', ''),
            c.get('tags', ''),
            c.get('history', ''),
            c.get('tasting_notes', ''),
            image_path
        ))
        
        cocktail_map[c.get('cocktail_id')] = cursor.lastrowid
    
    print(f"  ✅ Inserted {len(cocktail_map)} cocktails")
    
    # ── Insert ingredients ──
    print("\n📝 Inserting ingredients...")
    ingredient_map = {}
    for name, category in unique_ingredients.items():
        cursor.execute('INSERT OR IGNORE INTO ingredients (name, category) VALUES (?, ?)', (name, category))
        cursor.execute('SELECT id FROM ingredients WHERE name = ?', (name,))
        ingredient_map[name] = cursor.fetchone()[0]
    print(f"  ✅ Inserted {len(ingredient_map)} ingredients")
    
    # ── Create relationships ──
    print("\n🔗 Creating relationships...")
    inserted = 0
    skipped = 0
    for rel in relationships:
        cocktail_id = cocktail_map.get(rel['cocktail_id'])
        ingredient_id = ingredient_map.get(rel['ingredient_name'])
        
        if cocktail_id and ingredient_id:
            amount = rel['amount']
            try:
                amount_value = float(amount)
                prep_note = rel['prep_note']
            except (ValueError, TypeError):
                amount_value = 0
                prep_note = str(amount) if amount else rel['prep_note']
            
            cursor.execute('''
                INSERT INTO cocktail_ingredients (cocktail_id, ingredient_id, amount, unit, prep_note)
                VALUES (?, ?, ?, ?, ?)
            ''', (cocktail_id, ingredient_id, amount_value, 'ml', prep_note))
            inserted += 1
        else:
            skipped += 1
            if not cocktail_id:
                print(f"  ⚠️  No cocktail for cocktail_id={rel['cocktail_id']}")
            if not ingredient_id:
                print(f"  ⚠️  No ingredient for '{rel['ingredient_name']}'")
    
    print(f"  ✅ Created {inserted} relationships")
    if skipped:
        print(f"  ⚠️  Skipped {skipped} (missing cocktail or ingredient)")
    
    # ── Verify ──
    conn.commit()
    
    print(f"\n{'='*50}")
    print(f"✅ SUCCESS! Database created: {output_path}")
    print(f"   📊 {len(cocktail_map)} cocktails")
    print(f"   📊 {len(ingredient_map)} ingredients")
    print(f"   📊 {inserted} relationships")
    print(f"   ❤️  Favorites table created (empty)")
    print(f"\n💡 Image paths stored WITHOUT extensions")
    print(f"   Example: 'assets/images/cocktails/betweenthesheets'")
    
    conn.close()


if __name__ == "__main__":
    output_file = sys.argv[1] if len(sys.argv) > 1 else "./cocktails.db"
    create_database(output_file)

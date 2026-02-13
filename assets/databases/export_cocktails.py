#!/usr/bin/env python3
import sqlite3
import requests
import sys
import re

NOCODB_URL = "http://192.168.1.212:8080"
NOCODB_TOKEN = "lGgTK2mOKnXzrK7FBZdqSKxzzvGDqyMM6kp5J-ir"
PROJECT_ID = "p9s2ae5d7585acx"
COCKTAILS_TABLE = "mzp7a52otwqom4u"
INGREDIENTS_TABLE = "mx2b4ltaj61s5da"

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
        if len(records) < limit:  # Last page
            break
    
    return all_records

def generate_image_path(cocktail_name):
    """
    Generate image path from cocktail name.
    Examples:
        "Between The Sheets" -> "assets/images/cocktails/betweenthesheets"
        "Old Fashioned" -> "assets/images/cocktails/oldfashioned"
    
    Returns path WITHOUT extension - app will check for .png, .jpg, .webp
    """
    # Remove all non-alphanumeric characters and convert to lowercase
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
    
    # Create database
    print("🔨 Creating database...")
    conn = sqlite3.connect(output_path)
    cursor = conn.cursor()
    
    # Create cocktails table
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
            image_path TEXT
        )
    ''')
    
    # Create ingredients table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL DEFAULT 'Other'
        )
    ''')
    
    # Create junction table
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
    
    # Create favorites table (empty - users will populate it)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS favorites (
            cocktail_id INTEGER PRIMARY KEY,
            favorited_at INTEGER NOT NULL,
            FOREIGN KEY (cocktail_id) REFERENCES cocktails(id) ON DELETE CASCADE
        )
    ''')
    
    print("✅ Tables created\n")
    
    # Insert cocktails
    print("🍸 Inserting cocktails...")
    cocktail_map = {}  # Maps NocoDB cocktail_id to SQLite id
    
    for c in cocktails_data:
        name = c.get('name', '').strip()
        if not name:
            continue
        
        # Generate image path WITHOUT extension
        image_path = generate_image_path(name)
        
        cursor.execute('''
            INSERT INTO cocktails (name, method, method_instructions, glass, difficulty, base_spirit, ice, garnish, tags, history, image_path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            image_path
        ))
        
        # Map NocoDB cocktail_id to SQLite ROWID
        cocktail_map[c.get('cocktail_id')] = cursor.lastrowid
    
    print(f"  ✅ Inserted {len(cocktail_map)} cocktails")
    
    # Process ingredients
    print("\n🔍 Processing ingredients...")
    unique_ingredients = {}
    relationships = []
    
    for ing in ingredients_data:
        ingredient_name = ing.get('ingredient_name', '').strip()
        amount_ml = ing.get('amount_ml')
        category = ing.get('category', 'Other')
        
        if not ingredient_name or not amount_ml:
            continue
        
        # Track unique ingredients
        if ingredient_name not in unique_ingredients:
            unique_ingredients[ingredient_name] = category
        
        # Track relationships
        relationships.append({
            'cocktail_id': ing.get('cocktail_id'),
            'ingredient_name': ingredient_name,
            'amount': amount_ml,  # Keep as-is (could be number or text like "4 Dashes")
            'prep_note': ing.get('prep_note', '')
        })
    
    print(f"  Found {len(unique_ingredients)} unique ingredients")
    print(f"  Found {len(relationships)} relationships")
    
    # Insert ingredients
    print("\n🔍 Inserting ingredients...")
    ingredient_map = {}
    for name, category in unique_ingredients.items():
        cursor.execute('INSERT INTO ingredients (name, category) VALUES (?, ?)', (name, category))
        ingredient_map[name] = cursor.lastrowid
    print(f"  ✅ Inserted {len(ingredient_map)} ingredients")
    
    # Create relationships
    print("\n🔗 Creating relationships...")
    inserted = 0
    for rel in relationships:
        cocktail_id = cocktail_map.get(rel['cocktail_id'])
        ingredient_id = ingredient_map.get(rel['ingredient_name'])
        
        if cocktail_id and ingredient_id:
            # Handle amount - could be number or text
            amount = rel['amount']
            try:
                # Try to convert to float
                amount_value = float(amount)
            except (ValueError, TypeError):
                # If it's text like "4 Dashes", store as 0 and put full text in prep_note
                amount_value = 0
                prep_note = str(amount) if amount else rel['prep_note']
            else:
                prep_note = rel['prep_note']
            
            cursor.execute('''
                INSERT INTO cocktail_ingredients (cocktail_id, ingredient_id, amount, unit, prep_note)
                VALUES (?, ?, ?, ?, ?)
            ''', (cocktail_id, ingredient_id, amount_value, 'ml', prep_note))
            inserted += 1
    
    print(f"  ✅ Created {inserted} relationships")
    
    # Commit and close
    conn.commit()
    conn.close()
    
    print(f"\n✅ SUCCESS! Database created: {output_path}")
    print(f"   📊 {len(cocktail_map)} cocktails")
    print(f"   📊 {len(unique_ingredients)} ingredients")
    print(f"   📊 {inserted} relationships")
    print(f"   ❤️  Favorites table created (empty)")
    print(f"\n💡 Image paths are stored WITHOUT extensions")
    print(f"   Example: 'assets/images/cocktails/betweenthesheets'")
    print(f"   Your Flutter app should check for .png, .jpg, .webp, etc.")

if __name__ == "__main__":
    output_file = sys.argv[1] if len(sys.argv) > 1 else "/tmp/cocktails.db"
    create_database(output_file)
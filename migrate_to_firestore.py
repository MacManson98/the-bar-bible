#!/usr/bin/env python3
"""
Migrate cocktail data from CSV files to Firestore.
Run in Google Cloud Shell — uses application default credentials.
"""
import csv
import re
import firebase_admin
from firebase_admin import credentials, firestore

# ── Config ────────────────────────────────────────────────────────────────────
COCKTAILS_CSV = 'Cocktails_-_cocktails_csv__cocktails_csv__2026-06-03_20-39.csv'
INGREDIENTS_CSV = 'Cocktails_-_ingredients_csv__ingredients_csv__2026-06-03_20-39.csv'

NAME_FIXES = {
    'Angostura bitters': 'Angostura Bitters',
    'Lemon juice':       'Lemon Juice',
    'Marachino Luxardo': 'Maraschino Luxardo',
    'Bitter Campari':    'Campari',
    'Fernet':            'Fernet Branca',
    'Sweet Red Vermouth':'Sweet Vermouth',
    'Maraschino luxardo':'Maraschino Luxardo',
}

CATEGORY_OVERRIDES = {
    'Lemon Juice': 'Citrus', 'Lime Juice': 'Citrus', 'Lime': 'Citrus',
    'Grapefruit Juice': 'Juices', 'Cranberry Juice': 'Juices',
    'Freshly Squeezed Orange Juice': 'Juices', 'Orange juice': 'Juices',
    'Pineapple Juice': 'Juices', 'Tomato Juice': 'Juices',
    'Passionfruit Puree': 'Juices', 'White Peach Puree': 'Juices',
    'Gosling\u2019s Rum': 'Spirits', "Gosling's Rum": 'Spirits',
    'Ron Profundo Havana Club': 'Spirits', 'Ron Smoky Havana Club': 'Spirits',
    'Ginger Ale': 'Mixers', 'Champagne': 'Mixers', 'Prosecco': 'Mixers',
    'Fresh Cream': 'Mixers', 'Egg White': 'Mixers',
    'Sweet Vermouth': 'Liqueurs', 'Dry Vermouth': 'Liqueurs',
    'Absinthe': 'Liqueurs', 'Fernet Branca': 'Liqueurs',
    'Frangelico': 'Liqueurs', 'Lillet Blanc': 'Liqueurs',
    'Green Chartreuse': 'Liqueurs', 'Campari': 'Liqueurs',
    'Grand Marnier': 'Liqueurs', 'Falernum': 'Liqueurs',
    'Maraschino Luxardo': 'Liqueurs',
    'Sugar': 'Sweeteners', 'Sugar Cube': 'Sweeteners',
    'Superfine Sugar': 'Sweeteners', 'White Cane Sugar': 'Sweeteners',
    'Honey': 'Sweeteners', 'Raw Honey': 'Sweeteners',
    'Honey Syrup': 'Sweeteners', 'Sugar Syrup': 'Sweeteners',
    'Raspberry Syrup': 'Sweeteners', 'Passionfruit Syrup': 'Sweeteners',
    'Hot Coffee': 'Coffee', 'Strong Espresso': 'Coffee',
    'Basil Leaves': 'Other', 'Gengibre Slice': 'Other',
    'Celery Salt': 'Other', 'Pepper': 'Other', 'Tabasco': 'Other',
    'Worcestershire Sauce': 'Other',
}

def canonicalise(name):
    name = name.strip()
    return NAME_FIXES.get(name, name)

def resolve_category(name, raw):
    return CATEGORY_OVERRIDES.get(name, raw.strip() if raw else 'Other')

def generate_image_path(name):
    clean = re.sub(r'[^a-z0-9]', '', name.lower())
    return f"assets/images/cocktails/{clean}"

# ── Init Firebase ─────────────────────────────────────────────────────────────
app = firebase_admin.initialize_app()
db = firestore.client()

# ── Load CSVs ─────────────────────────────────────────────────────────────────
print("Reading cocktails CSV...")
cocktails = {}
with open(COCKTAILS_CSV, encoding='utf-8-sig') as f:
    for row in csv.DictReader(f):
        cid = row['cocktail_id'].strip()
        cocktails[cid] = {
            'name': row['name'].strip(),
            'method': row['method'].strip(),
            'method_instructions': row.get('method_instructions', '').strip(),
            'garnish': row.get('garnish', '').strip(),
            'glass': row.get('glass', '').strip(),
            'ice': row.get('ice', '').strip(),
            'difficulty': int(row.get('difficulty') or 2),
            'base_spirit': row.get('base_spirit', '').strip(),
            'tags': [t.strip() for t in row.get('tags', '').split(',') if t.strip()],
            'history': row.get('history', '').strip(),
            'tasting_notes': row.get('tasting_notes', '').strip(),
            'tiles_notes': row.get('tiles_notes', '').strip(),
            'image_path': generate_image_path(row['name'].strip()),
            'is_premium': False,
            'ingredients': [],
        }
print(f"  {len(cocktails)} cocktails loaded")

print("Reading ingredients CSV...")
unique_ingredients = {}
for cid, data in cocktails.items():
    data['ingredients'] = []

with open(INGREDIENTS_CSV, encoding='utf-8-sig') as f:
    for row in csv.DictReader(f):
        cid = row['cocktail_id'].strip()
        raw_name = row.get('ingredient_name', '').strip()
        amount_ml = row.get('amount_ml', '').strip()
        amount_oz = row.get('amount_oz', '').strip()
        category = row.get('category', 'Other').strip()

        if not raw_name or not amount_ml:
            continue

        name = canonicalise(raw_name)
        cat = resolve_category(name, category)
        unique_ingredients[name] = cat

        if cid in cocktails:
            cocktails[cid]['ingredients'].append({
                'name': name,
                'amount_ml': float(amount_ml) if amount_ml else 0,
                'amount_oz': float(amount_oz) if amount_oz else 0,
                'category': cat,
            })

print(f"  {len(unique_ingredients)} unique ingredients loaded")

# ── Push to Firestore ─────────────────────────────────────────────────────────
print("\nUploading cocktails to Firestore...")
cocktails_ref = db.collection('cocktails')
batch = db.batch()
count = 0

for cid, data in cocktails.items():
    doc_ref = cocktails_ref.document()
    batch.set(doc_ref, data)
    count += 1
    if count % 400 == 0:
        batch.commit()
        batch = db.batch()
        print(f"  Committed {count} cocktails...")

batch.commit()
print(f"  {count} cocktails uploaded")

print("\nUploading ingredients to Firestore...")
ingredients_ref = db.collection('ingredients')
batch = db.batch()
count = 0

for name, category in unique_ingredients.items():
    doc_id = re.sub(r'[^a-z0-9]', '_', name.lower())
    doc_ref = ingredients_ref.document(doc_id)
    batch.set(doc_ref, {'name': name, 'category': category})
    count += 1
    if count % 400 == 0:
        batch.commit()
        batch = db.batch()

batch.commit()
print(f"  {count} ingredients uploaded")

print("\nSUCCESS! Migration complete.")

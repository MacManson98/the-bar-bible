import 'dart:convert';

class FlavorChip {
  final String label;
  final Set<String> aliases;
  const FlavorChip({required this.label, required this.aliases});
}

const kFlavorChips = [
  FlavorChip(label: 'Citrus',      aliases: {'citrus', 'tart', 'fresh'}),
  FlavorChip(label: 'Fruity',      aliases: {'fruity'}),
  FlavorChip(label: 'Refreshing',  aliases: {'refreshing', 'light', 'spritz'}),
  FlavorChip(label: 'Sweet',       aliases: {'sweet', 'creamy', 'rich', 'dessert'}),
  FlavorChip(label: 'Floral',      aliases: {'floral'}),
  FlavorChip(label: 'Herbal',      aliases: {'herbal', 'spiced', 'botanical'}),
  FlavorChip(label: 'Bitter',      aliases: {'bitter', 'aperitif'}),
  FlavorChip(label: 'Smoky',       aliases: {'smoky'}),
  FlavorChip(label: 'Boozy',       aliases: {'boozy', 'spirit-forward', 'strong', 'bold'}),
];

Set<String> parseCocktailTags(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  final trimmed = raw.trim();
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
      }
    } catch (_) {}
  }
  return trimmed
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
}

bool cocktailHasFlavorTag(Set<String> tags, Set<String> aliases) {
  String normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\s]+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9-]'), '')
      .replaceAll(RegExp(r'-+'), '-');

  final normTags = tags.map(normalize).toSet();
  for (final alias in aliases.map(normalize)) {
    if (alias.isEmpty) continue;
    if (normTags.contains(alias)) return true;
    if (normTags.any((t) => (t.contains(alias) || alias.contains(t)) && t.length >= 5)) {
      return true;
    }
  }
  return false;
}

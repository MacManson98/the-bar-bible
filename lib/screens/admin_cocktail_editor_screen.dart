import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';
import '../services/firestore_sync_service.dart';

class AdminCocktailEditorScreen extends StatefulWidget {
  final AppDatabase database;
  final String? stagingDocId;
  final Map<String, dynamic>? initialData;
  final bool saveLive;

  const AdminCocktailEditorScreen({
    super.key,
    required this.database,
    this.stagingDocId,
    this.initialData,
    this.saveLive = false,
  });

  @override
  State<AdminCocktailEditorScreen> createState() =>
      _AdminCocktailEditorScreenState();
}

class _AdminCocktailEditorScreenState
    extends State<AdminCocktailEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  XFile? _pickedImage;
  bool _isUploadingImage = false;
  double _uploadProgress = 0;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _methodInstructionsCtrl;
  late final TextEditingController _glassCustomCtrl;
  late final TextEditingController _iceCustomCtrl;
  late final TextEditingController _garnishCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _historyCtrl;
  late final TextEditingController _tastingNotesCtrl;
  late final TextEditingController _imageUrlCtrl;

  // Stored as display value (capitalised); lowercased on save where needed
  String _method = 'Shake';
  String _baseSpirit = 'Gin';
  String _category = 'Cocktail';
  String _glass = 'Coupe';
  String _ice = 'Cubed';
  int _difficulty = 2;
  bool _isPremium = false;

  final List<_IngredientRow> _ingredients = [];

  // Display values — stored/saved as-is (Firestore is fine with capitalised values)
  static const _methodValues = ['Shake', 'Stir', 'Build', 'Blend', 'Throw', 'Roll'];
  static const _spirits = [
    'Gin', 'Vodka', 'Rum', 'Bourbon', 'Whiskey', 'Tequila',
    'Mezcal', 'Brandy', 'Cognac', 'Champagne', 'Wine', 'Beer',
    'Non-Alcoholic', 'Other',
  ];
  static const _categoryValues = ['Cocktail', 'Mocktail', 'Shot'];

  static const _glassOptions = [
    'Coupe',
    'Rocks / Old Fashioned',
    'Highball',
    'Martini',
    'Nick & Nora',
    'Hurricane',
    'Tiki Mug',
    'Champagne Flute',
    'Wine Glass',
    'Shot Glass',
    'Other',
  ];

  static const _iceOptions = [
    'Cubed',
    'Large Cube',
    'Crushed',
    'Cracked',
    'No Ice',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameCtrl = TextEditingController(text: d['name'] as String? ?? '');
    _methodInstructionsCtrl =
        TextEditingController(text: d['method_instructions'] as String? ?? '');
    _garnishCtrl = TextEditingController(text: d['garnish'] as String? ?? '');
    final rawTags = d['tags'];
    _tagsCtrl = TextEditingController(
        text: rawTags is List
            ? rawTags.join(', ')
            : (rawTags is String ? rawTags : ''));
    _historyCtrl = TextEditingController(text: d['history'] as String? ?? '');
    _tastingNotesCtrl =
        TextEditingController(text: d['tasting_notes'] as String? ?? '');
    _imageUrlCtrl =
        TextEditingController(text: d['image_url'] as String? ?? '');

    // Method: normalise stored value to capitalised display value
    final storedMethod = d['method'] as String? ?? 'shake';
    final normMethod = _capitalize(storedMethod);
    _method = _methodValues.contains(normMethod) ? normMethod : 'Shake';

    _baseSpirit = d['base_spirit'] as String? ?? 'Gin';
    if (!_spirits.contains(_baseSpirit)) _baseSpirit = 'Other';

    final storedCategory = d['category'] as String? ?? 'cocktail';
    final normCategory = _capitalize(storedCategory);
    _category = _categoryValues.contains(normCategory) ? normCategory : 'Cocktail';

    _difficulty = (d['difficulty'] as num?)?.toInt() ?? 2;
    _isPremium = d['is_premium'] as bool? ?? false;

    // Glass
    final storedGlass = d['glass'] as String? ?? '';
    if (_glassOptions.contains(storedGlass)) {
      _glass = storedGlass;
      _glassCustomCtrl = TextEditingController();
    } else {
      _glass = 'Other';
      _glassCustomCtrl = TextEditingController(text: storedGlass);
    }

    // Ice
    final storedIce = d['ice'] as String? ?? '';
    if (_iceOptions.contains(storedIce)) {
      _ice = storedIce.isEmpty ? 'Cubed' : storedIce;
      _iceCustomCtrl = TextEditingController();
    } else {
      _ice = storedIce.isEmpty ? 'Cubed' : 'Other';
      _iceCustomCtrl = TextEditingController(text: storedIce);
    }

    final rawIngredients = d['ingredients'] as List? ?? [];
    for (final ing in rawIngredients) {
      if (ing is Map) {
        final storedUnit = ing['unit'] as String? ?? 'ml';
        final unit = _IngredientRow.unitOptions.contains(storedUnit) ? storedUnit : 'ml';
        final amount = ing['amount']?.toString() ?? (ing['amount_ml'] ?? '').toString();
        _ingredients.add(_IngredientRow(
          nameCtrl: TextEditingController(text: ing['name'] as String? ?? ''),
          amountCtrl: TextEditingController(text: amount),
          prepNoteCtrl: TextEditingController(text: ing['prep_note'] as String? ?? ''),
          unit: unit,
        ));
      }
    }
    if (_ingredients.isEmpty) _addIngredient();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _methodInstructionsCtrl.dispose();
    _glassCustomCtrl.dispose();
    _iceCustomCtrl.dispose();
    _garnishCtrl.dispose();
    _tagsCtrl.dispose();
    _historyCtrl.dispose();
    _tastingNotesCtrl.dispose();
    _imageUrlCtrl.dispose();
    for (final ing in _ingredients) {
      ing.dispose();
    }
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientRow(
        nameCtrl: TextEditingController(),
        amountCtrl: TextEditingController(),
        prepNoteCtrl: TextEditingController(),
      ));
    });
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
  }

  String _buildImageStoragePath() {
    final id = widget.stagingDocId ??
        _nameCtrl.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'cocktail_images/$id.jpg';
  }

  Future<void> _pickAndUploadImage() async {
    if (widget.stagingDocId == null && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a cocktail name before adding an image.'),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;

    // Basic file-type guard — reject anything that isn't jpg/jpeg/png/webp
    final ext = picked.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPG, PNG or WebP images are allowed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() {
      _pickedImage = picked;
      _isUploadingImage = true;
      _uploadProgress = 0;
    });

    try {
      final path = _buildImageStoragePath();
      final ref = FirebaseStorage.instance.ref(path);
      final uploadTask = ref.putFile(
        File(picked.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      await uploadTask;
      final url = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _imageUrlCtrl.text = '$url?alt=media';
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _imageUrlCtrl.clear();
    });
  }

  String get _resolvedGlass =>
      _glass == 'Other' ? _glassCustomCtrl.text.trim() : _glass;

  String get _resolvedIce =>
      _ice == 'Other' ? _iceCustomCtrl.text.trim() : _ice;

  Map<String, dynamic> _buildPayload({bool staging = false}) {
    final tagsRaw = _tagsCtrl.text.trim();
    final tagsList = tagsRaw.isEmpty
        ? <String>[]
        : tagsRaw
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();

    final ingredients = _ingredients
        .where((i) => i.nameCtrl.text.trim().isNotEmpty)
        .map((i) {
          final unit = i.unit;
          final amountStr = i.amountCtrl.text.trim();
          final amountNum = double.tryParse(amountStr) ?? 0.0;
          return {
            'name': i.nameCtrl.text.trim(),
            'unit': unit,
            'amount': amountStr,
            'amount_ml': unit == 'ml' ? amountNum : (unit == 'oz' ? amountNum * 29.5735 : 0.0),
            'amount_oz': unit == 'oz' ? amountNum : (unit == 'ml' ? amountNum * 0.033814 : 0.0),
            'prep_note': i.prepNoteCtrl.text.trim().isEmpty ? null : i.prepNoteCtrl.text.trim(),
          };
        })
        .toList();

    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'method': _method.toLowerCase(), // keep Firestore values lowercase for back-compat
      'method_instructions': _methodInstructionsCtrl.text.trim().isEmpty
          ? null
          : _methodInstructionsCtrl.text.trim(),
      'glass': _resolvedGlass,
      'ice': _resolvedIce.isEmpty ? null : _resolvedIce,
      'garnish':
          _garnishCtrl.text.trim().isEmpty ? null : _garnishCtrl.text.trim(),
      'base_spirit': _baseSpirit,
      'difficulty': _difficulty,
      'tags': tagsList,
      'category': _category.toLowerCase(), // keep lowercase for back-compat
      'is_premium': _isPremium,
      'history':
          _historyCtrl.text.trim().isEmpty ? null : _historyCtrl.text.trim(),
      'tasting_notes': _tastingNotesCtrl.text.trim().isEmpty
          ? null
          : _tastingNotesCtrl.text.trim(),
      'image_url': _imageUrlCtrl.text.trim().isEmpty
          ? null
          : _imageUrlCtrl.text.trim(),
      'ingredients': ingredients,
    };

    if (staging) {
      payload['status'] = 'pending';
      payload['created_at'] = FieldValue.serverTimestamp();
    }

    return payload;
  }

  Future<void> _save({required bool toLive}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_glass == 'Other' && _glassCustomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a glass type.')),
      );
      return;
    }
    if (_ice == 'Other' && _iceCustomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an ice type.')),
      );
      return;
    }
    if (_ingredients.every((i) => i.nameCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one ingredient.')),
      );
      return;
    }
    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for image upload to finish.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final collection = toLive ? 'cocktails' : 'cocktails_staging';
      final payload = _buildPayload(staging: !toLive);

      if (widget.stagingDocId != null && !toLive) {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(widget.stagingDocId)
            .update(payload);
      } else if (widget.stagingDocId != null && toLive) {
        final batch = FirebaseFirestore.instance.batch();
        final liveRef = FirebaseFirestore.instance
            .collection('cocktails')
            .doc(widget.stagingDocId);
        final stagingRef = FirebaseFirestore.instance
            .collection('cocktails_staging')
            .doc(widget.stagingDocId);
        batch.set(liveRef, payload);
        batch.delete(stagingRef);
        await batch.commit();
      } else {
        await FirebaseFirestore.instance.collection(collection).add(payload);
      }

      if (toLive) {
        try {
          // Refresh the local cache so the new/updated cocktail shows up
          // immediately instead of waiting for the next 24h auto-sync.
          await FirestoreSyncService(widget.database).sync();
        } catch (_) {
          // Best-effort — the live write already succeeded either way.
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                toLive ? 'Cocktail published live!' : 'Saved to staging queue.'),
            backgroundColor:
                toLive ? Colors.green.shade700 : AppTheme.surfaceLight,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.stagingDocId != null;
    final title = widget.saveLive
        ? (isEditing ? 'EDIT COCKTAIL' : 'ADD COCKTAIL')
        : isEditing
            ? 'EDIT DRAFT'
            : 'NEW DRAFT';

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accentGold),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            _sectionLabel('BASICS'),

            // Name
            _labeledField(
              'Cocktail Name',
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDecoration('e.g. Strawberry Southside'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 12),

            // Method
            _labeledField(
              'Method',
              _dropdownWithValue<String>(
                value: _method,
                items: _methodValues,
                onChanged: (v) => setState(() => _method = v!),
              ),
            ),
            const SizedBox(height: 12),

            // Base Spirit
            _labeledField(
              'Base Spirit',
              _dropdownWithValue<String>(
                value: _baseSpirit,
                items: _spirits,
                onChanged: (v) => setState(() => _baseSpirit = v!),
              ),
            ),
            const SizedBox(height: 12),

            // Category
            _labeledField(
              'Category',
              _dropdownWithValue<String>(
                value: _category,
                items: _categoryValues,
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
            const SizedBox(height: 12),

            // Glass
            _labeledField(
              'Glass Type',
              _dropdownWithValue<String>(
                value: _glass,
                items: _glassOptions,
                onChanged: (v) => setState(() => _glass = v!),
              ),
            ),
            if (_glass == 'Other') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _glassCustomCtrl,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDecoration('Enter glass type'),
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 12),

            // Ice
            _labeledField(
              'Ice Type',
              _dropdownWithValue<String>(
                value: _ice,
                items: _iceOptions,
                onChanged: (v) => setState(() => _ice = v!),
              ),
            ),
            if (_ice == 'Other') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _iceCustomCtrl,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDecoration('Enter ice type'),
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 12),

            // Garnish
            _labeledField(
              'Garnish',
              TextFormField(
                controller: _garnishCtrl,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDecoration('e.g. Lime Wheel, Mint Sprig'),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(height: 16),

            // Difficulty
            _sectionLabel('DIFFICULTY'),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _difficulty = star),
                  icon: Icon(
                    star <= _difficulty ? Icons.star : Icons.star_border,
                    color: AppTheme.accentGold,
                    size: 28,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // Premium toggle
            Row(
              children: [
                const Text('Premium',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: _isPremium,
                  onChanged: (v) => setState(() => _isPremium = v),
                  activeThumbColor: AppTheme.accentGold,
                  activeTrackColor: AppTheme.accentGold.withValues(alpha: 0.3),
                  inactiveThumbColor: AppTheme.textSecondary,
                  inactiveTrackColor: AppTheme.surfaceLight,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ingredients
            _sectionLabel('INGREDIENTS'),
            ...List.generate(_ingredients.length, (i) {
              final ing = _ingredients[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: ing.nameCtrl,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration('Ingredient'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: ing.amountCtrl,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Amt'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Unit dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ing.unit,
                          dropdownColor: AppTheme.surfaceDark,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary, size: 14),
                          isDense: true,
                          items: _IngredientRow.unitOptions
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setState(() => ing.unit = v!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                        flex: 2, child: _fieldRaw(ing.prepNoteCtrl, 'Note')),
                    IconButton(
                      onPressed: () => _removeIngredient(i),
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.redAccent, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add, color: AppTheme.accentGold),
              label: const Text('Add Ingredient',
                  style: TextStyle(color: AppTheme.accentGold)),
            ),
            const SizedBox(height: 16),

            // Method instructions
            _sectionLabel('METHOD INSTRUCTIONS'),
            _field(_methodInstructionsCtrl, 'Step-by-step instructions',
                maxLines: 4),
            const SizedBox(height: 16),

            // Additional info
            _sectionLabel('ADDITIONAL INFO'),
            _field(_tagsCtrl, 'Tags (comma separated)'),
            const SizedBox(height: 12),
            _field(_historyCtrl, 'History / Background', maxLines: 3),
            const SizedBox(height: 12),
            _field(_tastingNotesCtrl, 'Tasting Notes', maxLines: 2),
            const SizedBox(height: 16),

            // Image
            _sectionLabel('IMAGE'),
            _buildImagePicker(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          border: Border(
              top: BorderSide(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (_isSaving || _isUploadingImage)
                    ? null
                    : () => _save(toLive: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.surfaceLight),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SAVE DRAFT',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (_isSaving || _isUploadingImage)
                    ? null
                    : () => _save(toLive: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('PUBLISH LIVE',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasExistingUrl =
        _imageUrlCtrl.text.isNotEmpty && _pickedImage == null;
    final hasPicked = _pickedImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickAndUploadImage,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            clipBehavior: Clip.hardEdge,
            child: _buildImagePreview(hasExistingUrl, hasPicked),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                    hasExistingUrl || hasPicked ? 'Change Image' : 'Pick Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentGold,
                  side: const BorderSide(color: AppTheme.accentGold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (hasExistingUrl || hasPicked) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _removeImage,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _field(_imageUrlCtrl, 'Or paste image URL manually'),
      ],
    );
  }

  Widget _buildImagePreview(bool hasExistingUrl, bool hasPicked) {
    if (_isUploadingImage) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: _uploadProgress,
                strokeWidth: 3,
                color: AppTheme.accentGold,
                backgroundColor: AppTheme.surfaceLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(_uploadProgress * 100).toInt()}%',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (hasPicked) {
      return Image.file(
        File(_pickedImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }

    if (hasExistingUrl) {
      return CachedNetworkImage(
        imageUrl: _imageUrlCtrl.text,
        fit: BoxFit.cover,
        width: double.infinity,
        errorWidget: (c, u, e) => _emptyImagePlaceholder(),
      );
    }

    return _emptyImagePlaceholder();
  }

  Widget _emptyImagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 40, color: AppTheme.textSecondary),
          SizedBox(height: 8),
          Text(
            'Tap to add image',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: AppTheme.accentGold,
        ),
      ),
    );
  }

  /// A field with a small label above it — consistent with creator screen style
  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: _inputDecoration(hint),
      textCapitalization: maxLines == 1
          ? TextCapitalization.words
          : TextCapitalization.sentences,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  Widget _fieldRaw(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: _inputDecoration(hint),
    );
  }

  Widget _dropdownWithValue<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceDark,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          icon: Icon(Icons.expand_more,
              color: AppTheme.textSecondary.withValues(alpha: 0.6)),
          items: items
              .map((o) => DropdownMenuItem<T>(value: o, child: Text(o.toString())))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 13),
      filled: true,
      fillColor: AppTheme.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.surfaceLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.surfaceLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.accentGold),
      ),
    );
  }
}

class _IngredientRow {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController prepNoteCtrl;
  String unit;

  static const unitOptions = [
    'ml', 'oz', 'dash', 'drop', 'barspoon', 'tsp', 'whole',
    'pcs', 'slice', 'wedge', 'wheel', 'leaves', 'g', 'top', 'float', 'sprinkle',
  ];

  _IngredientRow({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.prepNoteCtrl,
    this.unit = 'ml',
  });

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    prepNoteCtrl.dispose();
  }
}

// ignore_for_file: prefer_const_constructors
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';
import '../services/auth_service.dart';
import '../services/ai_service.dart';
import '../services/user_sync_service.dart';
import 'user_cocktail_detail_screen.dart';

class CocktailCreatorScreen extends StatefulWidget {
  final AppDatabase database;
  final UserCocktail? existing; // non-null when editing
  final AiCocktailSpec? aiPrefill; // non-null when creating from AI generation

  const CocktailCreatorScreen({
    super.key,
    required this.database,
    this.existing,
    this.aiPrefill,
  });

  @override
  State<CocktailCreatorScreen> createState() => _CocktailCreatorScreenState();
}

class _CocktailCreatorScreenState extends State<CocktailCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  XFile? _pickedImage;
  bool _isUploadingImage = false;
  double _uploadProgress = 0;
  String? _imageUrl;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _glassCustomController = TextEditingController();
  final _iceCustomController = TextEditingController();
  final _garnishController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  String _method = 'Shake';
  String _baseSpirit = 'Gin';
  String _category = 'cocktail';
  String _glass = 'Coupe';
  String _ice = 'Cubed';
  int _difficulty = 2;
  List<_IngredientRow> _ingredients = [];

  static const _methods = ['Shake', 'Stir', 'Build', 'Blend'];
  static const _spirits = [
    'Gin', 'Vodka', 'Rum', 'Bourbon', 'Whiskey', 'Tequila',
    'Brandy', 'Cognac', 'Mezcal', 'Champagne', 'Wine', 'Beer', 'Other',
  ];
  static const _categories = ['cocktail', 'mocktail', 'shot'];
  static const _categoryLabels = ['Cocktail', 'Mocktail', 'Shot'];
  static const _units = ['ml', 'oz', 'dash', 'tsp', 'tbsp', 'splash', 'top'];

  static const _glassOptions = [
    'Coupe', 'Rocks / Old Fashioned', 'Highball', 'Martini', 'Nick & Nora',
    'Hurricane', 'Tiki Mug', 'Champagne Flute', 'Wine Glass', 'Shot Glass', 'Other',
  ];
  static const _iceOptions = [
    'Cubed', 'Large Cube', 'Crushed', 'Cracked', 'No Ice', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _ingredients = [_IngredientRow()];

    // Populate if editing
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _imageUrl = e.imageUrl;
      final storedGlass = e.glass;
      if (_glassOptions.contains(storedGlass)) {
        _glass = storedGlass;
      } else {
        _glass = 'Other';
        _glassCustomController.text = storedGlass;
      }
      final storedIce = e.ice ?? '';
      if (_iceOptions.contains(storedIce) || storedIce.isEmpty) {
        _ice = storedIce.isEmpty ? 'Cubed' : storedIce;
      } else {
        _ice = 'Other';
        _iceCustomController.text = storedIce;
      }
      _garnishController.text = e.garnish ?? '';
      _notesController.text = e.notes ?? '';
      _tagsController.text = e.tags ?? '';
      _method = _capitalize(e.method);
      _baseSpirit = e.baseSpirit;
      _category = e.category;
      _difficulty = e.difficulty;
      _loadExistingIngredients();
      return;
    }

    // Populate from AI prefill
    final ai = widget.aiPrefill;
    if (ai != null) {
      _nameController.text = ai.name;
      final aiGlass = ai.glass;
      if (_glassOptions.contains(aiGlass)) {
        _glass = aiGlass;
      } else {
        _glass = 'Other';
        _glassCustomController.text = aiGlass;
      }
      final aiIce = ai.ice ?? '';
      if (_iceOptions.contains(aiIce) || aiIce.isEmpty) {
        _ice = aiIce.isEmpty ? 'Cubed' : aiIce;
      } else {
        _ice = 'Other';
        _iceCustomController.text = aiIce;
      }
      _garnishController.text = ai.garnish ?? '';
      _notesController.text = ai.notes ?? '';
      _tagsController.text = ai.tags ?? '';
      _method = _capitalize(ai.method);
      _baseSpirit = _spirits.contains(ai.baseSpirit) ? ai.baseSpirit : 'Other';
      _category = ai.category;
      _difficulty = ai.difficulty;
      if (ai.ingredients.isNotEmpty) {
        _ingredients = ai.ingredients.map((i) {
          final row = _IngredientRow();
          row.nameController.text = i.name;
          row.amountController.text = i.amount == i.amount.truncateToDouble()
              ? i.amount.toInt().toString()
              : i.amount.toString();
          row.unit = i.unit;
          row.prepNoteController.text = i.prepNote ?? '';
          return row;
        }).toList();
      }
    }
  }

  Future<void> _loadExistingIngredients() async {
    if (widget.existing == null) return;
    final rows = await widget.database.getUserCocktailIngredients(widget.existing!.id);
    if (!mounted) return;
    setState(() {
      _ingredients = rows.map((r) {
        final row = _IngredientRow();
        row.nameController.text = r.ingredientName;
        row.amountController.text = r.amount == r.amount.truncate()
            ? r.amount.toInt().toString()
            : r.amount.toString();
        row.unit = r.unit;
        row.prepNoteController.text = r.prepNote ?? '';
        return row;
      }).toList();
      if (_ingredients.isEmpty) _ingredients = [_IngredientRow()];
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _glassCustomController.dispose();
    _iceCustomController.dispose();
    _garnishController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    for (final row in _ingredients) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;

    final ext = picked.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only JPG, PNG or WebP images are allowed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _pickedImage = picked;
      _isUploadingImage = true;
      _uploadProgress = 0;
    });

    try {
      final safeName = _nameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final path = 'user_cocktail_images/${safeName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref(path);
      final task = ref.putFile(File(picked.path), SettableMetadata(contentType: 'image/jpeg'));
      task.snapshotEvents.listen((s) {
        if (mounted) setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes);
      });
      await task;
      final url = await ref.getDownloadURL();
      if (mounted) {
        setState(() {
          _imageUrl = '$url?alt=media';
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _removeImage() => setState(() {
        _pickedImage = null;
        _imageUrl = null;
      });

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${bytes.sublist(0, 4).map(hex).join()}-'
        '${bytes.sublist(4, 6).map(hex).join()}-'
        '${bytes.sublist(6, 8).map(hex).join()}-'
        '${bytes.sublist(8, 10).map(hex).join()}-'
        '${bytes.sublist(10).map(hex).join()}';
  }

  Future<void> _pushCocktailSync(String uid, int cocktailId) async {
    final messenger = ScaffoldMessenger.of(context);
    final synced =
        await UserSyncService(widget.database).pushSingleUserCocktail(uid, cocktailId);
    if (!synced) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t sync to cloud — will retry later')),
      );
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_ingredients.every((r) => r.nameController.text.trim().isEmpty)) {
      _showError('Add at least one ingredient.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final auth = context.read<AuthService>();
      final isEditing = widget.existing != null;

      if (!auth.isSignedIn) {
        setState(() => _isSaving = false);
        _showError('Create a free account to save cocktails.');
        return;
      }

      if (!isEditing) {
        final canCreate = await auth.canCreateCocktail(auth.isEffectivelyPremium);
        if (!canCreate && mounted) {
          setState(() => _isSaving = false);
          _showError('Create limit reached. Upgrade to Premium for unlimited creations.');
          return;
        }
      }

      final companion = UserCocktailsCompanion(
        id: isEditing ? Value(widget.existing!.id) : const Value.absent(),
        name: Value(_nameController.text.trim()),
        method: Value(_method.toLowerCase()),
        glass: Value(_glass == 'Other' ? _glassCustomController.text.trim() : _glass),
        ice: Value(() {
          final v = _ice == 'Other' ? _iceCustomController.text.trim() : _ice;
          return v.isEmpty ? null : v;
        }()),
        garnish: Value(_garnishController.text.trim().isEmpty ? null : _garnishController.text.trim()),
        baseSpirit: Value(_baseSpirit),
        difficulty: Value(_difficulty),
        tags: Value(_tagsController.text.trim().isEmpty ? null : _tagsController.text.trim()),
        notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
        category: Value(_category),
        isAiGenerated: Value(widget.aiPrefill != null),
        imageUrl: Value(_imageUrl),
        firestoreId: isEditing
            ? Value(widget.existing!.firestoreId ?? _generateUuid())
            : Value(_generateUuid()),
        updatedAt: Value(DateTime.now()),
      );

      // Save the cocktail and its ingredients atomically — a failure
      // partway through must not leave an orphaned, ingredient-less
      // cocktail (or a burned create-quota slot) behind.
      final saved = await widget.database.transaction(() async {
        UserCocktail result;
        if (isEditing) {
          await widget.database.updateUserCocktail(companion);
          result = widget.existing!;
        } else {
          result = await widget.database.insertUserCocktail(companion);
        }

        final ingredientCompanions = _ingredients
            .asMap()
            .entries
            .where((e) => e.value.nameController.text.trim().isNotEmpty)
            .map((e) => UserCocktailIngredientsCompanion(
                  userCocktailId: Value(result.id),
                  ingredientName: Value(e.value.nameController.text.trim()),
                  amount: Value(double.tryParse(e.value.amountController.text) ?? 0),
                  unit: Value(e.value.unit),
                  prepNote: Value(e.value.prepNoteController.text.trim().isEmpty
                      ? null
                      : e.value.prepNoteController.text.trim()),
                  sortOrder: Value(e.key),
                ))
            .toList();

        await widget.database.replaceUserCocktailIngredients(result.id, ingredientCompanions);
        return result;
      });

      // Quota is consumed only once the cocktail and its ingredients are
      // durably saved.
      if (!isEditing) {
        await auth.incrementCreatesUsed();
      }

      // Push to Firestore for cross-device sync — fired without blocking
      // navigation below; the local save already succeeded, this only
      // surfaces a sync failure.
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        _pushCocktailSync(uid, saved.id);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        if (!isEditing) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserCocktailDetailScreen(
                database: widget.database,
                cocktail: saved,
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Could not save cocktail. Please try again.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.surfaceDark),
    );
  }

  void _addIngredient() {
    setState(() => _ingredients.add(_IngredientRow()));
  }

  void _removeIngredient(int index) {
    if (_ingredients.length <= 1) return;
    setState(() {
      _ingredients[index].dispose();
      _ingredients.removeAt(index);
    });
  }

  Widget _buildImagePicker() {
    final hasUrl = _imageUrl != null && _imageUrl!.isNotEmpty;
    final hasPicked = _pickedImage != null;
    return Column(
      children: [
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickAndUploadImage,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.6)),
            ),
            clipBehavior: Clip.hardEdge,
            child: _isUploadingImage
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            value: _uploadProgress,
                            strokeWidth: 3,
                            color: AppTheme.accentGold,
                            backgroundColor: AppTheme.surfaceLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : hasPicked
                    ? Image.file(File(_pickedImage!.path), fit: BoxFit.cover, width: double.infinity)
                    : hasUrl
                        ? CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 36, color: AppTheme.textSecondary),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to add image',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: Text(hasUrl || hasPicked ? 'Change Image' : 'Pick Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentGold,
                  side: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (hasUrl || hasPicked) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _removeImage,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Cocktail' : 'Create Cocktail',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 0,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppTheme.surfaceLight.withValues(alpha: 0.4)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            _SectionLabel(label: 'THE BASICS'),
            const SizedBox(height: 12),

            _FormField(
              label: 'Cocktail name',
              child: TextFormField(
                controller: _nameController,
                style: _inputStyle,
                decoration: _inputDeco('e.g. Strawberry Southside'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
            ),
            const SizedBox(height: 16),

            _FormField(
              label: 'Category',
              child: _SegmentedPicker(
                options: _categoryLabels,
                selected: _categories.indexOf(_category),
                onSelect: (i) => setState(() => _category = _categories[i]),
              ),
            ),
            const SizedBox(height: 16),

            _FormField(
              label: 'Base spirit',
              child: _DropdownField(
                value: _baseSpirit,
                items: _spirits,
                onChanged: (v) => setState(() => _baseSpirit = v!),
              ),
            ),
            const SizedBox(height: 16),

            _FormField(
              label: 'Difficulty',
              child: _StarPicker(
                value: _difficulty,
                onChanged: (v) => setState(() => _difficulty = v),
              ),
            ),

            const SizedBox(height: 28),

            _SectionLabel(label: 'INGREDIENTS'),
            const SizedBox(height: 12),

            ...List.generate(_ingredients.length, (i) => _IngredientRowWidget(
              row: _ingredients[i],
              units: _units,
              index: i,
              canRemove: _ingredients.length > 1,
              onRemove: () => _removeIngredient(i),
            )),

            const SizedBox(height: 8),
            GestureDetector(
              onTap: _addIngredient,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: AppTheme.accentGold.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      'Add ingredient',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentGold.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            _SectionLabel(label: 'METHOD & SERVE'),
            const SizedBox(height: 12),

            _FormField(
              label: 'Method',
              child: _SegmentedPicker(
                options: _methods,
                selected: _methods.indexOf(_method),
                onSelect: (i) => setState(() => _method = _methods[i]),
              ),
            ),
            const SizedBox(height: 16),

            _FormField(
              label: 'Glass Type',
              child: _DropdownField(
                value: _glass,
                items: _glassOptions,
                onChanged: (v) => setState(() => _glass = v!),
              ),
            ),
            if (_glass == 'Other') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _glassCustomController,
                style: _inputStyle,
                decoration: _inputDeco('Enter glass type'),
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: 'Ice Type',
                    child: _DropdownField(
                      value: _ice,
                      items: _iceOptions,
                      onChanged: (v) => setState(() => _ice = v!),
                    ),
                  ),
                ),
                if (_ice == 'Other') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _iceCustomController,
                      style: _inputStyle,
                      decoration: _inputDeco('Enter ice type'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    label: 'Garnish',
                    child: TextFormField(
                      controller: _garnishController,
                      style: _inputStyle,
                      decoration: _inputDeco('e.g. Lime wheel'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            _SectionLabel(label: 'IMAGE'),
            const SizedBox(height: 12),
            _buildImagePicker(),

            const SizedBox(height: 28),

            _SectionLabel(label: 'FINISHING TOUCHES'),
            const SizedBox(height: 12),

            _FormField(
              label: 'Notes',
              child: TextFormField(
                controller: _notesController,
                style: _inputStyle,
                decoration: _inputDeco('Method instructions, tips, history...'),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(height: 16),

            _FormField(
              label: 'Tags',
              child: TextFormField(
                controller: _tagsController,
                style: _inputStyle,
                decoration: _inputDeco('e.g. citrus, refreshing, summer'),
                textCapitalization: TextCapitalization.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Separate tags with commas',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          border: Border(top: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.3))),
        ),
        child: ElevatedButton(
          onPressed: (_isSaving || _isUploadingImage) ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentGold,
            foregroundColor: AppTheme.primaryDark,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            disabledBackgroundColor: AppTheme.accentGold.withValues(alpha: 0.4),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark),
                )
              : Text(
                  isEditing ? 'Save Changes' : 'Save Cocktail',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  TextStyle get _inputStyle => const TextStyle(color: AppTheme.textPrimary, fontSize: 14);

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.45), fontSize: 13),
        filled: true,
        fillColor: AppTheme.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.7), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      );
}

// ─── Ingredient row model ──────────────────────────────────────────────────

class _IngredientRow {
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  final prepNoteController = TextEditingController();
  String unit = 'ml';

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    prepNoteController.dispose();
  }
}

// ─── Ingredient row widget ─────────────────────────────────────────────────

class _IngredientRowWidget extends StatefulWidget {
  final _IngredientRow row;
  final List<String> units;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  const _IngredientRowWidget({
    required this.row,
    required this.units,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  State<_IngredientRowWidget> createState() => _IngredientRowWidgetState();
}

class _IngredientRowWidgetState extends State<_IngredientRowWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: TextFormField(
                  controller: widget.row.amountController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '60',
                    hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.4), fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.primaryDark.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.6)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.row.unit,
                    dropdownColor: AppTheme.surfaceDark,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    icon: Icon(Icons.expand_more,
                        size: 16, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                    items: widget.units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => widget.row.unit = v!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: widget.row.nameController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Ingredient',
                    hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.4), fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.primaryDark.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.6)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              if (widget.canRemove) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Icon(Icons.remove_circle_outline,
                      size: 20, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.row.prepNoteController,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Prep note (optional) — e.g. freshly squeezed, muddled',
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3), fontSize: 12),
              filled: true,
              fillColor: AppTheme.primaryDark.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.4)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared form widgets ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.accentGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppTheme.accentGold.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final int selected;
  final void Function(int) onSelect;

  const _SegmentedPicker(
      {required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (i) {
        final isSelected = i == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: i < options.length - 1 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accentGold : AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentGold
                      : AppTheme.surfaceLight.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                options[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.primaryDark : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _DropdownField(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceDark,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          icon: Icon(Icons.expand_more, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;

  const _StarPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled
                  ? AppTheme.accentGold
                  : AppTheme.textSecondary.withValues(alpha: 0.3),
              size: 32,
            ),
          ),
        );
      }),
    );
  }
}

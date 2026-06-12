import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';

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
  late final TextEditingController _glassCtrl;
  late final TextEditingController _iceCtrl;
  late final TextEditingController _garnishCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _historyCtrl;
  late final TextEditingController _tastingNotesCtrl;
  late final TextEditingController _imageUrlCtrl;

  String _method = 'shake';
  String _baseSpirit = 'Gin';
  String _category = 'cocktail';
  int _difficulty = 2;
  bool _isPremium = false;

  final List<_IngredientRow> _ingredients = [];

  static const _methods = ['shake', 'stir', 'build', 'blend', 'throw'];
  static const _spirits = [
    'Gin', 'Vodka', 'Rum', 'Bourbon', 'Whiskey', 'Tequila',
    'Mezcal', 'Brandy', 'Cognac', 'Champagne', 'Wine', 'Beer',
    'Non-Alcoholic', 'Other',
  ];
  static const _categories = ['cocktail', 'mocktail', 'shot'];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameCtrl = TextEditingController(text: d['name'] as String? ?? '');
    _methodInstructionsCtrl =
        TextEditingController(text: d['method_instructions'] as String? ?? '');
    _glassCtrl = TextEditingController(text: d['glass'] as String? ?? '');
    _iceCtrl = TextEditingController(text: d['ice'] as String? ?? '');
    _garnishCtrl = TextEditingController(text: d['garnish'] as String? ?? '');
    _tagsCtrl = TextEditingController(
        text: (d['tags'] as List?)?.join(', ') ?? d['tags'] as String? ?? '');
    _historyCtrl = TextEditingController(text: d['history'] as String? ?? '');
    _tastingNotesCtrl =
        TextEditingController(text: d['tasting_notes'] as String? ?? '');
    _imageUrlCtrl =
        TextEditingController(text: d['image_url'] as String? ?? '');

    _method = d['method'] as String? ?? 'shake';
    _baseSpirit = d['base_spirit'] as String? ?? 'Gin';
    _category = d['category'] as String? ?? 'cocktail';
    _difficulty = (d['difficulty'] as num?)?.toInt() ?? 2;
    _isPremium = d['is_premium'] as bool? ?? false;

    final rawIngredients = d['ingredients'] as List? ?? [];
    for (final ing in rawIngredients) {
      if (ing is Map) {
        _ingredients.add(_IngredientRow(
          nameCtrl: TextEditingController(text: ing['name'] as String? ?? ''),
          amountCtrl: TextEditingController(
              text: (ing['amount_ml'] ?? '').toString()),
          prepNoteCtrl:
              TextEditingController(text: ing['prep_note'] as String? ?? ''),
        ));
      }
    }
    if (_ingredients.isEmpty) _addIngredient();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _methodInstructionsCtrl.dispose();
    _glassCtrl.dispose();
    _iceCtrl.dispose();
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;

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
        .map((i) => {
              'name': i.nameCtrl.text.trim(),
              'amount_ml': double.tryParse(i.amountCtrl.text.trim()) ?? 0.0,
              'prep_note': i.prepNoteCtrl.text.trim().isEmpty
                  ? null
                  : i.prepNoteCtrl.text.trim(),
            })
        .toList();

    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'method': _method,
      'method_instructions': _methodInstructionsCtrl.text.trim().isEmpty
          ? null
          : _methodInstructionsCtrl.text.trim(),
      'glass': _glassCtrl.text.trim(),
      'ice': _iceCtrl.text.trim().isEmpty ? null : _iceCtrl.text.trim(),
      'garnish':
          _garnishCtrl.text.trim().isEmpty ? null : _garnishCtrl.text.trim(),
      'base_spirit': _baseSpirit,
      'difficulty': _difficulty,
      'tags': tagsList,
      'category': _category,
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
            _field(_nameCtrl, 'Name', required: true),
            const SizedBox(height: 12),
            _dropdownRow('Method', _method, _methods,
                (v) => setState(() => _method = v!)),
            const SizedBox(height: 12),
            _dropdownRow('Spirit', _baseSpirit, _spirits,
                (v) => setState(() => _baseSpirit = v!)),
            const SizedBox(height: 12),
            _dropdownRow('Category', _category, _categories,
                (v) => setState(() => _category = v!)),
            const SizedBox(height: 12),
            _field(_glassCtrl, 'Glass', required: true),
            const SizedBox(height: 12),
            _field(_iceCtrl, 'Ice'),
            const SizedBox(height: 12),
            _field(_garnishCtrl, 'Garnish'),
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
                    Expanded(flex: 3, child: _fieldRaw(ing.nameCtrl, 'Name')),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _fieldRaw(ing.amountCtrl, 'ml')),
                    const SizedBox(width: 8),
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

            // ── Image ──────────────────────────────────────────────────
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
        // Preview area
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
        // Action buttons row
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
                  side: const BorderSide(
                      color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
        // Manual URL fallback
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

  Widget _field(TextEditingController ctrl, String hint,
      {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: _inputDecoration(hint),
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

  Widget _dropdownRow(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : options.first,
      dropdownColor: AppTheme.surfaceDark,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: _inputDecoration(label),
      items:
          options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
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

  _IngredientRow({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.prepNoteCtrl,
  });

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    prepNoteCtrl.dispose();
  }
}

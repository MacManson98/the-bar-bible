import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';
import '../services/ai_service.dart';
import 'cocktail_creator_screen.dart';

class AiGeneratorScreen extends StatefulWidget {
  final AppDatabase database;

  const AiGeneratorScreen({super.key, required this.database});

  @override
  State<AiGeneratorScreen> createState() => _AiGeneratorScreenState();
}

class _AiGeneratorScreenState extends State<AiGeneratorScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isGenerating = false;
  String? _error;

  static const _suggestions = [
    'A smoky mezcal sour with a citrus twist',
    'Something refreshing with elderflower and cucumber',
    'A rich bourbon cocktail for a cold evening',
    'A tropical tiki drink with rum and coconut',
    'A simple gin and tonic variation with herbs',
    'A low-ABV aperitivo style cocktail',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    HapticFeedback.lightImpact();

    try {
      final spec = await AiService().generateCocktail(prompt);

      if (!mounted) return;

      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CocktailCreatorScreen(
            database: widget.database,
            aiPrefill: spec,
          ),
        ),
      );

      if (created == true && mounted) {
        Navigator.pop(context, true);
      } else if (mounted) {
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = 'Generation failed. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Generate with AI',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: AppTheme.surfaceLight.withValues(alpha: 0.4),
          ),
        ),
      ),
      body: _isGenerating ? _buildGenerating() : _buildInput(),
    );
  }

  Widget _buildGenerating() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.accentGold.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.accentGold,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Crafting your cocktail...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This usually takes a few seconds',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.surfaceLight,
                color: AppTheme.accentGold,
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          MediaQuery.of(context).viewInsets.bottom + 100,
        ),
        children: [
          // Icon + heading
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.accentGold.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppTheme.accentGold,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Describe your ideal cocktail',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tell the AI what you want — flavour profile, spirit, occasion, or anything.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary.withValues(alpha: 0.55),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),

          // Prompt input
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 4,
            minLines: 3,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.5,
            ),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'e.g. A smoky mezcal sour with a hint of citrus and a salted rim',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.35),
                fontSize: 14,
                height: 1.5,
              ),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.accentGold.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],

          const SizedBox(height: 24),

          // Generate button
          GestureDetector(
            onTap: _controller.text.trim().isEmpty ? null : _generate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _controller.text.trim().isEmpty
                    ? AppTheme.accentGold.withValues(alpha: 0.3)
                    : AppTheme.accentGold,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: _controller.text.trim().isEmpty
                        ? AppTheme.primaryDark.withValues(alpha: 0.4)
                        : AppTheme.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generate Cocktail',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _controller.text.trim().isEmpty
                          ? AppTheme.primaryDark.withValues(alpha: 0.4)
                          : AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Suggestions
          Text(
            'NEED INSPIRATION?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          ..._suggestions.map(
            (s) => GestureDetector(
              onTap: () {
                _controller.text = s;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: s.length),
                );
                setState(() => _error = null);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 15,
                      color: AppTheme.accentGold.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.north_west,
                      size: 13,
                      color: AppTheme.textSecondary.withValues(alpha: 0.25),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

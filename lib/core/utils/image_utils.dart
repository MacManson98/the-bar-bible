import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Utility class for handling cocktail images with multiple format support
class ImageUtils {
  /// Supported image formats in order of preference
  static const List<String> _supportedFormats = [
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];
  static final Map<String, String?> _resolvedCache = {};

  /// Find the first available image format for a given base path
  static Future<String?> findCocktailImage(String basePath) async {
    if (basePath.contains('.')) {
      basePath = basePath.substring(0, basePath.lastIndexOf('.'));
    }
    if (_resolvedCache.containsKey(basePath)) {
      return _resolvedCache[basePath];
    }

    for (final extension in _supportedFormats) {
      final fullPath = '$basePath.$extension';
      try {
        await rootBundle.load(fullPath);
        _resolvedCache[basePath] = fullPath;
        return fullPath;
      } catch (_) {
        continue;
      }
    }

    _resolvedCache[basePath] = null;
    return null;
  }

  static Future<String> getCocktailImagePath(
    String basePath, {
    String placeholder = 'assets/images/cocktails/placeholder.png',
  }) async {
    final path = await findCocktailImage(basePath);
    return path ?? placeholder;
  }

  static String generateBasePathFromName(String cocktailName) {
    final cleanName = cocktailName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'assets/images/cocktails/$cleanName';
  }

  /// Get a widget for displaying a cocktail image.
  /// Prefers [imageUrl] (Firebase Storage) over local [imagePath] asset.
  static Widget getCocktailImage(
    String? imagePath, {
    BoxFit fit = BoxFit.cover,
    String? imageUrl,
  }) {
    // Prefer network URL if available
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: (context, url) => Container(
          color: Colors.grey[900],
          child: const Center(
            child: CircularProgressIndicator(color: Colors.grey, strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    // Fall back to local asset
    if (imagePath == null || imagePath.isEmpty) {
      return _buildPlaceholder();
    }

    String basePath = imagePath;
    if (imagePath.contains('.')) {
      basePath = imagePath.substring(0, imagePath.lastIndexOf('.'));
    }

    return FutureBuilder<String?>(
      future: findCocktailImage(basePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.grey),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildPlaceholder();
        }

        return Image.asset(
          snapshot.data!,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      },
    );
  }

  static Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.local_bar, size: 64, color: Colors.grey),
      ),
    );
  }
}

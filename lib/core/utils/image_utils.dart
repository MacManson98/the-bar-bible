import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for handling cocktail images with multiple format support
class ImageUtils {
  /// Supported image formats in order of preference
  static const List<String> _supportedFormats = [
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

  /// Find the first available image format for a given base path
  /// 
  /// Example:
  /// ```dart
  /// final path = await ImageUtils.findCocktailImage('assets/images/cocktails/betweenthesheets');
  /// // Returns 'assets/images/cocktails/betweenthesheets.png' if it exists
  /// // or tries .jpg, .jpeg, .webp in order
  /// ```
  static Future<String?> findCocktailImage(String basePath) async {
    // Remove extension if it was included
    if (basePath.contains('.')) {
      basePath = basePath.substring(0, basePath.lastIndexOf('.'));
    }

    for (final extension in _supportedFormats) {
      final fullPath = '$basePath.$extension';
      try {
        // Try to load the asset to check if it exists
        await rootBundle.load(fullPath);
        return fullPath; // Image found!
      } catch (_) {
        // Image not found, try next format
        continue;
      }
    }

    // No image found in any format
    return null;
  }

  /// Get the image path for a cocktail, falling back to a placeholder if not found
  /// 
  /// This is useful for widgets that need a non-nullable path
  static Future<String> getCocktailImagePath(
    String basePath, {
    String placeholder = 'assets/images/cocktails/placeholder.png',
  }) async {
    final path = await findCocktailImage(basePath);
    return path ?? placeholder;
  }

  /// Generate the base path for a cocktail image from its name
  /// 
  /// Converts "Between The Sheets" to "assets/images/cocktails/betweenthesheets"
  static String generateBasePathFromName(String cocktailName) {
    // Remove all non-alphanumeric characters and convert to lowercase
    final cleanName = cocktailName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    return 'assets/images/cocktails/$cleanName';
  }

  /// Get a widget for displaying a cocktail image
  /// Returns an Image widget with proper error handling and async loading
  static Widget getCocktailImage(String? imagePath, {BoxFit fit = BoxFit.cover}) {
    if (imagePath == null || imagePath.isEmpty) {
      return _buildPlaceholder();
    }

    // Remove extension if present to try multiple formats
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

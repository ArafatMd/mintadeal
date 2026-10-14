import 'package:flutter/material.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// Each category's pastel tile colour and the deeper accent used for its shop avatar.
extension CategoryStyle on VendorCategory {
  Color get tint => switch (this) {
        VendorCategory.GROCERY => const Color(0xFFFFF3E0),
        VendorCategory.MEAT_FISH => const Color(0xFFFFE4E6),
        VendorCategory.BAKERY => const Color(0xFFFFF0DB),
        VendorCategory.CLOTHING => const Color(0xFFE3F6EC),
        VendorCategory.ELECTRONICS => const Color(0xFFE6EFFF),
        VendorCategory.FURNITURE => const Color(0xFFEFE8FF),
        VendorCategory.HARDWARE => const Color(0xFFE8EDF2),
        VendorCategory.RESTAURANT => const Color(0xFFFFE9DC),
        VendorCategory.HOTEL => const Color(0xFFE3F3F7),
        VendorCategory.SALON_SPA => const Color(0xFFFCE7F3),
        VendorCategory.FITNESS => const Color(0xFFE6F4E7),
        VendorCategory.SERVICES => const Color(0xFFFFF7D6),
        VendorCategory.EVENTS => const Color(0xFFF1E6FF),
        VendorCategory.OTHER => const Color(0xFFF0F0F0),
      };

  Color get accent => switch (this) {
        VendorCategory.GROCERY => const Color(0xFF3E9B4F),
        VendorCategory.MEAT_FISH => const Color(0xFF14456E),
        VendorCategory.BAKERY => const Color(0xFF6B3E26),
        VendorCategory.CLOTHING => const Color(0xFF2E7D61),
        VendorCategory.ELECTRONICS => const Color(0xFF1F5FD6),
        VendorCategory.FURNITURE => const Color(0xFF6A4BC4),
        VendorCategory.HARDWARE => const Color(0xFF4A5A6A),
        VendorCategory.RESTAURANT => const Color(0xFFC2541A),
        VendorCategory.HOTEL => const Color(0xFF1C7C8C),
        VendorCategory.SALON_SPA => const Color(0xFFB0306E),
        VendorCategory.FITNESS => const Color(0xFF2F7D32),
        VendorCategory.SERVICES => const Color(0xFF8A6A00),
        VendorCategory.EVENTS => const Color(0xFF7B3FC4),
        VendorCategory.OTHER => const Color(0xFF555555),
      };
}

/// Pill colours for each shop tag: (background, text).
(Color, Color) shopTagColors(ShopTag tag) => switch (tag) {
      ShopTag.ENDS_TODAY => (const Color(0xFFFFE5E7), const Color(0xFFC4000F)),
      ShopTag.NEW => (const Color(0xFFE3F6EA), const Color(0xFF1C7A3E)),
      ShopTag.FREE_DELIVERY => (const Color(0xFFE5F0FF), const Color(0xFF1D5BC7)),
      ShopTag.VENUE_OFFER => (const Color(0xFFEFE7FF), const Color(0xFF6A3FC4)),
      ShopTag.DELIVERY => (const Color(0xFFE5F0FF), const Color(0xFF1D5BC7)),
      ShopTag.PICKUP => (const Color(0xFFFFF4D6), const Color(0xFF7A5A00)),
    };

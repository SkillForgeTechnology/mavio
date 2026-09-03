import 'dart:math';
import 'package:flutter/material.dart';

class AppToast {
  /// Cleans raw backend/Postgres exceptions into professional, human-readable text.
  static String cleanErrorMessage(dynamic rawError) {
    if (rawError == null) return "An unexpected error occurred.";
    var str = rawError.toString();

    // Check specific known database/auth error signatures
    if (str.contains('Only management can update authentication records')) {
      return 'Access denied: Only management accounts can update credentials.';
    }
    if (str.contains('Access denied')) {
      return 'Access denied: You do not have permission for this operation.';
    }
    if (str.contains('Invalid credentials') ||
        str.contains('invalid_credentials') ||
        str.contains('Invalid login')) {
      return 'Invalid User ID or Password. Please verify and try again.';
    }
    if (str.contains('Email not confirmed')) {
      return 'Email address not verified. Please check your inbox.';
    }
    if (str.contains('User already registered') || str.contains('already exists')) {
      return 'An account with this record already exists.';
    }
    if (str.contains('SocketException') ||
        str.contains('Failed host lookup') ||
        str.contains('ClientException') ||
        str.contains('NetworkImage')) {
      return 'Network error. Please check your internet connection.';
    }

    // Parse PostgrestException wrappers
    if (str.contains('PostgrestException(')) {
      final match = RegExp(r'message:\s*([^,]+)').firstMatch(str);
      if (match != null) {
        str = match.group(1)?.trim() ?? str;
      }
    }

    // Strip out common exception prefixes
    str = str.replaceAll(RegExp(r'^(Exception:|ClientException:|AuthException:|PostgrestException:)\s*'), '');

    // Trim trailing quotes/braces
    str = str.trim();
    if (str.isEmpty) return "An error occurred. Please try again.";
    
    // Capitalize first letter
    return str[0].toUpperCase() + str.substring(1);
  }

  /// Displays a modern, floating bottom toast card that auto-closes in 3 seconds.
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    final cleanMsg = isError ? cleanErrorMessage(message) : message;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Constrain width on desktop/web while preserving mobile margins
    final targetWidth = min(screenWidth - 32, 440.0);
    final horizontalMargin = max(16.0, (screenWidth - targetWidth) / 2);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        margin: EdgeInsets.only(
          bottom: 24,
          left: horizontalMargin,
          right: horizontalMargin,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? const Color(0xFFFF5252).withOpacity(0.4)
                : const Color(0xFF4CAF50).withOpacity(0.4),
            width: 1,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E24), // Sleek dark card
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFFF5252).withOpacity(0.15)
                    : const Color(0xFF4CAF50).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: isError ? const Color(0xFFFF5252) : const Color(0xFF4CAF50),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cleanMsg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Adaptive file picker that uses platform-appropriate file selection methods.
///
/// On mobile platforms (Android/iOS), uses image_picker for camera and gallery access.
/// On desktop platforms (Windows/macOS/Linux), uses file_picker for file system access.
class AdaptiveFilePicker {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Checks if the current platform is desktop.
  static bool get _isDesktop =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Picks multiple images from the device.
  ///
  /// On mobile: Shows options for camera or gallery using image_picker.
  /// On desktop: Opens file picker dialog for selecting image files.
  ///
  /// Returns a list of file paths, or null if the user cancels.
  static Future<List<String>?> pickImages({
    int? maxImages,
    bool allowCamera = true,
  }) async {
    if (_isDesktop) {
      // Desktop: Use file_picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: maxImages == null || maxImages > 1,
        allowedExtensions: null,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      // Limit to maxImages if specified
      final files = result.files;
      final limitedFiles = maxImages != null && files.length > maxImages
          ? files.take(maxImages).toList()
          : files;

      return limitedFiles
          .where((file) => file.path != null)
          .map((file) => file.path!)
          .toList();
    } else {
      // Mobile: Use image_picker
      if (maxImages == 1) {
        // Single image selection
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
        );
        return image != null ? [image.path] : null;
      } else {
        // Multiple image selection
        final List<XFile> images = await _imagePicker.pickMultiImage();
        if (images.isEmpty) {
          return null;
        }

        // Limit to maxImages if specified
        final limitedImages = maxImages != null && images.length > maxImages
            ? images.take(maxImages).toList()
            : images;

        return limitedImages.map((image) => image.path).toList();
      }
    }
  }

  /// Picks a single image from camera (mobile only).
  ///
  /// On desktop, this method returns null as cameras are not typically supported.
  ///
  /// Returns the file path, or null if the user cancels or platform doesn't support camera.
  static Future<String?> pickImageFromCamera() async {
    if (_isDesktop) {
      // Desktop: Camera not supported
      return null;
    }

    // Mobile: Use image_picker camera
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );

    return image?.path;
  }

  /// Picks a single file of any type.
  ///
  /// [allowedExtensions] can be used to filter file types (e.g., ['pdf', 'doc', 'docx']).
  /// If null, all file types are allowed.
  ///
  /// Returns the file path, or null if the user cancels.
  static Future<String?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.first.path;
  }

  /// Picks multiple files of any type.
  ///
  /// [allowedExtensions] can be used to filter file types (e.g., ['pdf', 'doc', 'docx']).
  /// If null, all file types are allowed.
  ///
  /// Returns a list of file paths, or null if the user cancels.
  static Future<List<String>?> pickFiles({
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files
        .where((file) => file.path != null)
        .map((file) => file.path!)
        .toList();
  }
}

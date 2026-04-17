import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';

/// Shape of the crop frame the user adjusts against.
enum CropAspect { square, recipe, cover }

extension on CropAspect {
  CropAspectRatio get ratio {
    switch (this) {
      case CropAspect.square:
        return const CropAspectRatio(ratioX: 1, ratioY: 1);
      case CropAspect.recipe:
        return const CropAspectRatio(ratioX: 4, ratioY: 3);
      case CropAspect.cover:
        return const CropAspectRatio(ratioX: 16, ratioY: 11);
    }
  }

  String get title {
    switch (this) {
      case CropAspect.square:
        return 'Adjust photo';
      case CropAspect.recipe:
        return 'Frame the dish';
      case CropAspect.cover:
        return 'Frame the cover';
    }
  }
}

/// Pick a photo from the library, then open the native crop/pan UI
/// so the user can position and scale it into the target aspect.
/// Returns a [File] pointing to the cropped image, or null if the user
/// cancelled at any step.
Future<File?> pickAndCropImage({
  required CropAspect aspect,
  int maxSize = 1920,
  int quality = 88,
  ImageSource source = ImageSource.gallery,
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    maxWidth: maxSize.toDouble(),
    maxHeight: maxSize.toDouble(),
    imageQuality: quality,
  );
  if (picked == null) return null;

  return _cropPickedFile(picked.path, aspect);
}

/// Pick multiple photos, then crop each one in turn. Returns the list of
/// successfully cropped files in the order they were picked.
Future<List<File>> pickAndCropMultipleImages({
  required CropAspect aspect,
  required int limit,
  int maxSize = 1920,
  int quality = 88,
}) async {
  if (limit <= 0) return const [];

  final picker = ImagePicker();
  final picked = await picker.pickMultiImage(
    maxWidth: maxSize.toDouble(),
    maxHeight: maxSize.toDouble(),
    imageQuality: quality,
    limit: limit,
  );
  if (picked.isEmpty) return const [];

  final results = <File>[];
  for (final image in picked) {
    final cropped = await _cropPickedFile(image.path, aspect);
    if (cropped != null) results.add(cropped);
  }
  return results;
}

Future<File?> _cropPickedFile(String path, CropAspect aspect) async {
  final cropper = ImageCropper();
  final cropped = await cropper.cropImage(
    sourcePath: path,
    aspectRatio: aspect.ratio,
    compressQuality: 92,
    uiSettings: [
      IOSUiSettings(
        title: aspect.title,
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
        rotateButtonsHidden: false,
        rotateClockwiseButtonHidden: false,
        doneButtonTitle: 'Use photo',
        cancelButtonTitle: 'Cancel',
      ),
      AndroidUiSettings(
        toolbarTitle: aspect.title,
        toolbarColor: AppTheme.accentPlayful,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: AppTheme.accentPlayful,
        backgroundColor: AppTheme.surfaceWarm,
        lockAspectRatio: true,
        hideBottomControls: false,
        initAspectRatio: CropAspectRatioPreset.original,
      ),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path);
}

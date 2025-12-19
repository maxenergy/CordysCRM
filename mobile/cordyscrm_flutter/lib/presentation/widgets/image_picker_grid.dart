import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/media_service.dart';
import '../theme/app_theme.dart';

/// 图片选择网格组件
class ImagePickerGrid extends StatelessWidget {
  const ImagePickerGrid({
    super.key,
    required this.images,
    required this.onImagesChanged,
    this.maxImages = 9,
    this.crossAxisCount = 3,
    this.imageSize = 100.0,
  });

  final List<ImageItem> images;
  final void Function(List<ImageItem> images) onImagesChanged;
  final int maxImages;
  final int crossAxisCount;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    final canAddMore = images.length < maxImages;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 已选图片
        ...images.asMap().entries.map((entry) {
          final index = entry.key;
          final image = entry.value;
          return _ImageTile(
            image: image,
            size: imageSize,
            onDelete: () {
              final newImages = List<ImageItem>.from(images)..removeAt(index);
              onImagesChanged(newImages);
            },
            onTap: () => _showImagePreview(context, images, index),
          );
        }),
        // 添加按钮
        if (canAddMore)
          _AddImageButton(
            size: imageSize,
            onPickFromGallery: () => _pickFromGallery(context),
            onTakePhoto: () => _takePhoto(context),
          ),
      ],
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final mediaService = MediaService();
    final remainingSlots = maxImages - images.length;
    final files = await mediaService.pickImagesFromGallery(maxImages: remainingSlots);
    
    if (files.isNotEmpty) {
      final newImages = List<ImageItem>.from(images);
      for (final file in files) {
        newImages.add(ImageItem.file(file));
      }
      onImagesChanged(newImages);
    }
  }

  Future<void> _takePhoto(BuildContext context) async {
    final mediaService = MediaService();
    final file = await mediaService.takePhoto();
    
    if (file != null) {
      final newImages = List<ImageItem>.from(images)..add(ImageItem.file(file));
      onImagesChanged(newImages);
    }
  }

  void _showImagePreview(BuildContext context, List<ImageItem> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImagePreviewPage(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// 图片项（支持本地文件和网络URL）
class ImageItem {
  final File? file;
  final String? url;

  const ImageItem._({this.file, this.url});

  factory ImageItem.file(File file) => ImageItem._(file: file);
  factory ImageItem.url(String url) => ImageItem._(url: url);

  bool get isFile => file != null;
  bool get isUrl => url != null;
}

/// 图片瓦片
class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.image,
    required this.size,
    required this.onDelete,
    required this.onTap,
  });

  final ImageItem image;
  final double size;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // 图片
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: size,
              height: size,
              child: image.isFile
                  ? Image.file(
                      image.file!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
                    )
                  : CachedNetworkImage(
                      imageUrl: image.url!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildLoadingPlaceholder(),
                      errorWidget: (context, url, error) => _buildErrorPlaceholder(),
                    ),
            ),
          ),
          // 删除按钮
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: AppTheme.backgroundColor,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppTheme.backgroundColor,
      child: const Center(
        child: Icon(Icons.broken_image, color: AppTheme.textTertiary),
      ),
    );
  }
}

/// 添加图片按钮
class _AddImageButton extends StatelessWidget {
  const _AddImageButton({
    required this.size,
    required this.onPickFromGallery,
    required this.onTakePhoto,
  });

  final double size;
  final VoidCallback onPickFromGallery;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppTheme.textTertiary),
            SizedBox(height: 4),
            Text('添加图片', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                onPickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                onTakePhoto();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 图片预览页面
class _ImagePreviewPage extends StatefulWidget {
  const _ImagePreviewPage({
    required this.images,
    required this.initialIndex,
  });

  final List<ImageItem> images;
  final int initialIndex;

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            child: Center(
              child: image.isFile
                  ? Image.file(image.file!, fit: BoxFit.contain)
                  : CachedNetworkImage(
                      imageUrl: image.url!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

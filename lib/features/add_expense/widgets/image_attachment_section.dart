import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';

/// Manages local image file selections before upload.
/// Validates: Requirements 15.1–15.4
class ImageAttachmentSection extends StatefulWidget {
  final List<File> images;
  final ValueChanged<List<File>> onChanged;

  const ImageAttachmentSection({
    super.key,
    required this.images,
    required this.onChanged,
  });

  @override
  State<ImageAttachmentSection> createState() => _ImageAttachmentSectionState();
}

class _ImageAttachmentSectionState extends State<ImageAttachmentSection> {
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final files = await _picker.pickMultiImage(imageQuality: 80);
        if (files.isNotEmpty) {
          widget.onChanged([
            ...widget.images,
            ...files.map((x) => File(x.path)),
          ]);
        }
      } else {
        final file = await _picker.pickImage(
            source: source, imageQuality: 80);
        if (file != null) {
          widget.onChanged([...widget.images, File(file.path)]);
        }
      }
    } catch (_) {}
  }

  void _remove(int index) {
    final updated = List<File>.from(widget.images)..removeAt(index);
    widget.onChanged(updated);
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OptionTile(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _OptionTile(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Add Image card
            _AttachCard(
              icon: Icons.add_photo_alternate_rounded,
              label: 'Add Image',
              onTap: _showOptions,
            ),
            const SizedBox(width: 10),
            // Scan Bill card
            _AttachCard(
              icon: Icons.document_scanner_rounded,
              label: 'Scan Bill',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bill scanning coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppTheme.primaryPurple,
                ),
              ),
            ),
          ],
        ),
        if (widget.images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _ImageThumb(
                file: widget.images[i],
                onRemove: () => _remove(i),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AttachCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primaryPurple, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _ImageThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                  color: AppTheme.errorRed, shape: BoxShape.circle),
              child:
                  const Icon(Icons.close_rounded, color: Colors.white, size: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.lightPurpleContainer,
                  shape: BoxShape.circle),
              child: Icon(icon, color: AppTheme.primaryPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

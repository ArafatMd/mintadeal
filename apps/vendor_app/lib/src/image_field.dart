import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// Picks a photo, uploads it, and reports the resulting URL.
class ImageField extends ConsumerStatefulWidget {
  const ImageField({super.key, required this.url, required this.category, required this.onChanged, this.label = 'Photo'});

  final String? url;
  final VendorCategory category;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  ConsumerState<ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends ConsumerState<ImageField> {
  bool _uploading = false;

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(apiProvider).uploadImage(await file.readAsBytes(), file.name);
      widget.onChanged(url);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Stack(alignment: Alignment.center, children: [
        CatalogueImage(url: widget.url, category: widget.category, size: 88),
        if (_uploading) const CircularProgressIndicator(),
      ]),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pick,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(widget.url == null ? 'Add photo' : 'Change'),
            ),
            if (widget.url != null)
              TextButton(onPressed: _uploading ? null : () => widget.onChanged(null), child: const Text('Remove')),
          ]),
        ]),
      ),
    ]);
  }
}

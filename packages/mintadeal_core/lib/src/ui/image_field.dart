import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/session.dart';
import '../models/enums.dart';
import '../models/models.dart';
import 'widgets.dart';

/// Lets the user choose a photo from the gallery, uploads it and returns its URL, or null if they cancelled.
Future<String?> pickAndUploadImage(BuildContext context, WidgetRef ref, {double maxWidth = 1600}) async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: maxWidth, imageQuality: 85);
  if (file == null) return null;
  return ref.read(apiProvider).uploadImage(await file.readAsBytes(), file.name);
}

/// Picks a photo, uploads it, and reports the resulting URL.
///
/// [aspectRatio] above 1 shows a wide preview, for covers and banners.
class ImageField extends ConsumerStatefulWidget {
  const ImageField({
    super.key,
    required this.url,
    required this.category,
    required this.onChanged,
    this.label = 'Photo',
    this.hint,
    this.aspectRatio = 1,
  });

  final String? url;
  final VendorCategory category;
  final ValueChanged<String?> onChanged;
  final String label;
  final String? hint;
  final double aspectRatio;

  @override
  ConsumerState<ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends ConsumerState<ImageField> {
  bool _uploading = false;

  Future<void> _pick() async {
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadImage(context, ref, maxWidth: widget.aspectRatio > 1 ? 2000 : 1600);
      if (url != null) widget.onChanged(url);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttons = Wrap(spacing: 8, children: [
      OutlinedButton.icon(
        onPressed: _uploading ? null : _pick,
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(widget.url == null ? 'Add photo' : 'Change'),
      ),
      if (widget.url != null)
        TextButton(onPressed: _uploading ? null : () => widget.onChanged(null), child: const Text('Remove')),
    ]);
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: theme.textTheme.titleSmall),
      if (widget.hint != null)
        Text(widget.hint!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);

    if (widget.aspectRatio > 1) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heading,
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(fit: StackFit.expand, children: [
              widget.url == null
                  ? Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.panorama_outlined, size: 40, color: theme.colorScheme.outline),
                    )
                  : Image.network(widget.url!, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: theme.colorScheme.outline)),
              if (_uploading) const Center(child: CircularProgressIndicator()),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        buttons,
      ]);
    }

    return Row(children: [
      Stack(alignment: Alignment.center, children: [
        CatalogueImage(url: widget.url, category: widget.category, size: 88),
        if (_uploading) const CircularProgressIndicator(),
      ]),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading,
          const SizedBox(height: 4),
          buttons,
        ]),
      ),
    ]);
  }
}

/// A round profile photo, or initials when there is none.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.url, required this.name, this.radius = 24});

  final String? url;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final words = (name ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty ? '' : words.take(2).map((w) => w[0].toUpperCase()).join();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: initials.isEmpty
          ? Icon(Icons.person, size: radius)
          : Text(initials, style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.7)),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(url!, width: radius * 2, height: radius * 2, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// The signed-in person's photo, name and phone, with buttons to change or remove the photo.
class ProfilePhotoCard extends ConsumerStatefulWidget {
  const ProfilePhotoCard({super.key, this.subtitle});

  /// Shown under the phone number, e.g. the person's role.
  final String? subtitle;

  @override
  ConsumerState<ProfilePhotoCard> createState() => _ProfilePhotoCardState();
}

class _ProfilePhotoCardState extends ConsumerState<ProfilePhotoCard> {
  bool _busy = false;

  Future<void> _set(Future<String?> Function() getUrl) async {
    setState(() => _busy = true);
    try {
      final url = await getUrl();
      if (url == null) return;
      final user = await ref.read(apiProvider).updateMe(avatarUrl: url);
      await ref.read(sessionProvider.notifier).updateUser(user);
      if (mounted) showMessage(context, url.isEmpty ? 'Photo removed' : 'Photo updated');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(sessionProvider).value?.user;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Stack(alignment: Alignment.center, children: [
            UserAvatar(url: user.avatarUrl, name: user.name, radius: 34),
            if (_busy) const CircularProgressIndicator(),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name ?? 'Your profile', style: theme.textTheme.titleMedium),
              Text(user.phone, style: theme.textTheme.bodySmall),
              if (widget.subtitle != null) Text(widget.subtitle!, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: _busy ? null : () => _set(() => pickAndUploadImage(context, ref, maxWidth: 800)),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(user.avatarUrl == null ? 'Add photo' : 'Change photo'),
                ),
                if (user.avatarUrl != null)
                  TextButton(
                    onPressed: _busy ? null : () => _set(() async => ''),
                    child: const Text('Remove'),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

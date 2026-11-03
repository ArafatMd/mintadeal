import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import '../shop_form_screen.dart';
import 'popup_text.dart';

final popupMeProvider = FutureProvider.autoDispose<PopupMe>((ref) => ref.watch(apiProvider).popupMe());

/// Green for "you are live": the one place it is used, so it reads as "on".
const _liveGreen = Color(0xFF1B7F3B);

/// A tall, full-width button with a big icon, for people who are not used to apps.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.icon, required this.label, this.onPressed, this.color, this.outlined = false,
      this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool outlined;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.primary;
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      busy
          ? SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: outlined ? bg : Colors.white))
          : Icon(icon, size: 30),
      const SizedBox(width: 12),
      Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
    ]);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(68)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    );
    return outlined
        ? OutlinedButton(
            onPressed: busy ? null : onPressed,
            style: style.copyWith(
              foregroundColor: WidgetStatePropertyAll(bg),
              side: WidgetStatePropertyAll(BorderSide(color: bg, width: 2)),
            ),
            child: child)
        : FilledButton(
            onPressed: busy ? null : onPressed,
            style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(onPressed == null ? scheme.surfaceContainerHighest : bg),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
            child: child);
  }
}

/// The globe in the top bar: English, Kannada or Hindi, as three big buttons.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(popupLangProvider);
    return TextButton.icon(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final l in PopupLang.values) ...[
                BigButton(
                  icon: l == lang ? Icons.check_circle : Icons.translate,
                  label: l.nativeName,
                  outlined: l != lang,
                  onPressed: () {
                    ref.read(popupLangProvider.notifier).choose(l);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ]),
          ),
        ),
      ),
      icon: const Icon(Icons.translate),
      label: Text(lang.nativeName),
    );
  }
}

/// First screen for someone without a shop: a shop, or a stall for a few days.
class StartChoiceScreen extends ConsumerWidget {
  const StartChoiceScreen({super.key, required this.me});

  final PopupMe me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(popupTextProvider);
    final theme = Theme.of(context);
    Widget choice(IconData icon, String title, String hint, Color color, VoidCallback onTap) => Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color, width: 2)),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(radius: 34, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, size: 38, color: color)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(hint, style: theme.textTheme.bodyLarge),
                  ]),
                ),
                Icon(Icons.chevron_right, size: 32, color: color),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: const MintadealLogo(height: 28),
        actions: [
          const LanguageButton(),
          IconButton(
            tooltip: t.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(t.chooseTitle, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        choice(Icons.storefront, t.haveShop, t.haveShopHint, theme.colorScheme.primary,
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopFormScreen(existing: null)))),
        const SizedBox(height: 16),
        choice(Icons.local_mall, t.stall, t.stallHint, _liveGreen,
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StallFlow(me: me)))),
      ]),
    );
  }
}

/// The seller's stall: live now, or start one, with earlier stalls to sell again.
class PopupHome extends ConsumerStatefulWidget {
  const PopupHome({super.key, required this.me});

  final PopupMe me;

  @override
  ConsumerState<PopupHome> createState() => _PopupHomeState();
}

class _PopupHomeState extends ConsumerState<PopupHome> {
  bool _busy = false;

  Future<void> _run(Future<PopupMe> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(popupMeProvider);
      if (mounted && done != null) showMessage(context, done);
    } on LocationProblem {
      if (mounted) showMessage(context, ref.read(popupTextProvider).locationFailed);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move(MyPopup live) async {
    final t = ref.read(popupTextProvider);
    await _run(() async {
      final p = await currentLocation();
      if (!inBengaluru(p)) throw ApiError(400, 'outside_city', t.outsideCity);
      return ref.read(apiProvider).movePopup(live.id, p);
    }, done: t.placeUpdated);
  }

  Future<void> _stop(MyPopup live) async {
    final t = ref.read(popupTextProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.stop),
        content: Text(t.stopConfirm, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.no, style: const TextStyle(fontSize: 18))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.yes, style: const TextStyle(fontSize: 18))),
        ],
      ),
    );
    if (ok == true) await _run(() => ref.read(apiProvider).stopPopup(live.id), done: t.stopped);
  }

  Future<void> _rename() async {
    final t = ref.read(popupTextProvider);
    final controller = TextEditingController(text: widget.me.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.changeName),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(fontSize: 20),
            textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.back)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(t.save)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await _run(() => ref.read(apiProvider).renamePopupSeller(name));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(popupTextProvider);
    final me = widget.me;
    final live = me.live;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(me.name ?? t.myStall, overflow: TextOverflow.ellipsis),
        actions: [
          const LanguageButton(),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'name' => _rename(),
              'help' => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const HelpScreen(as: Role.CUSTOMER))),
              _ => ref.read(sessionProvider.notifier).signOut(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'name', child: Text(t.changeName)),
              PopupMenuItem(value: 'help', child: Text(t.help)),
              PopupMenuItem(value: 'out', child: Text(t.signOut)),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(popupMeProvider.future),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (me.blocked)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Icon(Icons.block, size: 40, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 14),
                  Expanded(child: Text(t.blocked, style: theme.textTheme.titleMedium)),
                ]),
              ),
            )
          else if (live != null) ...[
            _LiveCard(popup: live),
            const SizedBox(height: 16),
            BigButton(icon: Icons.my_location, label: t.moved, outlined: true, busy: _busy, onPressed: () => _move(live)),
            const SizedBox(height: 12),
            BigButton(icon: Icons.stop_circle_outlined, label: t.stop, color: theme.colorScheme.error, outlined: true,
                busy: _busy, onPressed: () => _stop(live)),
          ] else
            BigButton(
              icon: Icons.add_a_photo,
              label: t.startSelling,
              color: _liveGreen,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StallFlow(me: me))),
            ),
          if (me.history.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(t.pastStalls, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final p in me.history)
              _PastStall(
                popup: p,
                canSellAgain: live == null && !me.blocked && p.status != PopupStatus.REMOVED,
                onSellAgain: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StallFlow(me: me, again: p))),
              ),
          ],
          const SizedBox(height: 24),
          const DeleteAccountTile(),
        ]),
      ),
    );
  }
}

class _LiveCard extends ConsumerWidget {
  const _LiveCard({required this.popup});

  final MyPopup popup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(popupTextProvider);
    final theme = Theme.of(context);
    final area = nearestArea(GeoPoint(popup.latitude, popup.longitude)).name;
    return Card(
      color: _liveGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.wifi_tethering, color: Colors.white, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t.liveTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(t.liveHint, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
          const SizedBox(height: 14),
          _Fact(icon: Icons.place, text: t.near(area)),
          _Fact(icon: Icons.timer_outlined, text: t.endsIn(popup.endsAt.difference(DateTime.now()))),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: popup.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _Thumb(item: popup.items[i], size: 84),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
        ]),
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.size});

  final PopupItem item;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(children: [
          Image.network(item.imageUrl, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(width: size, height: size, color: Colors.black12,
                  child: const Icon(Icons.image_not_supported_outlined))),
          if (item.priceMinor != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(formatInr(item.priceMinor!), textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      );
}

class _PastStall extends ConsumerWidget {
  const _PastStall({required this.popup, required this.canSellAgain, required this.onSellAgain});

  final MyPopup popup;
  final bool canSellAgain;
  final VoidCallback onSellAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(popupTextProvider);
    final theme = Theme.of(context);
    final d = popup.startsAt;
    final area = nearestArea(GeoPoint(popup.latitude, popup.longitude)).name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _Thumb(item: popup.items.first, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d.day}/${d.month}/${d.year} · ${t.days(popup.days)}', style: theme.textTheme.titleMedium),
                Text(t.near(area), style: theme.textTheme.bodyMedium),
                if (popup.status == PopupStatus.REMOVED)
                  Text(t.removed, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ]),
            ),
          ]),
          if (canSellAgain) ...[
            const SizedBox(height: 10),
            BigButton(icon: Icons.replay, label: t.sellAgain, outlined: true, color: _liveGreen, onPressed: onSellAgain),
          ],
        ]),
      ),
    );
  }
}

/// Opening a stall, one question per screen: name (first time), photos, days, "are you here?".
/// With [again], the photos of that earlier stall are reused and only days and place are asked.
class StallFlow extends ConsumerStatefulWidget {
  const StallFlow({super.key, required this.me, this.again});

  final PopupMe me;
  final MyPopup? again;

  @override
  ConsumerState<StallFlow> createState() => _StallFlowState();
}

enum _Step { name, photos, days, here, done }

class _Photo {
  _Photo(this.url);

  final String url;
  final title = TextEditingController();
  final price = TextEditingController();
}

class _StallFlowState extends ConsumerState<StallFlow> {
  late final List<_Step> _steps;
  int _at = 0;
  final _name = TextEditingController();
  final _photos = <_Photo>[];
  late int _days;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _steps = [
      if (widget.me.name == null) _Step.name,
      if (widget.again == null) _Step.photos,
      _Step.days,
      _Step.here,
      _Step.done,
    ];
    _days = widget.again?.days ?? widget.me.defaultDays;
  }

  @override
  void dispose() {
    _name.dispose();
    for (final p in _photos) {
      p.title.dispose();
      p.price.dispose();
    }
    super.dispose();
  }

  _Step get _step => _steps[_at];

  void _next() {
    final t = ref.read(popupTextProvider);
    if (_step == _Step.name && _name.text.trim().isEmpty) return setState(() => _error = t.typeName);
    if (_step == _Step.photos && _photos.isEmpty) return setState(() => _error = t.addOnePhoto);
    setState(() {
      _error = null;
      _at++;
    });
  }

  void _back() {
    if (_at == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = null;
        _at--;
      });
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final url = await pickAndUploadImage(context, ref, source: source, maxWidth: 1400);
      if (url != null) {
        setState(() {
          _photos.add(_Photo(url));
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final t = ref.read(popupTextProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await currentLocation();
      if (!inBengaluru(p)) {
        setState(() => _error = t.outsideCity);
        return;
      }
      final api = ref.read(apiProvider);
      if (widget.again != null) {
        await api.popupAgain(widget.again!.id, at: p, days: _days);
      } else {
        await api.startPopup(
          name: widget.me.name == null ? _name.text.trim() : null,
          items: [
            for (final ph in _photos)
              PopupItem(
                imageUrl: ph.url,
                title: ph.title.text.trim().isEmpty ? null : ph.title.text.trim(),
                priceMinor: parseRupees(ph.price.text),
              ),
          ],
          at: p,
          days: _days,
        );
      }
      ref.invalidate(popupMeProvider);
      setState(() => _at++);
    } on LocationProblem {
      setState(() => _error = t.locationFailed);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(popupTextProvider);
    final theme = Theme.of(context);
    final title = switch (_step) {
      _Step.name => t.yourName,
      _Step.photos => t.photosTitle,
      _Step.days => t.daysTitle,
      _Step.here => t.hereTitle,
      _Step.done => t.youAreLive,
    };
    final body = switch (_step) {
      _Step.name => _nameStep(t),
      _Step.photos => _photosStep(t),
      _Step.days => _daysStep(t),
      _Step.here => _hereStep(t),
      _Step.done => _doneStep(t),
    };
    final steps = _steps.length - 1;
    return PopScope(
      canPop: _at == 0 || _step == _Step.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: _step != _Step.done,
          title: _step == _Step.done ? null : Text('${_at + 1} / $steps', style: theme.textTheme.titleLarge),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_step != _Step.done)
              LinearProgressIndicator(value: (_at + 1) / steps, minHeight: 6, color: _liveGreen),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                body,
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: theme.textTheme.titleMedium)),
                    ]),
                  ),
                ],
              ]),
            ),
            if (_step != _Step.here && _step != _Step.done)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: BigButton(icon: Icons.arrow_forward, label: t.next, onPressed: _busy ? null : _next),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _nameStep(PopupText t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.person, size: 30)),
          onSubmitted: (_) => _next(),
        ),
        Text(t.yourNameHint, style: const TextStyle(fontSize: 16)),
      ]);

  Widget _photosStep(PopupText t) {
    final max = widget.me.maxItems;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < _photos.length; i++) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_photos[i].url, width: 96, height: 96, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(children: [
                  TextField(
                    controller: _photos[i].price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(labelText: t.price, helperText: t.optional, isDense: true),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _photos[i].title,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: t.itemName, isDense: true, counterText: ''),
                  ),
                ]),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close, size: 28),
                onPressed: () => setState(() => _photos.removeAt(i)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (_photos.length < max) ...[
        BigButton(
          icon: Icons.photo_camera,
          label: t.takePhoto,
          color: _liveGreen,
          busy: _busy,
          onPressed: () => _addPhoto(ImageSource.camera),
        ),
        const SizedBox(height: 10),
        BigButton(
          icon: Icons.photo_library,
          label: t.fromGallery,
          outlined: true,
          color: _liveGreen,
          busy: _busy,
          onPressed: () => _addPhoto(ImageSource.gallery),
        ),
      ],
      const SizedBox(height: 14),
      Text(t.notAllowed, style: const TextStyle(fontSize: 15)),
    ]);
  }

  Widget _daysStep(PopupText t) => Wrap(spacing: 12, runSpacing: 12, children: [
        for (final d in widget.me.allowedDays)
          SizedBox(
            width: 150,
            height: 96,
            child: ChoiceChip(
              showCheckmark: false,
              selected: _days == d,
              selectedColor: _liveGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              labelPadding: EdgeInsets.zero,
              label: SizedBox(
                width: 140,
                height: 84,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$d', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                      color: _days == d ? Colors.white : null)),
                  Text(t.days(d).replaceFirst('$d ', ''), style: TextStyle(fontSize: 18,
                      color: _days == d ? Colors.white : null)),
                ]),
              ),
              onSelected: (_) => setState(() => _days = d),
            ),
          ),
      ]);

  Widget _hereStep(PopupText t) {
    final phone = ref.watch(sessionProvider).value?.user.phone ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.person_pin_circle, size: 120, color: _liveGreen),
      Text(t.hereHint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 20),
      BigButton(
        icon: Icons.check_circle,
        label: _busy ? t.finding : t.imHere,
        color: _liveGreen,
        busy: _busy,
        onPressed: _start,
      ),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.call, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(t.phoneShown(phone), style: const TextStyle(fontSize: 16))),
      ]),
    ]);
  }

  Widget _doneStep(PopupText t) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.check_circle, size: 140, color: _liveGreen),
        Text(t.liveHint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 28),
        BigButton(icon: Icons.home, label: t.myStall, color: _liveGreen, onPressed: () => Navigator.of(context).pop()),
      ]);
}

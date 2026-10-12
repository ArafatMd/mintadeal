import 'package:flutter/material.dart';

import '../models/models.dart';
import 'async_view.dart';

/// A pull-to-refresh list that loads pages on demand. Change [queryKey] to reload from page 0.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.queryKey,
    required this.fetch,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.separator = 12,
  });

  final Object queryKey;
  final Future<PageResult<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;
  final Widget? header;
  final EdgeInsets padding;
  final double separator;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final List<T> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PagedList<T> old) {
    super.didUpdateWidget(old);
    if (old.queryKey != widget.queryKey) _reload();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final result = await widget.fetch(_page);
      // Ignore results for a query that was replaced while this page was loading.
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _page++;
        _error = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showEmpty = _items.isEmpty && !_loading && _error == null && !_hasMore;
    final showError = _items.isEmpty && _error != null;
    return RefreshIndicator(
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          children: [
            ?widget.header,
            if (showError) ErrorView(message: '$_error', onRetry: _reload),
            if (showEmpty) widget.empty,
            for (final (i, item) in _items.indexed) ...[
              if (i > 0) SizedBox(height: widget.separator),
              widget.itemBuilder(context, item),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_items.isNotEmpty && _error != null)
              TextButton(onPressed: _loadMore, child: const Text('Could not load more. Try again')),
          ],
        ),
      ),
    );
  }
}

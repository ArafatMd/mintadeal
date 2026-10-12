import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'vendor_detail_page.dart';

class VendorsPage extends ConsumerStatefulWidget {
  const VendorsPage({super.key});

  @override
  ConsumerState<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends ConsumerState<VendorsPage> {
  VendorStatus? _status = VendorStatus.PENDING;
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final date = DateFormat('d MMM, h:mm a');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Vendors', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 16),
          for (final s in [VendorStatus.PENDING, VendorStatus.APPROVED, VendorStatus.REJECTED, VendorStatus.SUSPENDED, null])
            ChoiceChip(
              label: Text(s == null ? 'All' : s.label),
              selected: _status == s,
              onSelected: (_) => setState(() => _status = s),
            ),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
        ]),
      ),
      Expanded(
        child: PagedList<Vendor>(
          queryKey: (_status, _reload),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          separator: 8,
          fetch: (page) => api.adminVendors(status: _status, page: page),
          empty: EmptyView(
            icon: Icons.inbox_outlined,
            title: _status == VendorStatus.PENDING ? 'No shops waiting for review' : 'No shops',
          ),
          itemBuilder: (context, v) => Card(
            child: ListTile(
              leading: CatalogueImage(url: v.json['logoUrl'] as String?, category: v.category, size: 44),
              title: Text(v.displayName),
              subtitle: Text([
                v.category.label,
                v.area,
                v.phone,
                if (v.vendorType == VendorType.INTERNAL) 'Mintadeal own',
                'applied ${date.format(v.createdAt)}',
              ].join(' · ')),
              trailing: StatusChip(label: v.status.label, color: vendorStatusColor(v.status)),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VendorDetailPage(vendorId: v.id)));
                setState(() => _reload++);
              },
            ),
          ),
        ),
      ),
    ]);
  }
}

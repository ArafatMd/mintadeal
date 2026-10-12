import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'job_screen.dart';

final availableJobsProvider = FutureProvider.autoDispose<List<DeliveryJobView>>((ref) {
  // Refresh the job board regularly while it is on screen.
  final timer = Timer(const Duration(seconds: 20), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(apiProvider).availableJobs();
});

final myJobsProvider = FutureProvider.autoDispose.family<List<DeliveryJobView>, String>(
    (ref, scope) => ref.watch(apiProvider).myJobs(scope));

class DeliveryHome extends ConsumerStatefulWidget {
  const DeliveryHome({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<DeliveryHome> createState() => _DeliveryHomeState();
}

class _DeliveryHomeState extends ConsumerState<DeliveryHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(myJobsProvider('ACTIVE')).value?.length ?? 0;
    final available = ref.watch(availableJobsProvider).value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const MintadealLogo(height: 32),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.user.name ?? 'Delivery partner', overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: const [
        _JobList(scope: 'AVAILABLE'),
        _JobList(scope: 'ACTIVE'),
        _JobList(scope: 'HISTORY'),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(isLabelVisible: available > 0, label: Text('$available'), child: const Icon(Icons.work_outline)),
            label: 'New jobs',
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: active > 0, label: Text('$active'), child: const Icon(Icons.delivery_dining_outlined)),
            selectedIcon: const Icon(Icons.delivery_dining),
            label: 'My jobs',
          ),
          const NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

class _JobList extends ConsumerWidget {
  const _JobList({required this.scope});

  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = scope == 'AVAILABLE' ? ref.watch(availableJobsProvider) : ref.watch(myJobsProvider(scope));
    Future<void> refresh() async {
      ref.invalidate(availableJobsProvider);
      ref.invalidate(myJobsProvider);
    }

    return AsyncView(
      value: jobs,
      onRetry: refresh,
      data: (list) => RefreshIndicator(
        onRefresh: refresh,
        child: list.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                EmptyView(
                  icon: scope == 'HISTORY' ? Icons.history : Icons.route_outlined,
                  title: switch (scope) {
                    'AVAILABLE' => 'No jobs waiting',
                    'ACTIVE' => 'No jobs in hand',
                    _ => 'No finished jobs yet',
                  },
                  message: scope == 'AVAILABLE' ? 'New pickups appear here. Pull down to refresh.' : null,
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => JobCard(
                  job: list[i],
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobScreen(jobId: list[i].id)));
                    await refresh();
                  },
                ),
              ),
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});

  final DeliveryJobView job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(job.pickup.name ?? job.pickup.area, style: theme.textTheme.titleSmall)),
              StatusChip(label: job.status.label, color: job.status.isActive ? theme.colorScheme.primary : Colors.grey.shade700),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.storefront_outlined, size: 16),
              const SizedBox(width: 4),
              Text(job.pickup.area),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 16)),
              const Icon(Icons.home_outlined, size: 16),
              const SizedBox(width: 4),
              Flexible(child: Text(job.drop.area, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text([
              '${job.distanceKm.toStringAsFixed(1)} km',
              '${job.itemCount} ${job.itemCount == 1 ? 'item' : 'items'}',
              job.cashToCollectMinor > 0 ? 'Collect ${formatInr(job.cashToCollectMinor)} cash' : 'Prepaid',
              job.orderCode,
            ].join(' · '), style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

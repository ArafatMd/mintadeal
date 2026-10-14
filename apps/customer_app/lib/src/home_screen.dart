import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'cart_bar.dart';
import 'deals_feed.dart';
import 'following_screen.dart';
import 'orders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          DealsFeed(),
          FollowingScreen(),
          OrdersScreen(),
          AccountScreen(),
        ],
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        // The cart bar follows the customer while they shop.
        if (_tab <= 1) const CartBar(),
        _BottomNav(index: _tab, onSelected: (i) => setState(() => _tab = i)),
      ]),
    );
  }
}

/// Home, Following, Orders, Account. The selected tab is red, with a red line under it.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.favorite_border, Icons.favorite, 'Following'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
    (Icons.person_outline, Icons.person, 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = theme.colorScheme.primary;
    final grey = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(children: [
            for (final (i, (icon, selectedIcon, label)) in _items.indexed)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: InkWell(
                    onTap: () => onSelected(i),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      Icon(i == index ? selectedIcon : icon, color: i == index ? red : grey, size: 26),
                      const SizedBox(height: 2),
                      Text(label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: i == index ? red : grey,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                          )),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: i == index ? 44 : 0,
                        decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(2)),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

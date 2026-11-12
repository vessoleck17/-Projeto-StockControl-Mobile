import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'dashboard_page.dart';
import 'products_page.dart';
import 'movements_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.apiService, required this.user});

  final ApiService apiService;
  final AppUser user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = <Widget>[
    DashboardPage(
      user: widget.user,
      apiService: widget.apiService,
      onOpenProducts: () {
        setState(() {
          _selectedIndex = 1;
        });
      },
      onOpenMovements: () {
        setState(() {
          _selectedIndex = 2;
        });
      },
    ),
    ProductsPage(user: widget.user, apiService: widget.apiService),
    MovementsPage(user: widget.user, apiService: widget.apiService),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Produtos',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz_rounded),
            label: 'Movimentações',
          ),
        ],
      ),
    );
  }
}

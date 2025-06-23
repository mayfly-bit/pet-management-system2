import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dog_provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/error_widget.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String location;

  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  final List<NavigationItem> _navigationItems = [
    const NavigationItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: '仪表板',
      route: '/dashboard',
    ),
    const NavigationItem(
      icon: Icons.pets_outlined,
      selectedIcon: Icons.pets,
      label: '狗狗',
      route: '/dogs',
    ),
    const NavigationItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: '支出',
      route: '/expenses',
    ),
    const NavigationItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: '报表',
      route: '/reports',
    ),
    const NavigationItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '设置',
      route: '/settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _updateSelectedIndex();
    // 延迟初始化数据，避免在构建过程中触发状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _updateSelectedIndex();
    }
  }

  void _updateSelectedIndex() {
    for (int i = 0; i < _navigationItems.length; i++) {
      if (widget.location.startsWith(_navigationItems[i].route)) {
        setState(() {
          _selectedIndex = i;
        });
        break;
      }
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    try {
      // Initialize providers with data
      final dogProvider = context.read<DogProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      
      // Load initial data
      await Future.wait([
        dogProvider.loadDogs(),
        expenseProvider.loadExpenses(),
        expenseProvider.loadCategories(),
      ]);
    } catch (e) {
      print('初始化数据失败: $e');
    }
  }

  void _onNavigationTap(int index) {
    if (index != _selectedIndex) {
      context.go(_navigationItems[index].route);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '退出登录',
      message: '确定要退出登录吗？',
      confirmText: '退出',
      cancelText: '取消',
      icon: Icons.logout,
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<AuthProvider>().signOut();
        if (mounted) {
          context.go('/auth/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('退出登录失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavigationTap,
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primaryContainer,
        destinations: _navigationItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          );
        }).toList(),
      ),
      drawer: _buildDrawer(context),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    
    return Drawer(
      child: Column(
        children: [
          // Drawer header
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final user = authProvider.currentUser;
              
              return DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.onPrimary,
                      child: user?.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(
                                user!.avatarUrl!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Text(
                                    user.initials,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Text(
                              user?.initials ?? 'U',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.displayName ?? '用户',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ..._navigationItems.map((item) {
                  final isSelected = widget.location.startsWith(item.route);
                  
                  return ListTile(
                    leading: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.onSurface,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(item.route);
                    },
                  );
                }),
                
                const Divider(),
                
                // Additional menu items
                ListTile(
                  leading: Icon(
                    Icons.backup_outlined,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: const Text('数据备份'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: Implement backup functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('备份功能即将推出'),
                      ),
                    );
                  },
                ),
                
                ListTile(
                  leading: Icon(
                    Icons.help_outline,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: const Text('帮助与支持'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: Implement help functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('帮助功能即将推出'),
                      ),
                    );
                  },
                ),
                
                ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: const Text('关于应用'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAboutDialog();
                  },
                ),
              ],
            ),
          ),
          
          // Logout button
          Container(
            padding: const EdgeInsets.all(16),
            child: CustomOutlinedButton(
              text: '退出登录',
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              width: double.infinity,
              borderColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '宠物利润管理系统',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.pets,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      children: [
        const Text(
          '一个专业的宠物利润管理应用，帮助您轻松管理犬只信息、追踪支出和分析利润。',
        ),
        const SizedBox(height: 16),
        const Text(
          '功能特色：',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text('• 犬只档案管理'),
        const Text('• 财务记录追踪'),
        const Text('• 利润分析报表'),
        const Text('• 数据同步备份'),
      ],
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dog_provider.dart';
import '../../providers/expense_provider.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/common/loading_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _notificationsEnabled = true;
  bool _autoBackup = true;
  String _backupFrequency = 'daily';
  String _currency = 'CNY';
  String _language = 'zh';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await LocalStorageService.init();
      
      // Load user preferences
      _notificationsEnabled = LocalStorageService.getBool('notifications_enabled', defaultValue: true);
      _autoBackup = LocalStorageService.getBool('auto_backup', defaultValue: true);
      _backupFrequency = LocalStorageService.getString('backup_frequency', defaultValue: 'daily');
      _currency = LocalStorageService.getString('currency', defaultValue: 'CNY');
      _language = LocalStorageService.getString('language', defaultValue: 'zh');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载设置失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      await LocalStorageService.init();
      
      if (value is bool) {
        await LocalStorageService.setBool(key, value);
      } else if (value is String) {
        await LocalStorageService.setString(key, value);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存设置失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await LocalStorageService.init();
      
      final data = await LocalStorageService.exportData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据导出成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有本地缓存数据吗？这将需要重新从服务器加载数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await LocalStorageService.init();
        await LocalStorageService.clearCachedData();
        
        // Reload data
        if (mounted) {
          await context.read<DogProvider>().loadDogs();
          await context.read<ExpenseProvider>().loadExpenses();
          await context.read<ExpenseProvider>().loadCategories();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('缓存清除成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('清除缓存失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _syncData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Sync all data
      await context.read<DogProvider>().loadDogs();
      await context.read<ExpenseProvider>().loadExpenses();
      await context.read<ExpenseProvider>().loadCategories();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据同步成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据同步失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<AuthProvider>().signOut();
        if (mounted) {
          context.go('/login');
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
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User info section
            _buildUserInfoSection(),
            
            const SizedBox(height: 24),
            
            // App settings section
            _buildAppSettingsSection(),
            
            const SizedBox(height: 24),
            
            // Data management section
            _buildDataManagementSection(),
            
            const SizedBox(height: 24),
            
            // About section
            _buildAboutSection(),
            
            const SizedBox(height: 24),
            
            // Logout button
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '用户信息',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.user;
                
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(user?.displayName ?? '未设置'),
                      subtitle: Text(user?.email ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          context.go('/settings/profile');
                        },
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '应用设置',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('推送通知'),
              subtitle: const Text('接收重要提醒和通知'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _saveSetting('notifications_enabled', value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              title: const Text('货币单位'),
              subtitle: Text(_getCurrencyName(_currency)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCurrencySelector(),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              title: const Text('语言'),
              subtitle: Text(_getLanguageName(_language)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageSelector(),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '数据管理',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('自动备份'),
              subtitle: const Text('定期自动备份数据到云端'),
              value: _autoBackup,
              onChanged: (value) {
                setState(() {
                  _autoBackup = value;
                });
                _saveSetting('auto_backup', value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_autoBackup) ...[
              const Divider(),
              ListTile(
                title: const Text('备份频率'),
                subtitle: Text(_getBackupFrequencyName(_backupFrequency)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBackupFrequencySelector(),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('同步数据'),
              subtitle: const Text('从服务器同步最新数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _syncData,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('导出数据'),
              subtitle: const Text('导出所有数据到本地文件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportData,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('清除缓存'),
              subtitle: const Text('清除本地缓存数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _clearCache,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '关于',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('应用版本'),
              subtitle: Text('1.0.0'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('帮助与支持'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to help page
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('隐私政策'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to privacy policy
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('服务条款'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to terms of service
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          '退出登录',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showCurrencySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final currencies = {
          'CNY': '人民币 (¥)',
          'USD': '美元 (\$)',
          'EUR': '欧元 (€)',
          'GBP': '英镑 (£)',
          'JPY': '日元 (¥)',
        };
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择货币单位',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...currencies.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  trailing: _currency == entry.key
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _currency = entry.key;
                    });
                    _saveSetting('currency', entry.key);
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final languages = {
          'zh': '中文',
          'en': 'English',
        };
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择语言',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...languages.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  trailing: _language == entry.key
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _language = entry.key;
                    });
                    _saveSetting('language', entry.key);
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showBackupFrequencySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final frequencies = {
          'daily': '每日',
          'weekly': '每周',
          'monthly': '每月',
        };
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择备份频率',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...frequencies.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  trailing: _backupFrequency == entry.key
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _backupFrequency = entry.key;
                    });
                    _saveSetting('backup_frequency', entry.key);
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _getCurrencyName(String currency) {
    switch (currency) {
      case 'CNY':
        return '人民币 (¥)';
      case 'USD':
        return '美元 (\$)';
      case 'EUR':
        return '欧元 (€)';
      case 'GBP':
        return '英镑 (£)';
      case 'JPY':
        return '日元 (¥)';
      default:
        return '人民币 (¥)';
    }
  }

  String _getLanguageName(String language) {
    switch (language) {
      case 'zh':
        return '中文';
      case 'en':
        return 'English';
      default:
        return '中文';
    }
  }

  String _getBackupFrequencyName(String frequency) {
    switch (frequency) {
      case 'daily':
        return '每日';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      default:
        return '每日';
    }
  }
}
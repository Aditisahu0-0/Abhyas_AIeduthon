import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/language_service.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    
    return Scaffold(
      appBar: AppBar(title: Text(languageService.translate('Settings')), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageService.translate('Appearance'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return SwitchListTile(
                        title: Text(languageService.translate('Dark Mode')),
                        subtitle: Text(
                          themeProvider.isDarkMode ? languageService.translate('Enabled') : languageService.translate('Disabled'),
                        ),
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme();
                        },
                        secondary: Icon(
                          themeProvider.isDarkMode
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: AppTheme.cyanAccent,
                        ),
                        activeColor: AppTheme.cyanAccent,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // About Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(languageService.translate('About'), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(languageService.translate('App Version')),
                    subtitle: const Text('1.0.0'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.school_rounded),
                    title: Text(languageService.translate('ABHYAS')),
                    subtitle: Text(languageService.translate('Offline Learning Platform')),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),



          // Account Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageService.translate('Account'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: Text(
                      languageService.translate('Logout'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(languageService.translate('Clear session and return to login')),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(languageService.translate('Logout')),
                          content: Text(
                            languageService.translate('Are you sure you want to logout? You will need internet to log in again.'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(languageService.translate('Cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                languageService.translate('Logout'),
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        final authService = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        await authService.logout();
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          // Sync Status Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageService.translate('Sync Status'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Consumer<SyncService>(
                    builder: (context, syncService, child) {
                      String statusText;
                      Color statusColor;
                      IconData statusIcon;

                      switch (syncService.status) {
                        case SyncStatus.syncing:
                          statusText = languageService.translate('Syncing...');
                          statusColor = Colors.blue;
                          statusIcon = Icons.sync;
                          break;
                        case SyncStatus.success:
                          statusText = languageService.translate('Synced');
                          statusColor = Colors.green;
                          statusIcon = Icons.check_circle;
                          break;
                        case SyncStatus.error:
                          statusText = languageService.translate('Sync Error');
                          statusColor = Colors.red;
                          statusIcon = Icons.error_outline;
                          break;
                        case SyncStatus.idle:
                        default:
                          statusText = languageService.translate('Up to date');
                          statusColor = Colors.grey;
                          statusIcon = Icons.cloud_done;
                          break;
                      }

                      String lastSyncText = languageService.translate('Never synced');
                      if (syncService.lastSyncTime != null) {
                        final diff = DateTime.now().difference(
                          syncService.lastSyncTime!,
                        );
                        if (diff.inMinutes < 1) {
                          lastSyncText = languageService.translate('Just now');
                        } else if (diff.inMinutes < 60) {
                          lastSyncText = '${diff.inMinutes} ${languageService.translate("mins ago")}';
                        } else if (diff.inHours < 24) {
                          lastSyncText = '${diff.inHours} ${languageService.translate("hours ago")}';
                        } else {
                          lastSyncText = '${diff.inDays} ${languageService.translate("days ago")}';
                        }
                      }

                      return ListTile(
                        leading: syncService.status == SyncStatus.syncing
                            ? const CircularProgressIndicator()
                            : Icon(statusIcon, color: statusColor),
                        title: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text('${languageService.translate("Last synced")}: $lastSyncText'),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            syncService.triggerSync();
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

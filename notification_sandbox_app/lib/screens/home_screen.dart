import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetch notifications when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).fetchNotifications();
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(notificationsProvider.notifier).clearNotifications();
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Sandbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(user),
          _buildNotificationsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            // Refresh notifications when switching to notifications tab
            ref.read(notificationsProvider.notifier).fetchNotifications();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(user) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(notificationsProvider.notifier).fetchUnreadCount();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome, ${user?.name ?? 'User'}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  if (user?.isAdmin == true) ...[
                    const SizedBox(height: 8),
                    Chip(
                      label: const Text('Admin'),
                      backgroundColor: Colors.amber.shade100,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('About This App'),
              subtitle: const Text(
                'This app demonstrates real-time push notifications using Firebase Cloud Messaging and Laravel Reverb WebSocket.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wifi, color: Colors.green),
                  title: const Text('WebSocket Status'),
                  subtitle: _buildWebSocketStatus(),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.orange),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Enabled'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSocketStatus() {
    // For now, show a simple status
    return const Text('Connected');
  }

  Widget _buildNotificationsTab() {
    final notificationsState = ref.watch(notificationsProvider);

    if (notificationsState.isLoading && notificationsState.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notificationsState.error != null && notificationsState.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(notificationsState.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).fetchNotifications();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (notificationsState.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(notificationsProvider.notifier).fetchNotifications();
      },
      child: Column(
        children: [
          if (notificationsState.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () async {
                  await ref.read(notificationsProvider.notifier).markAllAsRead();
                },
                child: const Text('Mark all as read'),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: notificationsState.notifications.length,
              itemBuilder: (context, index) {
                final notification = notificationsState.notifications[index];
                return Dismissible(
                  key: Key('notification_${notification.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    ref
                        .read(notificationsProvider.notifier)
                        .deleteNotification(notification.id);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: notification.read ? null : Colors.blue.shade50,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            notification.read ? Colors.grey.shade300 : Colors.blue,
                        child: Icon(
                          Icons.notifications,
                          color: notification.read ? Colors.grey : Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight:
                              notification.read ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'From: ${notification.senderName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: notification.read
                          ? null
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                            ),
                      onTap: () async {
                        if (!notification.read) {
                          await ref
                              .read(notificationsProvider.notifier)
                              .markAsRead(notification.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';

class StudentSidebar extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const StudentSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final displayName = authState.name.isNotEmpty ? authState.name : 'Student';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo Area
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.school_rounded, color: AppColors.primary, size: 28),
                SizedBox(width: 12),
                Text('AI Classroom', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // ── STUDENT NAV ITEMS ─────────────────────────────────────────────
          _SidebarItem(
            icon: Icons.dashboard_rounded,
            label: 'My Workspace',
            selected: selectedIndex == 0,
            onTap: () => onDestinationSelected(0),
          ),
          _SidebarItem(
            icon: Icons.search_rounded,
            label: 'Explore Courses', // ✅ Added Explore feature
            selected: selectedIndex == 1,
            onTap: () => onDestinationSelected(1),
          ),
          _SidebarItem(
            icon: Icons.collections_bookmark_rounded,
            label: 'My Batches', // ✅ Added Joined Batches feature
            selected: selectedIndex == 2,
            onTap: () => onDestinationSelected(2),
          ),
          _SidebarItem(
            icon: Icons.smart_toy_rounded,
            label: 'AI Assistant',
            selected: selectedIndex == 3,
            onTap: () => onDestinationSelected(3),
          ),

          const Spacer(),
          // Logout Section (Keep same as teacher)
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white38),
            title: const Text('Logout', style: TextStyle(color: Colors.white38)),
            onTap: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.primary : Colors.white54),
      title: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54)),
      selected: selected,
      onTap: onTap,
    );
  }
}

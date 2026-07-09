import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';

class TeacherSidebar extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const TeacherSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final displayName = authState.name.isNotEmpty ? authState.name : 'Teacher';
    final email = authState.email.isNotEmpty ? authState.email : 'Instructor';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Classroom',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'TEACHER PANEL',
                      style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Nav Items
          _SidebarItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            selected: selectedIndex == 0,
            onTap: () => onDestinationSelected(0),
          ),
          // ✅ Added My Batches 
          _SidebarItem(
            icon: Icons.groups_rounded,
            label: 'My Batches',
            selected: selectedIndex == 1,
            onTap: () => onDestinationSelected(1),
          ),
          _SidebarItem(
            icon: Icons.video_library_rounded,
            label: 'Videos',
            selected: selectedIndex == 2,
            onTap: () => onDestinationSelected(2),
          ),
          _SidebarItem(
            icon: Icons.live_tv_rounded,
            label: 'Live Classes',
            selected: selectedIndex == 3,
            onTap: () => onDestinationSelected(3),
          ),
          // ✅ Changed Doubt Room to AI Help
          _SidebarItem(
            icon: Icons.smart_toy_rounded,
            label: 'AI Help', 
            selected: selectedIndex == 4,
            onTap: () => onDestinationSelected(4),
          ),
          _SidebarItem(
            icon: Icons.person_outline_rounded,
            label: 'My Profile',
            selected: selectedIndex == 5, // Shifted to 5
            onTap: () => onDestinationSelected(5),
          ),

          const Spacer(),

          // Profile / Logout Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: InkWell(
              onTap: () => onDestinationSelected(5), // Shifted to 5
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.secondary,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T', 
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName, 
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          Text(
                            email, 
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ref.read(authProvider.notifier).logout();
                        context.go('/login');
                      },
                      icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
            ),
          ),
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

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : Colors.white54,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

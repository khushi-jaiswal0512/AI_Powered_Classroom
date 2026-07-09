import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import 'package:classroom_app/features/dashboard/providers/recommendation_provider.dart';

/// A self-contained widget that fetches and displays AI-driven topic
/// recommendations from GET /api/recommendation.
///
/// Drop it anywhere in the student dashboard — it manages its own state.
class RecommendationWidget extends ConsumerWidget {
  const RecommendationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recAsync = ref.watch(recommendationProvider);

    return recAsync.when(
      loading: () => _buildShell(
        context,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),

      // If recommendation API fails, show nothing (non-critical feature)
      error: (_, __) => const SizedBox.shrink(),

      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return _buildShell(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3),
                          AppColors.secondary.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.amberAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Recommendations',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Based on your quiz performance',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    onPressed: () => ref.invalidate(recommendationProvider),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white38, size: 18),
                    tooltip: 'Refresh',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 16),

              // ── Recommendation cards ────────────────────────────────────
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return _RecommendationCard(item: item, index: i);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Individual card ───────────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  final int index;

  const _RecommendationCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final config = _configFor(item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        children: [
          // Icon pill
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: config.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(config.icon, color: config.iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.focus,
                  style: TextStyle(
                    color: config.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    color: config.textColor.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                if (item.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: config.textColor.withOpacity(0.72),
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
                if (item.masteryLevel != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (item.masteryLevel!.clamp(0, 100)) / 100,
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(config.iconColor),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: config.badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.priority.isNotEmpty ? item.priority : config.badge,
                  style: TextStyle(
                    color: config.iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.actionLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: config.textColor.withOpacity(0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (80 * index).ms)
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  _CardConfig _configFor(String type) {
    switch (type) {
      case 'RETAKE_QUIZ_STRONG':
        return _CardConfig(
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.redAccent,
          iconBg: Colors.redAccent.withOpacity(0.15),
          bgColor: Colors.redAccent.withOpacity(0.06),
          borderColor: Colors.redAccent.withOpacity(0.25),
          textColor: Colors.red.shade200,
          badgeBg: Colors.redAccent.withOpacity(0.15),
          badge: 'URGENT',
        );
      case 'TAKE_ADVANCED_QUIZ':
        return _CardConfig(
          icon: Icons.rocket_launch_rounded,
          iconColor: Colors.greenAccent,
          iconBg: Colors.greenAccent.withOpacity(0.15),
          bgColor: Colors.greenAccent.withOpacity(0.05),
          borderColor: Colors.greenAccent.withOpacity(0.2),
          textColor: Colors.green.shade200,
          badgeBg: Colors.greenAccent.withOpacity(0.15),
          badge: 'STRONG',
        );
      case 'START_LEARNING_PATH':
        return _CardConfig(
          icon: Icons.flag_rounded,
          iconColor: Colors.lightBlueAccent,
          iconBg: Colors.lightBlueAccent.withOpacity(0.15),
          bgColor: Colors.lightBlueAccent.withOpacity(0.05),
          borderColor: Colors.lightBlueAccent.withOpacity(0.2),
          textColor: Colors.lightBlue.shade100,
          badgeBg: Colors.lightBlueAccent.withOpacity(0.15),
          badge: 'START',
        );
      case 'REVISE_TOPIC':
      default:
        return _CardConfig(
          icon: Icons.menu_book_rounded,
          iconColor: Colors.orangeAccent,
          iconBg: Colors.orangeAccent.withOpacity(0.15),
          bgColor: Colors.orangeAccent.withOpacity(0.05),
          borderColor: Colors.orangeAccent.withOpacity(0.2),
          textColor: Colors.orange.shade200,
          badgeBg: Colors.orangeAccent.withOpacity(0.15),
          badge: 'REVIEW',
        );
    }
  }
}

class _CardConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final Color badgeBg;
  final String badge;

  const _CardConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.badgeBg,
    required this.badge,
  });
}

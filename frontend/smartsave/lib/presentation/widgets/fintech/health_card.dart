import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FinancialHealthCard extends StatelessWidget {
  final String scoreLabel;
  final int score;
  final String status;
  final String? trend;

  const FinancialHealthCard({
    super.key,
    required this.scoreLabel,
    required this.score,
    required this.status,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 80, height: 80, child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (ctx, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          )),
          Text('$score', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(scoreLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(status, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(trend!.startsWith('+') ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: Colors.white),
                const SizedBox(width: 3),
                Text(trend!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
          ],
        ])),
      ]),
    );
  }
}

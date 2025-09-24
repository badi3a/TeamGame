import 'package:flutter/material.dart';

class AchievementBadge {
  final String name;
  final String icon;
  final Color color;
  final String description;

  AchievementBadge({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class BadgeSystem {
  // Define badge tiers based on score ranges
  static List<AchievementBadge> getBadgesForScore(double score) {
    List<AchievementBadge> earnedBadges = [];
    
    if (score < 2.6) {
      return earnedBadges; // No badges for scores below 2.6
    }
    
    // Always give participation badge for completing the category
    earnedBadges.add(AchievementBadge(
      name: "Category Completed",
      icon: "🎯",
      color: Colors.blue,
      description: "Completed all questions",
    ));
    
    // Score-based badges
    if (score >= 2.6 && score <= 3.0) {
      earnedBadges.addAll([
        AchievementBadge(
          name: "Bronze Explorer",
          icon: "🥉",
          color: Color(0xFFCD7F32),
          description: "Good start! Keep learning",
        ),
        AchievementBadge(
          name: "Determined Learner",
          icon: "📚",
          color: Colors.orange,
          description: "Shows dedication to learning",
        ),
      ]);
    } else if (score >= 3.1 && score <= 3.5) {
      earnedBadges.addAll([
        AchievementBadge(
          name: "Silver Achiever",
          icon: "🥈",
          color: Color(0xFFC0C0C0),
          description: "Solid understanding demonstrated",
        ),
        AchievementBadge(
          name: "Knowledge Seeker",
          icon: "🔍",
          color: Colors.grey,
          description: "Actively pursuing knowledge",
        ),
        AchievementBadge(
          name: "Progress Maker",
          icon: "📈",
          color: Colors.blue,
          description: "Making excellent progress",
        ),
      ]);
    } else if (score >= 3.6 && score <= 4.0) {
      earnedBadges.addAll([
        AchievementBadge(
          name: "Gold Standard",
          icon: "🥇",
          color: Color(0xFFFFD700),
          description: "Exceptional performance!",
        ),
        AchievementBadge(
          name: "Knowledge Master",
          icon: "🧠",
          color: Colors.purple,
          description: "Deep understanding achieved",
        ),
        AchievementBadge(
          name: "Star Performer",
          icon: "⭐",
          color: Colors.amber,
          description: "Outstanding results",
        ),
        AchievementBadge(
          name: "Rising Star",
          icon: "🌟",
          color: Colors.yellow,
          description: "Showing great potential",
        ),
      ]);
    } else if (score >= 4.1 && score <= 4.5) {
      earnedBadges.addAll([
        AchievementBadge(
          name: "Platinum Elite",
          icon: "🏆",
          color: Color(0xFFE5E4E2),
          description: "Elite level achievement",
        ),
        AchievementBadge(
          name: "Genius Mind",
          icon: "🧩",
          color: Colors.indigo,
          description: "Brilliant intellectual performance",
        ),
        AchievementBadge(
          name: "Excellence Badge",
          icon: "💎",
          color: Colors.cyan,
          description: "Pursuit of excellence",
        ),
        AchievementBadge(
          name: "Champion",
          icon: "👑",
          color: Colors.orange,
          description: "True champion spirit",
        ),
        AchievementBadge(
          name: "Lightning Mind",
          icon: "⚡",
          color: Colors.yellow,
          description: "Quick and accurate thinking",
        ),
      ]);
    } else if (score >= 4.6 && score <= 5.0) {
      earnedBadges.addAll([
        AchievementBadge(
          name: "Diamond Master",
          icon: "💎",
          color: Color(0xFFB9F2FF),
          description: "Ultimate mastery achieved",
        ),
        AchievementBadge(
          name: "Perfect Score",
          icon: "🎊",
          color: Colors.pink,
          description: "Flawless performance",
        ),
        AchievementBadge(
          name: "Legendary",
          icon: "🔥",
          color: Colors.red,
          description: "Legendary status unlocked",
        ),
        AchievementBadge(
          name: "Mastermind",
          icon: "🎭",
          color: Colors.purple,
          description: "True mastermind achieved",
        ),
        AchievementBadge(
          name: "Hall of Fame",
          icon: "🏅",
          color: Colors.yellow,
          description: "Inducted into Hall of Fame",
        ),
        AchievementBadge(
          name: "Supreme Scholar",
          icon: "📜",
          color: Colors.brown,
          description: "Supreme scholarly achievement",
        ),
      ]);
    }
    
    return earnedBadges;
  }
  
  // Widget to display badges in the completion dialog
  static Widget buildBadgeDisplay(List<AchievementBadge> badges) {
    if (badges.isEmpty) {
      return Container();
    }
    
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.withOpacity(0.1),
                Colors.orange.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.military_tech, color: Colors.amber.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Achievements Unlocked! 🎉',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Display badges in a wrap layout
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: badges.map((badge) => _buildBadgeChip(badge)).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  static Widget _buildBadgeChip(AchievementBadge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badge.color.withOpacity(0.2),
            badge.color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badge.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            badge.icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: badge.color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
  
  // Animated badge reveal widget
  static Widget buildAnimatedBadgeReveal(List<AchievementBadge> badges, AnimationController controller) {
    if (badges.isEmpty) return Container();
    
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (controller.value * 0.2),
          child: Opacity(
            opacity: controller.value,
            child: buildBadgeDisplay(badges),
          ),
        );
      },
    );
  }
}
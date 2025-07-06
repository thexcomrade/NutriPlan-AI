import 'package:flutter/material.dart';
import '../../components/AppTheme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  // This could eventually fetch live user data (meal count, health status, etc.)
  // For now, static sample data is used.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back!', style: AppTheme.textTheme.headline4),
              const SizedBox(height: 12),
              Text(
                'Here’s your personalized summary for today.',
                style: AppTheme.textTheme.subtitle1,
              ),
              const SizedBox(height: 24),

              _SummaryCard(
                icon: Icons.restaurant_menu,
                title: 'Meals Planned',
                description: '3 meals scheduled for today',
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),

              _SummaryCard(
                icon: Icons.favorite,
                title: 'Health Stats',
                description: 'All metrics are within healthy ranges',
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),

              _SummaryCard(
                icon: Icons.chat_bubble,
                title: 'Messages',
                description: 'You have 2 unread messages with AI Dietician',
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),

              Text('Quick Actions', style: AppTheme.textTheme.headline6),
              const SizedBox(height: 12),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _ActionButton(
                    icon: Icons.add_circle_outline,
                    label: 'Add Meal',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      // Navigate to add meal screen or trigger action
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add Meal tapped')));
                    },
                  ),
                  _ActionButton(
                    icon: Icons.favorite_border,
                    label: 'Update Health',
                    color: Colors.redAccent,
                    onTap: () {
                      // Navigate to health update screen
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Update Health tapped')));
                    },
                  ),
                  _ActionButton(
                    icon: Icons.chat,
                    label: 'Chat AI',
                    color: Colors.blueAccent,
                    onTap: () {
                      // Navigate to chat screen
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat AI tapped')));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _SummaryCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.textTheme.headline6?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 6),
                  Text(description, style: AppTheme.textTheme.subtitle2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTheme.textTheme.subtitle1?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

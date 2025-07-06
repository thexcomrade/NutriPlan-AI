import 'package:flutter/material.dart';
import '../../components/AppTheme.dart';
import '../../components/PrimaryButton.dart';
import '../meal_plan/MealPlanScreen.dart';
import '../chat_ai_dietician/ChatScreen.dart';
import '../health_tracker/HealthStatsScreen.dart';
import '../settings/SettingsScreen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = <Widget>[
    const HomeScreen(),
    const MealPlanScreen(),
    const ChatScreen(),
    const HealthStatsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('NutriPlan AI', style: AppTheme.textTheme.headline6),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey[500],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Meals'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Health'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Example content for Home screen with summary cards
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back!', style: AppTheme.textTheme.headline5),
          const SizedBox(height: 12),
          Text(
            'Here’s your health overview and meal plan for today.',
            style: AppTheme.textTheme.subtitle1,
          ),
          const SizedBox(height: 24),
          _InfoCard(
            icon: Icons.fastfood,
            title: 'Meals Planned',
            value: '3 meals',
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.favorite,
            title: 'Health Stats',
            value: 'Good',
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.chat,
            title: 'Messages with AI Dietician',
            value: '2 unread',
            color: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 24,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.textTheme.subtitle2),
                  const SizedBox(height: 4),
                  Text(value,
                      style: AppTheme.textTheme.headline6?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

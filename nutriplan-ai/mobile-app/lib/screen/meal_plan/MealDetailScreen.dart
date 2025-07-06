import 'package:flutter/material.dart';
import '../../components/AppTheme.dart';
import '../../models/MealPlanModel.dart';

class MealDetailScreen extends StatelessWidget {
  final MealPlanModel mealPlan;

  const MealDetailScreen({Key? key, required this.mealPlan}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(mealPlan.mealName),
        backgroundColor: AppTheme.primaryColor,
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal Image Placeholder
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                image: mealPlan.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(mealPlan.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: mealPlan.imageUrl == null
                  ? Icon(
                      Icons.fastfood_outlined,
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      size: 100,
                    )
                  : null,
            ),

            const SizedBox(height: 20),

            // Meal Name
            Text(
              mealPlan.mealName,
              style: AppTheme.textTheme.headline4?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),

            const SizedBox(height: 12),

            // Calories and Time
            Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.redAccent),
                const SizedBox(width: 6),
                Text(
                  '${mealPlan.calories} kcal',
                  style: AppTheme.textTheme.subtitle1,
                ),
                const SizedBox(width: 20),
                Icon(Icons.access_time, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  mealPlan.time,
                  style: AppTheme.textTheme.subtitle1,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Description / Recipe
            Text(
              'Description',
              style: AppTheme.textTheme.headline6?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              mealPlan.description,
              style: AppTheme.textTheme.bodyText2,
            ),

            const SizedBox(height: 24),

            // Ingredients Section (if any)
            if (mealPlan.ingredients != null && mealPlan.ingredients!.isNotEmpty) ...[
              Text(
                'Ingredients',
                style: AppTheme.textTheme.headline6?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...mealPlan.ingredients!.map(
                (ingredient) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ingredient,
                          style: AppTheme.textTheme.bodyText1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),

            // Action Button (e.g., Add to Favorites, Log Meal, etc.)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.favorite_border),
                label: const Text('Add to Favorites'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  elevation: 3,
                ),
                onPressed: () {
                  // TODO: Implement add to favorites functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to favorites!')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

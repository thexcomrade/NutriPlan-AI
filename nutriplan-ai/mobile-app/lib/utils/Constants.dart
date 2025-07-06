// 📄 D:\nutriplan-ai\mobile-app\lib\utils\Constants.dart

class AppConstants {
  // 🔐 API Keys (Use environment configs in production)
  static const String openAIAPIKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String firebaseServerKey = 'YOUR_FIREBASE_SERVER_KEY_HERE';

  // 🌐 API Endpoints
  static const String baseUrl = 'https://api.nutriplanai.com';
  static const String mealPlanEndpoint = '$baseUrl/generate-meal-plan';
  static const String medicalDataEndpoint = '$baseUrl/user/medical-data';
  static const String chatbotEndpoint = '$baseUrl/chat-dietician';
  static const String authEndpoint = '$baseUrl/auth';

  // 📱 App Information
  static const String appName = 'NutriPlan AI';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Personalized Diet & Nutrition Assistant';
  static const String appLogo = 'assets/images/logo.png';

  // 👤 User Profile Types
  static const List<String> userTypes = [
    'Gym-goer',
    'Hosteler',
    'Office-goer',
    'Health Conscious',
    'Diabetic',
    'Budget Conscious',
  ];

  // 💡 Hints, Messages, Titles
  static const String welcomeMessage = 'Welcome to NutriPlan AI';
  static const String loadingMessage = 'Analyzing your preferences...';
  static const String networkError = 'Check your internet connection.';
  static const String generalError = 'Something went wrong. Please try again.';
  static const String noDataFound = 'No data available. Try refreshing.';
  static const String retry = 'Retry';

  // ⏳ Durations
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 500);
  static const Duration longAnimationDuration = Duration(seconds: 1);

  // 🧠 AI Assistant Personalization
  static const String aiAssistantName = 'NutriBot';
  static const String aiWelcomeText =
      "Hi there! I'm NutriBot, your personal nutrition assistant. Ready to create your perfect meal plan?";

  // 🔗 Social & Legal
  static const String privacyPolicyUrl = 'https://nutriplanai.com/privacy-policy';
  static const String termsAndConditionsUrl = 'https://nutriplanai.com/terms';

  // 📅 Date Formats
  static const String dateFormatFull = 'dd MMMM yyyy';
  static const String dateFormatShort = 'dd/MM/yyyy';

  // 🎨 Lottie Animations
  static const String loadingLottie = 'assets/animations/loading.json';
  static const String successLottie = 'assets/animations/success.json';
  static const String errorLottie = 'assets/animations/error.json';
  static const String chatbotLottie = 'assets/animations/chatbot_wave.json';

  // 🧪 Testing/Debugging (remove or disable in release)
  static const bool isDebugMode = true;
}

// API configuration for the AI Classroom app.
//
// Environment switching:
//   - By default the app targets the Render production backend.
//   - To use a local backend during development, run with:
//       flutter run --dart-define=API_ENV=local
//   - To point to a staging backend:
//       flutter run --dart-define=API_ENV=staging
//
// Example (local Spring Boot on port 8080):
//   flutter run -d chrome --dart-define=API_ENV=local

class ApiConstants {
  ApiConstants._(); // non-instantiable

  // ── Environment detection ───────────────────────────────────────────────────
  //
  // Reads the compile-time variable injected by --dart-define=API_ENV=<value>.
  // Defaults to 'production' so release builds always target Render with no
  // extra flags needed.
  static const String _env =
      String.fromEnvironment('API_ENV', defaultValue: 'production');

  static bool get isLocal      => _env == 'local';
  static bool get isStaging    => _env == 'staging';
  static bool get isProduction => _env == 'production';

  // ── Base URLs ───────────────────────────────────────────────────────────────
  static const String _productionBaseUrl =
      'https://ai-classroom-s1fa.onrender.com/api/';

  static const String _stagingBaseUrl =
      'https://ai-classroom-s1fa.onrender.com/api/'; // ← replace when staging exists

  static const String _localBaseUrl =
      'http://localhost:8080/api/';

  /// The active base URL resolved at compile time.
  static String get baseUrl {
    if (isLocal)   return _localBaseUrl;
    if (isStaging) return _stagingBaseUrl;
    return _productionBaseUrl;
  }

  // ── Timeouts ────────────────────────────────────────────────────────────────
  //
  // Render free-tier goes to sleep and can take ~3 minutes to cold-start.
  // Local and staging servers respond almost immediately, so we use a shorter
  // timeout in those environments to catch real errors quickly.

  /// Used for register and first-request-after-sleep scenarios.
  static Duration get coldStartTimeout =>
      isLocal ? const Duration(seconds: 15) : const Duration(seconds: 180);

  /// Used for all other API calls.
  static Duration get normalTimeout =>
      isLocal ? const Duration(seconds: 10) : const Duration(seconds: 20);

  // ── Auth endpoints ──────────────────────────────────────────────────────────
  static const String login    = 'auth/login';
  static const String register = 'auth/register';
  static const String profile  = 'user/profile';

  // ── Video endpoints ─────────────────────────────────────────────────────────
  static const String upload         = 'video/upload';
  static const String uploadUrl      = 'video/upload-url';
  static const String saveVideo      = 'video/save';
  static const String myVideos       = 'video/my';
  static const String allVideos      = 'video/all';
  static const String downloadVideo  = 'video/download';   // append /<id>
  static const String playbackVideo  = 'video/playback';       // append /<id>
  static const String transcribe     = 'transcribe';       // append /<id>
  static const String batchVideos    = 'video/batch';      // append /<batchId
  // ── Quiz endpoints ──────────────────────────────────────────────────────────
  static const String quizForVideo   = 'quiz';             // append /<id>
  static const String generateQuiz   = 'quiz/generate';
  static const String adaptiveQuiz   = 'adaptive/quiz';    // append /<id>
  static const String submitQuiz     = 'quiz/submit';

  // ── Dashboard endpoints ─────────────────────────────────────────────────────
  static const String studentDashboard = 'student/dashboard';
  static const String teacherDashboard = 'teacher/dashboard';

  // ── Live class endpoints ────────────────────────────────────────────────────
  static const String createClass     = 'live/create';
  static const String startClass      = 'live/start';
  static const String endClass        = 'live/end';
  static const String joinClass       = 'live/join';      // append /<id>
  static const String classStatus     = 'live/status';    // append /<batchId>
  static const String leaveClass      = 'live/leave';     // append /<id>
  static const String attendance      = 'live/attendance'; // append /<id>
  static const String classToken      = 'live/token';     // append /<id>

  // ── AI endpoints ─────────────────────────────────────────────────────────────
  static const String doubt = 'ai/doubt';

  // ── Batch Management ─────────────────────────────────────────────────────────
  static const String myBatches   = 'batch/my';
  static const String createBatch = 'batch/create';
  
  // ✅ FIXED: Added missing joinBatch endpoint for the Student Explore feature
  static const String joinBatch   = 'batch/join';

  // ── Recommendation endpoints ──────────────────────────────────────────────
  static const String recommendations     = 'recommendation';        // GET
  static const String recommendationTrend = 'recommendation/trend';  // GET
}
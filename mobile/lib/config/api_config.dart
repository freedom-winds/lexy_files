class ApiConfig {
  // Change this to your backend URL
  static const String baseUrl = 'http://10.0.2.2:5000/api/v1'; // Android emulator
  // static const String baseUrl = 'http://localhost:5000/api/v1'; // iOS/Desktop
  // static const String baseUrl = 'http://192.168.x.x:5000/api/v1'; // Physical device

  /// WebSocket server root (no path, socket.io connects at root with namespace)
  static const String wsUrl = 'http://10.0.2.2:5000';
  // static const String wsUrl = 'http://localhost:5000';
  // static const String wsUrl = 'http://192.168.x.x:5000';

  static String get authLogin => '$baseUrl/auth/login';
  static String get authRegister => '$baseUrl/auth/register';
  static String get authRefresh => '$baseUrl/auth/refresh';
  static String get authLogout => '$baseUrl/auth/logout';
  static String get authMe => '$baseUrl/auth/me';

  static String get filesUpload => '$baseUrl/files/upload';
  static String get filesList => '$baseUrl/files';
  static String filePickup(String code) => '$baseUrl/files/pickup/$code';
  static String fileDownload(int id) => '$baseUrl/files/download/$id';
  static String fileDelete(int id) => '$baseUrl/files/$id';

  static String get devices => '$baseUrl/devices';
  static String deviceById(int id) => '$baseUrl/devices/$id';
  static String deviceDelete(int id) => '$baseUrl/devices/$id';

  static String get transfers => '$baseUrl/transfers';
  static String transferStatus(int id) => '$baseUrl/transfers/$id';
}

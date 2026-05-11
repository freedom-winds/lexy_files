import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  late final Dio _dio;
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            !(error.requestOptions.extra['_retry'] == true)) {
          try {
            final refreshToken = await _prefs.getString('refresh_token');
            if (refreshToken == null) return handler.next(error);

            final response = await Dio().post(
              ApiConfig.authRefresh,
              options: Options(
                headers: {'Authorization': 'Bearer $refreshToken'},
              ),
            );

            final newToken = response.data['access_token'] as String;
            await _prefs.setString('access_token', newToken);

            // Retry the original request
            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            error.requestOptions.extra['_retry'] = true;
            final retryResponse = await _dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (_) {
            await clearTokens();
            return handler.next(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  Future<void> setTokens(String accessToken, String refreshToken) async {
    await _prefs.setString('access_token', accessToken);
    await _prefs.setString('refresh_token', refreshToken);
  }

  Future<void> clearTokens() async {
    await _prefs.remove('access_token');
    await _prefs.remove('refresh_token');
  }

  Future<bool> hasToken() async {
    final token = await _prefs.getString('access_token');
    return token != null;
  }

  Future<String?> getAccessToken() async {
    return _prefs.getString('access_token');
  }

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<Response> login(String username, String password) {
    return _dio.post(ApiConfig.authLogin, data: {
      'username': username,
      'password': password,
    });
  }

  Future<Response> register(String username, String email, String password) {
    return _dio.post(ApiConfig.authRegister, data: {
      'username': username,
      'email': email,
      'password': password,
    });
  }

  Future<Response> getMe() {
    return _dio.get(ApiConfig.authMe);
  }

  Future<Response> logout() {
    return _dio.post(ApiConfig.authLogout);
  }

  Future<Response> anonymous(String deviceId, String fingerprint) {
    return _dio.post(ApiConfig.authAnonymous, data: {
      'device_id': deviceId,
      'fingerprint': fingerprint,
    });
  }

  // ─── Files ───────────────────────────────────────────────────────────────

  Future<Response> uploadFile(
    String filePath,
    String fileName, {
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromFileSync(filePath, filename: fileName),
    });
    return _dio.post(
      ApiConfig.filesUpload,
      data: formData,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<Response> getMyFiles() {
    return _dio.get(ApiConfig.filesList);
  }

  Future<Response> getFileByPickupCode(String code) {
    return _dio.get(ApiConfig.filePickup(code));
  }

  Future<Response> downloadFile(
    int fileId,
    String savePath, {
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) {
    return _dio.download(
      ApiConfig.fileDownload(fileId),
      savePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<Response> deleteFile(int fileId) {
    return _dio.delete(ApiConfig.fileDelete(fileId));
  }

  // ─── Devices ─────────────────────────────────────────────────────────────

  /// Fetch all devices belonging to the authenticated user.
  Future<Response> getDevices() {
    return _dio.get(ApiConfig.devices);
  }

  /// Register a new device. [name], [deviceType] (e.g. "phone"), [platform]
  /// (e.g. "android", "ios", "windows").
  Future<Response> registerDevice({
    required String name,
    required String deviceType,
    required String platform,
    required String deviceId,
  }) {
    return _dio.post(ApiConfig.devices, data: {
      'name': name,
      'device_type': deviceType,
      'platform': platform,
      'device_id': deviceId,
    });
  }

  /// Delete a device by ID.
  Future<Response> deleteDevice(int deviceId) {
    return _dio.delete(ApiConfig.deviceDelete(deviceId));
  }

  /// Mark this device as online by sending a heartbeat (PATCH or POST).
  Future<Response> markDeviceOnline(int deviceId) {
    return _dio.put(ApiConfig.deviceOnline(deviceId));
  }

  // ─── Transfers ───────────────────────────────────────────────────────────

  /// Create a transfer request from this device to [targetDeviceId].
  Future<Response> createTransfer({
    required int senderDeviceId,
    required int targetDeviceId,
    required String fileName,
    required int fileSize,
    String mode = 'same_account',
  }) {
    return _dio.post(ApiConfig.transfers, data: {
      'mode': mode,
      'sender_device_id': senderDeviceId,
      'target_device_id': targetDeviceId,
      'file_name': fileName,
      'file_size': fileSize,
    });
  }

  /// Get transfer status by ID.
  Future<Response> getTransfer(int transferId) {
    return _dio.get(ApiConfig.transferStatus(transferId));
  }

  // ─── SharedPreferences helpers ───────────────────────────────────────────

  Future<void> setDeviceDbId(int id) async {
    await _prefs.setInt('device_db_id', id);
  }

  Future<int?> getDeviceDbId() async {
    return _prefs.getInt('device_db_id');
  }

  Future<void> clearDeviceDbId() async {
    await _prefs.remove('device_db_id');
  }

  // ─── Error helper ────────────────────────────────────────────────────────

  String getApiError(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final errObj = data['error'];
        if (errObj is Map<String, dynamic> && errObj['message'] != null) {
          return errObj['message'] as String;
        }
        if (errObj is String) return errObj;
        if (data['message'] is String) return data['message'] as String;
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Please check your network.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Cannot connect to server. Please check your network.';
      }
    }
    return 'An unexpected error occurred.';
  }
}

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

  // Auth
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

  // Files
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

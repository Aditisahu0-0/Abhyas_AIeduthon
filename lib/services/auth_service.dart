import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final Dio _dio = Dio();
  static const String _baseUrl = 'https://abhyas.teampavbhaji.dedyn.io';

  static const String _tokenKey = 'auth_token';
  static const String _loginTimeKey = 'login_timestamp';
  static const String _userNameKey = 'user_name';
  static const int _validityDays = 30;

  bool _isLoggedIn = false;
  String? _userName;
  
  bool get isLoggedIn => _isLoggedIn;
  String? get userName => _userName;

  Future<void> init() async {
    _isLoggedIn = await checkAuthValidity();
    if (_isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString(_userNameKey);
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/auth/login',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        final token = response.data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          final now = DateTime.now().millisecondsSinceEpoch;

          await prefs.setString(_tokenKey, token);
          await prefs.setInt(_loginTimeKey, now);
          
          // Try to get name from response, otherwise use username as fallback if appropriate or leave null
          // Assuming response might have 'name' or 'user' object
          if (response.data['name'] != null) {
             _userName = response.data['name'];
             await prefs.setString(_userNameKey, _userName!);
          } else if (response.data['user'] != null && response.data['user']['name'] != null) {
             _userName = response.data['user']['name'];
             await prefs.setString(_userNameKey, _userName!);
          }

          _isLoggedIn = true;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Login Error: $e');
    }
    return false;
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required String studentClass,
    required String medium,
    required DateTime dob,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/auth/signup',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'student_class': studentClass,
          'medium': medium,
          'dob': dob.toIso8601String().split('T')[0], // YYYY-MM-DD
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final token = response.data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          final now = DateTime.now().millisecondsSinceEpoch;

          await prefs.setString(_tokenKey, token);
          await prefs.setInt(_loginTimeKey, now);
          
          // Save the name used for signup
          _userName = name;
          await prefs.setString(_userNameKey, name);

          _isLoggedIn = true;
          notifyListeners();
          return true;
        }
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Signup Error: ${e.message}');
        if (e.response != null) {
          print('Response Data: ${e.response?.data}');
          print('Response Headers: ${e.response?.headers}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Signup Error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_loginTimeKey);
    await prefs.remove(_userNameKey);
    _isLoggedIn = false;
    _userName = null;
    notifyListeners();
  }

  Future<bool> checkAuthValidity() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final timestamp = prefs.getInt(_loginTimeKey);
    _userName = prefs.getString(_userNameKey);

    if (token != null && timestamp != null) {
      final lastLogin = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final difference = DateTime.now().difference(lastLogin).inDays;

      if (difference < _validityDays) {
        return true;
      } else {
        // Expired
        await logout();
        return false;
      }
    }
    return false;
  }
}

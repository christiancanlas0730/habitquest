import 'package:supabase_flutter/supabase_flutter.dart';

class AuthResponseData {
  const AuthResponseData({required this.hasUser, required this.hasSession});

  final bool hasUser;
  final bool hasSession;
}

abstract interface class AuthClient {
  Future<AuthResponseData> signUp({
    required String email,
    required String password,
  });
  Future<AuthResponseData> signInWithPassword({
    required String email,
    required String password,
  });
  Future<void> signOut();
  User? get currentUser;
}

class SupabaseAuthClientAdapter implements AuthClient {
  SupabaseAuthClientAdapter(this._auth);

  final GoTrueClient _auth;

  @override
  Future<AuthResponseData> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _auth.signUp(email: email, password: password);
    return AuthResponseData(
      hasUser: response.user != null,
      hasSession: response.session != null,
    );
  }

  @override
  Future<AuthResponseData> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    return AuthResponseData(
      hasUser: response.user != null,
      hasSession: response.session != null,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  User? get currentUser => _auth.currentUser;
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.code);

  final String? code;
}

class AuthTransportException implements Exception {
  const AuthTransportException();
}

abstract interface class AuthRepository {
  Future<AuthResponseData> register(String email, String password);
  Future<AuthResponseData> login(String email, String password);
  Future<void> logout();
  User? getCurrentUser();
  bool isLoggedIn();
}

class AuthService implements AuthRepository {
  AuthService({SupabaseClient? client, AuthClient? authClient})
    : _auth =
          authClient ??
          SupabaseAuthClientAdapter(
            client == null ? _initializedSupabaseAuth : client.auth,
          );

  final AuthClient _auth;

  static GoTrueClient get _initializedSupabaseAuth =>
      Supabase.instance.client.auth;

  /// Maps known Auth error codes to fixed, user-safe messages.
  /// Raw server messages are intentionally not shown because they may include
  /// user-provided values.
  static String userFacingAuthError(Object error, {required String fallback}) {
    final code = error is AuthWeakPasswordException
        ? 'weak_password'
        : error is AuthApiException
        ? error.code
        : error is AuthRepositoryException
        ? error.code
        : null;
    if (code == null) return fallback;

    return userFacingAuthErrorCode(code, fallback: fallback);
  }

  static String userFacingAuthErrorCode(
    String? code, {
    required String fallback,
  }) => switch (code) {
    'weak_password' => 'Choose a stronger password and try again.',
    'email_not_confirmed' =>
      'Please confirm your email address before logging in.',
    'invalid_credentials' => 'Login failed. Check your email and password.',
    'email_address_invalid' =>
      'Supabase rejected this email address. Check it and try again.',
    'email_address_not_authorized' =>
      'Email delivery is restricted by the project mail settings.',
    'over_email_send_rate_limit' =>
      'Too many email requests. Please wait before trying again.',
    _ => fallback,
  };

  // Register a new account
  @override
  Future<AuthResponseData> register(String email, String password) async {
    try {
      return await _auth.signUp(email: email, password: password);
    } catch (error) {
      throw _mappedError(error);
    }
  }

  // Login
  @override
  Future<AuthResponseData> login(String email, String password) async {
    try {
      return await _auth.signInWithPassword(email: email, password: password);
    } catch (error) {
      throw _mappedError(error);
    }
  }

  // Logout
  @override
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (error) {
      throw _mappedError(error);
    }
  }

  // Get currently logged-in user
  @override
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if someone is logged in
  @override
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  Object _mappedError(Object error) => error is AuthApiException
      ? AuthRepositoryException(error.code)
      : error is AuthTransportException
      ? error
      : const AuthTransportException();
}

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Register a new account
  Future<AuthResponse> register(
    String email,
    String password,
  ) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Login
  Future<AuthResponse> login(
    String email,
    String password,
  ) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Get currently logged-in user
  User? getCurrentUser() {
    return supabase.auth.currentUser;
  }

  // Check if someone is logged in
  bool isLoggedIn() {
    return supabase.auth.currentUser != null;
  }
}
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/premium_ui.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final AuthRepository authService =
      widget.authRepository ?? AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool hidePassword = true;

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final error = RegisterFormValidation.error(email, password);
    if (error != null) {
      showMessage(error);
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      final response = await authService.register(email, password);
      if (!mounted) return;
      if (response.hasUser) {
        showMessage(
          !response.hasSession
              ? 'Check your email and confirm your address before logging in.'
              : 'Account created successfully.',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        showMessage('Registration failed.');
      }
    } catch (error) {
      if (!mounted) return;
      showMessage(
        error is AuthRepositoryException
            ? AuthService.userFacingAuthErrorCode(
                error.code,
                fallback: 'Registration failed. Please try again.',
              )
            : 'Registration failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 34, 24, 25),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HabitQuestBrand(),
                    const SizedBox(height: 27),
                    const Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Build a routine that feels like yours.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.newUsername,
                              AutofillHints.email,
                            ],
                            decoration: premiumInputDecoration(
                              hintText: 'Email address',
                              prefixIcon: Icons.mail_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 13),
                          TextField(
                            controller: passwordController,
                            obscureText: hidePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onSubmitted: (_) => register(),
                            decoration:
                                premiumInputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    tooltip: hidePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                      () => hidePassword = !hidePassword,
                                    ),
                                    icon: Icon(
                                      hidePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.muted,
                                      size: 20,
                                    ),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 20),
                          GradientActionButton(
                            label: 'Sign up',
                            icon: Icons.arrow_forward_rounded,
                            isLoading: isLoading,
                            onPressed: isLoading ? null : register,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              color: AppColors.blue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterFormValidation {
  const RegisterFormValidation._();

  static String? error(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please complete all fields.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }
}

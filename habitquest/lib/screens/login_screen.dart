import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/premium_ui.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthRepository authService =
      widget.authRepository ?? AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool hidePassword = true;

  Future<void> login() async {
    final error = LoginFormValidation.error(
      emailController.text,
      passwordController.text,
    );
    if (error != null) {
      showMessage(error);
      return;
    }
    final email = emailController.text.trim();
    final password = passwordController.text;
    setState(() {
      isLoading = true;
    });
    try {
      await authService.login(email, password);
    } catch (error) {
      if (!mounted) return;
      showMessage(
        error is AuthRepositoryException
            ? AuthService.userFacingAuthErrorCode(
                error.code,
                fallback: 'Login failed. Check your details and try again.',
              )
            : 'Login failed. Check your details and try again.',
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
                      'Pick up where your next good day begins.',
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
                              AutofillHints.username,
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
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => login(),
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
                            label: 'Log in',
                            icon: Icons.arrow_forward_rounded,
                            isLoading: isLoading,
                            onPressed: isLoading ? null : login,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign up',
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

class LoginFormValidation {
  const LoginFormValidation._();

  static String? error(String email, String password) =>
      email.trim().isEmpty || password.isEmpty
      ? 'Please enter your email and password.'
      : null;
}

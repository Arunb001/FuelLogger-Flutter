import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/version.dart';
import '../../widgets/custom_snackbar.dart';
import '../home/home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUpMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSuccess() {
    context.read<GarageProvider>().loadGarage();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeView()),
    );
  }

  Future<void> _handlePasswordAction() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showCustomSnackBar(context, 'Please enter a valid email address.', isError: true);
      return;
    }

    final password = _passwordController.text.trim();
    if (password.length < 6) {
      showCustomSnackBar(context, 'Password must be at least 6 characters.', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();

    final success = _isSignUpMode
        ? await auth.signUpWithPassword(email, password)
        : await auth.signInWithPassword(email, password);

    if (!mounted) return;

    if (success) {
      showCustomSnackBar(context, 'Welcome to Fuel Logger!');
      _onSuccess();
    } else {
      showCustomSnackBar(context, auth.errorMessage, isError: true);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();

    if (!mounted) return;

    if (success) {
      showCustomSnackBar(context, 'Signed in with Google!');
      _onSuccess();
    } else if (auth.errorMessage.isNotEmpty) {
      showCustomSnackBar(context, auth.errorMessage, isError: true);
    }
  }

  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Row(
            children: const [
              Icon(Icons.mail_outline, color: AppTheme.costAmber, size: 22),
              SizedBox(width: 8),
              Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address and we will send you a password reset link.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: resetCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'name@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  showCustomSnackBar(context, 'Please enter a valid email.', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                final ok = await context.read<AuthProvider>().resetPassword(email);
                if (mounted) {
                  if (ok) {
                    showCustomSnackBar(context, 'Password reset link sent to your email!');
                  } else {
                    showCustomSnackBar(context, 'Failed to send reset link.', isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Reset Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.all(16),
                        color: AppTheme.surfaceHigh,
                        child: const Icon(Icons.local_gas_station, size: 48, color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fuel Logger',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mileage & Telemetry Tracker',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 28),

                // Auth Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Google Native Sign-In Button
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGoogleIcon(),
                              const SizedBox(width: 12),
                              const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // OR Divider
                        Row(
                          children: const [
                            Expanded(child: Divider(color: AppTheme.borderColor)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            Expanded(child: Divider(color: AppTheme.borderColor)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Mode Title
                        Row(
                          children: [
                            const Icon(Icons.lock_outline, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isSignUpMode ? 'Create Account' : 'Sign In with Password',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignUpMode
                              ? 'Enter your email and create a password (min 6 chars).'
                              : 'Enter your credentials to log in.',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 18),

                        // Email Field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'name@gmail.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: _isSignUpMode ? 'Create Password' : 'Password',
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Forgot Password Link (Sign in mode only)
                        if (!_isSignUpMode) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(color: AppTheme.distanceBlue, fontSize: 12),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                        ],

                        // Main Action Button (Sign In / Create Account)
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handlePasswordAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isSignUpMode ? Icons.person_add : Icons.login,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isSignUpMode ? 'Create Account & Sign In' : 'Sign In with Password',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 14),

                        // Toggle Sign Up / Sign In
                        TextButton(
                          onPressed: () => setState(() => _isSignUpMode = !_isSignUpMode),
                          child: Text(
                            _isSignUpMode
                                ? 'Already have an account? Sign In'
                                : 'New to Fuel Logger? Create account',
                            style: const TextStyle(color: AppTheme.costAmber, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Guest Mode
                TextButton(
                  onPressed: () {
                    auth.continueAsGuest();
                    _onSuccess();
                  },
                  child: const Text(
                    'Continue as Guest (Offline Mode)',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 28),
                // Version display - only "Version - #"
                Text(
                  AppVersion.display,
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: 'Roboto',
            color: Colors.blue.shade700,
          ),
        ),
      ),
    );
  }
}

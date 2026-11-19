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
  final _otpController = TextEditingController();

  bool _isPasswordMode = true;
  bool _isSignUpMode = false;
  bool _otpSent = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onSuccess() {
    context.read<GarageProvider>().loadGarage();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeView()),
    );
  }

  Future<void> _handleAction() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showCustomSnackBar(context, 'Please enter a valid email address.', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();

    if (_isPasswordMode) {
      final password = _passwordController.text.trim();
      if (password.length < 6) {
        showCustomSnackBar(context, 'Password must be at least 6 characters.', isError: true);
        return;
      }

      final success = _isSignUpMode
          ? await auth.signUpWithPassword(email, password)
          : await auth.signInWithPassword(email, password);

      if (success) {
        showCustomSnackBar(context, 'Welcome to Fuel Logger!');
        _onSuccess();
      } else {
        showCustomSnackBar(context, auth.errorMessage, isError: true);
      }
    } else {
      // OTP Flow
      final success = await auth.sendOtp(email);
      if (success) {
        setState(() => _otpSent = true);
        showCustomSnackBar(context, 'Sign-in email sent! Enter code or tap link in email.');
      } else {
        showCustomSnackBar(context, auth.errorMessage, isError: true);
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim();
    final code = _otpController.text.trim();
    if (code.length != 6) {
      showCustomSnackBar(context, 'Please enter the 6-digit code.', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(email, code);
    if (success) {
      showCustomSnackBar(context, 'Signed in successfully!');
      _onSuccess();
    } else {
      showCustomSnackBar(context, auth.errorMessage, isError: true);
    }
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade900, width: 1.5),
                  ),
                  child: const Icon(Icons.local_gas_station, size: 54, color: AppTheme.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fuel Logger',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cloud Mileage & Telemetry Tracker',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Auth Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_outline, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isPasswordMode
                                  ? (_isSignUpMode ? 'Create Account' : 'Sign In with Password')
                                  : 'Sign In with Email',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isPasswordMode
                              ? (_isSignUpMode
                                  ? 'Enter your email and create a password (min 6 chars).'
                                  : 'Enter your credentials to log in instantly (no email required).')
                              : 'Enter your email to receive an instant sign-in link or 6-digit code.',
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

                        // Password Field (if in Password mode)
                        if (_isPasswordMode) ...[
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
                          const SizedBox(height: 16),
                        ],

                        // Main Action Button
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
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
                                      _isPasswordMode
                                          ? (_isSignUpMode ? Icons.person_add : Icons.login)
                                          : Icons.send,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isPasswordMode
                                          ? (_isSignUpMode ? 'Create Account & Sign In' : 'Sign In with Password')
                                          : (_otpSent ? 'Resend Email' : 'Send Sign-In Code / Link'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),

                        // OTP Verification Fields (if code was sent)
                        if (!_isPasswordMode && _otpSent) ...[
                          const SizedBox(height: 18),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(letterSpacing: 6, fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              labelText: '6-Digit Verification Code',
                              hintText: '123456',
                              counterText: '',
                              prefixIcon: Icon(Icons.pin, size: 20),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: auth.isLoading ? null : _handleVerifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.mileageGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Verify Code & Sign In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ],

                        // Toggle Sign Up / Sign In (Password mode only)
                        if (_isPasswordMode) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() => _isSignUpMode = !_isSignUpMode),
                            child: Text(
                              _isSignUpMode
                                  ? 'Already have an account? Sign In'
                                  : 'New to Fuel Logger? Create account',
                              style: const TextStyle(color: AppTheme.costAmber, fontSize: 12),
                            ),
                          ),
                        ],

                        const Divider(height: 24, color: AppTheme.borderColor),

                        // Toggle Mode Button
                        TextButton(
                          onPressed: () => setState(() {
                            _isPasswordMode = !_isPasswordMode;
                            _otpSent = false;
                          }),
                          child: Text(
                            _isPasswordMode
                                ? 'Or sign in with Email Link / OTP'
                                : 'Or sign in with Password (Instant)',
                            style: const TextStyle(color: AppTheme.distanceBlue, fontSize: 12),
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
                Text(
                  '${AppVersion.fullDisplay} • Supabase Cloud',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

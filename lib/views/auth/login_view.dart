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
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool codeSent = false;
    bool isWorking = false;
    String statusMsg = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.lock_reset, color: AppTheme.costAmber, size: 24),
                  SizedBox(width: 8),
                  Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      codeSent
                          ? 'Enter the 6-digit code sent to ${resetCtrl.text.trim()} and choose your new password.'
                          : 'Enter your email to receive a 6-digit recovery code.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: resetCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !codeSent && !isWorking,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                    ),
                    if (codeSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: '6-Digit Recovery Code *',
                          hintText: '123456',
                          prefixIcon: Icon(Icons.pin, size: 20),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password (min 6 chars) *',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                      ),
                    ],
                    if (statusMsg.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        statusMsg,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusMsg.contains('Error') || statusMsg.contains('Failed') || statusMsg.contains('Invalid')
                              ? Colors.redAccent
                              : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isWorking ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                if (!codeSent)
                  ElevatedButton(
                    onPressed: isWorking
                        ? null
                        : () async {
                            final email = resetCtrl.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              setDialogState(() => statusMsg = 'Please enter a valid email address.');
                              return;
                            }
                            setDialogState(() {
                              isWorking = true;
                              statusMsg = 'Sending recovery code...';
                            });
                            final ok = await context.read<AuthProvider>().resetPassword(email);
                            setDialogState(() {
                              isWorking = false;
                              if (ok) {
                                codeSent = true;
                                statusMsg = 'Code sent! Check your email for the 6-digit code.';
                              } else {
                                statusMsg = context.read<AuthProvider>().errorMessage;
                              }
                            });
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                    child: Text(isWorking ? 'Sending...' : 'Send Recovery Code'),
                  )
                else
                  ElevatedButton(
                    onPressed: isWorking
                        ? null
                        : () async {
                            final code = codeCtrl.text.trim();
                            final newPass = newPassCtrl.text.trim();
                            if (code.length < 6) {
                              setDialogState(() => statusMsg = 'Please enter the 6-digit code.');
                              return;
                            }
                            if (newPass.length < 6) {
                              setDialogState(() => statusMsg = 'Password must be at least 6 characters.');
                              return;
                            }
                            setDialogState(() {
                              isWorking = true;
                              statusMsg = 'Verifying and updating password...';
                            });
                            final ok = await context.read<AuthProvider>().verifyOtpAndSetPassword(
                                  email: resetCtrl.text.trim(),
                                  token: code,
                                  newPassword: newPass,
                                );
                            if (ok) {
                              Navigator.pop(ctx);
                              showCustomSnackBar(context, 'Password reset successfully! Logged in.');
                              _onSuccess();
                            } else {
                              setDialogState(() {
                                isWorking = false;
                                statusMsg = context.read<AuthProvider>().errorMessage;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mileageGreen, foregroundColor: Colors.black),
                    child: Text(isWorking ? 'Updating...' : 'Set Password & Log In', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
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
                  'Mileage Tracker',
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
                          child: const Center(
                            child: Text(
                              'Sign in with Google',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
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
}

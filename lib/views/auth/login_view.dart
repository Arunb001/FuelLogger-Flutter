import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/version.dart';
import '../../config/env.dart';
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
    // In DEV environment, Supabase has Google OAuth provider disabled.
    // Show an informative dialog instead of redirecting to a broken browser page.
    if (AppConfig.isDev) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.info_outline, color: AppTheme.costAmber, size: 24),
              SizedBox(width: 8),
              Flexible(child: Text('DEV Environment Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Google Sign-In is disabled on the DEV Supabase backend ("Unsupported provider: provider is not enabled").',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'For testing on DEV, please use:\n'
                '• Sign In with Password (or create an account)\n'
                '• Continue as Guest (Offline Mode)',
                style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Note: Google Sign-In is active and fully configured on PROD.',
                style: TextStyle(fontSize: 12, color: AppTheme.distanceBlue, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('OK, Use Password / Guest', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Try Anyway', style: TextStyle(color: AppTheme.costAmber)),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

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
    final linkCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool emailSent = false;
    bool isWorking = false;
    bool useCodeMode = true;
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
                    if (!emailSent) ...[
                      const Text(
                        'Enter your email to receive a password reset link from Supabase.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: resetCtrl,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isWorking,
                        decoration: const InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                      ),
                    ] else if (!useCodeMode) ...[
                      // Link Paste Mode (Default for Supabase link emails)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'How to reset using the link:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.costAmber),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• If you clicked the email link and Chrome showed "localhost:3000":\n'
                              '  Copy the URL from Chrome\'s address bar (localhost:3000/#access_token=...) and paste it below.\n'
                              '• If copying directly from email:\n'
                              '  Long-press "Reset password" -> "Copy link address" and paste below without opening in browser first.',
                              style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: linkCtrl,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: 'Paste Reset Link or Chrome URL *',
                                hintText: 'https://... or localhost:3000/#access_token=...',
                                prefixIcon: Icon(Icons.link, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.paste, color: AppTheme.distanceBlue),
                            tooltip: 'Paste from clipboard',
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null && data!.text!.isNotEmpty) {
                                setDialogState(() {
                                  linkCtrl.text = data.text!;
                                });
                              }
                            },
                          ),
                        ],
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => setDialogState(() => useCodeMode = true),
                          child: const Text(
                            'Received a 6-digit code instead? Tap to enter code',
                            style: TextStyle(color: AppTheme.distanceBlue, fontSize: 11, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ] else ...[
                      // 6-digit code mode (Default)
                      Text(
                        'Enter the 6-digit recovery code sent to ${resetCtrl.text.trim()} and your new password.',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => setDialogState(() => useCodeMode = false),
                          child: const Text(
                            'Received an email link instead? Tap to paste link',
                            style: TextStyle(color: AppTheme.distanceBlue, fontSize: 11, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                    if (statusMsg.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        statusMsg,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusMsg.contains('Error') || statusMsg.contains('Failed') || statusMsg.contains('Invalid') || statusMsg.contains('Could not')
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
                if (!emailSent)
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
                              statusMsg = 'Sending reset email...';
                            });
                            final ok = await context.read<AuthProvider>().resetPassword(email);
                            setDialogState(() {
                              isWorking = false;
                              if (ok) {
                                emailSent = true;
                                statusMsg = 'Reset email sent! Please check your inbox.';
                              } else {
                                statusMsg = context.read<AuthProvider>().errorMessage;
                              }
                            });
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                    child: Text(isWorking ? 'Sending...' : 'Send Reset Email'),
                  )
                else if (!useCodeMode)
                  ElevatedButton(
                    onPressed: isWorking
                        ? null
                        : () async {
                            final rawUrl = linkCtrl.text.trim();
                            final newPass = newPassCtrl.text.trim();
                            if (rawUrl.isEmpty) {
                              setDialogState(() => statusMsg = 'Please paste the reset link or browser URL.');
                              return;
                            }
                            if (newPass.length < 6) {
                              setDialogState(() => statusMsg = 'Password must be at least 6 characters.');
                              return;
                            }
                            setDialogState(() {
                              isWorking = true;
                              statusMsg = 'Validating link and setting new password...';
                            });
                            final ok = await context.read<AuthProvider>().resetPasswordWithPastedLink(
                                  rawUrl: rawUrl,
                                  newPassword: newPass,
                                );
                            if (ok) {
                              Navigator.pop(ctx);
                              showCustomSnackBar(context, 'Password updated successfully! Welcome.');
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

                // Guest Mode (DEV only - completely removed on Production)
                if (AppConfig.isDev) ...[
                  const SizedBox(height: 14),
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
                ],

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

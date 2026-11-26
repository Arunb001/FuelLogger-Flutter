import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/version.dart';
import '../../config/env.dart';
import '../../widgets/custom_snackbar.dart';
import '../shell/main_shell.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

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
      MaterialPageRoute(builder: (_) => const MainShell()),
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
    final c = context.appColors;
    if (AppConfig.isDev && (AppConfig.googleWebClientId == null || AppConfig.googleWebClientId!.isEmpty)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: c.costAmber, size: 24),
              const SizedBox(width: 8),
              const Flexible(child: Text('DEV OAuth Setup Pending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DEV Web Client ID is not yet set in env_dev.dart.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                'For testing on DEV right now, you can use:\n'
                '• Sign In with Password (or create an account)\n'
                '• Continue as Guest (Offline Mode)',
                style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Use Password / Guest', style: TextStyle(color: c.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Try Anyway', style: TextStyle(color: c.costAmber)),
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
    final c = context.appColors;
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
              backgroundColor: c.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: c.costAmber, size: 24),
                  const SizedBox(width: 8),
                  const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!emailSent) ...[
                      Text(
                        'Enter your email to receive a password reset link from Supabase.',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.subtleBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How to reset using the link:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: c.costAmber),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• If you clicked the email link and Chrome showed "localhost:3000":\n'
                              '  Copy the URL from Chrome\'s address bar (localhost:3000/#access_token=...) and paste it below.\n'
                              '• If copying directly from email:\n'
                              '  Long-press "Reset password" -> "Copy link address" and paste below without opening in browser first.',
                              style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.3),
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
                            icon: Icon(Icons.paste, color: c.distanceBlue),
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
                          child: Text(
                            'Received a 6-digit code instead? Tap to enter code',
                            style: TextStyle(color: c.distanceBlue, fontSize: 11, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Enter the 6-digit recovery code sent to ${resetCtrl.text.trim()} and your new password.',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
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
                          child: Text(
                            'Received an email link instead? Tap to paste link',
                            style: TextStyle(color: c.distanceBlue, fontSize: 11, decoration: TextDecoration.underline),
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
                              ? c.accentPrimary
                              : c.mileageGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isWorking ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: c.accentPrimary, foregroundColor: Colors.white),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.mileageGreen,
                      foregroundColor: context.isDarkTheme ? Colors.black : Colors.white,
                    ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.mileageGreen,
                      foregroundColor: context.isDarkTheme ? Colors.black : Colors.white,
                    ),
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
    final c = context.appColors;
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: c.accentPrimary.withOpacity(0.28),
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
                        color: c.surfaceElevated,
                        child: Icon(Icons.local_gas_station, size: 48, color: c.accentPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Fuel Logger',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.3, color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mileage Tracker',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 28),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.isDarkTheme ? Colors.white : c.surfaceElevated,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: context.isDarkTheme ? BorderSide.none : BorderSide(color: c.subtleBorder),
                            ),
                            elevation: 0,
                          ),
                          child: Center(
                            child: Text(
                              'Sign in with Google',
                              style: TextStyle(
                                color: context.isDarkTheme ? Colors.black87 : c.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(child: Divider(color: c.subtleBorder)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR', style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            Expanded(child: Divider(color: c.subtleBorder)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Icon(Icons.lock_outline, color: c.accentPrimary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isSignUpMode ? 'Create Account' : 'Sign In with Password',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignUpMode
                              ? 'Enter your email and create a password (min 6 chars).'
                              : 'Enter your credentials to log in.',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                        const SizedBox(height: 18),

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

                        if (!_isSignUpMode) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(color: c.distanceBlue, fontSize: 12),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                        ],

                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handlePasswordAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.accentPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                        TextButton(
                          onPressed: () => setState(() => _isSignUpMode = !_isSignUpMode),
                          child: Text(
                            _isSignUpMode
                                ? 'Already have an account? Sign In'
                                : 'New to Fuel Logger? Create account',
                            style: TextStyle(color: c.costAmber, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (AppConfig.isDev) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () {
                      auth.continueAsGuest();
                      _onSuccess();
                    },
                    child: Text(
                      'Continue as Guest (Offline Mode)',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                Text(
                  AppVersion.display,
                  style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

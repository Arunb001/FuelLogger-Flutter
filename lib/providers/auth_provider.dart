import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user = SupabaseService.currentUser;
  bool _isGuest = false;
  bool _isLoading = false;
  String _errorMessage = '';

  User? get user => _user;
  bool get isAuthenticated => (_user != null && SupabaseService.hasValidSession) || _isGuest;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get userEmail => _isGuest ? 'guest@fuellogger.app' : (_user?.email ?? 'guest@fuellogger.app');

  AuthProvider() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _user = data.session?.user;
        _isGuest = false;
        notifyListeners();
      }
    });
  }

  void continueAsGuest() {
    _isGuest = true;
    _user = null;
    _errorMessage = '';
    notifyListeners();
  }

  Future<bool> signInWithPassword(String email, String password) async {
    _setLoading(true);
    try {
      final res = await SupabaseService.signInWithPassword(email: email, password: password);
      if (res.session != null && res.user != null) {
        _user = res.user;
        _isGuest = false;
        _errorMessage = '';
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Email verification required. Please check your inbox or sign in with Google.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUpWithPassword(String email, String password) async {
    _setLoading(true);
    try {
      final res = await SupabaseService.signUpWithPassword(email: email, password: password);
      if (res.session != null && res.user != null) {
        _user = res.user;
        _isGuest = false;
        _errorMessage = '';
        notifyListeners();
        return true;
      } else {
        // When session is null, check if user was already registered
        if (res.user != null && (res.user!.identities == null || res.user!.identities!.isEmpty)) {
          _errorMessage = 'Account already exists. Please sign in with your password or use Google Sign-In.';
        } else {
          _errorMessage = 'Account created! Please check your email to confirm before signing in.';
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final res = await SupabaseService.signInWithGoogleNative();
      if (res != null && res.user != null && res.session != null) {
        _user = res.user;
        _isGuest = false;
        _errorMessage = '';
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    try {
      await SupabaseService.resetPassword(email);
      _errorMessage = '';
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPasswordWithPastedLink({
    required String rawUrl,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      String clean = rawUrl.trim();
      // Ensure scheme exists for Uri.parse if user pasted localhost:3000/#access_token=...
      if (!clean.startsWith('http://') && !clean.startsWith('https://') && !clean.startsWith('fuellogger://') && !clean.startsWith('com.fuellogger')) {
        clean = 'http://$clean';
      }
      final uri = Uri.parse(clean);

      // 1. Try Supabase built-in getSessionFromUrl
      try {
        final res = await Supabase.instance.client.auth.getSessionFromUrl(uri);
        await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword.trim()));
        _user = res.session.user;
        _isGuest = false;
        _errorMessage = '';
        notifyListeners();
        return true;
      } catch (_) {}

      // 2. Try URL Fragment parsing (#access_token=...&refresh_token=...)
      String fragment = uri.fragment;
      if (fragment.isEmpty && clean.contains('#')) {
        fragment = clean.substring(clean.indexOf('#') + 1);
      }
      if (fragment.isNotEmpty) {
        final q = Uri.splitQueryString(fragment);
        final refreshToken = q['refresh_token'];
        if (refreshToken != null && refreshToken.isNotEmpty) {
          try {
            await Supabase.instance.client.auth.setSession(refreshToken);
            await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword.trim()));
            _user = SupabaseService.currentUser;
            _isGuest = false;
            _errorMessage = '';
            notifyListeners();
            return true;
          } catch (_) {}
        }
      }

      // 3. Try query token parameter
      final q = uri.queryParameters;
      final token = q['token'];
      if (token != null && token.isNotEmpty) {
        final res = await Supabase.instance.client.auth.verifyOTP(
          tokenHash: token,
          type: OtpType.recovery,
        );
        if (res.session != null) {
          await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword.trim()));
          _user = res.session?.user ?? SupabaseService.currentUser;
          _isGuest = false;
          _errorMessage = '';
          notifyListeners();
          return true;
        }
      }

      _errorMessage = 'Could not extract session from pasted link. Make sure to copy the full URL.';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyOtpAndSetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );
      if (res.session != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword.trim()),
        );
        _user = res.user ?? SupabaseService.currentUser;
        _isGuest = false;
        _errorMessage = '';
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid or expired 6-digit recovery code.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _setLoading(true);
    try {
      await SupabaseService.updatePassword(newPassword);
      _errorMessage = '';
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await CacheService.clearUserCache();
    await SupabaseService.signOut();
    _user = null;
    _isGuest = false;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  String _cleanError(String raw) {
    if (raw.contains('invalid_credentials') || raw.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('otp_expired') || raw.contains('Email link is invalid or has expired')) {
      return 'This recovery link has already been used or expired. If you opened it in Chrome, please copy the URL from Chrome\'s address bar (localhost:3000/#access_token=...) and paste it here, or request a fresh link.';
    }
    if (raw.contains('ApiException: 10') || raw.contains('sign_in_failed') || raw.contains('api.ApiException')) {
      return 'Google Sign-In configuration error (unregistered SHA-1). Please sign in with password or use Guest Mode.';
    }
    if (raw.contains('over_email_send_rate_limit') || raw.contains('rate limit')) {
      return 'Rate limit reached. Please sign in with Google or try again later.';
    }
    if (raw.contains('User already registered') || raw.contains('already exists')) {
      return 'Account already exists. Please sign in with your password.';
    }
    if (raw.contains('network_error') || raw.contains('SocketException')) {
      return 'Network connection issue. You can continue in Guest (Offline) Mode.';
    }
    return raw
        .replaceAll('AuthException', '')
        .replaceAll('AuthApiException', '')
        .replaceAll('Exception:', '')
        .replaceAll('PostgrestException', '')
        .replaceAll('message:', '')
        .trim();
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

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

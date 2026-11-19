import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user = SupabaseService.currentUser;
  bool _isGuest = false;
  bool _isLoading = false;
  String _errorMessage = '';

  User? get user => _user;
  bool get isAuthenticated => _user != null || _isGuest;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get userEmail => _isGuest ? 'guest@fuellogger.app' : (_user?.email ?? 'guest@fuellogger.app');

  AuthProvider() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  void continueAsGuest() {
    _isGuest = true;
    _user = null;
    notifyListeners();
  }

  Future<bool> signInWithPassword(String email, String password) async {
    _setLoading(true);
    try {
      final res = await SupabaseService.signInWithPassword(email: email, password: password);
      _user = res.user;
      _isGuest = false;
      _errorMessage = '';
      notifyListeners();
      return true;
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
      _user = res.user;
      _isGuest = false;
      _errorMessage = '';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendOtp(String email) async {
    _setLoading(true);
    try {
      await SupabaseService.sendOtp(email);
      _errorMessage = '';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyOtp(String email, String token) async {
    _setLoading(true);
    try {
      final res = await SupabaseService.verifyOtp(email: email, token: token);
      _user = res.user;
      _isGuest = false;
      _errorMessage = '';
      notifyListeners();
      return true;
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
      return 'Email limit reached (3-4/hr). Please sign in with Password.';
    }
    if (raw.contains('User already registered')) {
      return 'Account already exists. Please sign in.';
    }
    return raw.replaceAll('AuthException', '').replaceAll('Exception:', '').trim();
  }
}

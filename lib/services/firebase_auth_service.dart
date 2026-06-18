import 'package:firebase_auth/firebase_auth.dart';

/// Service class interfacing directly with Firebase Authentication SDK for session logic.
class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Exposes the currently active Firebase User
  User? get currentUser => _firebaseAuth.currentUser;

  /// Triggers Firebase Phone Verification.
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Authenticate directly with a PhoneAuthCredential (used for auto-verification)
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return await _firebaseAuth.signInWithCredential(credential);
  }

  /// Authenticate the verification code with Firebase Auth.
  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final AuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _firebaseAuth.signInWithCredential(credential);
  }

  /// Triggers Firebase sign-out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}

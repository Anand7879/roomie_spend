import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';

// --- Authentication States ---
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthCodeSent extends AuthState {
  final String verificationId;
  final String phoneNumber;
  const AuthCodeSent({required this.verificationId, required this.phoneNumber});
}

class AuthProfileIncomplete extends AuthState {
  final String phone;
  const AuthProfileIncomplete({required this.phone});
}

class AuthAuthenticated extends AuthState {
  final RoommateUser user;
  const AuthAuthenticated(this.user);
}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
}

// --- Dependency Service Providers ---
// To override these in tests, use ProviderScope(overrides: [
//   storageServiceProvider.overrideWithValue(MockStorageService()),
//   firebaseAuthServiceProvider.overrideWithValue(MockFirebaseAuthService()),
//   firestoreServiceProvider.overrideWithValue(MockFirestoreService()),
// ])
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) => FirebaseAuthService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

// --- State Notifier Provider (Riverpod) ---
final authStateNotifierProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends Notifier<AuthState> {
  late final StorageService _storageService;
  late final FirebaseAuthService _firebaseAuthService;
  late final FirestoreService _firestoreService;

  @override
  AuthState build() {
    _storageService = ref.watch(storageServiceProvider);
    _firebaseAuthService = ref.watch(firebaseAuthServiceProvider);
    _firestoreService = ref.watch(firestoreServiceProvider);
    return const AuthInitial();
  }

  /// Runs session auto-login verification on app launch
  Future<void> initializeSession() async {
    try {
      final firebaseUser = _firebaseAuthService.currentUser;
      if (firebaseUser != null) {
        // Fetch matching user document from Cloud Firestore
        final roommateUser = await _firestoreService.getUser(firebaseUser.uid);
        if (roommateUser != null && roommateUser.profileCompleted) {
          // Store session locally
          await _storageService.saveSession(
            uid: roommateUser.uid,
            phone: roommateUser.phone,
            name: roommateUser.name,
            email: roommateUser.email,
          );
          state = AuthAuthenticated(roommateUser);
          return;
        } else {
          // User exists in Auth but Firestore profile is not completed
          state = AuthProfileIncomplete(phone: firebaseUser.phoneNumber ?? '');
          return;
        }
      }
      
      // No active session
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthFailure("Session initialization error: ${e.toString()}");
    }
  }

  /// Sends OTP code request via Firebase Auth verifyPhoneNumber
  Future<void> sendOtp(String rawPhoneNumber) async {
    state = const AuthLoading();
    try {
      await _firebaseAuthService.verifyPhone(
        phoneNumber: rawPhoneNumber,
        verificationCompleted: (credential) async {
          // Auto code retrieval or instant verification
          try {
            final userCred = await _firebaseAuthService.signInWithCredential(credential);
            final user = userCred.user;
            if (user != null) {
              await _checkUserInFirestore(user.uid, rawPhoneNumber);
            }
          } catch (e) {
            state = AuthFailure("Auto-verification failed: ${e.toString()}");
          }
        },
        verificationFailed: (e) {
          state = AuthFailure(e.message ?? "Phone verification failed.");
        },
        codeSent: (verificationId, resendToken) {
          state = AuthCodeSent(
            verificationId: verificationId,
            phoneNumber: rawPhoneNumber,
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {},
      );
    } catch (e) {
      state = AuthFailure("Failed to request OTP: ${e.toString()}");
    }
  }

  /// Submits the 6-digit verification PIN to authenticate the session
  Future<void> verifyOtp(String smsCode) async {
    final currentState = state;
    if (currentState is! AuthCodeSent) return;

    final verificationId = currentState.verificationId;
    final phoneNumber = currentState.phoneNumber;

    state = const AuthLoading();
    try {
      final userCred = await _firebaseAuthService.signInWithOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final user = userCred.user;
      if (user != null) {
        await _checkUserInFirestore(user.uid, phoneNumber);
      } else {
        state = const AuthFailure("Failed to authenticate verification credentials.");
      }
    } catch (e) {
      state = AuthFailure("Invalid OTP verification code. Please try again.");
    }
  }

  /// Checks Cloud Firestore users collection for user existence
  Future<void> _checkUserInFirestore(String uid, String phoneNumber) async {
    try {
      final roommateUser = await _firestoreService.getUser(uid);
      if (roommateUser != null && roommateUser.profileCompleted) {
        // Save user details to Secure Storage
        await _storageService.saveSession(
          uid: roommateUser.uid,
          phone: roommateUser.phone,
          name: roommateUser.name,
          email: roommateUser.email,
        );

        state = AuthAuthenticated(roommateUser);
      } else {
        // New User -> Redirect to complete profile setup
        state = AuthProfileIncomplete(phone: phoneNumber);
      }
    } catch (e) {
      state = AuthFailure("Database sync error: ${e.toString()}");
    }
  }

  /// Saves the complete profile details in Cloud Firestore & secure storage, finalizing login
  Future<void> finalizeProfile({
    required String name,
    required String email,
    required String avatar,
    required String referralCode,
  }) async {
    final currentState = state;
    if (currentState is! AuthProfileIncomplete) return;

    final phone = currentState.phone;
    final firebaseUser = _firebaseAuthService.currentUser;
    if (firebaseUser == null) {
      state = const AuthFailure("No authenticated Firebase user found.");
      return;
    }

    state = const AuthLoading();
    try {
      final roommateUser = RoommateUser(
        uid: firebaseUser.uid,
        phone: phone.isNotEmpty ? phone : (firebaseUser.phoneNumber ?? ''),
        name: name,
        email: email,
        avatar: avatar,
        referralCode: referralCode,
        profileCompleted: true,
        createdAt: DateTime.now(), // toMap mapping writes serverTimestamp()
      );

      // Save directly to Cloud Firestore users collection
      await _firestoreService.createUser(roommateUser);

      // Save user details to Secure Storage
      await _storageService.saveSession(
        uid: roommateUser.uid,
        phone: roommateUser.phone,
        name: roommateUser.name,
        email: roommateUser.email,
      );

      state = AuthAuthenticated(roommateUser);
    } catch (e) {
      state = AuthFailure("Failed to save profile: ${e.toString()}");
    }
  }

  /// Triggers Sign Out (clears Firebase session, secure storage, and triggers UI redirection)
  Future<void> logout() async {
    state = const AuthLoading();
    try {
      await _firebaseAuthService.signOut();
      await _storageService.clearSession();
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthFailure("Failed to sign out: ${e.toString()}");
    }
  }
}

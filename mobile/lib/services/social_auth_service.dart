import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SocialAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleReady = false;

  Future<Map<String, String>> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      if (!_googleReady) {
        await googleSignIn.initialize();
        _googleReady = true;
      }
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Could not get Google auth token');
      }

      await _auth.signOut();
      await googleSignIn.signOut();
      return {'idToken': idToken, 'provider': 'GOOGLE'};
    } catch (e) {
      throw Exception(
        'Google sign-in is not ready yet. Please verify Firebase, SHA keys, and Google provider setup.',
      );
    }
  }

  Future<Map<String, String>> signInWithFacebook() async {
    throw Exception(
      'Facebook sign-in is temporarily unavailable in the Flutter app until Facebook Android setup is completed.',
    );
  }
}

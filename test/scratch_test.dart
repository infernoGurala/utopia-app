import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:utopia_app/firebase_options.dart';

void main() {
  test('fetch supabase config', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.android,
    );
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('web_app_config')
        .get();
    print('WEB_APP_CONFIG_DATA: ${doc.data()}');
  });
}

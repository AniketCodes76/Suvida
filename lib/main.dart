import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://unmlcvopevwwozfewawg.supabase.co',
    anonKey: 'sb_publishable_G0IGJsKOwvNqSYtw3TjpNw_p5_HFWzt',
  );

  runApp(const AccessibleRoutePlanner());
}

class AccessibleRoutePlanner extends StatelessWidget {
  const AccessibleRoutePlanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Accessible Route Planner',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}
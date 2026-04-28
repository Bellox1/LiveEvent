import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://pucbfcunmpaltnceufcy.supabase.co',
    anonKey: 'sb_publishable___n4XffxFC5949TzT5d-tg_uLdaOUE4',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Event App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, 
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session;

          
          if (session != null) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'Bienvenue ! (Connecté)',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }

        
          return LoginPage();
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = true;
  
  // VARIABLE POUR MASQUER/AFFICHER LE MOT DE PASSE
  bool _obscurePassword = true;

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entrez votre email d'abord"), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email de réinitialisation envoyé !"), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (response.user != null) {
          await Supabase.instance.client.from('users').insert({
            'id': response.user!.id,
            'email': response.user!.email,
            'created_at': DateTime.now().toIso8601String(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Inscription réussie !"), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // MODIFICATION DU WIDGET POUR L'ICÔNE DE L'ŒIL
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false, // On ajoute ce paramètre
    TextInputType keyboardType = TextInputType.text, 
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        // Si c'est un mot de passe, on utilise la variable _obscurePassword
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          // AJOUT DE L'ICÔNE DE L'ŒIL ICI
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ) 
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const SizedBox(height: 50),
              const Icon(Icons.event_available, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 20),
              Text(
                _isSignUp ? "Créer un compte" : "Bienvenue !",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              if (_isSignUp)
                _buildTextField(controller: _nameController, label: "Nom complet", icon: Icons.person_outline),
              
              _buildTextField(
                controller: _emailController, 
                label: "Email", 
                icon: Icons.email_outlined, 
                keyboardType: TextInputType.emailAddress
              ),
              
              // UTILISATION DU CHAMP MOT DE PASSE AVEC L'ŒIL
              _buildTextField(
                controller: _passwordController, 
                label: "Mot de passe", 
                icon: Icons.lock_outline, 
                isPassword: true // On active l'option mot de passe
              ),

              if (!_isSignUp)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text("Mot de passe oublié ?", style: TextStyle(color: Colors.grey)),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_isSignUp ? "S'INSCRIRE" : "SE CONNECTER"),
                    ),
              
              const SizedBox(height: 15),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp ? "Déjà un compte ? Connexion" : "Pas de compte ? Créer un compte"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// LA HOME PAGE RESTE LA MÊME
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("EventLive - Accueil"), backgroundColor: Colors.blueAccent),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Supabase.instance.client.auth.signOut().then((_) => 
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthPage()))),
          child: const Text("Se déconnecter"),
        ),
      ),
    );
  }
}
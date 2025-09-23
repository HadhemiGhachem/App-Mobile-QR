import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:qr_app_new/auth/Register.dart';
import 'package:qr_app_new/Home.dart';


class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  StreamSubscription? _sub;

  bool _showPassword = false;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // _initDeepLinkListener();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  // void _initDeepLinkListener() async {
  //   _sub = uriLinkStream.listen((Uri? uri) {
  //     if (uri != null && uri.scheme == 'myapp' && uri.path == '/auth/callback') {
  //       _handleGoogleCallback(uri);
  //     }
  //   }, onError: (err) {
  //     setState(() {
  //       _error = 'Erreur de lien profond : $err';
  //     });
  //   });

  //   final initialUri = await getInitialUri();
  //   if (initialUri != null &&
  //       initialUri.scheme == 'myapp' &&
  //       initialUri.path == '/auth/callback') {
  //     _handleGoogleCallback(initialUri);
  //   }
  // }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Veuillez remplir tous les champs';
      });
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connexion réussie'),
            duration: const Duration(seconds: 0),
          ),
        );
        await Future.delayed(const Duration(seconds: 0));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/excelDisplay');
        }
      } else {
        setState(() {
          _error = jsonDecode(response.body)['message'] ?? 'Échec de la connexion';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur réseau : $e';
      });
    }
  }

  // void _loginWithGoogle() async {
  //   setState(() {
  //     _error = null;
  //     _isLoading = true;
  //   });

  //   try {
  //     final response = await http.get(
  //       Uri.parse('http://10.0.2.2:8000/api/auth/google'),
  //       headers: {'Content-Type': 'application/json'},
  //     );

  //     setState(() {
  //       _isLoading = false;
  //     });

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       final redirectUrl = data['redirect_url'];

  //       final uri = Uri.parse(redirectUrl);
  //       if (await canLaunchUrl(uri)) {
  //         await launchUrl(uri, mode: LaunchMode.externalApplication);
  //       } else {
  //         setState(() {
  //           _error = 'Impossible de lancer l\'URL de connexion Google';
  //         });
  //       }
  //     } else {
  //       setState(() {
  //         _error = jsonDecode(response.body)['message'] ?? 'Échec de la récupération de l\'URL Google';
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isLoading = false;
  //       _error = 'Erreur réseau : $e';
  //     });
  //   }
  // }

  // void _handleGoogleCallback(Uri uri) async {
  //   final code = uri.queryParameters['code'];
  //   if (code == null) {
  //     setState(() {
  //       _error = 'Code d\'authentification Google manquant';
  //     });
  //     return;
  //   }

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     final response = await http.get(
  //       Uri.parse('http://10.0.2.2:8000/api/auth/google/callback?code=$code'),
  //       headers: {'Content-Type': 'application/json'},
  //     );

  //     setState(() {
  //       _isLoading = false;
  //     });

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       final token = data['token'];
  //       final prefs = await SharedPreferences.getInstance();
  //       await prefs.setString('auth_token', token);

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Connexion Google réussie'),
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //       await Future.delayed(const Duration(seconds: 2));
  //       if (mounted) {
  //         Navigator.pushReplacementNamed(context, '/home');
  //       }
  //     } else {
  //       setState(() {
  //         _error = jsonDecode(response.body)['message'] ?? 'Échec de la connexion Google';
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isLoading = false;
  //       _error = 'Erreur réseau : $e';
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  'Bienvenue',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous pour continuer',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => setState(() => _error = null),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                )
                              : const Text(
                                  'Se connecter',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // SizedBox(
                      //   width: double.infinity,
                      //   height: 52,
                      //   child: ElevatedButton.icon(
                      //     onPressed: _isLoading ? null : _loginWithGoogle,
                      //     icon: Image.asset(
                      //       'assets/google_logo.png',
                      //       height: 24,
                      //     ),
                      //     label: const Text(
                      //       'Se connecter avec Google',
                      //       style: TextStyle(fontSize: 18),
                      //     ),
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: Colors.white,
                      //       foregroundColor: Colors.black,
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(16),
                      //       ),
                      //       elevation: 5,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Pas encore de compte ? ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Register()),
                        );
                      },
                      child: Text(
                        'S\'inscrire',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
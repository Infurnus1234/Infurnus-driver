import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    return Scaffold(
      appBar: AppBar(title: const Text('INFURNUS Driver')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome Back',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Sign in to your existing driver account.'),
          const SizedBox(height: 24),
          TextField(
            controller: _identifier,
            enabled: !session.busy,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Mobile Number or Email',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            enabled: !session.busy,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 24),
          if (session.error != null)
            Text(session.error!, style: const TextStyle(color: Colors.red)),
          ElevatedButton(
            onPressed: session.busy
                ? null
                : () async {
                    final success = await session.login(
                      _identifier.text,
                      _password.text,
                    );
                    _password.clear();
                    if (context.mounted && success) context.go('/otp');
                  },
            child: Text(session.busy ? 'Signing in…' : 'Log In with Password'),
          ),
          TextButton(
            onPressed: session.busy ? null : () => context.go('/register'),
            child: const Text('Create a Driver account'),
          ),
          const Divider(),
          GoogleSignInButton(
            enabled: !session.busy,
            onIdToken: (token) async {
              await session.authenticateGoogle(token);
              if (context.mounted && session.authenticated) {
                context.go(session.landingPath);
              }
            },
          ),
          const Text(
            'Already registered but Google is not linked? Sign in with your existing method, then link Google from your verification screen.',
          ),
        ],
      ),
    );
  }
}

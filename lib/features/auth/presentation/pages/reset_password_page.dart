import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ResetPasswordPage extends StatefulWidget {
  final String? initialToken;
  const ResetPasswordPage({Key? key, this.initialToken}) : super(key: key);

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _message;

  final String _baseUrl = 'http://197.239.116.77:3000/api/v1';

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) _tokenCtrl.text = widget.initialToken!;
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final url = Uri.parse('$_baseUrl/auth/reset-password');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': _tokenCtrl.text.trim(),
          'newPassword': _passCtrl.text,
        }),
      );

      if (resp.statusCode == 200) {
        setState(() => _message = 'Mot de passe réinitialisé avec succès.');
        // navigate back to login after short delay
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else if (resp.statusCode == 401) {
        setState(() => _message = 'Token invalide ou expiré. Demandez un nouveau code.');
      } else {
        final data = jsonDecode(resp.body);
        setState(() => _message = data['message'] ?? 'Erreur lors de la réinitialisation.');
      }
    } catch (e) {
      setState(() => _message = 'Erreur réseau. Vérifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau mot de passe')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Icon(Icons.vpn_key, size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(height: 24),
                const Text('Entrez le code et choisissez un nouveau mot de passe.'),
                const SizedBox(height: 24),

                if (_message != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                    child: Text(_message!),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(labelText: 'Code de réinitialisation', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer le code' : (v.length < 6 ? 'Code trop court' : null),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nouveau mot de passe', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Veuillez entrer un mot de passe';
                    if (v.length < 8) return 'Minimum 8 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Veuillez confirmer le mot de passe';
                    if (v != _passCtrl.text) return 'Les mots de passe ne correspondent pas';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Réinitialiser le mot de passe'),
                ),

                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Retour')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

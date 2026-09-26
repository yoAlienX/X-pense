import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/crypto_service.dart';
import '../../services/storage_service.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../widgets/liquid_glass_snackbar.dart';

class DecryptionScreen extends StatefulWidget {
  const DecryptionScreen({Key? key}) : super(key: key);

  @override
  State<DecryptionScreen> createState() => _DecryptionScreenState();
}

class _DecryptionScreenState extends State<DecryptionScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isVerifying = false;

  Future<void> _verifyKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() => _isVerifying = true);

    final cryptoService = CryptoService();
    await cryptoService.setSecretKey(key);

    // Verify hash if available
    final storedHash = StorageService().prefs.getString('encryption_hash');
    if (storedHash != null && storedHash.isNotEmpty) {
      if (cryptoService.generateKeyHash() != storedHash) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            LiquidGlassSnackBar(
              context: context,
              message: 'Invalid Secret Key.',
              type: SnackBarType.error,
            ),
          );
        }
        cryptoService.clearSecretKey();
        setState(() => _isVerifying = false);
        return;
      }
    }

    // Try to initialize viewmodel with new key
    await context.read<TransactionViewModel>().initialize();

    if (mounted) {
      final stillNeedsDecryption = context.read<TransactionViewModel>().needsDecryptionKey;
      if (stillNeedsDecryption) {
        cryptoService.clearSecretKey();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          LiquidGlassSnackBar(
            context: context,
            message: 'Decryption failed. Please check your key.',
            type: SnackBarType.error,
          ),
        );
        setState(() => _isVerifying = false);
      } else {
        // Successful decryption via manual entry. Save the hash and reset the 30-day timer!
        await cryptoService.persistHashLocally();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.enhanced_encryption, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text(
              'Encrypted Data Found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your transactions are encrypted. Please enter your secret key to unlock them.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _keyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Secret Key',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyKey,
                child: _isVerifying
                    ? const CircularProgressIndicator()
                    : const Text('Unlock Data', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

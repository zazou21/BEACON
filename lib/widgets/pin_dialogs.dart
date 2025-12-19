import 'package:flutter/material.dart';
import 'package:beacon_project/services/db_service.dart';


// ---------- PIN Entry ----------
class PinEntryDialog extends StatefulWidget {
  final VoidCallback onVerified;
  const PinEntryDialog({required this.onVerified, super.key});

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final TextEditingController _pinController = TextEditingController();
  final DBService _db = DBService();
  String? _error;
  bool _checking = false;

  Future<void> _verify() async {
    setState(() => _checking = true);
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() {
        _error = 'Enter 4 digits';
        _checking = false;
      });
      return;
    }

    final ok = await _db.verifyPin(pin);
    if (ok) {
      widget.onVerified();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Enter PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(counterText: '', hintText: '4-digit PIN'),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: TextStyle(color: colors.error))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _checking ? null : _verify, child: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Unlock')),
      ],
    );
  }
}

// ---------- PIN Setup ----------
class PinSetupDialog extends StatefulWidget {
  final Future<void> Function(String pin) onPinSet;
  const PinSetupDialog({required this.onPinSet, super.key});

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _error;
  bool _saving = false;

  Future<void> _savePin() async {
    setState(() => _error = null);
    final p1 = _pinController.text.trim();
    final p2 = _confirmController.text.trim();
    if (p1.length != 4 || p2.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() => _saving = true);
    await widget.onPinSet(p1);
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Create 4-digit PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _pinController, keyboardType: TextInputType.number, obscureText: true, maxLength: 4, decoration: const InputDecoration(counterText: '', hintText: 'Enter PIN')),
          const SizedBox(height: 6),
          TextField(controller: _confirmController, keyboardType: TextInputType.number, obscureText: true, maxLength: 4, decoration: const InputDecoration(counterText: '', hintText: 'Confirm PIN')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: TextStyle(color: colors.error))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _savePin, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create')),
      ],
    );
  }
}

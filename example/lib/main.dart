import 'package:android_otp_kit/android_otp_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(
  MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
    home: const OtpDemo(),
  ),
);

enum FieldStyle { outlined, circle, underlined, filled, custom }

class OtpDemo extends StatefulWidget {
  const OtpDemo({super.key});

  @override
  State<OtpDemo> createState() => _OtpDemoState();
}

class _OtpDemoState extends State<OtpDemo> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  List<String> _hashes = const [];
  SmsListenMode _mode = SmsListenMode.retriever;
  FieldStyle _style = FieldStyle.outlined;
  bool _obscure = false;
  bool _waitingForOtp = false;
  int _listenCount = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    AndroidOtpKit.getAppSignatures().then((h) => setState(() => _hashes = h));
  }

  Future<void> _pickNumber() async {
    try {
      final number = await AndroidOtpKit.requestPhoneNumberHint();
      if (number != null) _phone.text = number;
    } on PlatformException catch (e) {
      setState(() => _status = 'Hint unavailable: ${e.message}');
    }
  }

  // This demo has no backend, so it can't send an SMS. It only starts
  // listening; send the test message from another phone (or to yourself).
  void _startListening() {
    _otp.clear();
    setState(() {
      _waitingForOtp = true;
      _listenCount++;
      _status = 'Listening for 5 minutes. Now send this SMS to this phone:';
    });
  }

  void _stopListening() => setState(() {
    _waitingForOtp = false;
    _status = '';
  });

  String get _testSms => _mode == SmsListenMode.retriever
      ? 'Your OTP is 482913\n\n${_hashes.isEmpty ? '<app hash>' : _hashes.first}'
      : 'Your OTP is 482913';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('android_otp_kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number',
              suffixIcon: IconButton(
                icon: const Icon(Icons.sim_card_outlined),
                tooltip: 'Pick from SIM',
                onPressed: _pickNumber,
              ),
            ),
            onTap: () {
              if (_phone.text.isEmpty) _pickNumber();
            },
          ),
          const SizedBox(height: 16),
          SegmentedButton<SmsListenMode>(
            segments: const [
              ButtonSegment(
                value: SmsListenMode.retriever,
                label: Text('Retriever'),
              ),
              ButtonSegment(
                value: SmsListenMode.userConsent,
                label: Text('User consent'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _waitingForOtp
                ? null
                : (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          _waitingForOtp
              ? OutlinedButton(
                  onPressed: _stopListening,
                  child: const Text('Stop listening'),
                )
              : FilledButton(
                  onPressed: _startListening,
                  child: const Text('Start listening for OTP'),
                ),
          const SizedBox(height: 24),
          const Text('Field style'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in FieldStyle.values)
                ChoiceChip(
                  label: Text(s.name),
                  selected: _style == s,
                  onSelected: (_) => setState(() => _style = s),
                ),
              FilterChip(
                label: const Text('obscure'),
                selected: _obscure,
                onSelected: (v) => setState(() => _obscure = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildOtpField(context),
          const SizedBox(height: 16),
          Text(_status),
          if (_waitingForOtp) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: SelectableText(_testSms),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: _testSms)),
                ),
              ),
            ),
          ],
          const Divider(height: 32),
          SelectableText('App hash (this build): ${_hashes.join(', ')}'),
        ],
      ),
    );
  }

  Widget _buildOtpField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OtpTextField(
      // A new key restarts the SMS listener each time "Start listening" is tapped.
      key: ValueKey('$_listenCount-$_style'),
      controller: _otp,
      listenForSms: _waitingForOtp,
      mode: _mode,
      obscureText: _obscure,
      onSmsEvent: (e) => setState(() => _status = 'SMS event: $e'),
      validator: (code) => code == '482913' ? null : 'That code is not right',
      onCompleted: (code) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verifying $code…'))),
      defaultTheme: switch (_style) {
        FieldStyle.outlined => null, // package default
        FieldStyle.circle => OtpBoxTheme.circle(
          borderColor: scheme.outlineVariant,
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        FieldStyle.underlined => OtpBoxTheme.underlined(
          borderColor: scheme.outlineVariant,
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        FieldStyle.filled => OtpBoxTheme.filled(
          fillColor: scheme.surfaceContainerHighest,
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        FieldStyle.custom => null,
      },
      separatorBuilder: _style == FieldStyle.filled
          ? (i) =>
                i == 2 ? const Text('–', style: TextStyle(fontSize: 24)) : null
          : null,
      boxBuilder: _style == FieldStyle.custom
          ? (context, state) {
              // The active box gets a light fill, a ring and the cursor.
              final solid = state.isFilled && !state.isFocused;
              final text = Text(
                _obscure && state.isFilled ? '•' : state.value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: solid ? scheme.onPrimary : scheme.primary,
                ),
              );
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.hasError
                      ? scheme.errorContainer
                      : solid
                      ? scheme.primary
                      : state.isFocused
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  border: state.isFocused
                      ? Border.all(color: scheme.primary, width: 2)
                      : null,
                ),
                child: !state.isFocused
                    ? text
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.isFilled) text,
                          // The package's cursor, so users see the active box.
                          OtpCursor(color: scheme.primary, height: 20),
                        ],
                      ),
              );
            }
          : null,
    );
  }
}

import 'package:android_otp_kit/android_otp_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

final _cursorFinder = find.byWidgetPredicate((w) => w is OtpCursor);

void main() {
  testWidgets('typing fills the boxes and calls onChanged / onCompleted', (
    tester,
  ) async {
    final changes = <String>[];
    String? completed;
    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: 4,
          listenForSms: false,
          hapticFeedback: false,
          onChanged: changes.add,
          onCompleted: (v) => completed = v,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(completed, isNull);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, '1234');
    expect(changes.last, '1234');
  });

  testWidgets('only digits are accepted by default and length is capped', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: 4,
          controller: controller,
          listenForSms: false,
          hapticFeedback: false,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '1a2b3c4d5');
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.text, '1234');
  });

  testWidgets('obscureText hides digits', (tester) async {
    await tester.pumpWidget(
      _app(
        const OtpTextField(
          length: 4,
          obscureText: true,
          obscuringCharacter: '*',
          listenForSms: false,
          hapticFeedback: false,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '98');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('9'), findsNothing);
    expect(find.text('*'), findsNWidgets(2));
  });

  testWidgets('validator shows an error and clears it on edit', (tester) async {
    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: 4,
          listenForSms: false,
          hapticFeedback: false,
          validator: (v) => v == '1111' ? null : 'Wrong code',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Wrong code'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Wrong code'), findsNothing);
  });

  testWidgets('errorText and custom boxBuilder are used', (tester) async {
    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: 3,
          listenForSms: false,
          errorText: 'Expired',
          boxBuilder: (context, state) =>
              Text('box${state.index}${state.hasError ? '!' : ''}'),
        ),
      ),
    );
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('box0!'), findsOneWidget);
    expect(find.text('box2!'), findsOneWidget);
  });

  testWidgets('separatorBuilder adds a widget between boxes', (tester) async {
    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: 6,
          listenForSms: false,
          separatorBuilder: (i) => i == 2 ? const Text('-') : null,
        ),
      ),
    );
    expect(find.text('-'), findsOneWidget);
  });

  /// Sends what a real keyboard sends: the hidden field's text with the new
  /// character appended, or with the last character removed for backspace.
  Future<void> typeKey(WidgetTester tester, String key) async {
    final field = tester.widget<TextField>(find.byType(TextField));
    final text = field.controller!.text;
    final next = key == 'backspace'
        ? text.substring(0, text.length - 1)
        : text + key;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<TextEditingController> pumpField(
    WidgetTester tester, {
    int length = 4,
    ValueChanged<String>? onCompleted,
  }) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: length,
          controller: controller,
          listenForSms: false,
          hapticFeedback: false,
          closeKeyboardWhenCompleted: false,
          onCompleted: onCompleted,
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  testWidgets('tapping a filled box and typing replaces only that digit', (
    tester,
  ) async {
    String? completed;
    final controller = await pumpField(
      tester,
      onCompleted: (v) => completed = v,
    );
    for (final key in ['1', '2', '3', '4']) {
      await typeKey(tester, key);
    }
    expect(completed, '1234');

    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_cursorFinder, findsOneWidget);

    await typeKey(tester, '9');
    expect(controller.text, '1934');
    expect(completed, '1934');
  });

  testWidgets('backspace on a selected box clears that box, not the last', (
    tester,
  ) async {
    final controller = await pumpField(tester);
    for (final key in ['1', '2', '3', '4']) {
      await typeKey(tester, key);
    }

    // Select the 3rd box and press backspace.
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await typeKey(tester, 'backspace');
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsOneWidget, reason: 'last digit is kept');
    expect(controller.text, '124');

    // Typing now fills the cleared 3rd box.
    await typeKey(tester, '7');
    expect(controller.text, '1274');
  });

  testWidgets('backspace on an empty box clears the previous one', (
    tester,
  ) async {
    final controller = await pumpField(tester);
    await typeKey(tester, '5');
    await typeKey(tester, '6');
    await typeKey(tester, 'backspace');
    expect(controller.text, '5');
    await typeKey(tester, 'backspace');
    expect(controller.text, '');
  });

  testWidgets('tapping an empty box goes to the first empty box', (
    tester,
  ) async {
    final controller = await pumpField(tester, length: 6);
    await typeKey(tester, '1');
    await typeKey(tester, '2');

    await tester.tap(find.byType(GestureDetector).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_cursorFinder, findsOneWidget);

    await typeKey(tester, '3');
    expect(controller.text, '123');
  });

  testWidgets('circle theme and a custom box get the cursor', (tester) async {
    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: 4,
          listenForSms: false,
          autofocus: true,
          defaultTheme: OtpBoxTheme.circle(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_cursorFinder, findsOneWidget);

    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: 4,
          listenForSms: false,
          autofocus: true,
          boxBuilder: (context, box) => CircleAvatar(
            child: box.isFocused ? const OtpCursor() : Text(box.value),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OtpCursor), findsOneWidget);
  });

  testWidgets('error state colors the digits too, and cursorColor works', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const OtpTextField(
          length: 4,
          listenForSms: false,
          autofocus: true,
          cursorColor: Colors.orange,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<OtpCursor>(find.byType(OtpCursor)).color,
      Colors.orange,
    );

    final controller = TextEditingController(text: '12');
    await tester.pumpWidget(
      _app(
        OtpTextField(
          length: 4,
          controller: controller,
          listenForSms: false,
          errorText: 'Wrong code',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final error = Theme.of(tester.element(find.text('1'))).colorScheme.error;
    expect(tester.widget<Text>(find.text('1')).style?.color, error);
    expect(tester.widget<Text>(find.text('Wrong code')).style?.color, error);
  });

  testWidgets('fills itself from an incoming SMS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const events = EventChannel('android_otp_kit/sms');
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (_, sink) =>
            sink.success({'type': 'sms', 'message': 'Code 482913 abcdEFGhijk'}),
      ),
    );

    String? completed;
    await tester.pumpWidget(
      _app(
        OtpTextField(hapticFeedback: false, onCompleted: (v) => completed = v),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(completed, '482913');
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    tester.binding.defaultBinaryMessenger.setMockStreamHandler(events, null);
    debugDefaultTargetPlatformOverride = null;
  });
}

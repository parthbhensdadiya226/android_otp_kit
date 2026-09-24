import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'android_otp_kit.dart';
import 'otp_box_theme.dart';
import 'sms_event.dart';

/// A pin-style OTP input with one box per character.
///
/// On Android it listens for the OTP SMS while it's on screen and fills
/// itself in. On iOS it offers the keyboard's one-time code suggestion.
/// Every part of its look can be changed: box themes for each state, a
/// custom cursor, separators, obscuring, or a completely custom
/// [boxBuilder].
class OtpTextField extends StatefulWidget {
  /// Creates a pin-style OTP field with [length] boxes.
  const OtpTextField({
    super.key,
    this.length = 6,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.onSubmitted,
    this.listenForSms = true,
    this.mode = SmsListenMode.retriever,
    this.senderPhoneNumber,
    this.otpPattern,
    this.onSmsEvent,
    this.defaultTheme,
    this.focusedTheme,
    this.filledTheme,
    this.errorTheme,
    this.disabledTheme,
    this.boxBuilder,
    this.spacing = 10,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.separatorBuilder,
    this.showCursor = true,
    this.cursor,
    this.cursorColor,
    this.obscureText = false,
    this.obscuringCharacter = '●',
    this.obscuringWidget,
    this.hintCharacter,
    this.hintStyle,
    this.errorText,
    this.forceErrorState = false,
    this.validator,
    this.errorTextStyle,
    this.errorBuilder,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.textInputAction = TextInputAction.done,
    this.closeKeyboardWhenCompleted = true,
    this.hapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 180),
    this.animationCurve = Curves.easeOut,
    this.enableInteractiveSelection = true,
  }) : assert(length > 0),
       assert(obscuringCharacter.length == 1);

  /// Number of boxes.
  final int length;

  /// Supply your own to read, set or clear the value.
  final TextEditingController? controller;

  /// Supply your own to move focus in or out programmatically.
  final FocusNode? focusNode;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called when all [length] boxes are filled, by typing, pasting or SMS.
  final ValueChanged<String>? onCompleted;

  /// Called when the keyboard's action button is pressed.
  final ValueChanged<String>? onSubmitted;

  // --- SMS ------------------------------------------------------------------

  /// Listen for the OTP SMS while the field is on screen (Android only).
  final bool listenForSms;

  /// Which SMS API to use. See [SmsListenMode].
  final SmsListenMode mode;

  /// Only accept SMS from this sender ([SmsListenMode.userConsent] only).
  final String? senderPhoneNumber;

  /// Custom pattern to find the code in the SMS. By default a run of
  /// [length] digits is used.
  final RegExp? otpPattern;

  /// Called for every SMS result, including timeouts and denied consent.
  final ValueChanged<SmsEvent>? onSmsEvent;

  // --- Look -----------------------------------------------------------------

  /// Theme of an empty box. Defaults to an outlined box based on your app's
  /// [ColorScheme].
  final OtpBoxTheme? defaultTheme;

  /// Theme of the box the next character goes into, while the field has focus.
  final OtpBoxTheme? focusedTheme;

  /// Theme of a box that has a character.
  final OtpBoxTheme? filledTheme;

  /// Theme of every box while there is an error.
  final OtpBoxTheme? errorTheme;

  /// Theme of every box when [enabled] is false.
  final OtpBoxTheme? disabledTheme;

  /// Builds each box yourself. When set, the themes, cursor and obscuring
  /// options are ignored. Show an [OtpCursor] when [OtpBoxState.isFocused]
  /// is true so users can see which box they're editing.
  final Widget Function(BuildContext context, OtpBoxState state)? boxBuilder;

  /// Gap between boxes.
  final double spacing;

  /// Horizontal alignment of the boxes and the error message: start, end or
  /// center.
  final MainAxisAlignment mainAxisAlignment;

  /// Widget placed after the box at `index`, e.g. a dash in the middle.
  /// Return null for no separator.
  final Widget? Function(int index)? separatorBuilder;

  /// Show a blinking cursor in the focused box.
  final bool showCursor;

  /// Custom cursor widget. Defaults to a thin blinking bar.
  final Widget? cursor;

  /// Color of the default cursor. Defaults to the theme's primary color,
  /// and to the error color while there is an error.
  final Color? cursorColor;

  /// Hide the characters, like a password.
  final bool obscureText;

  /// Character shown instead of each digit when [obscureText] is true.
  final String obscuringCharacter;

  /// Widget shown instead of each digit when [obscureText] is true.
  /// Takes priority over [obscuringCharacter].
  final Widget? obscuringWidget;

  /// Character shown in empty boxes, e.g. '-' or '0'.
  final String? hintCharacter;

  /// Style of [hintCharacter]. Defaults to the box text style in the
  /// theme's hint color.
  final TextStyle? hintStyle;

  // --- Errors ---------------------------------------------------------------

  /// Error message shown under the boxes. Also switches boxes to [errorTheme].
  final String? errorText;

  /// Use [errorTheme] without showing a message.
  final bool forceErrorState;

  /// Called when all boxes are filled. Return an error message to show it,
  /// or null if the value is fine.
  final String? Function(String value)? validator;

  /// Style of the error message. Defaults to `bodySmall` in the error color.
  final TextStyle? errorTextStyle;

  /// Builds the error message yourself.
  final Widget Function(BuildContext context, String error)? errorBuilder;

  // --- Behaviour ------------------------------------------------------------

  /// When false, the boxes use [disabledTheme] and ignore input.
  final bool enabled;

  /// When true, the code can't be edited but the boxes still show it.
  final bool readOnly;

  /// Focus the field and open the keyboard as soon as it's shown.
  final bool autofocus;

  /// Keyboard to show. Defaults to the number pad.
  final TextInputType keyboardType;

  /// Defaults to digits only. Pass `[]` to allow any character.
  final List<TextInputFormatter>? inputFormatters;

  /// Action button on the keyboard. See [onSubmitted].
  final TextInputAction textInputAction;

  /// Hide the keyboard once every box is filled.
  final bool closeKeyboardWhenCompleted;

  /// Light vibration on each key press.
  final bool hapticFeedback;

  /// Duration of the box and character animations. Use [Duration.zero] to
  /// turn them off.
  final Duration animationDuration;

  /// Curve of the box and character animations.
  final Curve animationCurve;

  /// Show a "Paste" menu when a box is long-pressed.
  final bool enableInteractiveSelection;

  @override
  State<OtpTextField> createState() => _OtpTextFieldState();
}

class _OtpTextFieldState extends State<OtpTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  StreamSubscription<SmsEvent>? _smsSubscription;
  String? _validationError;

  /// One entry per box; an empty string is an empty box. The field keeps its
  /// own slots so that a box in the middle can be cleared or replaced
  /// without shifting the others. [OtpTextField.controller] holds the filled
  /// characters joined together.
  late List<String> _slots;

  /// The box the next key press goes into.
  int _active = 0;

  /// The invisible text field the keyboard talks to. It always holds the
  /// current code with the caret at the end; each keyboard edit is read as
  /// "characters typed" or "backspace" and applied to [_active]. This way
  /// the result doesn't depend on how a keyboard handles selections.
  final _input = TextEditingController();
  String _inputBaseline = '';
  bool _updatingInput = false;
  bool _updatingController = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  String get _code => _slots.join();

  bool get _isComplete => _slots.every((c) => c.isNotEmpty);

  bool get _hasError =>
      widget.forceErrorState ||
      widget.errorText != null ||
      _validationError != null;

  List<TextInputFormatter> get _formatters =>
      widget.inputFormatters ?? [FilteringTextInputFormatter.digitsOnly];

  @override
  void initState() {
    super.initState();
    _loadFromController();
    _controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
    _input.addListener(_onInputChanged);
    if (widget.listenForSms) _startSmsListener();
  }

  @override
  void didUpdateWidget(OtpTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(
        _onControllerChanged,
      );
      _controller.addListener(_onControllerChanged);
      _loadFromController();
    } else if (oldWidget.length != widget.length) {
      _loadFromController();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.listenForSms != widget.listenForSms ||
        oldWidget.mode != widget.mode ||
        oldWidget.senderPhoneNumber != widget.senderPhoneNumber) {
      _smsSubscription?.cancel();
      _smsSubscription = null;
      if (widget.listenForSms) _startSmsListener();
    }
  }

  @override
  void dispose() {
    _smsSubscription?.cancel();
    _controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _input.dispose();
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  // --- SMS ------------------------------------------------------------------

  void _startSmsListener() {
    _smsSubscription = AndroidOtpKit.listenForSms(
      mode: widget.mode,
      senderPhoneNumber: widget.senderPhoneNumber,
      otpLength: widget.otpPattern == null ? widget.length : null,
      otpPattern: widget.otpPattern,
    ).listen(_onSms, onError: (_) {});
  }

  void _onSms(SmsEvent event) {
    widget.onSmsEvent?.call(event);
    if (event case SmsReceived(:final code?)) {
      final previous = List.of(_slots);
      _replaceAll(code);
      _commit(previous);
    }
  }

  // --- Editing --------------------------------------------------------------

  void _loadFromController() {
    final text = _controller.text;
    _slots = List.generate(
      widget.length,
      (i) => i < text.length ? text[i] : '',
    );
    _active = _firstEmpty() ?? widget.length - 1;
    _resetInput();
  }

  int? _firstEmpty([int from = 0]) {
    for (var i = from; i < widget.length; i++) {
      if (_slots[i].isEmpty) return i;
    }
    return null;
  }

  String _filter(String text) {
    var value = TextEditingValue(text: text);
    for (final formatter in _formatters) {
      value = formatter.formatEditUpdate(TextEditingValue.empty, value);
    }
    return value.text;
  }

  /// Characters were typed (or pasted, or autofilled) at the active box.
  void _insert(String text) {
    final chars = _filter(text);
    if (chars.isEmpty) return;
    if (chars.length >= widget.length) {
      _replaceAll(chars); // a whole code, e.g. autofill or paste
      return;
    }
    for (final char in chars.split('')) {
      _slots[_active] = char;
      // Move on to the next empty box; while correcting a complete code,
      // just move one box to the right.
      _active =
          _firstEmpty(_active + 1) ??
          _firstEmpty() ??
          (_active + 1).clamp(0, widget.length - 1);
    }
  }

  /// Backspace: clear the active box, or the one before it if it's empty.
  void _backspace() {
    if (_slots[_active].isNotEmpty) {
      _slots[_active] = '';
    } else if (_active > 0) {
      _active--;
      _slots[_active] = '';
    }
  }

  void _replaceAll(String text) {
    var chars = _filter(text);
    if (chars.length > widget.length) {
      chars = chars.substring(0, widget.length);
    }
    _slots = List.generate(
      widget.length,
      (i) => i < chars.length ? chars[i] : '',
    );
    _active = _firstEmpty() ?? widget.length - 1;
  }

  void _onInputChanged() {
    if (_updatingInput) return;
    final before = _inputBaseline;
    final after = _input.text;
    if (after == before) {
      _resetInput(); // only the caret moved; keep it at the end
      return;
    }
    final previous = List.of(_slots);
    if (after.length > before.length && after.startsWith(before)) {
      _insert(after.substring(before.length));
    } else if (after.length < before.length && before.startsWith(after)) {
      for (var i = 0; i < before.length - after.length; i++) {
        _backspace();
      }
    } else {
      _replaceAll(after);
    }
    _commit(previous);
  }

  void _resetInput() {
    _inputBaseline = _code;
    final value = TextEditingValue(
      text: _inputBaseline,
      selection: TextSelection.collapsed(offset: _inputBaseline.length),
    );
    if (_input.value == value) return;
    _updatingInput = true;
    _input.value = value;
    _updatingInput = false;
  }

  /// Publishes the slots to the controller and runs the callbacks.
  void _commit(List<String> previous) {
    final code = _code;
    if (_controller.text != code) {
      _updatingController = true;
      _controller.value = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
      _updatingController = false;
    }
    _resetInput();

    if (listEquals(previous, _slots)) {
      setState(() {}); // e.g. backspace on the first, empty box
      return;
    }
    if (widget.hapticFeedback) HapticFeedback.selectionClick();
    _validationError = null;
    widget.onChanged?.call(code);

    if (_isComplete) {
      _validationError = widget.validator?.call(code);
      // Close the keyboard only when the code was just completed, not while
      // the user is correcting single boxes of a complete code.
      final wasComplete = previous.every((c) => c.isNotEmpty);
      if (widget.closeKeyboardWhenCompleted && !wasComplete) {
        _focusNode.unfocus();
      }
      widget.onCompleted?.call(code);
    }
    setState(() {});
  }

  /// The app changed the controller (e.g. `controller.clear()`).
  void _onControllerChanged() {
    if (_updatingController || _controller.text == _code) return;
    final previous = List.of(_slots);
    _replaceAll(_controller.text);
    _commit(previous);
  }

  void _onFocusChanged() => setState(() {});

  void _onBoxTap(int index) {
    if (!widget.enabled || widget.readOnly) return;
    // A filled box can be selected to change it. An empty box sends the
    // user to the first empty box, so no gaps are left behind.
    setState(() {
      _active = _slots[index].isNotEmpty ? index : (_firstEmpty() ?? index);
    });
    if (_focusNode.hasFocus) {
      // Already focused, but the keyboard may have been dismissed.
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focusNode.requestFocus();
    }
  }

  Future<void> _onBoxLongPress(Offset globalPosition) async {
    if (!widget.enabled ||
        widget.readOnly ||
        !widget.enableInteractiveSelection) {
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = overlay.globalToLocal(globalPosition);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'paste',
          child: Text(MaterialLocalizations.of(context).pasteButtonLabel),
        ),
      ],
    );
    if (action != 'paste' || !mounted) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (_filter(text).isEmpty) return;
    final previous = List.of(_slots);
    _replaceAll(text);
    _commit(previous);
  }

  // --- Themes ---------------------------------------------------------------

  OtpBoxTheme _defaultTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    return widget.defaultTheme ??
        OtpBoxTheme.outlined(
          borderColor: scheme.outlineVariant,
          textStyle: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        );
  }

  OtpBoxTheme _themeFor(OtpBoxState state, ThemeData theme) {
    final scheme = theme.colorScheme;
    final base = _defaultTheme(theme);
    if (!state.enabled) {
      return widget.disabledTheme ??
          base.copyBorderWith(color: scheme.onSurface.withValues(alpha: 0.12));
    }
    if (state.hasError) {
      // Border, digits and cursor all turn to the error color.
      return widget.errorTheme ??
          base
              .copyBorderWith(color: scheme.error)
              .mergeTextStyle(TextStyle(color: scheme.error));
    }
    if (state.isFocused) {
      return widget.focusedTheme ??
          base.copyBorderWith(color: scheme.primary, width: 2);
    }
    if (state.isFilled) {
      return widget.filledTheme ?? base.copyBorderWith(color: scheme.outline);
    }
    return base;
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focused = _focusNode.hasFocus;
    final active = _active;
    final error = widget.errorText ?? _validationError;

    final boxes = <Widget>[];
    for (var i = 0; i < widget.length; i++) {
      final state = OtpBoxState(
        index: i,
        value: _slots[i],
        isFocused: focused && widget.enabled && i == active,
        isFilled: _slots[i].isNotEmpty,
        hasError: _hasError,
        enabled: widget.enabled,
      );
      if (i > 0 && widget.spacing > 0) {
        boxes.add(SizedBox(width: widget.spacing));
      }
      final index = i;
      boxes.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onBoxTap(index),
          onLongPressStart: (details) =>
              _onBoxLongPress(details.globalPosition),
          child:
              widget.boxBuilder?.call(context, state) ??
              _buildBox(state, theme),
        ),
      );
      final separator = widget.separatorBuilder?.call(i);
      if (separator != null && i < widget.length - 1) {
        boxes.add(SizedBox(width: widget.spacing));
        boxes.add(separator);
      }
    }

    final field = Stack(
      children: [
        // The real text field, invisible and underneath the boxes. It owns
        // the keyboard connection and OS autofill; the boxes handle taps.
        Positioned.fill(child: IgnorePointer(child: _buildHiddenField(theme))),
        // Scale down instead of overflowing on narrow screens.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: boxes),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossAxisAlignment,
      children: [
        field,
        AnimatedSize(
          duration: widget.animationDuration,
          curve: widget.animationCurve,
          child: error == null || error.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      widget.errorBuilder?.call(context, error) ??
                      Text(
                        error,
                        style:
                            widget.errorTextStyle ??
                            theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                      ),
                ),
        ),
      ],
    );
  }

  CrossAxisAlignment get _crossAxisAlignment =>
      switch (widget.mainAxisAlignment) {
        MainAxisAlignment.start => CrossAxisAlignment.start,
        MainAxisAlignment.end => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.center,
      };

  Widget _buildHiddenField(ThemeData theme) {
    return TextSelectionTheme(
      data: const TextSelectionThemeData(
        selectionColor: Colors.transparent,
        selectionHandleColor: Colors.transparent,
      ),
      child: TextField(
        controller: _input,
        focusNode: _focusNode,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: const [AutofillHints.oneTimeCode],
        enableInteractiveSelection: false,
        showCursor: false,
        enableSuggestions: false,
        autocorrect: false,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(color: Colors.transparent, fontSize: 1),
        cursorColor: Colors.transparent,
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildBox(OtpBoxState state, ThemeData theme) {
    final boxTheme = _themeFor(state, theme);
    final textStyle =
        boxTheme.textStyle ??
        _defaultTheme(theme).textStyle ??
        theme.textTheme.headlineSmall;

    final showCursor = state.isFocused && widget.showCursor && !widget.readOnly;
    final cursor =
        widget.cursor ??
        OtpCursor(
          color:
              widget.cursorColor ??
              (state.hasError ? theme.colorScheme.error : null),
          height: (textStyle?.fontSize ?? 24) * 1.1,
        );

    Widget content;
    if (state.isFilled) {
      final character = widget.obscureText
          ? (widget.obscuringWidget ??
                Text(widget.obscuringCharacter, style: textStyle))
          : Text(state.value, style: textStyle);
      // A selected digit shows the cursor next to it: typing replaces it.
      content = showCursor
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [character, const SizedBox(width: 2), cursor],
            )
          : character;
    } else if (showCursor) {
      content = cursor;
    } else if (widget.hintCharacter != null) {
      content = Text(
        widget.hintCharacter!,
        style: widget.hintStyle ?? textStyle?.copyWith(color: theme.hintColor),
      );
    } else {
      content = const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: widget.animationDuration,
      curve: widget.animationCurve,
      width: boxTheme.width,
      height: boxTheme.height,
      padding: boxTheme.padding,
      margin: boxTheme.margin,
      decoration: boxTheme.decoration,
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: widget.animationDuration,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: KeyedSubtree(
          key: ValueKey('${state.value}-${state.isFocused}'),
          child: content,
        ),
      ),
    );
  }
}

/// The blinking cursor shown in the active box.
///
/// Use it in your own [OtpTextField.boxBuilder] when
/// [OtpBoxState.isFocused] is true.
class OtpCursor extends StatefulWidget {
  /// Creates a blinking cursor.
  const OtpCursor({
    super.key,
    this.color,
    this.width = 2,
    this.height = 24,
    this.blinkDuration = const Duration(milliseconds: 500),
  });

  /// Defaults to the theme's primary color.
  final Color? color;

  /// Thickness of the cursor.
  final double width;

  /// Height of the cursor.
  final double height;

  /// How long one fade in or out takes.
  final Duration blinkDuration;

  @override
  State<OtpCursor> createState() => _OtpCursorState();
}

class _OtpCursorState extends State<OtpCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: widget.blinkDuration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _blink,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color ?? Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(widget.width / 2),
        ),
      ),
    );
  }
}

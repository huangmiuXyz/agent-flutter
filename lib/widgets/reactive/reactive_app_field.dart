import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'package:agent/widgets/field/app_field.dart';

/// A reactive wrapper around [AppField] that binds to a
/// `FormControl<String>` via `formControlName`.
class ReactiveAppField extends ReactiveFormField<String, String> {
  /// Placeholder text shown when the field is empty.
  final String? placeholder;

  /// Label displayed above the field.
  final String? label;

  /// Optional leading icon name resolved via [AppIcon].
  final String? icon;

  /// Optional trailing icon name.
  final String? suffixIcon;

  /// Whether to obscure the text (for passwords, etc.).
  final bool obscureText;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Visual size variant.
  final FieldSize size;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final double? cursorHeight;

  ReactiveAppField({
    super.key,
    required super.formControlName,
    super.formControl,
    super.validationMessages,
    super.showErrors,
    this.placeholder,
    this.label,
    this.icon,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.size = FieldSize.md,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.cursorHeight,
  }) : super(
          builder: (ReactiveFormFieldState<String, String> field) {
            final state = field as _ReactiveAppFieldState;
            final w = state.widget as ReactiveAppField;

            return AppField(
              controller: state._controller,
              placeholder: w.placeholder,
              label: w.label,
              icon: w.icon,
              suffixIcon: w.suffixIcon,
              obscureText: w.obscureText,
              enabled: !state.control.disabled,
              readOnly: w.readOnly,
              errorText: state.errorText,
              size: w.size,
              keyboardType: w.keyboardType,
              textInputAction: w.textInputAction,
              maxLines: w.maxLines,
              minLines: w.minLines,
              cursorHeight: w.cursorHeight,
              onChanged: (value) {
                state.didChange(value);
              },
            );
          },
        );

  @override
  ReactiveFormFieldState<String, String> createState() =>
      _ReactiveAppFieldState();
}

class _ReactiveAppFieldState extends ReactiveFormFieldState<String, String> {
  late final TextEditingController _controller;
  StreamSubscription<String?>? _valueSub;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: control.value ?? '');
    _valueSub = control.valueChanges.listen((value) {
      final newText = value ?? '';
      if (_controller.text != newText) {
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(offset: newText.length);
      }
    });
  }

  @override
  void dispose() {
    _valueSub?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

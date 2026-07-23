import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'package:agent/widgets/reactive/form_row.dart';
import 'package:agent/widgets/reactive/reactive_app_field.dart';
import 'package:agent/widgets/reactive/reactive_app_select.dart';
import 'package:agent/widgets/reactive/reactive_app_switch.dart';
import 'package:agent/widgets/select/app_select.dart';
// ────────────────────────────────────────────────────────────────
// Field configs — each type has ONLY its relevant properties
// ────────────────────────────────────────────────────────────────

/// Base class for all field configs.
sealed class JsonFieldConfig {
  final String key;
  final String label;

  const JsonFieldConfig({required this.key, required this.label});
}

/// Text / email / password input.
class TextFieldConfig extends JsonFieldConfig {
  final String? placeholder;
  final String? icon;
  final bool required;
  final int? minLength;
  final int? maxLength;
  final bool email;
  final String? pattern;
  final bool obscureText;
  final String? defaultValue;
  final Map<String, String>? messages;

  const TextFieldConfig({
    required super.key,
    required super.label,
    this.placeholder,
    this.icon,
    this.required = false,
    this.minLength,
    this.maxLength,
    this.email = false,
    this.pattern,
    this.obscureText = false,
    this.defaultValue,
    this.messages,
  });
}

/// Dropdown select.
class SelectFieldConfig extends JsonFieldConfig {
  final String? placeholder;
  final bool required;
  final List<String> options;
  final String? defaultValue;
  final Map<String, String>? messages;

  const SelectFieldConfig({
    required super.key,
    required super.label,
    required this.options,
    this.placeholder,
    this.required = false,
    this.defaultValue,
    this.messages,
  });
}

/// Toggle switch.
class SwitchFieldConfig extends JsonFieldConfig {
  final bool defaultValue;

  const SwitchFieldConfig({
    required super.key,
    required super.label,
    this.defaultValue = false,
  });
}

// ────────────────────────────────────────────────────────────────
// JSON parsing
// ────────────────────────────────────────────────────────────────

/// Parse a JSON list into [JsonFieldConfig] list.
List<JsonFieldConfig> parseJsonFields(List<dynamic> json) {
  return json.map((e) {
    final map = e as Map<String, dynamic>;
    final type = map['type'] as String? ?? 'text';
    final key = map['key'] as String? ?? '';
    final label = map['label'] as String? ?? '';

    return switch (type) {
      'email' || 'password' || 'text' => TextFieldConfig(
        key: key,
        label: label,
        placeholder: map['placeholder'] as String?,
        icon: map['icon'] as String?,
        required: map['required'] as bool? ?? false,
        minLength: map['minLength'] as int?,
        maxLength: map['maxLength'] as int?,
        email: type == 'email',
        pattern: map['pattern'] as String?,
        obscureText: type == 'password',
        defaultValue: map['default'] as String?,
        messages: _parseMessages(map['messages']),
      ),
      'select' => SelectFieldConfig(
        key: key,
        label: label,
        placeholder: map['placeholder'] as String?,
        required: map['required'] as bool? ?? false,
        options: map['options'] is List
            ? (map['options'] as List).cast<String>()
            : const [],
        defaultValue: map['default'] as String?,
        messages: _parseMessages(map['messages']),
      ),
      'switch' => SwitchFieldConfig(
        key: key,
        label: label,
        defaultValue: map['default'] as bool? ?? false,
      ),
      _ => TextFieldConfig(key: key, label: label),
    };
  }).toList();
}

Map<String, String>? _parseMessages(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
  return null;
}

// ────────────────────────────────────────────────────────────────
// FormGroup builder
// ────────────────────────────────────────────────────────────────

/// Build a [FormGroup] from field configs.
FormGroup buildFormGroup(List<JsonFieldConfig> fields) {
  final map = <String, Object>{};
  for (final f in fields) {
    map[f.key] = switch (f) {
      TextFieldConfig(:final required, :final minLength, :final maxLength,
              :final email, :final pattern, :final defaultValue) =>
        _makeControl(defaultValue ?? '', [
          if (required) Validators.required,
          if (minLength != null) Validators.minLength(minLength),
          if (maxLength != null) Validators.maxLength(maxLength),
          if (email) Validators.email,
          if (pattern != null) Validators.pattern(pattern),
        ]),
      SelectFieldConfig(:final required, :final defaultValue) =>
        _makeControl(defaultValue ?? '', [
          if (required) Validators.required,
        ]),
      SwitchFieldConfig(:final defaultValue) =>
        _makeControl(defaultValue, <Validator<dynamic>>[]),
    };
  }
  return fb.group(map);
}

Object _makeControl(Object value, List<Validator<dynamic>> validators) {
  return validators.isEmpty ? value : [value, ...validators];
}

// ────────────────────────────────────────────────────────────────
// Widget builders
// ────────────────────────────────────────────────────────────────

/// Build a list of [FormRow] widgets from field configs.
List<FormRow> buildFormRows(List<JsonFieldConfig> fields) {
  return fields.map(_buildRow).toList();
}

FormRow _buildRow(JsonFieldConfig f) {
  return switch (f) {
    TextFieldConfig(
      :final key,
      :final label,
      :final placeholder,
      :final icon,
      :final obscureText,
      :final messages,
    ) =>
      FormRow(
        label: label,
        child: ReactiveAppField(
          formControlName: key,
          placeholder: placeholder,
          icon: icon,
          obscureText: obscureText,
          validationMessages: _msgMap(messages, label),
        ),
      ),
    SelectFieldConfig(
      :final key,
      :final label,
      :final placeholder,
      :final options,
      :final messages,
    ) =>
      FormRow(
        label: label,
        child: ReactiveAppSelect<String>(
          formControlName: key,
          placeholder: placeholder,
          options: options
              .map((o) => AppSelectOption(value: o, label: o))
              .toList(),
          validationMessages: _msgMap(messages, label),
        ),
      ),
    SwitchFieldConfig(:final key, :final label) =>
      FormRow(
        label: label,
        child: ReactiveAppSwitch(formControlName: key),
      ),
  };
}

/// Merge custom messages with sensible defaults for required fields.
Map<String, ValidationMessageFunction> _msgMap(
  Map<String, String>? custom,
  String label,
) {
  final map = <String, ValidationMessageFunction>{};
  if (custom != null) {
    for (final e in custom.entries) {
      map[e.key] = (_) => e.value;
    }
  }
  map.putIfAbsent(
    ValidationMessage.required,
    () => (_) => '$label is required',
  );
  return map;
}

/// Build a complete form widget (group + rows).
Widget buildFormFromConfig({
  required List<JsonFieldConfig> fields,
  FormGroup? group,
}) {
  final formGroup = group ?? buildFormGroup(fields);
  return ReactiveForm(
    formGroup: formGroup,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buildFormRows(fields),
    ),
  );
}

/// Build a complete form widget from raw JSON.
Widget buildFormFromJson(List<dynamic> json, {FormGroup? group}) {
  final fields = parseJsonFields(json);
  return buildFormFromConfig(fields: fields, group: group);
}

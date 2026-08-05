import 'package:reactive_forms/reactive_forms.dart';

import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/select/app_select.dart';

/// A reactive wrapper around [AppSelect] that binds to a
/// `FormControl<T>` via `formControlName`.
class ReactiveAppSelect<T> extends ReactiveFormField<T, T> {
  /// Available options.
  final List<AppSelectOption<T>> options;

  /// Hint text shown when no value is selected.
  final String? placeholder;

  /// Label displayed above the select field.
  final String? label;

  /// The visual size, matching [FieldSize].
  final FieldSize size;

  /// Maximum height of the dropdown menu.
  final double menuMaxHeight;

  /// Maximum width of the dropdown menu; null = follow the field width.
  final double? menuMaxWidth;

  ReactiveAppSelect({
    super.key,
    required super.formControlName,
    super.formControl,
    super.validationMessages,
    super.showErrors,
    required this.options,
    this.placeholder,
    this.label,
    this.size = FieldSize.md,
    this.menuMaxHeight = 300,
    this.menuMaxWidth,
  }) : super(
          builder: (ReactiveFormFieldState<T, T> field) {
            final state = field;
            final w = state.widget as ReactiveAppSelect<T>;

            return AppSelect<T>(
              value: state.control.value,
              placeholder: w.placeholder,
              label: w.label,
              errorText: state.errorText,
              disabled: state.control.disabled,
              size: w.size,
              options: w.options,
              menuMaxHeight: w.menuMaxHeight,
              menuMaxWidth: w.menuMaxWidth,
              onChanged: (value) {
                state.didChange(value);
              },
            );
          },
        );

  @override
  ReactiveFormFieldState<T, T> createState() => ReactiveFormFieldState<T, T>();
}

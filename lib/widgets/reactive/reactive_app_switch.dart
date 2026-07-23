import 'package:reactive_forms/reactive_forms.dart';

import 'package:agent/widgets/switch/app_switch.dart';

/// A reactive wrapper around [AppSwitch] that binds to a
/// `FormControl<bool>` via `formControlName`.
class ReactiveAppSwitch extends ReactiveFormField<bool, bool> {
  /// Optional label displayed to the right of the switch.
  final String? label;

  /// Whether the switch is disabled.
  final bool disabled;

  /// The size of the switch.
  final SwitchSize size;

  ReactiveAppSwitch({
    super.key,
    required super.formControlName,
    super.formControl,
    super.validationMessages,
    super.showErrors,
    this.label,
    this.disabled = false,
    this.size = SwitchSize.md,
  }) : super(
          builder: (ReactiveFormFieldState<bool, bool> field) {
            final state = field;
            final w = state.widget as ReactiveAppSwitch;
            final isDisabled = w.disabled || state.control.disabled;

            return AppSwitch(
              value: state.control.value ?? false,
              onChanged:
                  isDisabled ? null : (value) => state.didChange(value),
              disabled: isDisabled,
              label: w.label,
              size: w.size,
            );
          },
        );

  @override
  ReactiveFormFieldState<bool, bool> createState() =>
      ReactiveFormFieldState<bool, bool>();
}

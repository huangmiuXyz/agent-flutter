import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/reactive/reactive.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Demo page for reactive_forms wrappers.
class ReactiveDemo extends HookConsumerWidget {
  const ReactiveDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final submitted = useState<Map<String, dynamic>?>(null);
    final form = useMemoized(() => fb.group({
      'name': ['', Validators.required],
      'email': ['', Validators.required, Validators.email],
      'role': ['developer', Validators.required],
      'notifications': true,
    }));

    return SingleChildScrollView(
      padding: EdgeInsets.all(custom.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Reactive Forms Demo',
            variant: AppTextVariant.title,
          ),
          SizedBox(height: custom.spacing.lg),

          // ── Vertical layout ──
          AppText(
            'Vertical layout',
            variant: AppTextVariant.subtitle,
          ),
          SizedBox(height: custom.spacing.md),

          ReactiveForm(
            formGroup: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReactiveAppField(
                  formControlName: 'name',
                  label: 'Name',
                  placeholder: 'Enter your name',
                  icon: 'user',
                  validationMessages: {
                    ValidationMessage.required: (_) => 'Name is required',
                  },
                ),
                SizedBox(height: custom.spacing.md),

                ReactiveAppField(
                  formControlName: 'email',
                  label: 'Email',
                  placeholder: 'Enter your email',
                  icon: 'mail',
                  validationMessages: {
                    ValidationMessage.required: (_) => 'Email is required',
                    ValidationMessage.email: (_) => 'Enter a valid email',
                  },
                ),
                SizedBox(height: custom.spacing.md),

                ReactiveAppSelect<String>(
                  formControlName: 'role',
                  label: 'Role',
                  placeholder: 'Select role',
                  options: const [
                    AppSelectOption(value: 'developer', label: 'Developer'),
                    AppSelectOption(value: 'designer', label: 'Designer'),
                    AppSelectOption(value: 'manager', label: 'Manager'),
                    AppSelectOption(value: 'admin', label: 'Admin'),
                  ],
                  validationMessages: {
                    ValidationMessage.required: (_) => 'Role is required',
                  },
                ),
                SizedBox(height: custom.spacing.md),

                ReactiveAppSwitch(
                  formControlName: 'notifications',
                  label: 'Enable notifications',
                  size: SwitchSize.md,
                ),
                SizedBox(height: custom.spacing.lg),

                ReactiveFormConsumer(
                  builder: (context, f, child) {
                    return AppPrimaryButton(
                      text: 'Submit',
                      disabled: !f.valid,
                      onPressed: () {
                        submitted.value = f.value;
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: custom.spacing.xl),

          // ── Horizontal layout (settings-style) ──
          AppText(
            'Horizontal layout (FormRow)',
            variant: AppTextVariant.subtitle,
          ),
          SizedBox(height: custom.spacing.md),

          ReactiveForm(
            formGroup: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormRow(
                  label: 'Name',
                  child: ReactiveAppField(
                    formControlName: 'name',
                    placeholder: 'Enter your name',
                    icon: 'user',
                    validationMessages: {
                      ValidationMessage.required: (_) => 'Name is required',
                    },
                  ),
                ),
                FormRow(
                  label: 'Email',
                  child: ReactiveAppField(
                    formControlName: 'email',
                    placeholder: 'Enter your email',
                    icon: 'mail',
                    validationMessages: {
                      ValidationMessage.required: (_) => 'Email is required',
                      ValidationMessage.email: (_) => 'Enter a valid email',
                    },
                  ),
                ),
                FormRow(
                  label: 'Role',
                  child: ReactiveAppSelect<String>(
                    formControlName: 'role',
                    placeholder: 'Select role',
                    options: const [
                      AppSelectOption(value: 'developer', label: 'Developer'),
                      AppSelectOption(value: 'designer', label: 'Designer'),
                      AppSelectOption(value: 'manager', label: 'Manager'),
                      AppSelectOption(value: 'admin', label: 'Admin'),
                    ],
                    validationMessages: {
                      ValidationMessage.required: (_) => 'Role is required',
                    },
                  ),
                ),
                FormRow(
                  label: 'Notifications',
                  child: ReactiveAppSwitch(
                    formControlName: 'notifications',
                    size: SwitchSize.md,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: custom.spacing.xl),

          // ── JSON-driven form ──
          AppText(
            'JSON-driven form',
            variant: AppTextVariant.subtitle,
          ),
          SizedBox(height: custom.spacing.md),

          _JsonBuiltForm(),
          SizedBox(height: custom.spacing.lg),

          // ── Submitted result ──
          if (submitted.value != null) ...[
            AppText(
              'Submitted:',
              variant: AppTextVariant.subtitle,
            ),
            SizedBox(height: custom.spacing.sm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(custom.spacing.md),
              decoration: BoxDecoration(
                color: custom.colors.panel,
                borderRadius: custom.radii.sm,
                border: Border.all(color: custom.colors.borderSubtle),
              ),
              child: AppText(
                submitted.value.toString(),
                variant: AppTextVariant.body,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

  /// A form built entirely from JSON config via [JsonFormBuilder].
  class _JsonBuiltForm extends HookWidget {

    const _JsonBuiltForm();

    @override
    Widget build(BuildContext context) {
      final fields = useMemoized(() => parseJsonFields(_jsonFields));
      final formGroup = useMemoized(() => buildFormGroup(fields));

      return ReactiveForm(
        formGroup: formGroup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: buildFormRows(fields),
        ),
      );
    }

    static const _jsonFields = [
      {
        'key': 'fullName',
        'type': 'text',
        'label': 'Full Name',
        'placeholder': 'Enter your name',
        'icon': 'user',
        'required': true,
        'messages': {'required': 'Please enter your name'},
      },
      {
        'key': 'email',
        'type': 'email',
        'label': 'Email',
        'placeholder': 'Enter your email',
        'icon': 'mail',
        'required': true,
      },
      {
        'key': 'password',
        'type': 'password',
        'label': 'Password',
        'placeholder': 'Min 6 characters',
        'icon': 'lock',
        'required': true,
        'minLength': 6,
      },
      {
        'key': 'country',
        'type': 'select',
        'label': 'Country',
        'options': ['China', 'USA', 'Japan', 'Germany'],
        'required': true,
      },
      {
        'key': 'autoSave',
        'type': 'switch',
        'label': 'Auto Save',
        'default': true,
      },
    ];
  }

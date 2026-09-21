import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/support/domain/entities/support_form.dart';
import 'package:hather_app/features/support/presentation/providers/support_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class SupportFormScreen extends ConsumerStatefulWidget {
  const SupportFormScreen({required this.formId, super.key});

  final String formId;

  @override
  ConsumerState<SupportFormScreen> createState() => _SupportFormScreenState();
}

class _SupportFormScreenState extends ConsumerState<SupportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _values = <String, String>{};
  final _controllers = <String, TextEditingController>{};
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(SupportFormField field) {
    return _controllers.putIfAbsent(
      field.fieldKey,
      () => TextEditingController(text: _values[field.fieldKey] ?? ''),
    );
  }

  Future<void> _submit(SupportFormDetail detail) async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(supportRepositoryProvider).submitForm(
          formId: widget.formId,
          answers: Map<String, String>.from(_values),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.when(
      success: (_) {
        ref.invalidate(mySupportRequestsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.supportFormSubmitted)),
        );
        context.pop();
      },
      onFailure: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.supportSubmitFailed)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formAsync = ref.watch(supportFormDetailProvider(widget.formId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: formAsync.maybeWhen(
          data: (form) => Text(form.title, style: AppTextStyles.sectionTitle),
          orElse: () => Text(l10n.supportFormsTitle, style: AppTextStyles.sectionTitle),
        ),
      ),
      body: formAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Text(l10n.supportSubmitFailed, style: AppTextStyles.body),
        ),
        data: (form) {
          if (form.fields.isEmpty) {
            return Center(
              child: Text(l10n.supportNoForms, style: AppTextStyles.body),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (form.description != null && form.description!.isNotEmpty) ...[
                  Text(
                    form.description!,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                for (final field in form.fields) ...[
                  _DynamicField(
                    field: field,
                    l10n: l10n,
                    controller: field.isSelect ? null : _controllerFor(field),
                    value: _values[field.fieldKey],
                    onChanged: (value) {
                      setState(() => _values[field.fieldKey] = value);
                    },
                    validator: (value) {
                      if (field.isRequired && (value == null || value.trim().isEmpty)) {
                        return l10n.supportRequiredField;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(form),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.supportSubmitForm),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({
    required this.field,
    required this.l10n,
    required this.controller,
    required this.value,
    required this.onChanged,
    required this.validator,
  });

  final SupportFormField field;
  final AppLocalizations l10n;
  final TextEditingController? controller;
  final String? value;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final label = field.isRequired ? '${field.label} *' : field.label;

    if (field.isSelect) {
      return DropdownButtonFormField<String>(
        initialValue: value != null && value!.isNotEmpty ? value : null,
        decoration: _decoration(label, field.placeholder ?? l10n.supportSelectPlaceholder),
        items: field.options
            .map(
              (opt) => DropdownMenuItem<String>(
                value: opt,
                child: Text(opt),
              ),
            )
            .toList(),
        onChanged: (v) => onChanged(v ?? ''),
        validator: validator,
      );
    }

    return TextFormField(
      controller: controller,
      maxLines: field.isTextArea ? 5 : 1,
      decoration: _decoration(label, field.placeholder),
      onChanged: onChanged,
      validator: validator,
    );
  }

  InputDecoration _decoration(String label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    );
  }
}

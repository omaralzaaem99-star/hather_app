import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/routing/safe_navigation.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/widgets/app_text_field.dart';
import 'package:hather_app/core/widgets/error_message.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/core/utils/iqd_format.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class CreateDeliveryOrderScreen extends ConsumerStatefulWidget {
  const CreateDeliveryOrderScreen({super.key});

  @override
  ConsumerState<CreateDeliveryOrderScreen> createState() =>
      _CreateDeliveryOrderScreenState();
}

class _CreateDeliveryOrderScreenState
    extends ConsumerState<CreateDeliveryOrderScreen> {
  final _detailsController = TextEditingController();
  final _addressController = TextEditingController();
  final _couponController = TextEditingController();

  DeleteDurationOption? _duration;
  DeliveryFeeOption? _fee;
  DestinationChoice? _destination;
  CouponValidation? _coupon;
  String? _formError;
  String? _couponMessage;
  bool _couponOk = false;
  bool _submitting = false;
  bool _validatingCoupon = false;
  bool _loadingLocation = false;
  bool _defaultsApplied = false;

  @override
  void dispose() {
    _detailsController.dispose();
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  void _handleBack() {
    safeBack(context, fallbackLocation: AuthenticatedRoutes.home);
  }

  Future<void> _useCurrentLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loadingLocation = true;
      _formError = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _loadingLocation = false;
          _formError = l10n.locationDisabled;
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _formError = l10n.locationPermissionDenied;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final addressNote = _addressController.text.trim();
      setState(() {
        _destination = DestinationChoice(
          type: DestinationType.current,
          lat: position.latitude,
          lng: position.longitude,
          address: addressNote.isEmpty ? null : addressNote,
        );
        _loadingLocation = false;
      });
    } catch (_) {
      setState(() {
        _loadingLocation = false;
        _formError = l10n.locationFailed;
      });
    }
  }

  void _syncAddressIntoDestination(String value) {
    final dest = _destination;
    if (dest == null) return;
    final trimmed = value.trim();
    setState(() {
      _destination = DestinationChoice(
        type: dest.type,
        lat: dest.lat,
        lng: dest.lng,
        address: trimmed.isEmpty ? null : trimmed,
      );
    });
  }

  Future<void> _validateCoupon() async {
    final l10n = AppLocalizations.of(context);
    if (_fee == null) {
      setState(() {
        _couponMessage = l10n.selectDeliveryFeeFirst;
        _couponOk = false;
      });
      return;
    }
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _coupon = null;
        _couponMessage = null;
        _couponOk = false;
      });
      return;
    }

    setState(() {
      _validatingCoupon = true;
      _couponMessage = null;
    });
    final result = await ref.read(deliveryRepositoryProvider).validateCoupon(
          code: code,
          feeOptionId: _fee!.id,
        );
    if (!mounted) return;
    result.when(
      success: (coupon) {
        setState(() {
          _validatingCoupon = false;
          _coupon = coupon;
          _couponOk = true;
          _couponMessage = l10n.couponValid(IqdFormat.format(coupon.discountIqd));
        });
      },
      onFailure: (error) {
        setState(() {
          _validatingCoupon = false;
          _coupon = null;
          _couponOk = false;
          _couponMessage = error is Failure
              ? mapFailureToMessage(context, error)
              : l10n.couponInvalid;
        });
      },
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_submitting) return;

    final details = _detailsController.text.trim();
    if (details.isEmpty) {
      setState(() => _formError = l10n.orderDetailsRequired);
      return;
    }
    if (_destination == null ||
        _destination!.lat == null ||
        _destination!.lng == null) {
      setState(() => _formError = l10n.destinationRequired);
      return;
    }
    if (_duration == null || _fee == null) {
      setState(() => _formError = l10n.fillAllRequiredFields);
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    final addressNote = _addressController.text.trim();
    final destination = DestinationChoice(
      type: _destination!.type,
      lat: _destination!.lat,
      lng: _destination!.lng,
      address: addressNote.isEmpty ? null : addressNote,
    );

    final input = CreateDeliveryOrderInput(
      details: details,
      deleteDuration: _duration!,
      feeOption: _fee!,
      destination: destination,
      couponCode: _coupon?.code,
    );

    final result =
        await ref.read(deliveryRepositoryProvider).createOrder(input);
    if (!mounted) return;

    await result.when(
      success: (order) async {
        setState(() => _submitting = false);
        ref.invalidate(myOrdersProvider);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              l10n.orderCreatedSuccess,
              style: AppTextStyles.bodyStrong,
            ),
            content: Text(
              l10n.orderCreatedWaitingCaptain,
              style: AppTextStyles.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.okAction),
              ),
            ],
          ),
        );
        if (!mounted) return;
        // Land on orders, then open detail so Back → طلباتي → Home.
        context.go('/orders');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.push('/delivery/orders/${order.id}');
        });
      },
      onFailure: (error) async {
        setState(() {
          _submitting = false;
          _formError = error is Failure
              ? mapFailureToMessage(context, error)
              : l10n.orderSubmitFailed;
        });
      },
    );
  }

  void _applyDefaultsIfNeeded(DeliveryOrderSettings settings) {
    if (_defaultsApplied) return;
    if (settings.durations.isEmpty && settings.fees.isEmpty) return;
    var changed = false;
    if (_duration == null && settings.defaultDuration != null) {
      _duration = settings.defaultDuration;
      changed = true;
    }
    if (_fee == null && settings.defaultFee != null) {
      _fee = settings.defaultFee;
      changed = true;
    }
    _defaultsApplied = true;
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(deliveryOrderSettingsProvider);

    ref.listen(deliveryOrderSettingsProvider, (prev, next) {
      next.whenData(_applyDefaultsIfNeeded);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(
            l10n.createDeliveryOrderTitle,
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
        ),
        body: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            final message = error is Failure
                ? mapFailureToMessage(context, error)
                : l10n.orderSettingsLoadFailed;
            return Center(
              child: Padding(
                padding: AppDimensions.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: l10n.retryAction,
                      onPressed: () {
                        ref.invalidate(deliveryOrderSettingsProvider);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          data: (settings) => _buildForm(context, l10n, settings),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    DeliveryOrderSettings settings,
  ) {
    final durations = settings.durations;
    final fees = settings.fees;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyDefaultsIfNeeded(settings);
    });

    final canSubmit = durations.isNotEmpty && fees.isNotEmpty;
    final feeAmount = _fee?.amountIqd ?? 0;
    final discount = _couponOk ? (_coupon?.discountIqd ?? 0) : 0;
    final finalAmount = feeAmount - discount;

    return ListView(
      padding: AppDimensions.screenPadding,
      children: [
        Text(
          l10n.createDeliveryOrderSubtitle,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 16),
        AuthFormErrorBanner(message: _formError),
        _SectionLabel(l10n.orderDetailsLabel),
          TextField(
            controller: _detailsController,
            minLines: 4,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            style: AppTextStyles.input,
            cursorColor: AppColors.icon,
            onChanged: (_) {
              if (_formError != null) setState(() => _formError = null);
            },
            decoration: InputDecoration(
              hintText: l10n.orderDetailsHint,
              hintStyle:
                  AppTextStyles.body.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: BorderSide(
                  color: AppColors.icon.withValues(alpha: 0.85),
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          _SectionLabel(l10n.destinationLabel),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_loadingLocation || _submitting)
                  ? null
                  : _useCurrentLocation,
              icon: _loadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                _destination == null
                    ? l10n.currentLocation
                    : l10n.updateLocationAction,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.borderSubtle),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          if (_destination != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.locationConfirmed,
                      style: AppTextStyles.bodyStrong,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _SectionLabel(l10n.destinationAddressLabel),
          AppTextField(
            controller: _addressController,
            hintText: l10n.destinationAddressHint,
            textInputAction: TextInputAction.next,
            onChanged: _syncAddressIntoDestination,
          ),
          const SizedBox(height: 14),
          _SectionLabel(l10n.orderDeleteDurationLabel),
          _DropdownField<DeleteDurationOption>(
            value: _duration,
            hint: l10n.orderDeleteDurationHint,
            items: durations,
            labelBuilder: (item) => item.labelAr,
            onChanged: (value) => setState(() => _duration = value),
          ),
          const SizedBox(height: 14),
          _SectionLabel(l10n.deliveryFeeLabel),
          _DropdownField<DeliveryFeeOption>(
            value: _fee,
            hint: l10n.deliveryFeeHint,
            items: fees,
            labelBuilder: (item) => item.labelAr,
            onChanged: (value) {
              setState(() {
                _fee = value;
                _coupon = null;
                _couponOk = false;
                _couponMessage = null;
              });
            },
          ),
          const SizedBox(height: 14),
          _SectionLabel(l10n.couponLabel),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _couponController,
                  hintText: l10n.couponHint,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  onChanged: (_) {
                    setState(() {
                      _coupon = null;
                      _couponOk = false;
                      _couponMessage = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: AppDimensions.inputHeight,
                child: ElevatedButton(
                  onPressed:
                      (_validatingCoupon || _submitting) ? null : _validateCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: Size(96, AppDimensions.inputHeight),
                    maximumSize: Size(140, AppDimensions.inputHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                  child: _validatingCoupon
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.verifyCouponAction),
                ),
              ),
            ],
          ),
          if (_couponMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _couponMessage!,
                style: AppTextStyles.caption.copyWith(
                  color: _couponOk ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          if (_couponOk && _fee != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أجرة التوصيل        ${IqdFormat.format(feeAmount)} د.ع',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الخصم                 ${IqdFormat.format(discount)} د.ع',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الإجمالي            ${IqdFormat.format(finalAmount)} د.ع',
                    style: AppTextStyles.bodyStrong,
                  ),
                ],
              ),
            ),
          ],
          if (durations.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'لا توجد مدة متاحة حالياً.',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          if (fees.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'لا توجد أجور توصيل متاحة حالياً.',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.submitOrderAction,
            isLoading: _submitting,
            onPressed: (_submitting || !canSubmit) ? null : _submit,
          ),
          const SizedBox(height: 24),
        ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.bodyStrong),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T item) labelBuilder;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
          dropdownColor: AppColors.surface,
          iconEnabledColor: AppColors.icon,
          style: AppTextStyles.input,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelBuilder(item)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'حاضر'**
  String get appName;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتفك والرمز السري للمتابعة'**
  String get loginSubtitle;

  /// No description provided for @welcomeBack.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك مجدداً'**
  String get welcomeBack;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumber;

  /// No description provided for @secretCode.
  ///
  /// In ar, this message translates to:
  /// **'الرمز السري'**
  String get secretCode;

  /// No description provided for @confirmSecretCode.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الرمز السري'**
  String get confirmSecretCode;

  /// No description provided for @forgotSecretCode.
  ///
  /// In ar, this message translates to:
  /// **'نسيت الرمز السري؟'**
  String get forgotSecretCode;

  /// No description provided for @loginAction.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginAction;

  /// No description provided for @noAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get noAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟'**
  String get alreadyHaveAccount;

  /// No description provided for @createAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get createAccount;

  /// No description provided for @createAccountAction.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get createAccountAction;

  /// No description provided for @registerTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل معلوماتك لإنشاء حساب جديد'**
  String get registerSubtitle;

  /// No description provided for @phoneHintLocal.
  ///
  /// In ar, this message translates to:
  /// **'07XXXXXXXXX'**
  String get phoneHintLocal;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fullName;

  /// No description provided for @otpTitle.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز المرسل إلى الرقم:'**
  String get otpSubtitle;

  /// No description provided for @otpPasteHint.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك لصق الرمز مباشرة'**
  String get otpPasteHint;

  /// No description provided for @otpCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق'**
  String get otpCode;

  /// No description provided for @verifyAction.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get verifyAction;

  /// No description provided for @resendOtp.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرمز'**
  String get resendOtp;

  /// No description provided for @resendOtpAfter.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال بعد {seconds} ثانية'**
  String resendOtpAfter(int seconds);

  /// No description provided for @changePhoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'تغيير رقم الهاتف'**
  String get changePhoneNumber;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسيت الرمز السري'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتفك لإرسال رمز التحقق'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendOtpAction.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز التحقق'**
  String get sendOtpAction;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعيين رمز سري جديد'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز السري الجديد ثم أكده'**
  String get resetPasswordSubtitle;

  /// No description provided for @saveNewSecretCode.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الرمز السري'**
  String get saveNewSecretCode;

  /// No description provided for @homeWelcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، {name}'**
  String homeWelcome(String name);

  /// No description provided for @loginSuccessMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدخول بنجاح'**
  String get loginSuccessMessage;

  /// No description provided for @accountCreatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء حسابك بنجاح'**
  String get accountCreatedSuccess;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تعيين الرمز السري بنجاح'**
  String get passwordResetSuccess;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// No description provided for @countryCode.
  ///
  /// In ar, this message translates to:
  /// **'+964'**
  String get countryCode;

  /// No description provided for @errorFullNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل مطلوب'**
  String get errorFullNameRequired;

  /// No description provided for @errorFullNameTooShort.
  ///
  /// In ar, this message translates to:
  /// **'الاسم يجب أن لا يقل عن حرفين'**
  String get errorFullNameTooShort;

  /// No description provided for @errorFullNameDigitsOnly.
  ///
  /// In ar, this message translates to:
  /// **'الاسم لا يمكن أن يكون أرقاماً فقط'**
  String get errorFullNameDigitsOnly;

  /// No description provided for @errorPhoneRequired.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف مطلوب'**
  String get errorPhoneRequired;

  /// No description provided for @errorPhoneInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير صحيح'**
  String get errorPhoneInvalid;

  /// No description provided for @errorSecretCodeRequired.
  ///
  /// In ar, this message translates to:
  /// **'الرمز السري مطلوب'**
  String get errorSecretCodeRequired;

  /// No description provided for @errorSecretCodeTooShort.
  ///
  /// In ar, this message translates to:
  /// **'الرمز السري يجب أن يتكون من 6 خانات على الأقل'**
  String get errorSecretCodeTooShort;

  /// No description provided for @errorSecretCodeMismatch.
  ///
  /// In ar, this message translates to:
  /// **'الرمزان السريان غير متطابقين'**
  String get errorSecretCodeMismatch;

  /// No description provided for @errorOtpIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز التحقق المكوّن من 6 خانات'**
  String get errorOtpIncomplete;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف أو الرمز السري غير صحيح'**
  String get errorInvalidCredentials;

  /// No description provided for @errorInvalidPassword.
  ///
  /// In ar, this message translates to:
  /// **'الرمز السري غير صحيح'**
  String get errorInvalidPassword;

  /// No description provided for @registerUnregisteredPhoneHint.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرقم غير مسجل، أنشئ حسابك للمتابعة.'**
  String get registerUnregisteredPhoneHint;

  /// No description provided for @errorPhoneAlreadyExists.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف مسجل مسبقاً، يرجى تسجيل الدخول.'**
  String get errorPhoneAlreadyExists;

  /// No description provided for @errorInvalidOtp.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق غير صحيح'**
  String get errorInvalidOtp;

  /// No description provided for @errorOtpExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية رمز التحقق، أعد إرسال رمز جديد'**
  String get errorOtpExpired;

  /// No description provided for @errorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.'**
  String get errorNetwork;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلبات كثيرة، حاول مرة أخرى لاحقاً'**
  String get errorTooManyRequests;

  /// No description provided for @errorServer.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ، حاول مرة أخرى.'**
  String get errorServer;

  /// No description provided for @errorPhoneNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مرتبط بهذا الرقم'**
  String get errorPhoneNotFound;

  /// No description provided for @errorUnknown.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع'**
  String get errorUnknown;

  /// No description provided for @orderSettingsLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل إعدادات الطلب حالياً. حاول مرة أخرى.'**
  String get orderSettingsLoadFailed;

  /// No description provided for @devOtpHint.
  ///
  /// In ar, this message translates to:
  /// **'وضع التطوير المؤقت — رمز التحقق:'**
  String get devOtpHint;

  /// No description provided for @fieldRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get fieldRequired;

  /// No description provided for @okAction.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get okAction;

  /// No description provided for @retryAction.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retryAction;

  /// No description provided for @legalContentLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل المحتوى حالياً. يرجى المحاولة مرة أخرى.'**
  String get legalContentLoadFailed;

  /// No description provided for @notificationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات حالياً'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In ar, this message translates to:
  /// **'تعليم الكل كمقروء'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل الإشعارات. حاول مرة أخرى.'**
  String get notificationsLoadError;

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف إذن الإشعارات. يمكنك تفعيله من إعدادات الجهاز لاستلام تحديثات الطلبات.'**
  String get notificationPermissionDenied;

  /// No description provided for @openAppSettingsAction.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get openAppSettingsAction;

  /// No description provided for @notificationExpiredDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة الطلب'**
  String get notificationExpiredDialogTitle;

  /// No description provided for @notificationExpiredDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة الطلب قبل أن يقبله أحد الكباتن.'**
  String get notificationExpiredDialogBody;

  /// No description provided for @notificationCreateNewOrder.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء طلب جديد'**
  String get notificationCreateNewOrder;

  /// No description provided for @notificationOrderReleased.
  ///
  /// In ar, this message translates to:
  /// **'هذا الطلب لم يعد مسنداً إليك.'**
  String get notificationOrderReleased;

  /// No description provided for @captainOrderNoLongerAvailable.
  ///
  /// In ar, this message translates to:
  /// **'هذا الطلب لم يعد متاحاً.'**
  String get captainOrderNoLongerAvailable;

  /// No description provided for @adsSectionTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعلانات'**
  String get adsSectionTitle;

  /// No description provided for @adsPlaceholderTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إعلانات حالياً'**
  String get adsPlaceholderTitle;

  /// No description provided for @adsPlaceholderBody.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر الإعلانات هنا عند توفرها.'**
  String get adsPlaceholderBody;

  /// No description provided for @servicesSectionTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخدمات'**
  String get servicesSectionTitle;

  /// No description provided for @servicesSectionSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر الخدمة المناسبة لك'**
  String get servicesSectionSubtitle;

  /// No description provided for @deliveryServiceCta.
  ///
  /// In ar, this message translates to:
  /// **'اطلب مندوب'**
  String get deliveryServiceCta;

  /// No description provided for @taxiComingSoonTitle.
  ///
  /// In ar, this message translates to:
  /// **'تكسي حاضر'**
  String get taxiComingSoonTitle;

  /// No description provided for @taxiComingSoonBody.
  ///
  /// In ar, this message translates to:
  /// **'قريباً — خدمة التكسي قيد التجهيز'**
  String get taxiComingSoonBody;

  /// No description provided for @createDeliveryOrderTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب توصيل'**
  String get createDeliveryOrderTitle;

  /// No description provided for @createDeliveryOrderSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتب تفاصيل طلبك وحدد مكان التوصيل'**
  String get createDeliveryOrderSubtitle;

  /// No description provided for @deliveryOrderDisplayTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب توصيل'**
  String get deliveryOrderDisplayTitle;

  /// No description provided for @orderTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'نوع الطلب'**
  String get orderTypeLabel;

  /// No description provided for @orderTypeHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الطلب'**
  String get orderTypeHint;

  /// No description provided for @orderDetailsLabel.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get orderDetailsLabel;

  /// No description provided for @orderDetailsHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب ما تحتاجه بالتفصيل...'**
  String get orderDetailsHint;

  /// No description provided for @orderDetailsRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى كتابة تفاصيل الطلب'**
  String get orderDetailsRequired;

  /// No description provided for @orderDeleteDurationLabel.
  ///
  /// In ar, this message translates to:
  /// **'مدة بقاء الطلب للكباتن'**
  String get orderDeleteDurationLabel;

  /// No description provided for @orderDeleteDurationHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر المدة'**
  String get orderDeleteDurationHint;

  /// No description provided for @deliveryFeeLabel.
  ///
  /// In ar, this message translates to:
  /// **'أجور التوصيل'**
  String get deliveryFeeLabel;

  /// No description provided for @deliveryFeeHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر أجور التوصيل'**
  String get deliveryFeeHint;

  /// No description provided for @couponLabel.
  ///
  /// In ar, this message translates to:
  /// **'كوبون الخصم'**
  String get couponLabel;

  /// No description provided for @couponHint.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get couponHint;

  /// No description provided for @verifyCouponAction.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get verifyCouponAction;

  /// No description provided for @couponInvalid.
  ///
  /// In ar, this message translates to:
  /// **'كوبون غير صالح'**
  String get couponInvalid;

  /// No description provided for @couponValid.
  ///
  /// In ar, this message translates to:
  /// **'تم تطبيق خصم {amount} د.ع'**
  String couponValid(String amount);

  /// No description provided for @selectDeliveryFeeFirst.
  ///
  /// In ar, this message translates to:
  /// **'اختر أجور التوصيل أولاً'**
  String get selectDeliveryFeeFirst;

  /// No description provided for @destinationLabel.
  ///
  /// In ar, this message translates to:
  /// **'موقع التوصيل'**
  String get destinationLabel;

  /// No description provided for @destinationRequired.
  ///
  /// In ar, this message translates to:
  /// **'موقع التوصيل مطلوب'**
  String get destinationRequired;

  /// No description provided for @destinationAddressLabel.
  ///
  /// In ar, this message translates to:
  /// **'وصف العنوان (اختياري)'**
  String get destinationAddressLabel;

  /// No description provided for @destinationAddressHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: حي الجامعة، قرب مدرسة...'**
  String get destinationAddressHint;

  /// No description provided for @currentLocation.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الموقع'**
  String get currentLocation;

  /// No description provided for @updateLocationAction.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الموقع'**
  String get updateLocationAction;

  /// No description provided for @locationConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديد موقع التوصيل'**
  String get locationConfirmed;

  /// No description provided for @pickFromMap.
  ///
  /// In ar, this message translates to:
  /// **'اختيار من الخريطة'**
  String get pickFromMap;

  /// No description provided for @confirmLocation.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الموقع'**
  String get confirmLocation;

  /// No description provided for @mapPinReady.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديد النقطة'**
  String get mapPinReady;

  /// No description provided for @mapPinHint.
  ///
  /// In ar, this message translates to:
  /// **'أكد الموقع لإضافته إلى الطلب'**
  String get mapPinHint;

  /// No description provided for @locationDisabled.
  ///
  /// In ar, this message translates to:
  /// **'فعّل خدمة الموقع من إعدادات الجهاز'**
  String get locationDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'يلزم السماح بالوصول إلى الموقع'**
  String get locationPermissionDenied;

  /// No description provided for @locationFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحديد الموقع'**
  String get locationFailed;

  /// No description provided for @mapSelectedAddress.
  ///
  /// In ar, this message translates to:
  /// **'موقع محدد من الخريطة'**
  String get mapSelectedAddress;

  /// No description provided for @valueNotAvailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متوفر'**
  String get valueNotAvailable;

  /// No description provided for @fillAllRequiredFields.
  ///
  /// In ar, this message translates to:
  /// **'أكمل جميع الحقول المطلوبة'**
  String get fillAllRequiredFields;

  /// No description provided for @submitOrderAction.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get submitOrderAction;

  /// No description provided for @orderCreatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلبك بنجاح'**
  String get orderCreatedSuccess;

  /// No description provided for @orderCreatedWaitingCaptain.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار قبول أحد الكباتن'**
  String get orderCreatedWaitingCaptain;

  /// No description provided for @orderSubmitFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر إرسال الطلب. حاول مرة أخرى.'**
  String get orderSubmitFailed;

  /// No description provided for @orderDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get orderDetailTitle;

  /// No description provided for @orderCreatedAtLabel.
  ///
  /// In ar, this message translates to:
  /// **'وقت الإنشاء'**
  String get orderCreatedAtLabel;

  /// No description provided for @orderWaitingCaptainHint.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار قبول أحد الكباتن'**
  String get orderWaitingCaptainHint;

  /// No description provided for @orderCaptainSectionTitle.
  ///
  /// In ar, this message translates to:
  /// **'الكابتن'**
  String get orderCaptainSectionTitle;

  /// No description provided for @orderCaptainPhoneUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'رقم الكابتن غير متوفر'**
  String get orderCaptainPhoneUnavailable;

  /// No description provided for @orderContactCaptainTitle.
  ///
  /// In ar, this message translates to:
  /// **'التواصل مع الكابتن'**
  String get orderContactCaptainTitle;

  /// No description provided for @cancelOrderAction.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cancelOrderAction;

  /// No description provided for @cancelOrderTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cancelOrderTitle;

  /// No description provided for @cancelOrderConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إلغاء الطلب؟'**
  String get cancelOrderConfirmBody;

  /// No description provided for @cancelOrderBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get cancelOrderBack;

  /// No description provided for @cancelOrderConfirmAction.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الإلغاء'**
  String get cancelOrderConfirmAction;

  /// No description provided for @orderCancelledSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الطلب'**
  String get orderCancelledSuccess;

  /// No description provided for @ordersOngoingSection.
  ///
  /// In ar, this message translates to:
  /// **'تحت التنفيذ'**
  String get ordersOngoingSection;

  /// No description provided for @ordersPastSection.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات المكتملة'**
  String get ordersPastSection;

  /// No description provided for @ordersTabUnderExecution.
  ///
  /// In ar, this message translates to:
  /// **'تحت التنفيذ'**
  String get ordersTabUnderExecution;

  /// No description provided for @ordersTabCompleted.
  ///
  /// In ar, this message translates to:
  /// **'المكتملة'**
  String get ordersTabCompleted;

  /// No description provided for @ordersTabPrevious.
  ///
  /// In ar, this message translates to:
  /// **'السابقة'**
  String get ordersTabPrevious;

  /// No description provided for @ordersEmptyUnderExecution.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات تحت التنفيذ حالياً'**
  String get ordersEmptyUnderExecution;

  /// No description provided for @ordersEmptyCompleted.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات مكتملة حتى الآن'**
  String get ordersEmptyCompleted;

  /// No description provided for @ordersEmptyPrevious.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات سابقة'**
  String get ordersEmptyPrevious;

  /// No description provided for @orderExpiredHint.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة هذا الطلب قبل أن يقبله أحد الكباتن.'**
  String get orderExpiredHint;

  /// No description provided for @orderExpiresAtLabel.
  ///
  /// In ar, this message translates to:
  /// **'وقت انتهاء الطلب'**
  String get orderExpiresAtLabel;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلبات'**
  String get navOrders;

  /// No description provided for @navAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get navAccount;

  /// No description provided for @ordersTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلباتي'**
  String get ordersTitle;

  /// No description provided for @ordersSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'آخر الطلبات التي أنشأتها'**
  String get ordersSubtitle;

  /// No description provided for @orderNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الطلب'**
  String get orderNumberLabel;

  /// No description provided for @orderNumberCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ رقم الطلب'**
  String get orderNumberCopied;

  /// No description provided for @copyOrderNumberAction.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get copyOrderNumberAction;

  /// No description provided for @ordersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بعد'**
  String get ordersEmpty;

  /// No description provided for @ordersEmptyNow.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات حالياً'**
  String get ordersEmptyNow;

  /// No description provided for @ordersEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ طلب توصيل من الصفحة الرئيسية'**
  String get ordersEmptyHint;

  /// No description provided for @ordersLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل الطلبات'**
  String get ordersLoadError;

  /// No description provided for @orderStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار كابتن'**
  String get orderStatusPending;

  /// No description provided for @orderStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'جاري التوصيل'**
  String get orderStatusActive;

  /// No description provided for @captainOrderStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get captainOrderStatusActive;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get orderStatusCompleted;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغي'**
  String get orderStatusCancelled;

  /// No description provided for @orderStatusExpired.
  ///
  /// In ar, this message translates to:
  /// **'منتهي'**
  String get orderStatusExpired;

  /// No description provided for @orderStatusUnknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get orderStatusUnknown;

  /// No description provided for @accountTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get accountTitle;

  /// No description provided for @accountSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'معلوماتك وإعدادات الحساب'**
  String get accountSubtitle;

  /// No description provided for @accountSectionSettings.
  ///
  /// In ar, this message translates to:
  /// **'⚙️ الحساب والإعدادات'**
  String get accountSectionSettings;

  /// No description provided for @themeSettingLabel.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get themeSettingLabel;

  /// No description provided for @themeModeDark.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get themeModeDark;

  /// No description provided for @themeModeLight.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الفاتح'**
  String get themeModeLight;

  /// No description provided for @accountSectionPrivacySecurity.
  ///
  /// In ar, this message translates to:
  /// **'🔐 الخصوصية والأمان'**
  String get accountSectionPrivacySecurity;

  /// No description provided for @accountSectionAppInfo.
  ///
  /// In ar, this message translates to:
  /// **'ℹ️ معلومات التطبيق'**
  String get accountSectionAppInfo;

  /// No description provided for @accountSectionTechnicalSupport.
  ///
  /// In ar, this message translates to:
  /// **'💬 الدعم الفني'**
  String get accountSectionTechnicalSupport;

  /// No description provided for @accountSupportAdminPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'سيتم ربط قنوات الدعم من لوحة الإدارة قريباً.'**
  String get accountSupportAdminPlaceholder;

  /// No description provided for @supportScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدعم الفني'**
  String get supportScreenTitle;

  /// No description provided for @supportContactUs.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا'**
  String get supportContactUs;

  /// No description provided for @supportDefaultMessage.
  ///
  /// In ar, this message translates to:
  /// **'فريق حاضر جاهز لمساعدتك. اختر وسيلة التواصل المناسبة.'**
  String get supportDefaultMessage;

  /// No description provided for @supportChannelWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get supportChannelWhatsapp;

  /// No description provided for @supportChannelPhone.
  ///
  /// In ar, this message translates to:
  /// **'اتصال هاتفي'**
  String get supportChannelPhone;

  /// No description provided for @supportChannelEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get supportChannelEmail;

  /// No description provided for @supportNoChannels.
  ///
  /// In ar, this message translates to:
  /// **'قنوات الدعم غير متاحة حالياً.'**
  String get supportNoChannels;

  /// No description provided for @supportLaunchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح التطبيق المطلوب'**
  String get supportLaunchFailed;

  /// No description provided for @supportFaqsTitle.
  ///
  /// In ar, this message translates to:
  /// **'❓ الأسئلة الشائعة'**
  String get supportFaqsTitle;

  /// No description provided for @supportFormsTitle.
  ///
  /// In ar, this message translates to:
  /// **'📋 أنواع طلبات الدعم'**
  String get supportFormsTitle;

  /// No description provided for @supportMyRequestsTitle.
  ///
  /// In ar, this message translates to:
  /// **'📨 طلباتي للدعم'**
  String get supportMyRequestsTitle;

  /// No description provided for @supportNoFaqs.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أسئلة شائعة حالياً.'**
  String get supportNoFaqs;

  /// No description provided for @supportNoForms.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أنواع طلبات دعم متاحة حالياً.'**
  String get supportNoForms;

  /// No description provided for @supportNoRequests.
  ///
  /// In ar, this message translates to:
  /// **'لم ترسل أي طلب دعم بعد.'**
  String get supportNoRequests;

  /// No description provided for @supportRequestDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل طلب الدعم'**
  String get supportRequestDetailTitle;

  /// No description provided for @supportRequestNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الطلب'**
  String get supportRequestNumberLabel;

  /// No description provided for @supportRequestTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'نوع الطلب'**
  String get supportRequestTypeLabel;

  /// No description provided for @supportRequestSubmittedAtLabel.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإرسال'**
  String get supportRequestSubmittedAtLabel;

  /// No description provided for @supportYourAnswersTitle.
  ///
  /// In ar, this message translates to:
  /// **'إجاباتك'**
  String get supportYourAnswersTitle;

  /// No description provided for @supportAdminReplyTitle.
  ///
  /// In ar, this message translates to:
  /// **'💬 رد فريق حاضر'**
  String get supportAdminReplyTitle;

  /// No description provided for @supportNoAdminReplyYet.
  ///
  /// In ar, this message translates to:
  /// **'لم يرد فريق حاضر بعد. سنبلغك عند توفر رد.'**
  String get supportNoAdminReplyYet;

  /// No description provided for @supportSubmitForm.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get supportSubmitForm;

  /// No description provided for @supportFormSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب الدعم بنجاح'**
  String get supportFormSubmitted;

  /// No description provided for @supportSubmitFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال طلب الدعم'**
  String get supportSubmitFailed;

  /// No description provided for @supportSelectPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'اختر'**
  String get supportSelectPlaceholder;

  /// No description provided for @supportRequiredField.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get supportRequiredField;

  /// No description provided for @supportStatusNew.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get supportStatusNew;

  /// No description provided for @supportStatusInProgress.
  ///
  /// In ar, this message translates to:
  /// **'قيد المتابعة'**
  String get supportStatusInProgress;

  /// No description provided for @supportStatusResolved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحل'**
  String get supportStatusResolved;

  /// No description provided for @supportStatusClosed.
  ///
  /// In ar, this message translates to:
  /// **'مغلق'**
  String get supportStatusClosed;

  /// No description provided for @accountSectionLegal.
  ///
  /// In ar, this message translates to:
  /// **'📄 معلومات وسياسات التطبيق'**
  String get accountSectionLegal;

  /// No description provided for @accountSectionManagement.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ إدارة الحساب'**
  String get accountSectionManagement;

  /// No description provided for @accountAppVersion.
  ///
  /// In ar, this message translates to:
  /// **'إصدار التطبيق'**
  String get accountAppVersion;

  /// No description provided for @accountEditProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get accountEditProfile;

  /// No description provided for @accountNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get accountNotifications;

  /// No description provided for @accountChangePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرمز السري'**
  String get accountChangePassword;

  /// No description provided for @accountPrivacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get accountPrivacyPolicy;

  /// No description provided for @accountTerms.
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام'**
  String get accountTerms;

  /// No description provided for @accountAbout.
  ///
  /// In ar, this message translates to:
  /// **'حول تطبيق حاضر'**
  String get accountAbout;

  /// No description provided for @accountSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم والتواصل'**
  String get accountSupport;

  /// No description provided for @accountDeleteAccount.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get accountDeleteAccount;

  /// No description provided for @accountDeleteAccountUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب غير متاح حالياً. هذه الميزة غير متاحة حالياً.'**
  String get accountDeleteAccountUnavailable;

  /// No description provided for @accountDeleteIntroBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم حذف حسابك وبياناتك الشخصية نهائياً، ولن تتمكن من استعادتها بعد إكمال عملية الحذف.'**
  String get accountDeleteIntroBody;

  /// No description provided for @accountDeleteIrreversibleWarning.
  ///
  /// In ar, this message translates to:
  /// **'هذا الإجراء لا يمكن التراجع عنه.'**
  String get accountDeleteIrreversibleWarning;

  /// No description provided for @accountDeleteContinueAction.
  ///
  /// In ar, this message translates to:
  /// **'متابعة حذف الحساب'**
  String get accountDeleteContinueAction;

  /// No description provided for @accountDeleteConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد حذف الحساب'**
  String get accountDeleteConfirmTitle;

  /// No description provided for @accountDeleteConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف حسابك نهائياً؟'**
  String get accountDeleteConfirmBody;

  /// No description provided for @accountDeleteFinalAction.
  ///
  /// In ar, this message translates to:
  /// **'حذف حسابي نهائياً'**
  String get accountDeleteFinalAction;

  /// No description provided for @accountDeleteBackAction.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get accountDeleteBackAction;

  /// No description provided for @accountDeletePasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز السري للتأكيد'**
  String get accountDeletePasswordLabel;

  /// No description provided for @accountDeletePasswordRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز السري لتأكيد الحذف'**
  String get accountDeletePasswordRequired;

  /// No description provided for @accountDeleteSubscriptionWarning.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه: حذف الحساب ينهي وصولك إلى الاشتراك الحالي ولن يتم استرداد أي مبالغ تلقائياً.'**
  String get accountDeleteSubscriptionWarning;

  /// No description provided for @accountDeleteSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف حسابك'**
  String get accountDeleteSuccessTitle;

  /// No description provided for @accountDeleteSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف حسابك بنجاح.'**
  String get accountDeleteSuccessBody;

  /// No description provided for @accountDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر حذف الحساب حالياً. يرجى المحاولة مرة أخرى.'**
  String get accountDeleteFailed;

  /// No description provided for @accountDeleteActiveUserOrder.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن حذف الحساب أثناء وجود طلب نشط. أكمل أو ألغِ طلبك الحالي أولاً.'**
  String get accountDeleteActiveUserOrder;

  /// No description provided for @accountDeleteActiveCaptainOrder.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن حذف حساب الكابتن أثناء وجود طلبات نشطة. أكمل الطلبات الحالية أولاً.'**
  String get accountDeleteActiveCaptainOrder;

  /// No description provided for @featureComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'هذه الميزة قيد التجهيز'**
  String get featureComingSoon;

  /// No description provided for @subscriptionStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'فعال'**
  String get subscriptionStatusActive;

  /// No description provided for @subscriptionStatusExpired.
  ///
  /// In ar, this message translates to:
  /// **'منتهي'**
  String get subscriptionStatusExpired;

  /// No description provided for @subscriptionTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'نوع الاشتراك'**
  String get subscriptionTypeLabel;

  /// No description provided for @subscriptionStatusLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get subscriptionStatusLabel;

  /// No description provided for @subscriptionRemainingLabel.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get subscriptionRemainingLabel;

  /// No description provided for @subscriptionRemainingDaysValue.
  ///
  /// In ar, this message translates to:
  /// **'{days} يوم'**
  String subscriptionRemainingDaysValue(String days);

  /// No description provided for @subscriptionExpiryDateLabel.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get subscriptionExpiryDateLabel;

  /// No description provided for @subscriptionTrialLabel.
  ///
  /// In ar, this message translates to:
  /// **'تجربة مجانية'**
  String get subscriptionTrialLabel;

  /// No description provided for @subscriptionPaidLabel.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك مدفوع'**
  String get subscriptionPaidLabel;

  /// No description provided for @subscriptionEndsLabel.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي: {date}'**
  String subscriptionEndsLabel(String date);

  /// No description provided for @aboutVersionLabel.
  ///
  /// In ar, this message translates to:
  /// **'إصدار التطبيق'**
  String get aboutVersionLabel;

  /// No description provided for @supportPlaceholderTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدعم والتواصل'**
  String get supportPlaceholderTitle;

  /// No description provided for @supportPlaceholderBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إضافة قنوات الدعم الرسمية هنا قريباً.'**
  String get supportPlaceholderBody;

  /// No description provided for @accountTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'نوع الحساب'**
  String get accountTypeLabel;

  /// No description provided for @accountStatusLabel.
  ///
  /// In ar, this message translates to:
  /// **'حالة الحساب'**
  String get accountStatusLabel;

  /// No description provided for @phoneVerifiedLabel.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الهاتف'**
  String get phoneVerifiedLabel;

  /// No description provided for @accountTypeUser.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم'**
  String get accountTypeUser;

  /// No description provided for @accountTypeCaptain.
  ///
  /// In ar, this message translates to:
  /// **'كابتن'**
  String get accountTypeCaptain;

  /// No description provided for @accountStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get accountStatusActive;

  /// No description provided for @accountStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get accountStatusPending;

  /// No description provided for @accountStatusSuspended.
  ///
  /// In ar, this message translates to:
  /// **'موقوف'**
  String get accountStatusSuspended;

  /// No description provided for @accountStatusDisabled.
  ///
  /// In ar, this message translates to:
  /// **'معطّل'**
  String get accountStatusDisabled;

  /// No description provided for @yesLabel.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get yesLabel;

  /// No description provided for @noLabel.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get noLabel;

  /// No description provided for @convertToCaptainAction.
  ///
  /// In ar, this message translates to:
  /// **'تحويل حسابي إلى كابتن'**
  String get convertToCaptainAction;

  /// No description provided for @convertToCaptainTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحويل إلى كابتن'**
  String get convertToCaptainTitle;

  /// No description provided for @convertToCaptainConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تحويل حسابك إلى كابتن؟ سيتم مراجعة الطلب من الإدارة.'**
  String get convertToCaptainConfirm;

  /// No description provided for @convertToCaptainHint.
  ///
  /// In ar, this message translates to:
  /// **'بعد التحويل يمكنك العمل ككابتن بعد موافقة الإدارة'**
  String get convertToCaptainHint;

  /// No description provided for @convertToCaptainSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب التحويل إلى كابتن'**
  String get convertToCaptainSuccess;

  /// No description provided for @captainPendingMessage.
  ///
  /// In ar, this message translates to:
  /// **'حسابك كابتن قيد المراجعة من الإدارة'**
  String get captainPendingMessage;

  /// No description provided for @captainPendingScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة'**
  String get captainPendingScreenTitle;

  /// No description provided for @captainPendingScreenMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم استلام طلب انضمامك ككابتن بنجاح. سيتم مراجعة طلبك من قبل إدارة حاضر، وسيتم تفعيل حسابك بعد الموافقة.'**
  String get captainPendingScreenMessage;

  /// No description provided for @captainPendingScreenHint.
  ///
  /// In ar, this message translates to:
  /// **'لا تحتاج إلى إرسال الطلب مرة أخرى.'**
  String get captainPendingScreenHint;

  /// No description provided for @captainPendingRefreshStatus.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الحالة'**
  String get captainPendingRefreshStatus;

  /// No description provided for @captainRejectionMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض طلب التحويل إلى كابتن.'**
  String get captainRejectionMessage;

  /// No description provided for @captainRejectionRefreshFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحديث حالة الحساب. تحقق من الاتصال وحاول مرة أخرى.'**
  String get captainRejectionRefreshFailed;

  /// No description provided for @captainNavHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get captainNavHome;

  /// No description provided for @captainNavOrders.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get captainNavOrders;

  /// No description provided for @captainNavAccount.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get captainNavAccount;

  /// No description provided for @captainHomeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لوحة الكابتن'**
  String get captainHomeSubtitle;

  /// No description provided for @captainHomeActiveStatus.
  ///
  /// In ar, this message translates to:
  /// **'حسابك فعّال'**
  String get captainHomeActiveStatus;

  /// No description provided for @captainAvailableOrdersTitle.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات المتاحة'**
  String get captainAvailableOrdersTitle;

  /// No description provided for @captainAvailableOrdersSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبات بانتظار كابتن'**
  String get captainAvailableOrdersSubtitle;

  /// No description provided for @captainAvailableOrdersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات متاحة حالياً'**
  String get captainAvailableOrdersEmpty;

  /// No description provided for @captainAvailableOrdersEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر الطلبات الجديدة هنا عند توفرها.'**
  String get captainAvailableOrdersEmptyHint;

  /// No description provided for @captainAvailableOrdersLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل الطلبات المتاحة. حاول مرة أخرى.'**
  String get captainAvailableOrdersLoadError;

  /// No description provided for @captainActiveOrdersAtCapacityTitle.
  ///
  /// In ar, this message translates to:
  /// **'أكمل طلباتك الحالية'**
  String get captainActiveOrdersAtCapacityTitle;

  /// No description provided for @captainActiveOrdersAtCapacityHint.
  ///
  /// In ar, this message translates to:
  /// **'أكمل أحد طلباتك الحالية حتى تتمكن من استلام طلب جديد.'**
  String get captainActiveOrdersAtCapacityHint;

  /// No description provided for @captainMyOrdersSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات التي قبلتها ككابتن'**
  String get captainMyOrdersSubtitle;

  /// No description provided for @captainMyOrdersEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا الطلبات التي تقبلها.'**
  String get captainMyOrdersEmptyHint;

  /// No description provided for @captainViewOrderDetails.
  ///
  /// In ar, this message translates to:
  /// **'عرض التفاصيل'**
  String get captainViewOrderDetails;

  /// No description provided for @captainOrderFeeLabel.
  ///
  /// In ar, this message translates to:
  /// **'أجرة التوصيل: {amount} د.ع'**
  String captainOrderFeeLabel(String amount);

  /// No description provided for @captainOrderExpiresAt.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي الساعة {time}'**
  String captainOrderExpiresAt(String time);

  /// No description provided for @captainAcceptanceNotReady.
  ///
  /// In ar, this message translates to:
  /// **'نظام قبول الطلبات قيد التجهيز — سيتوفر قريباً'**
  String get captainAcceptanceNotReady;

  /// No description provided for @captainAcceptOrderAction.
  ///
  /// In ar, this message translates to:
  /// **'قبول الطلب'**
  String get captainAcceptOrderAction;

  /// No description provided for @captainAcceptOrderConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبول الطلب'**
  String get captainAcceptOrderConfirmTitle;

  /// No description provided for @captainAcceptOrderConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد قبول هذا الطلب؟'**
  String get captainAcceptOrderConfirmBody;

  /// No description provided for @captainAcceptOrderSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم قبول الطلب بنجاح'**
  String get captainAcceptOrderSuccess;

  /// No description provided for @captainOrderAvailableBadge.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get captainOrderAvailableBadge;

  /// No description provided for @captainOrderAcceptedAtLabel.
  ///
  /// In ar, this message translates to:
  /// **'وقت القبول'**
  String get captainOrderAcceptedAtLabel;

  /// No description provided for @captainCompleteOrderAction.
  ///
  /// In ar, this message translates to:
  /// **'تم تسليم الطلب'**
  String get captainCompleteOrderAction;

  /// No description provided for @captainCompleteOrderConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد تسليم الطلب'**
  String get captainCompleteOrderConfirmTitle;

  /// No description provided for @captainCompleteOrderConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل تم تسليم الطلب للعميل؟'**
  String get captainCompleteOrderConfirmBody;

  /// No description provided for @captainCompleteOrderConfirmAction.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد التسليم'**
  String get captainCompleteOrderConfirmAction;

  /// No description provided for @captainCompleteOrderSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إكمال الطلب بنجاح'**
  String get captainCompleteOrderSuccess;

  /// No description provided for @captainOrderCompletedBadge.
  ///
  /// In ar, this message translates to:
  /// **'تم تسليم الطلب'**
  String get captainOrderCompletedBadge;

  /// No description provided for @captainOrderCompletedAtLabel.
  ///
  /// In ar, this message translates to:
  /// **'وقت التسليم'**
  String get captainOrderCompletedAtLabel;

  /// No description provided for @orderDeliveredAtLabel.
  ///
  /// In ar, this message translates to:
  /// **'وقت التسليم'**
  String get orderDeliveredAtLabel;

  /// No description provided for @captainSubscriptionRequiredAccept.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكك غير فعال. فعّل الاشتراك لتتمكن من قبول الطلبات.'**
  String get captainSubscriptionRequiredAccept;

  /// No description provided for @captainActiveOrdersSection.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات الجارية'**
  String get captainActiveOrdersSection;

  /// No description provided for @captainPastOrdersSection.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات السابقة'**
  String get captainPastOrdersSection;

  /// No description provided for @captainOrdersTabUnderExecution.
  ///
  /// In ar, this message translates to:
  /// **'تحت التنفيذ'**
  String get captainOrdersTabUnderExecution;

  /// No description provided for @captainOrdersTabCompleted.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات المكتملة'**
  String get captainOrdersTabCompleted;

  /// No description provided for @captainOrdersEmptyUnderExecution.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات تحت التنفيذ'**
  String get captainOrdersEmptyUnderExecution;

  /// No description provided for @captainOrdersEmptyCompletedTab.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات مكتملة'**
  String get captainOrdersEmptyCompletedTab;

  /// No description provided for @captainOrderTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'نوع الطلب'**
  String get captainOrderTypeLabel;

  /// No description provided for @captainOrderDetailsLabel.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get captainOrderDetailsLabel;

  /// No description provided for @captainOrderDestinationLabel.
  ///
  /// In ar, this message translates to:
  /// **'وجهة التوصيل'**
  String get captainOrderDestinationLabel;

  /// No description provided for @captainOrderCreatedLabel.
  ///
  /// In ar, this message translates to:
  /// **'وقت الإنشاء'**
  String get captainOrderCreatedLabel;

  /// No description provided for @captainOrderRemainingTimeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتبقي'**
  String get captainOrderRemainingTimeLabel;

  /// No description provided for @captainOrderExpiredLabel.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة الطلب'**
  String get captainOrderExpiredLabel;

  /// No description provided for @captainOrderGpsLabel.
  ///
  /// In ar, this message translates to:
  /// **'إحداثيات الموقع'**
  String get captainOrderGpsLabel;

  /// No description provided for @captainCustomerInfoTitle.
  ///
  /// In ar, this message translates to:
  /// **'معلومات العميل'**
  String get captainCustomerInfoTitle;

  /// No description provided for @captainCustomerNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get captainCustomerNameLabel;

  /// No description provided for @captainCustomerPhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get captainCustomerPhoneLabel;

  /// No description provided for @captainCustomerLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'وصف الموقع'**
  String get captainCustomerLocationLabel;

  /// No description provided for @captainCustomerLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'موقع العميل'**
  String get captainCustomerLocationTitle;

  /// No description provided for @captainCallAction.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get captainCallAction;

  /// No description provided for @captainCallCustomerAction.
  ///
  /// In ar, this message translates to:
  /// **'اتصال بالعميل'**
  String get captainCallCustomerAction;

  /// No description provided for @captainOpenLocationAction.
  ///
  /// In ar, this message translates to:
  /// **'فتح الموقع'**
  String get captainOpenLocationAction;

  /// No description provided for @captainCallLaunchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح تطبيق الاتصال'**
  String get captainCallLaunchFailed;

  /// No description provided for @captainWhatsAppAction.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get captainWhatsAppAction;

  /// No description provided for @captainWhatsAppLaunchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح واتساب'**
  String get captainWhatsAppLaunchFailed;

  /// No description provided for @captainWazeAction.
  ///
  /// In ar, this message translates to:
  /// **'Waze'**
  String get captainWazeAction;

  /// No description provided for @captainWazeLaunchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح Waze'**
  String get captainWazeLaunchFailed;

  /// No description provided for @captainGoogleMapsAction.
  ///
  /// In ar, this message translates to:
  /// **'خرائط Google'**
  String get captainGoogleMapsAction;

  /// No description provided for @captainGoogleMapsLaunchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح خرائط Google'**
  String get captainGoogleMapsLaunchFailed;

  /// No description provided for @captainMapsLaunchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح تطبيق الخرائط'**
  String get captainMapsLaunchFailed;

  /// No description provided for @captainDeliveryFeeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أجرة التوصيل'**
  String get captainDeliveryFeeTitle;

  /// No description provided for @captainDeliveryFeeAmount.
  ///
  /// In ar, this message translates to:
  /// **'{amount} د.ع'**
  String captainDeliveryFeeAmount(String amount);

  /// No description provided for @captainCouponDiscountLabel.
  ///
  /// In ar, this message translates to:
  /// **'الخصم'**
  String get captainCouponDiscountLabel;

  /// No description provided for @captainOrderActionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات الطلب'**
  String get captainOrderActionsTitle;

  /// No description provided for @captainCustomerNoAnswerAction.
  ///
  /// In ar, this message translates to:
  /// **'العميل لا يرد'**
  String get captainCustomerNoAnswerAction;

  /// No description provided for @captainCustomerNoAnswerTitle.
  ///
  /// In ar, this message translates to:
  /// **'العميل لا يرد'**
  String get captainCustomerNoAnswerTitle;

  /// No description provided for @captainCustomerNoAnswerBody.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل أن العميل لم يرد على الاتصال؟'**
  String get captainCustomerNoAnswerBody;

  /// No description provided for @captainCustomerNoAnswerConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get captainCustomerNoAnswerConfirm;

  /// No description provided for @captainCustomerNoAnswerSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل أن العميل لا يرد'**
  String get captainCustomerNoAnswerSuccess;

  /// No description provided for @captainTransferOrderAction.
  ///
  /// In ar, this message translates to:
  /// **'تحويل الطلب إلى كابتن آخر'**
  String get captainTransferOrderAction;

  /// No description provided for @captainTransferOrderTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحويل الطلب'**
  String get captainTransferOrderTitle;

  /// No description provided for @captainTransferOrderBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إرجاع الطلب إلى قائمة الطلبات المتاحة ليتمكن كابتن آخر من قبوله. هل تريد المتابعة؟'**
  String get captainTransferOrderBody;

  /// No description provided for @captainTransferOrderConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد التحويل'**
  String get captainTransferOrderConfirm;

  /// No description provided for @captainTransferReasonTitle.
  ///
  /// In ar, this message translates to:
  /// **'سبب التحويل'**
  String get captainTransferReasonTitle;

  /// No description provided for @captainTransferReasonCannotComplete.
  ///
  /// In ar, this message translates to:
  /// **'تعذر إكمال الطلب'**
  String get captainTransferReasonCannotComplete;

  /// No description provided for @captainTransferReasonVehicle.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة في المركبة'**
  String get captainTransferReasonVehicle;

  /// No description provided for @captainTransferReasonFar.
  ///
  /// In ar, this message translates to:
  /// **'بعيد عن موقع العميل'**
  String get captainTransferReasonFar;

  /// No description provided for @captainTransferReasonOther.
  ///
  /// In ar, this message translates to:
  /// **'سبب آخر'**
  String get captainTransferReasonOther;

  /// No description provided for @captainTransferReasonOtherHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب السبب'**
  String get captainTransferReasonOtherHint;

  /// No description provided for @captainTransferSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحويل الطلب إلى قائمة المتاح'**
  String get captainTransferSuccess;

  /// No description provided for @captainOrdersSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبات التوصيل المخصصة لك'**
  String get captainOrdersSubtitle;

  /// No description provided for @captainOrdersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات حالياً'**
  String get captainOrdersEmpty;

  /// No description provided for @captainOrdersFeedPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'طلبات التوصيل المتاحة ستظهر هنا'**
  String get captainOrdersFeedPlaceholder;

  /// No description provided for @captainAccountSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'معلومات حساب الكابتن'**
  String get captainAccountSubtitle;

  /// No description provided for @captainSuspendedTitle.
  ///
  /// In ar, this message translates to:
  /// **'حساب الكابتن موقوف'**
  String get captainSuspendedTitle;

  /// No description provided for @captainSuspendedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف حسابك ككابتن مؤقتاً. تواصل مع إدارة حاضر إذا كنت تعتقد أن هذا خطأ.'**
  String get captainSuspendedMessage;

  /// No description provided for @captainDisabledTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل الحساب'**
  String get captainDisabledTitle;

  /// No description provided for @captainDisabledMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل حسابك ككابتن. تواصل مع إدارة حاضر للمزيد من المعلومات.'**
  String get captainDisabledMessage;

  /// No description provided for @accountBlockedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم حظر حسابك'**
  String get accountBlockedTitle;

  /// No description provided for @accountBlockedMessage.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك استخدام خدمات حاضر حالياً.\nيرجى التواصل مع إدارة حاضر للمزيد من المعلومات.'**
  String get accountBlockedMessage;

  /// No description provided for @accountBlockedContactAdmin.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الإدارة'**
  String get accountBlockedContactAdmin;

  /// No description provided for @alreadyCaptainMessage.
  ///
  /// In ar, this message translates to:
  /// **'حسابك مسجّل ككابتن'**
  String get alreadyCaptainMessage;

  /// No description provided for @captainSubscriptionTitle.
  ///
  /// In ar, this message translates to:
  /// **'💳 الاشتراك'**
  String get captainSubscriptionTitle;

  /// No description provided for @captainSubscriptionActiveTrial.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك تجريبي فعال'**
  String get captainSubscriptionActiveTrial;

  /// No description provided for @captainSubscriptionActivePaid.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك مدفوع فعال'**
  String get captainSubscriptionActivePaid;

  /// No description provided for @captainSubscriptionExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهى الاشتراك'**
  String get captainSubscriptionExpired;

  /// No description provided for @captainSubscriptionNone.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اشتراك فعال'**
  String get captainSubscriptionNone;

  /// No description provided for @captainSubscriptionRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي: {days} يوم'**
  String captainSubscriptionRemaining(String days);

  /// No description provided for @captainSubscriptionEndsAt.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي: {date}'**
  String captainSubscriptionEndsAt(String date);

  /// No description provided for @cancelAction.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancelAction;

  /// No description provided for @confirmAction.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirmAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

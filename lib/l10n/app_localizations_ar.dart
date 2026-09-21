// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'حاضر';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginSubtitle => 'أدخل رقم هاتفك والرمز السري للمتابعة';

  @override
  String get welcomeBack => 'مرحباً بك مجدداً';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get secretCode => 'الرمز السري';

  @override
  String get confirmSecretCode => 'تأكيد الرمز السري';

  @override
  String get forgotSecretCode => 'نسيت الرمز السري؟';

  @override
  String get loginAction => 'تسجيل الدخول';

  @override
  String get noAccount => 'ليس لديك حساب؟';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get createAccountAction => 'إنشاء الحساب';

  @override
  String get registerTitle => 'إنشاء حساب';

  @override
  String get registerSubtitle => 'أدخل معلوماتك لإنشاء حساب جديد';

  @override
  String get phoneHintLocal => '07XXXXXXXXX';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get otpTitle => 'رمز التحقق';

  @override
  String get otpSubtitle => 'أدخل الرمز المرسل إلى الرقم:';

  @override
  String get otpPasteHint => 'يمكنك لصق الرمز مباشرة';

  @override
  String get otpCode => 'رمز التحقق';

  @override
  String get verifyAction => 'تحقق';

  @override
  String get resendOtp => 'إعادة إرسال الرمز';

  @override
  String resendOtpAfter(int seconds) {
    return 'إعادة الإرسال بعد $seconds ثانية';
  }

  @override
  String get changePhoneNumber => 'تغيير رقم الهاتف';

  @override
  String get forgotPasswordTitle => 'نسيت الرمز السري';

  @override
  String get forgotPasswordSubtitle => 'أدخل رقم هاتفك لإرسال رمز التحقق';

  @override
  String get sendOtpAction => 'إرسال رمز التحقق';

  @override
  String get resetPasswordTitle => 'تعيين رمز سري جديد';

  @override
  String get resetPasswordSubtitle => 'أدخل الرمز السري الجديد ثم أكده';

  @override
  String get saveNewSecretCode => 'حفظ الرمز السري';

  @override
  String homeWelcome(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get loginSuccessMessage => 'تم تسجيل الدخول بنجاح';

  @override
  String get accountCreatedSuccess => 'تم إنشاء حسابك بنجاح';

  @override
  String get passwordResetSuccess => 'تم تعيين الرمز السري بنجاح';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get countryCode => '+964';

  @override
  String get errorFullNameRequired => 'الاسم الكامل مطلوب';

  @override
  String get errorFullNameTooShort => 'الاسم يجب أن لا يقل عن حرفين';

  @override
  String get errorFullNameDigitsOnly => 'الاسم لا يمكن أن يكون أرقاماً فقط';

  @override
  String get errorPhoneRequired => 'رقم الهاتف مطلوب';

  @override
  String get errorPhoneInvalid => 'رقم الهاتف غير صحيح';

  @override
  String get errorSecretCodeRequired => 'الرمز السري مطلوب';

  @override
  String get errorSecretCodeTooShort =>
      'الرمز السري يجب أن يتكون من 6 خانات على الأقل';

  @override
  String get errorSecretCodeMismatch => 'الرمزان السريان غير متطابقين';

  @override
  String get errorOtpIncomplete => 'أدخل رمز التحقق المكوّن من 6 خانات';

  @override
  String get errorInvalidCredentials => 'رقم الهاتف أو الرمز السري غير صحيح';

  @override
  String get errorInvalidPassword => 'الرمز السري غير صحيح';

  @override
  String get registerUnregisteredPhoneHint =>
      'هذا الرقم غير مسجل، أنشئ حسابك للمتابعة.';

  @override
  String get errorPhoneAlreadyExists =>
      'رقم الهاتف مسجل مسبقاً، يرجى تسجيل الدخول.';

  @override
  String get errorInvalidOtp => 'رمز التحقق غير صحيح';

  @override
  String get errorOtpExpired => 'انتهت صلاحية رمز التحقق، أعد إرسال رمز جديد';

  @override
  String get errorNetwork =>
      'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get errorTooManyRequests => 'طلبات كثيرة، حاول مرة أخرى لاحقاً';

  @override
  String get errorServer => 'حدث خطأ، حاول مرة أخرى.';

  @override
  String get errorPhoneNotFound => 'لا يوجد حساب مرتبط بهذا الرقم';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع';

  @override
  String get orderSettingsLoadFailed =>
      'تعذر تحميل إعدادات الطلب حالياً. حاول مرة أخرى.';

  @override
  String get devOtpHint => 'وضع التطوير المؤقت — رمز التحقق:';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب';

  @override
  String get okAction => 'حسناً';

  @override
  String get retryAction => 'إعادة المحاولة';

  @override
  String get legalContentLoadFailed =>
      'تعذر تحميل المحتوى حالياً. يرجى المحاولة مرة أخرى.';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsEmpty => 'لا توجد إشعارات حالياً';

  @override
  String get notificationsMarkAllRead => 'تعليم الكل كمقروء';

  @override
  String get notificationsLoadError => 'تعذر تحميل الإشعارات. حاول مرة أخرى.';

  @override
  String get notificationPermissionDenied =>
      'تم إيقاف إذن الإشعارات. يمكنك تفعيله من إعدادات الجهاز لاستلام تحديثات الطلبات.';

  @override
  String get openAppSettingsAction => 'الإعدادات';

  @override
  String get notificationExpiredDialogTitle => 'انتهت مدة الطلب';

  @override
  String get notificationExpiredDialogBody =>
      'انتهت مدة الطلب قبل أن يقبله أحد الكباتن.';

  @override
  String get notificationCreateNewOrder => 'إنشاء طلب جديد';

  @override
  String get notificationOrderReleased => 'هذا الطلب لم يعد مسنداً إليك.';

  @override
  String get captainOrderNoLongerAvailable => 'هذا الطلب لم يعد متاحاً.';

  @override
  String get adsSectionTitle => 'الإعلانات';

  @override
  String get adsPlaceholderTitle => 'لا توجد إعلانات حالياً';

  @override
  String get adsPlaceholderBody => 'ستظهر الإعلانات هنا عند توفرها.';

  @override
  String get servicesSectionTitle => 'الخدمات';

  @override
  String get servicesSectionSubtitle => 'اختر الخدمة المناسبة لك';

  @override
  String get deliveryServiceCta => 'اطلب مندوب';

  @override
  String get taxiComingSoonTitle => 'تكسي حاضر';

  @override
  String get taxiComingSoonBody => 'قريباً — خدمة التكسي قيد التجهيز';

  @override
  String get createDeliveryOrderTitle => 'طلب توصيل';

  @override
  String get createDeliveryOrderSubtitle =>
      'اكتب تفاصيل طلبك وحدد مكان التوصيل';

  @override
  String get deliveryOrderDisplayTitle => 'طلب توصيل';

  @override
  String get orderTypeLabel => 'نوع الطلب';

  @override
  String get orderTypeHint => 'اختر نوع الطلب';

  @override
  String get orderDetailsLabel => 'تفاصيل الطلب';

  @override
  String get orderDetailsHint => 'اكتب ما تحتاجه بالتفصيل...';

  @override
  String get orderDetailsRequired => 'يرجى كتابة تفاصيل الطلب';

  @override
  String get orderDeleteDurationLabel => 'مدة بقاء الطلب للكباتن';

  @override
  String get orderDeleteDurationHint => 'اختر المدة';

  @override
  String get deliveryFeeLabel => 'أجور التوصيل';

  @override
  String get deliveryFeeHint => 'اختر أجور التوصيل';

  @override
  String get couponLabel => 'كوبون الخصم';

  @override
  String get couponHint => 'اختياري';

  @override
  String get verifyCouponAction => 'تحقق';

  @override
  String get couponInvalid => 'كوبون غير صالح';

  @override
  String couponValid(String amount) {
    return 'تم تطبيق خصم $amount د.ع';
  }

  @override
  String get selectDeliveryFeeFirst => 'اختر أجور التوصيل أولاً';

  @override
  String get destinationLabel => 'موقع التوصيل';

  @override
  String get destinationRequired => 'موقع التوصيل مطلوب';

  @override
  String get destinationAddressLabel => 'وصف العنوان (اختياري)';

  @override
  String get destinationAddressHint => 'مثال: حي الجامعة، قرب مدرسة...';

  @override
  String get currentLocation => 'تحديد الموقع';

  @override
  String get updateLocationAction => 'تحديث الموقع';

  @override
  String get locationConfirmed => 'تم تحديد موقع التوصيل';

  @override
  String get pickFromMap => 'اختيار من الخريطة';

  @override
  String get confirmLocation => 'تأكيد الموقع';

  @override
  String get mapPinReady => 'تم تحديد النقطة';

  @override
  String get mapPinHint => 'أكد الموقع لإضافته إلى الطلب';

  @override
  String get locationDisabled => 'فعّل خدمة الموقع من إعدادات الجهاز';

  @override
  String get locationPermissionDenied => 'يلزم السماح بالوصول إلى الموقع';

  @override
  String get locationFailed => 'تعذر تحديد الموقع';

  @override
  String get mapSelectedAddress => 'موقع محدد من الخريطة';

  @override
  String get valueNotAvailable => 'غير متوفر';

  @override
  String get fillAllRequiredFields => 'أكمل جميع الحقول المطلوبة';

  @override
  String get submitOrderAction => 'إرسال الطلب';

  @override
  String get orderCreatedSuccess => 'تم إرسال طلبك بنجاح';

  @override
  String get orderCreatedWaitingCaptain => 'بانتظار قبول أحد الكباتن';

  @override
  String get orderSubmitFailed => 'تعذر إرسال الطلب. حاول مرة أخرى.';

  @override
  String get orderDetailTitle => 'تفاصيل الطلب';

  @override
  String get orderCreatedAtLabel => 'وقت الإنشاء';

  @override
  String get orderWaitingCaptainHint => 'بانتظار قبول أحد الكباتن';

  @override
  String get orderCaptainSectionTitle => 'الكابتن';

  @override
  String get orderCaptainPhoneUnavailable => 'رقم الكابتن غير متوفر';

  @override
  String get orderContactCaptainTitle => 'التواصل مع الكابتن';

  @override
  String get cancelOrderAction => 'إلغاء الطلب';

  @override
  String get cancelOrderTitle => 'إلغاء الطلب';

  @override
  String get cancelOrderConfirmBody => 'هل تريد إلغاء الطلب؟';

  @override
  String get cancelOrderBack => 'رجوع';

  @override
  String get cancelOrderConfirmAction => 'تأكيد الإلغاء';

  @override
  String get orderCancelledSuccess => 'تم إلغاء الطلب';

  @override
  String get ordersOngoingSection => 'تحت التنفيذ';

  @override
  String get ordersPastSection => 'الطلبات المكتملة';

  @override
  String get ordersTabUnderExecution => 'تحت التنفيذ';

  @override
  String get ordersTabCompleted => 'المكتملة';

  @override
  String get ordersTabPrevious => 'السابقة';

  @override
  String get ordersEmptyUnderExecution => 'لا توجد طلبات تحت التنفيذ حالياً';

  @override
  String get ordersEmptyCompleted => 'لا توجد طلبات مكتملة حتى الآن';

  @override
  String get ordersEmptyPrevious => 'لا توجد طلبات سابقة';

  @override
  String get orderExpiredHint =>
      'انتهت مدة هذا الطلب قبل أن يقبله أحد الكباتن.';

  @override
  String get orderExpiresAtLabel => 'وقت انتهاء الطلب';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navOrders => 'طلبات';

  @override
  String get navAccount => 'الحساب';

  @override
  String get ordersTitle => 'طلباتي';

  @override
  String get ordersSubtitle => 'آخر الطلبات التي أنشأتها';

  @override
  String get orderNumberLabel => 'رقم الطلب';

  @override
  String get orderNumberCopied => 'تم نسخ رقم الطلب';

  @override
  String get copyOrderNumberAction => 'نسخ';

  @override
  String get ordersEmpty => 'لا توجد طلبات بعد';

  @override
  String get ordersEmptyNow => 'لا توجد طلبات حالياً';

  @override
  String get ordersEmptyHint => 'أنشئ طلب توصيل من الصفحة الرئيسية';

  @override
  String get ordersLoadError => 'تعذر تحميل الطلبات';

  @override
  String get orderStatusPending => 'بانتظار كابتن';

  @override
  String get orderStatusActive => 'جاري التوصيل';

  @override
  String get captainOrderStatusActive => 'قيد التنفيذ';

  @override
  String get orderStatusCompleted => 'مكتمل';

  @override
  String get orderStatusCancelled => 'ملغي';

  @override
  String get orderStatusExpired => 'منتهي';

  @override
  String get orderStatusUnknown => 'غير معروف';

  @override
  String get accountTitle => 'حسابي';

  @override
  String get accountSubtitle => 'معلوماتك وإعدادات الحساب';

  @override
  String get accountSectionSettings => '⚙️ الحساب والإعدادات';

  @override
  String get themeSettingLabel => 'المظهر';

  @override
  String get themeModeDark => 'الوضع الداكن';

  @override
  String get themeModeLight => 'الوضع الفاتح';

  @override
  String get accountSectionPrivacySecurity => '🔐 الخصوصية والأمان';

  @override
  String get accountSectionAppInfo => 'ℹ️ معلومات التطبيق';

  @override
  String get accountSectionTechnicalSupport => '💬 الدعم الفني';

  @override
  String get accountSupportAdminPlaceholder =>
      'سيتم ربط قنوات الدعم من لوحة الإدارة قريباً.';

  @override
  String get supportScreenTitle => 'الدعم الفني';

  @override
  String get supportContactUs => 'تواصل معنا';

  @override
  String get supportDefaultMessage =>
      'فريق حاضر جاهز لمساعدتك. اختر وسيلة التواصل المناسبة.';

  @override
  String get supportChannelWhatsapp => 'واتساب';

  @override
  String get supportChannelPhone => 'اتصال هاتفي';

  @override
  String get supportChannelEmail => 'البريد الإلكتروني';

  @override
  String get supportNoChannels => 'قنوات الدعم غير متاحة حالياً.';

  @override
  String get supportLaunchFailed => 'تعذّر فتح التطبيق المطلوب';

  @override
  String get supportFaqsTitle => '❓ الأسئلة الشائعة';

  @override
  String get supportFormsTitle => '📋 أنواع طلبات الدعم';

  @override
  String get supportMyRequestsTitle => '📨 طلباتي للدعم';

  @override
  String get supportNoFaqs => 'لا توجد أسئلة شائعة حالياً.';

  @override
  String get supportNoForms => 'لا توجد أنواع طلبات دعم متاحة حالياً.';

  @override
  String get supportNoRequests => 'لم ترسل أي طلب دعم بعد.';

  @override
  String get supportRequestDetailTitle => 'تفاصيل طلب الدعم';

  @override
  String get supportRequestNumberLabel => 'رقم الطلب';

  @override
  String get supportRequestTypeLabel => 'نوع الطلب';

  @override
  String get supportRequestSubmittedAtLabel => 'تاريخ الإرسال';

  @override
  String get supportYourAnswersTitle => 'إجاباتك';

  @override
  String get supportAdminReplyTitle => '💬 رد فريق حاضر';

  @override
  String get supportNoAdminReplyYet =>
      'لم يرد فريق حاضر بعد. سنبلغك عند توفر رد.';

  @override
  String get supportSubmitForm => 'إرسال الطلب';

  @override
  String get supportFormSubmitted => 'تم إرسال طلب الدعم بنجاح';

  @override
  String get supportSubmitFailed => 'تعذّر إرسال طلب الدعم';

  @override
  String get supportSelectPlaceholder => 'اختر';

  @override
  String get supportRequiredField => 'هذا الحقل مطلوب';

  @override
  String get supportStatusNew => 'جديد';

  @override
  String get supportStatusInProgress => 'قيد المتابعة';

  @override
  String get supportStatusResolved => 'تم الحل';

  @override
  String get supportStatusClosed => 'مغلق';

  @override
  String get accountSectionLegal => '📄 معلومات وسياسات التطبيق';

  @override
  String get accountSectionManagement => '⚠️ إدارة الحساب';

  @override
  String get accountAppVersion => 'إصدار التطبيق';

  @override
  String get accountEditProfile => 'تعديل الملف الشخصي';

  @override
  String get accountNotifications => 'الإشعارات';

  @override
  String get accountChangePassword => 'تغيير الرمز السري';

  @override
  String get accountPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get accountTerms => 'شروط الاستخدام';

  @override
  String get accountAbout => 'حول تطبيق حاضر';

  @override
  String get accountSupport => 'الدعم والتواصل';

  @override
  String get accountDeleteAccount => 'حذف الحساب';

  @override
  String get accountDeleteAccountUnavailable =>
      'حذف الحساب غير متاح حالياً. هذه الميزة غير متاحة حالياً.';

  @override
  String get accountDeleteIntroBody =>
      'سيتم حذف حسابك وبياناتك الشخصية نهائياً، ولن تتمكن من استعادتها بعد إكمال عملية الحذف.';

  @override
  String get accountDeleteIrreversibleWarning =>
      'هذا الإجراء لا يمكن التراجع عنه.';

  @override
  String get accountDeleteContinueAction => 'متابعة حذف الحساب';

  @override
  String get accountDeleteConfirmTitle => 'تأكيد حذف الحساب';

  @override
  String get accountDeleteConfirmBody => 'هل أنت متأكد من حذف حسابك نهائياً؟';

  @override
  String get accountDeleteFinalAction => 'حذف حسابي نهائياً';

  @override
  String get accountDeleteBackAction => 'تراجع';

  @override
  String get accountDeletePasswordLabel => 'أدخل الرمز السري للتأكيد';

  @override
  String get accountDeletePasswordRequired => 'أدخل الرمز السري لتأكيد الحذف';

  @override
  String get accountDeleteSubscriptionWarning =>
      'تنبيه: حذف الحساب ينهي وصولك إلى الاشتراك الحالي ولن يتم استرداد أي مبالغ تلقائياً.';

  @override
  String get accountDeleteSuccessTitle => 'تم حذف حسابك';

  @override
  String get accountDeleteSuccessBody => 'تم حذف حسابك بنجاح.';

  @override
  String get accountDeleteFailed =>
      'تعذر حذف الحساب حالياً. يرجى المحاولة مرة أخرى.';

  @override
  String get accountDeleteActiveUserOrder =>
      'لا يمكن حذف الحساب أثناء وجود طلب نشط. أكمل أو ألغِ طلبك الحالي أولاً.';

  @override
  String get accountDeleteActiveCaptainOrder =>
      'لا يمكن حذف حساب الكابتن أثناء وجود طلبات نشطة. أكمل الطلبات الحالية أولاً.';

  @override
  String get featureComingSoon => 'هذه الميزة قيد التجهيز';

  @override
  String get subscriptionStatusActive => 'فعال';

  @override
  String get subscriptionStatusExpired => 'منتهي';

  @override
  String get subscriptionTypeLabel => 'نوع الاشتراك';

  @override
  String get subscriptionStatusLabel => 'الحالة';

  @override
  String get subscriptionRemainingLabel => 'المتبقي';

  @override
  String subscriptionRemainingDaysValue(String days) {
    return '$days يوم';
  }

  @override
  String get subscriptionExpiryDateLabel => 'تاريخ الانتهاء';

  @override
  String get subscriptionTrialLabel => 'تجربة مجانية';

  @override
  String get subscriptionPaidLabel => 'اشتراك مدفوع';

  @override
  String subscriptionEndsLabel(String date) {
    return 'ينتهي: $date';
  }

  @override
  String get aboutVersionLabel => 'إصدار التطبيق';

  @override
  String get supportPlaceholderTitle => 'الدعم والتواصل';

  @override
  String get supportPlaceholderBody =>
      'سيتم إضافة قنوات الدعم الرسمية هنا قريباً.';

  @override
  String get accountTypeLabel => 'نوع الحساب';

  @override
  String get accountStatusLabel => 'حالة الحساب';

  @override
  String get phoneVerifiedLabel => 'التحقق من الهاتف';

  @override
  String get accountTypeUser => 'مستخدم';

  @override
  String get accountTypeCaptain => 'كابتن';

  @override
  String get accountStatusActive => 'نشط';

  @override
  String get accountStatusPending => 'قيد المراجعة';

  @override
  String get accountStatusSuspended => 'موقوف';

  @override
  String get accountStatusDisabled => 'معطّل';

  @override
  String get yesLabel => 'نعم';

  @override
  String get noLabel => 'لا';

  @override
  String get convertToCaptainAction => 'تحويل حسابي إلى كابتن';

  @override
  String get convertToCaptainTitle => 'تحويل إلى كابتن';

  @override
  String get convertToCaptainConfirm =>
      'هل تريد تحويل حسابك إلى كابتن؟ سيتم مراجعة الطلب من الإدارة.';

  @override
  String get convertToCaptainHint =>
      'بعد التحويل يمكنك العمل ككابتن بعد موافقة الإدارة';

  @override
  String get convertToCaptainSuccess => 'تم إرسال طلب التحويل إلى كابتن';

  @override
  String get captainPendingMessage => 'حسابك كابتن قيد المراجعة من الإدارة';

  @override
  String get captainPendingScreenTitle => 'طلبك قيد المراجعة';

  @override
  String get captainPendingScreenMessage =>
      'تم استلام طلب انضمامك ككابتن بنجاح. سيتم مراجعة طلبك من قبل إدارة حاضر، وسيتم تفعيل حسابك بعد الموافقة.';

  @override
  String get captainPendingScreenHint => 'لا تحتاج إلى إرسال الطلب مرة أخرى.';

  @override
  String get captainPendingRefreshStatus => 'تحديث الحالة';

  @override
  String get captainRejectionMessage => 'تم رفض طلب التحويل إلى كابتن.';

  @override
  String get captainRejectionRefreshFailed =>
      'تعذر تحديث حالة الحساب. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get captainNavHome => 'الرئيسية';

  @override
  String get captainNavOrders => 'الطلبات';

  @override
  String get captainNavAccount => 'حسابي';

  @override
  String get captainHomeSubtitle => 'لوحة الكابتن';

  @override
  String get captainHomeActiveStatus => 'حسابك فعّال';

  @override
  String get captainAvailableOrdersTitle => 'الطلبات المتاحة';

  @override
  String get captainAvailableOrdersSubtitle => 'طلبات بانتظار كابتن';

  @override
  String get captainAvailableOrdersEmpty => 'لا توجد طلبات متاحة حالياً';

  @override
  String get captainAvailableOrdersEmptyHint =>
      'ستظهر الطلبات الجديدة هنا عند توفرها.';

  @override
  String get captainAvailableOrdersLoadError =>
      'تعذر تحميل الطلبات المتاحة. حاول مرة أخرى.';

  @override
  String get captainActiveOrdersAtCapacityTitle => 'أكمل طلباتك الحالية';

  @override
  String get captainActiveOrdersAtCapacityHint =>
      'أكمل أحد طلباتك الحالية حتى تتمكن من استلام طلب جديد.';

  @override
  String get captainMyOrdersSubtitle => 'الطلبات التي قبلتها ككابتن';

  @override
  String get captainMyOrdersEmptyHint => 'ستظهر هنا الطلبات التي تقبلها.';

  @override
  String get captainViewOrderDetails => 'عرض التفاصيل';

  @override
  String captainOrderFeeLabel(String amount) {
    return 'أجرة التوصيل: $amount د.ع';
  }

  @override
  String captainOrderExpiresAt(String time) {
    return 'ينتهي الساعة $time';
  }

  @override
  String get captainAcceptanceNotReady =>
      'نظام قبول الطلبات قيد التجهيز — سيتوفر قريباً';

  @override
  String get captainAcceptOrderAction => 'قبول الطلب';

  @override
  String get captainAcceptOrderConfirmTitle => 'قبول الطلب';

  @override
  String get captainAcceptOrderConfirmBody => 'هل تريد قبول هذا الطلب؟';

  @override
  String get captainAcceptOrderSuccess => 'تم قبول الطلب بنجاح';

  @override
  String get captainOrderAvailableBadge => 'متاح';

  @override
  String get captainOrderAcceptedAtLabel => 'وقت القبول';

  @override
  String get captainCompleteOrderAction => 'تم تسليم الطلب';

  @override
  String get captainCompleteOrderConfirmTitle => 'تأكيد تسليم الطلب';

  @override
  String get captainCompleteOrderConfirmBody => 'هل تم تسليم الطلب للعميل؟';

  @override
  String get captainCompleteOrderConfirmAction => 'تأكيد التسليم';

  @override
  String get captainCompleteOrderSuccess => 'تم إكمال الطلب بنجاح';

  @override
  String get captainOrderCompletedBadge => 'تم تسليم الطلب';

  @override
  String get captainOrderCompletedAtLabel => 'وقت التسليم';

  @override
  String get orderDeliveredAtLabel => 'وقت التسليم';

  @override
  String get captainSubscriptionRequiredAccept =>
      'اشتراكك غير فعال. فعّل الاشتراك لتتمكن من قبول الطلبات.';

  @override
  String get captainActiveOrdersSection => 'الطلبات الجارية';

  @override
  String get captainPastOrdersSection => 'الطلبات السابقة';

  @override
  String get captainOrdersTabUnderExecution => 'تحت التنفيذ';

  @override
  String get captainOrdersTabCompleted => 'الطلبات المكتملة';

  @override
  String get captainOrdersEmptyUnderExecution => 'لا توجد طلبات تحت التنفيذ';

  @override
  String get captainOrdersEmptyCompletedTab => 'لا توجد طلبات مكتملة';

  @override
  String get captainOrderTypeLabel => 'نوع الطلب';

  @override
  String get captainOrderDetailsLabel => 'تفاصيل الطلب';

  @override
  String get captainOrderDestinationLabel => 'وجهة التوصيل';

  @override
  String get captainOrderCreatedLabel => 'وقت الإنشاء';

  @override
  String get captainOrderRemainingTimeLabel => 'الوقت المتبقي';

  @override
  String get captainOrderExpiredLabel => 'انتهت مدة الطلب';

  @override
  String get captainOrderGpsLabel => 'إحداثيات الموقع';

  @override
  String get captainCustomerInfoTitle => 'معلومات العميل';

  @override
  String get captainCustomerNameLabel => 'الاسم';

  @override
  String get captainCustomerPhoneLabel => 'رقم الهاتف';

  @override
  String get captainCustomerLocationLabel => 'وصف الموقع';

  @override
  String get captainCustomerLocationTitle => 'موقع العميل';

  @override
  String get captainCallAction => 'اتصال';

  @override
  String get captainCallCustomerAction => 'اتصال بالعميل';

  @override
  String get captainOpenLocationAction => 'فتح الموقع';

  @override
  String get captainCallLaunchFailed => 'تعذر فتح تطبيق الاتصال';

  @override
  String get captainWhatsAppAction => 'واتساب';

  @override
  String get captainWhatsAppLaunchFailed => 'تعذر فتح واتساب';

  @override
  String get captainWazeAction => 'Waze';

  @override
  String get captainWazeLaunchFailed => 'تعذر فتح Waze';

  @override
  String get captainGoogleMapsAction => 'خرائط Google';

  @override
  String get captainGoogleMapsLaunchFailed => 'تعذر فتح خرائط Google';

  @override
  String get captainMapsLaunchFailed => 'تعذر فتح تطبيق الخرائط';

  @override
  String get captainDeliveryFeeTitle => 'أجرة التوصيل';

  @override
  String captainDeliveryFeeAmount(String amount) {
    return '$amount د.ع';
  }

  @override
  String get captainCouponDiscountLabel => 'الخصم';

  @override
  String get captainOrderActionsTitle => 'إجراءات الطلب';

  @override
  String get captainCustomerNoAnswerAction => 'العميل لا يرد';

  @override
  String get captainCustomerNoAnswerTitle => 'العميل لا يرد';

  @override
  String get captainCustomerNoAnswerBody =>
      'هل تريد تسجيل أن العميل لم يرد على الاتصال؟';

  @override
  String get captainCustomerNoAnswerConfirm => 'تأكيد';

  @override
  String get captainCustomerNoAnswerSuccess => 'تم تسجيل أن العميل لا يرد';

  @override
  String get captainTransferOrderAction => 'تحويل الطلب إلى كابتن آخر';

  @override
  String get captainTransferOrderTitle => 'تحويل الطلب';

  @override
  String get captainTransferOrderBody =>
      'سيتم إرجاع الطلب إلى قائمة الطلبات المتاحة ليتمكن كابتن آخر من قبوله. هل تريد المتابعة؟';

  @override
  String get captainTransferOrderConfirm => 'تأكيد التحويل';

  @override
  String get captainTransferReasonTitle => 'سبب التحويل';

  @override
  String get captainTransferReasonCannotComplete => 'تعذر إكمال الطلب';

  @override
  String get captainTransferReasonVehicle => 'مشكلة في المركبة';

  @override
  String get captainTransferReasonFar => 'بعيد عن موقع العميل';

  @override
  String get captainTransferReasonOther => 'سبب آخر';

  @override
  String get captainTransferReasonOtherHint => 'اكتب السبب';

  @override
  String get captainTransferSuccess => 'تم تحويل الطلب إلى قائمة المتاح';

  @override
  String get captainOrdersSubtitle => 'طلبات التوصيل المخصصة لك';

  @override
  String get captainOrdersEmpty => 'لا توجد طلبات حالياً';

  @override
  String get captainOrdersFeedPlaceholder => 'طلبات التوصيل المتاحة ستظهر هنا';

  @override
  String get captainAccountSubtitle => 'معلومات حساب الكابتن';

  @override
  String get captainSuspendedTitle => 'حساب الكابتن موقوف';

  @override
  String get captainSuspendedMessage =>
      'تم إيقاف حسابك ككابتن مؤقتاً. تواصل مع إدارة حاضر إذا كنت تعتقد أن هذا خطأ.';

  @override
  String get captainDisabledTitle => 'تم تعطيل الحساب';

  @override
  String get captainDisabledMessage =>
      'تم تعطيل حسابك ككابتن. تواصل مع إدارة حاضر للمزيد من المعلومات.';

  @override
  String get accountBlockedTitle => 'تم حظر حسابك';

  @override
  String get accountBlockedMessage =>
      'لا يمكنك استخدام خدمات حاضر حالياً.\nيرجى التواصل مع إدارة حاضر للمزيد من المعلومات.';

  @override
  String get accountBlockedContactAdmin => 'تواصل مع الإدارة';

  @override
  String get alreadyCaptainMessage => 'حسابك مسجّل ككابتن';

  @override
  String get captainSubscriptionTitle => '💳 الاشتراك';

  @override
  String get captainSubscriptionActiveTrial => 'اشتراك تجريبي فعال';

  @override
  String get captainSubscriptionActivePaid => 'اشتراك مدفوع فعال';

  @override
  String get captainSubscriptionExpired => 'انتهى الاشتراك';

  @override
  String get captainSubscriptionNone => 'لا يوجد اشتراك فعال';

  @override
  String captainSubscriptionRemaining(String days) {
    return 'المتبقي: $days يوم';
  }

  @override
  String captainSubscriptionEndsAt(String date) {
    return 'ينتهي: $date';
  }

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get confirmAction => 'تأكيد';
}

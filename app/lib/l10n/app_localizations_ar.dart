// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'FMS';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonDone => 'تم';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonUpload => 'رفع';

  @override
  String get commonUploadHintFormats => 'PDF/JPG/PNG';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonView => 'عرض';

  @override
  String get commonOptional => 'اختياري';

  @override
  String get commonYes => 'نعم';

  @override
  String get commonNo => 'لا';

  @override
  String get commonSubmit => 'إرسال';

  @override
  String get commonSkip => 'تخطي';

  @override
  String get languageSettingTitle => 'اللغة';

  @override
  String get languageSettingSubtitle => 'اختر لغة عرض التطبيق';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languagePickerTitle => 'اختر اللغة';

  @override
  String get logOutLabel => 'تسجيل الخروج';

  @override
  String get logOutTitle => 'تسجيل الخروج';

  @override
  String get logOutConfirmMessage => 'هل أنت متأكد من رغبتك في تسجيل الخروج؟';

  @override
  String get logOutBlockedActiveTrip =>
      'لا يمكنك تسجيل الخروج أثناء وجود رحلة قيد التنفيذ. أنهِ الرحلة أو سلّمها أولاً.';

  @override
  String get logOutTooltipBlocked => 'تسجيل الخروج (غير متاح أثناء رحلة نشطة)';

  @override
  String get loginWelcomeTitle => 'مرحبًا بك في FMS';

  @override
  String get loginWelcomeSubtitle => 'سجّل الدخول للوصول إلى حسابك';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get emailHint => 'أدخل بريدك الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get passwordHint => 'أدخل كلمة المرور';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get forgotPasswordSnack => 'تواصل مع المسؤول لإعادة تعيين كلمة المرور';

  @override
  String get logIn => 'تسجيل الدخول';

  @override
  String get featureSecureTitle => 'آمن وموثوق';

  @override
  String get featureSecureDesc => 'بياناتك محمية بأعلى مستوى';

  @override
  String get featureEasyTitle => 'إدارة سهلة';

  @override
  String get featureEasyDesc => 'تتبّع شحناتك لحظة بلحظة';

  @override
  String get featureReportsTitle => 'تقارير ذكية';

  @override
  String get featureReportsDesc => 'تحليلات وتقارير دقيقة';

  @override
  String get authNoAccount => 'ليس لديك حساب؟';

  @override
  String get authSignUp => 'إنشاء حساب';

  @override
  String get errorFillAllFields => 'يرجى تعبئة جميع الحقول';

  @override
  String get loggingInTitle => 'جارٍ تسجيل الدخول...';

  @override
  String get loggingInSubtitle => 'يرجى الانتظار قليلاً';

  @override
  String get createAccountTitle => 'أنشئ\nحسابك.';

  @override
  String get createAccountSubtitle => 'اختر نوع الحساب الذي تحتاجه';

  @override
  String get roleCompanyTitle => 'شركة';

  @override
  String get roleCompanySubtitle =>
      'اشحن بضائعك — اطلب شاحنات وتتبّع عمليات التسليم';

  @override
  String get roleDriverTitle => 'فردي (سائق)';

  @override
  String get roleDriverSubtitle =>
      'قُد شاحنتك الخاصة — احصل على مطابقة مع الشحنات';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String stepXofY(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get passwordStrengthWeak => 'ضعيفة';

  @override
  String get passwordStrengthFair => 'متوسطة';

  @override
  String get passwordStrengthStrong => 'قوية';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get stepAccountInfoTitle => 'معلومات الحساب';

  @override
  String get stepAccountInfoSubtitle => 'أدخل بيانات حسابك';

  @override
  String get stepReviewTitle => 'راجع معلوماتك';

  @override
  String get stepReviewSubtitle => 'يرجى مراجعة جميع المعلومات قبل الإرسال';

  @override
  String get documentsNotice =>
      'يجب أن تكون جميع المستندات واضحة وسارية المفعول. لا تُقبل المستندات منتهية الصلاحية.';

  @override
  String get reviewCannotEditNotice => 'لن تتمكن من التعديل بعد الإرسال.';

  @override
  String get submitForReview => 'إرسال للمراجعة';

  @override
  String get validationFillRequired => 'يرجى تعبئة جميع الحقول المطلوبة';

  @override
  String get validationInvalidEmail => 'يرجى إدخال بريد إلكتروني صحيح';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String errorSubmitGeneric(String error) {
    return 'حدث خطأ أثناء الإرسال: $error';
  }

  @override
  String get companyRegStepCompanyTitle => 'معلومات الشركة';

  @override
  String get companyRegStepCompanySubtitle => 'أخبرنا عن شركتك';

  @override
  String get companyRegStepDocumentsTitle => 'مستندات الشركة';

  @override
  String get companyRegStepDocumentsSubtitle => 'جميع المستندات إلزامية';

  @override
  String get companyNameLabel => 'اسم الشركة';

  @override
  String get companyNameHint => 'الشركة العالمية للخدمات اللوجستية';

  @override
  String get companyEmailHint => 'contact@company.com';

  @override
  String get companyAgreeTerms => 'أوافق على الشروط والأحكام وسياسة الخصوصية';

  @override
  String get companyPhoneLabel => 'رقم الهاتف';

  @override
  String get companyPhoneHint => '+971 4 123 4567';

  @override
  String get companyAddressLabel => 'عنوان الشركة';

  @override
  String get companyAddressHint => 'الشارع، المدينة، الدولة';

  @override
  String get tradeLicenseLabel => 'الرخصة التجارية';

  @override
  String get tradeLicenseUploaded => 'تم رفع الرخصة التجارية';

  @override
  String get noDocumentUploaded => 'لم يتم رفع أي مستند';

  @override
  String get validationAgreeTerms => 'يرجى الموافقة على الشروط والأحكام';

  @override
  String get validationCompanyPhone => 'يرجى إدخال رقم هاتف الشركة';

  @override
  String get validationCompanyAddress => 'يرجى إدخال عنوان الشركة';

  @override
  String get validationAttachLicense => 'يرجى إرفاق الرخصة التجارية';

  @override
  String get driverRegStepDriverTitle => 'معلومات السائق';

  @override
  String get driverRegStepDriverSubtitle => 'جميع الحقول إلزامية';

  @override
  String get driverRegStepDocumentsTitle => 'مستندات السائق';

  @override
  String get driverRegStepDocumentsSubtitle => 'جميع المستندات إلزامية';

  @override
  String get driverRegStepHealthTitle => 'الصحة والتغطية';

  @override
  String get driverRegStepHealthSubtitle =>
      'أخبرنا عن حالتك الصحية وتغطية العمل';

  @override
  String get driverRegStepTruckTitle => 'معلومات الشاحنة';

  @override
  String get driverRegStepTruckSubtitle => 'أدخل بيانات شاحنتك';

  @override
  String get driverRegStepTruckDocsTitle => 'مستندات الشاحنة';

  @override
  String get driverRegStepTruckDocsSubtitle => 'جميع المستندات إلزامية';

  @override
  String get fullNameLabel => 'الاسم الكامل';

  @override
  String get fullNameHint => 'محمد علي';

  @override
  String get driverEmailHint => 'mohamed.ali@example.com';

  @override
  String get driverAgreeTerms => 'أوافق على الشروط والأحكام';

  @override
  String get codeLabel => 'الرمز';

  @override
  String get phoneCountryTitle => 'رمز الدولة';

  @override
  String get phoneNumberLabel => 'رقم الهاتف';

  @override
  String get phoneNumberHint => '50 123 4567';

  @override
  String get nationalityLabel => 'الجنسية';

  @override
  String get nationalityHint => 'اختر الجنسية';

  @override
  String get nationalityTitle => 'الجنسية';

  @override
  String get dateOfBirthLabel => 'تاريخ الميلاد';

  @override
  String get dateOfBirthHint => '15 / 05 / 1992';

  @override
  String get ageLabel => 'العمر';

  @override
  String get driverLicenseNumberLabel => 'رقم رخصة القيادة';

  @override
  String get driverLicenseNumberHint => 'D1234567';

  @override
  String get searchCountryHint => 'ابحث عن دولة';

  @override
  String get docLicenseFront => 'رخصة القيادة — الوجه الأمامي';

  @override
  String get docLicenseBack => 'رخصة القيادة — الوجه الخلفي (اختياري)';

  @override
  String get docPassport => 'جواز السفر (الصفحة الأولى)';

  @override
  String get docResidency => 'الهوية الإماراتية / الإقامة';

  @override
  String get docDriverPhoto => 'صورة السائق (اختياري)';

  @override
  String get docDriverPhotoHint => 'صورة شخصية واضحة';

  @override
  String get expiryDateLabel => 'تاريخ الانتهاء';

  @override
  String get expiryDateHint => 'يوم/شهر/سنة';

  @override
  String get healthStatusLabel => 'الحالة الصحية';

  @override
  String get healthStatusHint => 'اختر أي حالات صحية';

  @override
  String get healthStatusTitle => 'الحالة الصحية';

  @override
  String get describeOtherCondition => 'صف الحالة الأخرى';

  @override
  String get bloodTypeLabel => 'فصيلة الدم';

  @override
  String get bloodTypeHint => 'اختر فصيلة الدم';

  @override
  String get bloodTypeTitle => 'فصيلة الدم';

  @override
  String get workDestinationsLabel => 'وجهات العمل';

  @override
  String get workDestinationsHint => 'الدول التي تعمل بها';

  @override
  String get workDestinationsTitle => 'وجهات العمل';

  @override
  String get truckTypeLabel => 'نوع الشاحنة';

  @override
  String get truckTypeHint => 'اختر نوع الشاحنة';

  @override
  String get truckTypeTitle => 'نوع الشاحنة';

  @override
  String get truckPlateLabel => 'رقم لوحة الشاحنة';

  @override
  String get truckPlateHint => 'C 12345';

  @override
  String get permitTypeLabel => 'نوع التصريح (اختياري)';

  @override
  String get docVehicleReg => 'استمارة تسجيل المركبة';

  @override
  String get docInsurance => 'التأمين (اختياري)';

  @override
  String get docInspection => 'الفحص الفني (اختياري)';

  @override
  String get truckDocsNotice =>
      'تأكد من أن استمارة تسجيل المركبة سارية المفعول — لا تُقبل المستندات منتهية الصلاحية.';

  @override
  String get reviewAccountInfoTitle => 'معلومات الحساب';

  @override
  String get reviewDriverInfoTitle => 'معلومات السائق';

  @override
  String get reviewDriverDocsTitle => 'مستندات السائق';

  @override
  String get reviewCompanyInfoTitle => 'معلومات الشركة';

  @override
  String get reviewTruckInfoTitle => 'معلومات الشاحنة';

  @override
  String get reviewTruckDocsTitle => 'مستندات الشاحنة';

  @override
  String uploadedCountOfTotal(int count, int total) {
    return 'تم رفع $count/$total';
  }

  @override
  String licenseNumberPrefix(String number) {
    return 'رخصة رقم $number';
  }

  @override
  String get driverValidationAgreeTerms =>
      'يرجى الموافقة على شروط الخدمة وسياسة الخصوصية';

  @override
  String get driverValidationPhone => 'يرجى إدخال رقم هاتف صحيح (أرقام فقط)';

  @override
  String get driverValidationNationality => 'يرجى اختيار جنسيتك';

  @override
  String get driverValidationDob => 'يرجى اختيار تاريخ ميلادك';

  @override
  String get driverValidationAge => 'يجب أن يكون العمر بين 18 و65 عامًا';

  @override
  String get driverValidationLicenseNumber => 'يرجى إدخال رقم رخصة القيادة';

  @override
  String get driverValidationLicenseDoc =>
      'يرجى إرفاق رخصة القيادة وتاريخ انتهائها';

  @override
  String get driverValidationPassportDoc =>
      'يرجى إرفاق جواز السفر وتاريخ انتهائه';

  @override
  String get driverValidationResidencyDoc =>
      'يرجى إرفاق الهوية الإماراتية / الإقامة وتاريخ انتهائها';

  @override
  String get driverValidationBloodType => 'يرجى اختيار فصيلة الدم';

  @override
  String get driverValidationDestinations =>
      'يرجى اختيار وجهة واحدة على الأقل تعمل بها';

  @override
  String get driverValidationTruckType => 'يرجى اختيار نوع الشاحنة';

  @override
  String get driverValidationTruckPlate => 'يرجى إدخال رقم لوحة الشاحنة';

  @override
  String get driverValidationVehicleRegDoc =>
      'يرجى إرفاق استمارة تسجيل المركبة';

  @override
  String get otpTitle => 'تحقق من\nبريدك الإلكتروني.';

  @override
  String otpSubtitle(String email) {
    return 'أرسلنا رمزًا مكوّنًا من 6 أرقام إلى $email';
  }

  @override
  String get otpEnterCode => 'أدخل الرمز الذي أرسلناه إلى بريدك الإلكتروني';

  @override
  String get otpVerify => 'تحقق';

  @override
  String get otpResendCode => 'إعادة إرسال الرمز';

  @override
  String otpResendCodeIn(int seconds) {
    return 'إعادة الإرسال خلال $seconds ث';
  }

  @override
  String otpResentTo(String email) {
    return 'تم إرسال رمز جديد إلى $email';
  }

  @override
  String otpSomethingWrong(String error) {
    return 'حدث خطأ ما: $error';
  }

  @override
  String get forceChangePasswordTitle => 'عيّن كلمة\nمرور جديدة.';

  @override
  String get forceChangePasswordSubtitle =>
      'لأسباب أمنية، يجب عليك تعيين كلمة مرور خاصة بك قبل المتابعة.';

  @override
  String get temporaryPasswordLabel => 'كلمة المرور المؤقتة';

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get confirmNewPasswordLabel => 'تأكيد كلمة المرور الجديدة';

  @override
  String get passwordRequirementsHint =>
      '8 أحرف على الأقل، تشمل حرفًا كبيرًا وصغيرًا ورقمًا ورمزًا.';

  @override
  String get updatePassword => 'تحديث كلمة المرور';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navShipments => 'الشحنات';

  @override
  String get navWallet => 'المحفظة';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get navFinance => 'المالية';

  @override
  String get navDashboard => 'لوحة التحكم';

  @override
  String get navApprovals => 'الموافقات';

  @override
  String get navMenu => 'القائمة';

  @override
  String get navOffers => 'العروض';

  @override
  String get navDrivers => 'السائقون';

  @override
  String get navCompanies => 'الشركات';

  @override
  String get navReports => 'التقارير';

  @override
  String get drawerDrivers => 'السائقون';

  @override
  String get drawerCompanies => 'الشركات';

  @override
  String get drawerOffers => 'العروض';

  @override
  String get drawerWorkDestinations => 'وجهات العمل';

  @override
  String get drawerReports => 'التقارير';

  @override
  String get drawerNotifications => 'الإشعارات';

  @override
  String get drawerActivityLog => 'سجل النشاطات';

  @override
  String get drawerSettings => 'الإعدادات';

  @override
  String get roleSuperAdmin => 'مسؤول عام';

  @override
  String get roleSubAdmin => 'مسؤول فرعي';

  @override
  String get roleAdmin => 'مسؤول';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsNoneAvailable =>
      'لا توجد إعدادات متاحة وفق صلاحياتك الحالية.';

  @override
  String get settingsSectionGeneral => 'عام';

  @override
  String get settingsSectionAdministration => 'الإدارة';

  @override
  String get settingsSectionFinance => 'المالية والمدفوعات';

  @override
  String get settingsSectionRecycleBin => 'سلة المحذوفات';

  @override
  String get adminAccountsTitle => 'حسابات المسؤولين';

  @override
  String get adminAccountsSubtitle =>
      'إنشاء مسؤولين فرعيين، إدارة الصلاحيات، إيقافهم أو حذفهم';

  @override
  String get profileEditRequestsTitle => 'طلبات تعديل الملف الشخصي';

  @override
  String get profileEditRequestsSubtitle =>
      'مراجعة تعديلات السائقين/الشركات الذاتية قبل تطبيقها';

  @override
  String get financeTileTitle => 'المالية';

  @override
  String get financeTileSubtitle =>
      'مراجعة الإيداعات ومستحقات السائقين وتحديد حدود ائتمان الشركات';

  @override
  String get priceListTitle => 'قائمة الأسعار';

  @override
  String get priceListSubtitle =>
      'مسؤول المالية: تصدير/استيراد مصفوفة الأسعار المركزية';

  @override
  String get zonePricingTitle => 'تسعير المناطق';

  @override
  String get zonePricingSubtitle =>
      'محرك التسعير الذكي: مراجعة المسارات السابقة وتعديل نسبة السوق';

  @override
  String get platformSettingsTitle => 'إعدادات المنصة';

  @override
  String get platformSettingsSubtitle =>
      'للمسؤول العام فقط — هامش الربح، أوزان المطابقة/المهلة، إعدادات السائقين الافتراضية';

  @override
  String get deletedDriversTitle => 'السائقون المحذوفون';

  @override
  String get deletedDriversSubtitle => 'استعادة السائقين المحذوفين من النظام';

  @override
  String get deletedCompaniesTitle => 'الشركات المحذوفة';

  @override
  String get deletedCompaniesSubtitle => 'استعادة الشركات المحذوفة من النظام';

  @override
  String get couldntConnectTitle => 'تعذر الاتصال';

  @override
  String get couldntConnectBody =>
      'أنت لا تزال مسجلاً الدخول — لم نتمكن فقط من الوصول إلى الخادم. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get greetingMorning => 'صباح الخير';

  @override
  String get greetingAfternoon => 'مساء الخير';

  @override
  String get greetingEvening => 'مساء الخير';

  @override
  String greetingComma(String greeting, String name) {
    return '$greeting، $name';
  }

  @override
  String get driveSafe => 'قيادة آمنة!';

  @override
  String get activeTripBanner =>
      'رحلة نشطة — مشاركة الموقع مفعّلة. تسجيل الخروج غير متاح حتى تنتهي.';

  @override
  String get complianceExpiringTitle => 'مستند على وشك الانتهاء';

  @override
  String get complianceExpiringBody =>
      'أحد المستندات على وشك الانتهاء — جدّده الآن لتجنب فقدان عروض الشحن الجديدة.';

  @override
  String get compliancePendingTitle => 'التجديد قيد المراجعة';

  @override
  String get compliancePendingBody =>
      'تم إرسال طلب التجديد وهو بانتظار موافقة الإدارة — لن تصلك عروض شحن جديدة حتى تتم الموافقة.';

  @override
  String get complianceActionTitle => 'إجراء مطلوب';

  @override
  String get complianceActionBody =>
      'أحد المستندات منتهي الصلاحية — جدّده الآن لمواصلة استلام عروض الشحن الجديدة.';

  @override
  String get walletBalanceLabel => 'رصيد المحفظة';

  @override
  String get couldNotLoadWalletBalance =>
      'تعذر تحميل رصيد المحفظة — يتم عرض 0 درهم مؤقتًا.';

  @override
  String get quickOverview => 'نظرة سريعة';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get statActiveTrips => 'الرحلات النشطة';

  @override
  String get statUpcoming => 'القادمة';

  @override
  String get statCompleted => 'مكتملة';

  @override
  String get statPendingPayments => 'مدفوعات معلّقة';

  @override
  String get currentTripLabel => 'الرحلة الحالية';

  @override
  String get recentNotifications => 'أحدث الإشعارات';

  @override
  String get noNotificationsYet => 'لا توجد إشعارات حتى الآن';

  @override
  String couldNotLoadShipments(String error) {
    return 'تعذر تحميل شحناتك.\n$error';
  }

  @override
  String get viewTracking => 'عرض التتبع';

  @override
  String get companyHomeSubtitle => 'إليك آخر تحديثات الحركة اليوم';

  @override
  String get blockedCreateShipmentExpiring =>
      'رخصتك التجارية على وشك الانتهاء — جدّدها لتجنب فقدان القدرة على إنشاء شحنات.';

  @override
  String get blockedCreateShipmentPending =>
      'تجديد رخصتك التجارية لا يزال قيد مراجعة الإدارة.';

  @override
  String get blockedCreateShipmentExpired =>
      'انتهت صلاحية رخصتك التجارية — جدّدها لإنشاء شحنات جديدة.';

  @override
  String get trackAShipmentTitle => 'تتبّع شحنة';

  @override
  String get companyComplianceExpiringTitle =>
      'الرخصة التجارية على وشك الانتهاء';

  @override
  String get companyCompliancePendingTitle => 'التجديد قيد المراجعة';

  @override
  String get companyComplianceActionTitle => 'إجراء مطلوب';

  @override
  String get companyComplianceExpiringBody =>
      'جدّدها قبل انتهائها لتجنب فقدان القدرة على إنشاء شحنات جديدة.';

  @override
  String get companyCompliancePendingBody =>
      'تم إرسال رخصتك التجارية المجدّدة وهي بانتظار موافقة الإدارة.';

  @override
  String get companyComplianceActionBody =>
      'جدّد رخصتك التجارية لإنشاء شحنات جديدة.';

  @override
  String get trackLiveShipmentOne => 'تتبّع الشحنة المباشرة';

  @override
  String trackLiveShipmentsMany(int count) {
    return 'تتبّع $count شحنات مباشرة';
  }

  @override
  String get onTheRoadNow => 'على الطريق الآن — اضغط لعرض الخريطة المباشرة';

  @override
  String get statActiveShipments => 'الشحنات النشطة';

  @override
  String get statInTransit => 'قيد النقل';

  @override
  String get statPending => 'قيد الانتظار';

  @override
  String get statDelivered => 'تم التسليم';

  @override
  String get createShipment => 'إنشاء شحنة';

  @override
  String get createShipmentBlocked => 'إنشاء شحنة (محظور)';

  @override
  String get viewMyOffers => 'عرض عروضي';

  @override
  String get recentShipments => 'الشحنات الأخيرة';

  @override
  String get noShipmentsYet => 'لا توجد شحنات حتى الآن';

  @override
  String get weekdayMonday => 'الاثنين';

  @override
  String get weekdayTuesday => 'الثلاثاء';

  @override
  String get weekdayWednesday => 'الأربعاء';

  @override
  String get weekdayThursday => 'الخميس';

  @override
  String get weekdayFriday => 'الجمعة';

  @override
  String get weekdaySaturday => 'السبت';

  @override
  String get weekdaySunday => 'الأحد';

  @override
  String get monthJanuary => 'يناير';

  @override
  String get monthFebruary => 'فبراير';

  @override
  String get monthMarch => 'مارس';

  @override
  String get monthApril => 'أبريل';

  @override
  String get monthMay => 'مايو';

  @override
  String get monthJune => 'يونيو';

  @override
  String get monthJuly => 'يوليو';

  @override
  String get monthAugust => 'أغسطس';

  @override
  String get monthSeptember => 'سبتمبر';

  @override
  String get monthOctober => 'أكتوبر';

  @override
  String get monthNovember => 'نوفمبر';

  @override
  String get monthDecember => 'ديسمبر';

  @override
  String todayLabelFormat(String weekday, String month, int day, int year) {
    return '$weekday، $day $month $year';
  }

  @override
  String couldNotLoadDashboardStats(String error) {
    return 'تعذر تحميل إحصاءات لوحة التحكم.\n$error';
  }

  @override
  String get statPendingApprovals => 'الموافقات المعلّقة';

  @override
  String get statDocumentRenewals => 'تجديد المستندات';

  @override
  String get statChangesRequired => 'تعديلات مطلوبة';

  @override
  String get statActiveDrivers => 'السائقون النشطون';

  @override
  String get statAvailableTrucks => 'الشاحنات المتاحة';

  @override
  String get statActiveCompanies => 'الشركات النشطة';

  @override
  String get statCompletedThisMonth => 'المكتملة هذا الشهر';

  @override
  String get importantAlerts => 'تنبيهات مهمة';

  @override
  String get allCaughtUp => 'لا يوجد جديد — لا توجد تنبيهات حاليًا.';

  @override
  String get myShipmentsTitle => 'شحناتي';

  @override
  String tabAllCount(int count) {
    return 'الكل ($count)';
  }

  @override
  String tabActiveCount(int count) {
    return 'نشطة ($count)';
  }

  @override
  String tabCompletedCount(int count) {
    return 'مكتملة ($count)';
  }

  @override
  String tabCancelledCount(int count) {
    return 'ملغاة ($count)';
  }

  @override
  String get failedToLoadShipments => 'فشل تحميل الشحنات';

  @override
  String get noShipmentsHere => 'لا توجد شحنات هنا';

  @override
  String get shipmentsMatchingFilterEmpty =>
      'ستظهر هنا الشحنات المطابقة لهذا الفلتر.';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get contactInformationTitle => 'معلومات التواصل';

  @override
  String get accountSectionTitle => 'الحساب';

  @override
  String get personalInformationLabel => 'المعلومات الشخصية';

  @override
  String get personalInformationSubtitle => 'الاسم والهاتف والبريد الإلكتروني';

  @override
  String get bankDetailsLabel => 'البيانات المصرفية';

  @override
  String get bankDetailsSubtitle => 'الحساب الذي تُرسل إليه مستحقاتك';

  @override
  String get changePasswordLabel => 'تغيير كلمة المرور';

  @override
  String get changePasswordSubtitle => 'تحديث كلمة مرور الدخول';

  @override
  String get helpSupportLabel => 'المساعدة والدعم';

  @override
  String get helpSupportSubtitle =>
      'اتصال، واتساب، بريد إلكتروني والأسئلة الشائعة';

  @override
  String get financeSectionTitle => 'المالية';

  @override
  String get myBalanceLabel => 'رصيدي';

  @override
  String get myPerformanceTitle => 'أدائي';

  @override
  String get statCompletedLabel => 'مكتملة';

  @override
  String get statCancelledLabel => 'ملغاة';

  @override
  String get ratingComplianceTitle => 'التقييم والامتثال';

  @override
  String get documentsCoverageTitle => 'المستندات والتغطية';

  @override
  String get myDocumentsLabel => 'مستنداتي';

  @override
  String get myDocumentsSubtitle => 'الرخصة، جواز السفر، الإقامة والمزيد';

  @override
  String get myTruckLabel => 'شاحنتي';

  @override
  String get myTruckSubtitle => 'اللوحة والسعة وتاريخ انتهاء المستندات';

  @override
  String get myDestinationsLabel => 'وجهاتي';

  @override
  String get myDestinationsSubtitle =>
      'الدول التي تغطيها — تُستخدم في المطابقة';

  @override
  String get myTrucksTitle => 'شاحناتي';

  @override
  String get addTruckLabel => 'إضافة شاحنة';

  @override
  String get couldNotLoadTrucks => 'تعذر تحميل الشاحنات';

  @override
  String get noTrucksAddedYet =>
      'لم تتم إضافة أي شاحنة بعد. أضف شاحنتك ليتم مطابقتك مع الشحنات.';

  @override
  String get roleUserFallback => 'مستخدم';

  @override
  String get roleDriver => 'سائق';

  @override
  String get roleCompany => 'شركة';

  @override
  String get newTradeLicenseExpiryDate =>
      'تاريخ انتهاء الرخصة التجارية الجديدة';

  @override
  String get licenseStatusExpired => 'منتهية';

  @override
  String get licenseStatusExpiringSoon => 'على وشك الانتهاء';

  @override
  String get licenseStatusPendingReview => 'قيد المراجعة';

  @override
  String get licenseStatusValid => 'سارية';

  @override
  String daysOverdue(int days) {
    return 'متأخرة $days يوم';
  }

  @override
  String get expiresToday => 'تنتهي اليوم';

  @override
  String daysLeft(int days) {
    return 'متبقي $days يوم';
  }

  @override
  String get editCompanyInfoTitle => 'تعديل معلومات الشركة';

  @override
  String get phoneLabel => 'الهاتف';

  @override
  String get companyInformationTitle => 'معلومات الشركة';

  @override
  String get phoneLabelShort => 'الهاتف';

  @override
  String get notUploadedYet => 'لم يتم الرفع بعد';

  @override
  String get tradeLicenseOnFile => 'الرخصة التجارية مسجّلة';

  @override
  String get uploadingEllipsis => 'جارٍ الرفع…';

  @override
  String get uploadTradeLicense => 'رفع الرخصة التجارية';

  @override
  String get renewTradeLicense => 'تجديد الرخصة التجارية';

  @override
  String get financeLinkSubtitle => 'الرصيد وحد الائتمان والإيداعات';

  @override
  String get notificationsLinkSubtitle => 'تحديثات الشحنات والحساب';

  @override
  String get accountStatusActive => 'نشط';

  @override
  String get accountStatusSuspended => 'موقوف';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get markAllRead => 'تحديد الكل كمقروء';

  @override
  String couldNotLoadNotifications(String error) {
    return 'تعذر تحميل الإشعارات: $error';
  }

  @override
  String get filterAll => 'الكل';

  @override
  String get filterUnread => 'غير مقروءة';

  @override
  String get noUnreadNotifications => 'لا توجد إشعارات غير مقروءة';

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int minutes) {
    return 'منذ $minutes د';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'منذ $hours س';
  }

  @override
  String timeDaysAgo(int days) {
    return 'منذ $days يوم';
  }

  @override
  String get addShipmentTitle => 'إنشاء شحنة';

  @override
  String get addShipmentStepRoute => 'المسار';

  @override
  String get addShipmentStepCargo => 'تفاصيل البضاعة';

  @override
  String get addShipmentStepTruckPricing => 'الشاحنة والتسعير';

  @override
  String get addShipmentStepReview => 'المراجعة والإرسال';

  @override
  String get addShipmentSubtitleRoute => 'إلى أين تتجه هذه الشحنة؟';

  @override
  String get addShipmentSubtitleCargo => 'أخبرنا بما سيتم شحنه';

  @override
  String get addShipmentSubtitleTruckPricing => 'ما نوع الشاحنة، وكم ستدفع؟';

  @override
  String get addShipmentSubtitleReview => 'تحقق من كل شيء قبل إنشاء العرض';

  @override
  String addShipmentFailedToLoadZones(String error) {
    return 'فشل تحميل المناطق: $error';
  }

  @override
  String get addShipmentSelectPickupZone => 'الرجاء اختيار منطقة الاستلام';

  @override
  String get addShipmentSelectDropoffZone => 'الرجاء اختيار منطقة التسليم';

  @override
  String get addShipmentWeightMustBeNumber => 'يجب أن يكون الوزن رقمًا';

  @override
  String get addShipmentSelectTruckTypeRequired =>
      'الرجاء اختيار نوع الشاحنة المطلوب';

  @override
  String get addShipmentDomestic => 'شحنة داخلية';

  @override
  String get addShipmentCrossBorder => 'شحنة عبر الحدود';

  @override
  String get addShipmentPickupLabel => 'الاستلام';

  @override
  String get addShipmentDropoffLabel => 'التسليم';

  @override
  String get addShipmentPickupCountry => 'دولة الاستلام';

  @override
  String get addShipmentPickupCity => 'مدينة الاستلام';

  @override
  String get addShipmentPickupZone => 'منطقة الاستلام';

  @override
  String get addShipmentDropoffCountry => 'دولة التسليم';

  @override
  String get addShipmentDropoffCity => 'مدينة التسليم';

  @override
  String get addShipmentDropoffZone => 'منطقة التسليم';

  @override
  String get addShipmentPickupAddressOptional => 'عنوان الاستلام (اختياري)';

  @override
  String get addShipmentDropoffAddressOptional => 'عنوان التسليم (اختياري)';

  @override
  String get addShipmentAddressHint => 'المبنى، الشارع، معلم مميز…';

  @override
  String get addShipmentSelectCountry => 'اختر دولة';

  @override
  String get addShipmentSelectCountryFirst => 'اختر الدولة أولاً';

  @override
  String get addShipmentSelectCity => 'اختر مدينة';

  @override
  String get addShipmentSelectCityFirst => 'اختر المدينة أولاً';

  @override
  String get addShipmentSelectZone => 'اختر منطقة';

  @override
  String get addShipmentWeightKg => 'الوزن (كجم)';

  @override
  String get addShipmentCargoDescription => 'وصف البضاعة';

  @override
  String get addShipmentCargoDescriptionHint => 'اختياري — ما الذي سيتم شحنه';

  @override
  String get addShipmentRequiredTruckType => 'نوع الشاحنة المطلوب';

  @override
  String get addShipmentSelectTruckType => 'اختر نوع الشاحنة';

  @override
  String get addShipmentRequiresPermit => 'تتطلب تصريحًا خاصًا';

  @override
  String get addShipmentHazardousCargo => 'بضاعة خطرة';

  @override
  String get addShipmentFragileCargo => 'بضاعة قابلة للكسر';

  @override
  String get addShipmentPricingLabel => 'التسعير';

  @override
  String get addShipmentPricingSelectPrompt =>
      'اختر منطقة الاستلام والتسليم ونوع الشاحنة لرؤية اقتراح السعر.';

  @override
  String get addShipmentPricingNotLoaded => 'لم يتم تحميل اقتراح السعر بعد.';

  @override
  String get addShipmentPricingNoHistorical =>
      'لا يوجد تسعير سابق لهذا المسار — سيقوم فريقنا بالمراجعة وتحديد سعر بعد إرسالك مباشرة.';

  @override
  String get addShipmentNoOptionsAvailable => 'لا توجد خيارات متاحة';

  @override
  String get addShipmentNoZonesForCity => 'لا توجد مناطق متاحة لهذه المدينة';

  @override
  String addShipmentHistoricalReference(String value) {
    return 'السعر المرجعي السابق: $value';
  }

  @override
  String addShipmentTypicalRange(String value) {
    return 'النطاق المعتاد: $value';
  }

  @override
  String addShipmentPastTrips(int count) {
    return '$count رحلة سابقة';
  }

  @override
  String get addShipmentYourPriceLabel => 'سعرك (درهم، يُحصّل منك)';

  @override
  String get addShipmentYourPriceHint =>
      'افتراضيًا السعر المرجعي السابق — يمكنك تغييره';

  @override
  String get addShipmentCreateOfferButton => 'إنشاء العرض';

  @override
  String get addShipmentReviewType => 'النوع';

  @override
  String get addShipmentReviewOrigin => 'نقطة الانطلاق';

  @override
  String get addShipmentReviewDestination => 'الوجهة';

  @override
  String get addShipmentReviewWeight => 'الوزن';

  @override
  String get addShipmentReviewDescription => 'الوصف';

  @override
  String get addShipmentReviewTruckType => 'نوع الشاحنة';

  @override
  String get addShipmentReviewSpecialPermit => 'تصريح خاص';

  @override
  String get addShipmentReviewHazardous => 'خطرة';

  @override
  String get addShipmentReviewFragile => 'قابلة للكسر';

  @override
  String get addShipmentReviewYourPrice => 'سعرك';

  @override
  String get addShipmentDomesticShort => 'داخلية';

  @override
  String get addShipmentCrossBorderShort => 'عبر الحدود';

  @override
  String get addShipmentSetByCrm => 'سيُحدد من قبل الفريق بعد المراجعة';

  @override
  String get addShipmentSuccessNoAutoPrice =>
      'تم إنشاء العرض — لم يتم العثور على سعر تلقائي، سيقوم الفريق بتحديد سعر قريبًا';

  @override
  String get addShipmentSuccessMatching =>
      'تم إنشاء العرض — جارٍ مطابقة السائقين';

  @override
  String addShipmentSomethingWentWrong(String error) {
    return 'حدث خطأ ما: $error';
  }

  @override
  String get companyShipmentsSearchHint =>
      'ابحث برقم التتبع أو المعرّف أو المسار...';

  @override
  String get tabPendingLabel => 'قيد الانتظار';

  @override
  String get tabLiveLabel => 'مباشر';

  @override
  String get tabDeliveredLabel => 'تم التسليم';

  @override
  String get adminShipmentsTitle => 'الشحنات';

  @override
  String get adminShipmentsSearchHint =>
      'ابحث برقم التتبع، الشركة، أو السائق...';

  @override
  String get adminShipmentsChipActive => 'نشطة';

  @override
  String get adminShipmentsChipDelivered => 'تم التسليم';

  @override
  String get adminShipmentsChipCancelled => 'ملغاة';

  @override
  String get adminShipmentsNoneFound => 'لم يتم العثور على شحنات';

  @override
  String get adminShipmentsWaitingForDriver => 'بانتظار السائق';

  @override
  String get shipmentDetailsTitle => 'تفاصيل الشحنة';

  @override
  String get rateDriverTitle => 'قيّم هذا السائق';

  @override
  String get commentOptionalHint => 'تعليق (اختياري)';

  @override
  String get reportDriverTitle => 'الإبلاغ عن السائق';

  @override
  String get describeWhatHappenedHint => 'صف ما حدث';

  @override
  String get reviewProofOfDeliveryButton => 'مراجعة إثبات التسليم';

  @override
  String get viewTrackingTimelineButton => 'عرض الجدول الزمني للتتبع';

  @override
  String get reportDriverButton => 'الإبلاغ عن السائق';

  @override
  String get awaitingYourConfirmation => 'بانتظار تأكيدك';

  @override
  String get underAdminReview => 'قيد مراجعة الإدارة';

  @override
  String get sectionRoute => 'المسار';

  @override
  String get sectionShipmentInfo => 'معلومات الشحنة';

  @override
  String get sectionTimeline => 'الجدول الزمني';

  @override
  String get fieldShipmentId => 'معرّف الشحنة';

  @override
  String get fieldCreated => 'تاريخ الإنشاء';

  @override
  String get fieldPickupTime => 'وقت الاستلام';

  @override
  String get fieldDeliveredAt => 'وقت التسليم';

  @override
  String get yourReportedProblem => 'المشكلة التي أبلغت عنها';

  @override
  String get availableShipmentsTitle => 'الشحنات المتاحة';

  @override
  String get availabilityAvailable => 'متاح';

  @override
  String get availabilityUnavailable => 'غير متاح';

  @override
  String get couldNotUpdateStatus => 'تعذّر تحديث الحالة';

  @override
  String get availabilityCardTitle => 'حالة العمل';

  @override
  String get availabilityAvailableHint => 'متاح لاستقبال شحنات جديدة';

  @override
  String get availabilityUnavailableHint => 'غير متاح لاستقبال شحنات جديدة';

  @override
  String get availabilityBusy => 'مشغول';

  @override
  String get availabilityBusyHint => 'لديك رحلة نشطة حاليًا — ستعود الحالة تلقائيًا بعد انتهائها';

  @override
  String get searchByLocationLoadType => 'ابحث بالموقع أو نوع الحمولة...';

  @override
  String tabNearbyCount(int count) {
    return 'القريبة ($count)';
  }

  @override
  String tabSavedCount(int count) {
    return 'المحفوظة ($count)';
  }

  @override
  String get couldNotLoadOffers => 'تعذّر تحميل العروض';

  @override
  String get noSavedOffersYet => 'لا توجد عروض محفوظة بعد.';

  @override
  String get noNearbyOffersRightNow =>
      'لا توجد عروض قريبة تحتوي على إحداثيات استلام حاليًا.';

  @override
  String get noMatchingOffersRightNow => 'لا توجد عروض مطابقة حاليًا.';

  @override
  String get tagPermit => 'تصريح';

  @override
  String get tagHazardous => 'خطر';

  @override
  String get tagFragile => 'قابل للكسر';

  @override
  String distanceKmAway(String km) {
    return 'على بُعد $km كم';
  }

  @override
  String priceLabelAed(String price) {
    return 'السعر: $price درهم';
  }

  @override
  String get detailsButton => 'التفاصيل';

  @override
  String get acceptButton => 'قبول';

  @override
  String get declineOfferTitle => 'رفض هذا العرض؟';

  @override
  String get declineOfferBody =>
      'لن تتم مطابقتك مع هذه الشحنة مرة أخرى إلا إذا أُعيد عرضها.';

  @override
  String get commonDecline => 'رفض';

  @override
  String get commonSaved => 'محفوظ';

  @override
  String get failedToDeclineOffer => 'فشل رفض العرض';

  @override
  String get statusOffered => 'معروض';

  @override
  String postedByCompany(String name) {
    return 'نُشر بواسطة $name';
  }

  @override
  String get sectionLoadInformation => 'معلومات الحمولة';

  @override
  String get fieldOrderType => 'نوع الطلب';

  @override
  String get fieldPickupZone => 'منطقة الاستلام';

  @override
  String get fieldDropoffZone => 'منطقة التسليم';

  @override
  String get requirementSpecialPermit => 'تصريح خاص';

  @override
  String get requirementHazardousCargo => 'بضاعة خطرة';

  @override
  String get requirementFragileCargo => 'بضاعة قابلة للكسر';

  @override
  String get fieldRequirements => 'المتطلبات';

  @override
  String get sectionCargoDescription => 'وصف البضاعة';

  @override
  String get sectionPayment => 'الدفع';

  @override
  String get fieldPriceToYou => 'السعر المستحق لك';

  @override
  String get toBeConfirmed => 'سيتم تأكيده لاحقًا';

  @override
  String get acceptShipmentButton => 'قبول الشحنة';

  @override
  String get myShipmentOffersTitle => 'عروض شحناتي';

  @override
  String get newOfferButton => 'عرض جديد';

  @override
  String get failedToLoadOffers => 'فشل تحميل العروض';

  @override
  String get noOffersYet => 'لا توجد عروض بعد';

  @override
  String get tapNewOfferHint => 'اضغط على \"عرض جديد\" لطلب شحنة.';

  @override
  String get offerStatusMatchingDrivers => 'جارٍ مطابقة السائقين';

  @override
  String get offerStatusAwaitingPrice => 'بانتظار السعر';

  @override
  String get offerStatusEscalated => 'تم التصعيد';

  @override
  String get offerStatusAccepted => 'مقبول';

  @override
  String get offerStatusCancelled => 'ملغى';

  @override
  String get offerStatusExpired => 'منتهي الصلاحية';

  @override
  String get raisePriceDialogTitle => 'رفع السعر إلى العميل';

  @override
  String get newPriceAedLabel => 'السعر الجديد (درهم)';

  @override
  String get cancelOfferDialogTitle => 'إلغاء العرض';

  @override
  String get reasonLabel => 'السبب';

  @override
  String get commonBack => 'رجوع';

  @override
  String get cancelOfferButton => 'إلغاء العرض';

  @override
  String get offerCancelledMsg => 'تم إلغاء العرض';

  @override
  String get failedToCancelOffer => 'فشل إلغاء العرض';

  @override
  String eligibleDriversCount(int count) {
    return '$count سائق مؤهل';
  }

  @override
  String priceToClientLabel(String price) {
    return 'السعر للعميل: $price درهم';
  }

  @override
  String get manualSuffix => ' (يدوي)';

  @override
  String get raisePriceButton => 'رفع السعر';

  @override
  String get cancelThisOfferTitle => 'إلغاء هذا العرض؟';

  @override
  String get cancellationReasonHint => 'سبب الإلغاء';

  @override
  String get couldNotCancelOffer => 'تعذّر إلغاء العرض';

  @override
  String get notFoundLabel => 'غير موجود';

  @override
  String get waitingForDriverCardTitle => 'بانتظار السائق';

  @override
  String get findingBestMatchedDrivers =>
      'نقوم بإيجاد أفضل السائقين المطابقين لهذه الشحنة.';

  @override
  String get statEligibleDrivers => 'السائقون المؤهلون';

  @override
  String get statOffersSent => 'العروض المرسلة';

  @override
  String get statCurrentRound => 'الجولة الحالية';

  @override
  String get cancellationSectionTitle => 'الإلغاء';

  @override
  String get fieldReason => 'السبب';

  @override
  String get fieldCancelledBy => 'أُلغي بواسطة';

  @override
  String get fieldCancelledAt => 'تاريخ الإلغاء';

  @override
  String get pricingReferenceSectionTitle =>
      'السعر المرجعي (محرك التسعير الذكي)';

  @override
  String get fieldHistoricalReference => 'السعر المرجعي السابق';

  @override
  String get fieldTypicalRange => 'النطاق المعتاد';

  @override
  String get fieldConfidence => 'مستوى الثقة';

  @override
  String get fieldMarketAdjustmentApplied => 'تعديل السوق المطبّق';

  @override
  String get fieldCompanyWasCharged => 'المبلغ المحصّل من الشركة';

  @override
  String get matchingTimelineTitle => 'الجدول الزمني للمطابقة';

  @override
  String get noMatchingRoundsYet => 'لا توجد جولات مطابقة بعد.';

  @override
  String roundAcceptedBy(String name) {
    return 'قُبل من قبل $name';
  }

  @override
  String get roundAccepted => 'مقبول';

  @override
  String get roundNoAcceptance => 'لا يوجد قبول';

  @override
  String get roundWaitingForResponse => 'بانتظار الرد';

  @override
  String roundNotifiedLabel(String round, String count) {
    return 'الجولة $round • تم إشعار $count سائق';
  }

  @override
  String get decisionApprovedTitle => 'تمت الموافقة على الطلب';

  @override
  String get decisionChangesRequestedTitle => 'تم طلب تعديلات';

  @override
  String get decisionRejectedTitle => 'تم رفض الطلب';

  @override
  String decisionApprovedMessageDriver(String name) {
    return 'تمت الموافقة على $name ويمكنه الآن استخدام التطبيق ومطابقته مع الشحنات.';
  }

  @override
  String decisionApprovedMessageCompany(String name) {
    return 'تمت الموافقة على $name ويمكنها الآن استخدام التطبيق.';
  }

  @override
  String decisionChangesRequiredMessage(String name) {
    return 'تم إشعار $name بالتعديلات المطلوبة، ويمكن إعادة الإرسال بعد إصلاحها.';
  }

  @override
  String decisionRejectedMessageDriver(String name) {
    return 'تم رفض تسجيل السائق $name. تم إشعاره بذلك.';
  }

  @override
  String decisionRejectedMessageCompany(String name) {
    return 'تم رفض تسجيل الشركة $name. تم إشعارها بذلك.';
  }

  @override
  String get backToRequestsButton => 'العودة إلى الطلبات';

  @override
  String get cancelledLabel => 'ملغاة';

  @override
  String get cancellationSummaryTitle => 'ملخص الإلغاء';

  @override
  String get financialImpactTitle => 'الأثر المالي';

  @override
  String get fieldDriverAssigned => 'تم تعيين سائق';

  @override
  String get fieldStageReached => 'المرحلة التي وصل إليها';

  @override
  String get fieldClientPrice => 'سعر العميل';

  @override
  String get fieldDriverPrice => 'سعر السائق';

  @override
  String get deliveredLabel => 'تم التسليم';

  @override
  String get statDistance => 'المسافة';

  @override
  String get statDuration => 'المدة';

  @override
  String get statPickupTime => 'وقت الاستلام';

  @override
  String get statDeliveryTime => 'وقت التسليم';

  @override
  String get tripTimelineTitle => 'الجدول الزمني للرحلة';

  @override
  String get driverAndTruckTitle => 'السائق والشاحنة';

  @override
  String get fieldDriverLabel => 'السائق';

  @override
  String get fieldPhone => 'الهاتف';

  @override
  String get fieldTruck => 'الشاحنة';

  @override
  String get financialSummaryTitle => 'الملخص المالي';

  @override
  String get fieldCommission => 'العمولة';

  @override
  String get proofOfDeliveryTitle => 'إثبات التسليم';

  @override
  String receiverLabel(String name) {
    return 'المستلم: $name';
  }

  @override
  String get documentUnavailable => 'المستند غير متاح';

  @override
  String get viewDeliveryDocument => 'عرض مستند التسليم';

  @override
  String get signatureUnavailable => 'التوقيع غير متاح';

  @override
  String get noUpdateYet => 'لا يوجد تحديث بعد';

  @override
  String minAgoFull(int minutes) {
    return 'منذ $minutes دقيقة';
  }

  @override
  String lastLocationUpdateLabel(String ago) {
    return 'آخر تحديث للموقع: $ago';
  }

  @override
  String get shipmentProgressTitle => 'تقدّم الشحنة';

  @override
  String get sectionShipmentDetails => 'تفاصيل الشحنة';

  @override
  String get fieldNeedsPermit => 'يتطلب تصريحًا';

  @override
  String get fieldRating => 'التقييم';

  @override
  String get companySectionTitle => 'الشركة';

  @override
  String get fieldName => 'الاسم';

  @override
  String get noLocationDataYet => 'لا تتوفر بيانات موقع لهذه الشحنة بعد';

  @override
  String get neverLabel => 'أبدًا';

  @override
  String get liveTrackingTitle => 'التتبع المباشر';

  @override
  String updatedAgoLabel(String ago) {
    return 'آخر تحديث $ago';
  }

  @override
  String get noGpsFixYet => 'لا يوجد تحديد موقع بعد';

  @override
  String get noGpsPositionYetBody =>
      'لم يقم السائق بإرسال موقعه بعد — سيتحدث هذا تلقائيًا بمجرد أن يفعل (يقوم التطبيق بإرسال الموقع أثناء تنفيذ الشحنة).';

  @override
  String get complianceReportsTitle => 'تقارير الالتزام';

  @override
  String get couldNotLoadReports => 'تعذّر تحميل التقارير';

  @override
  String get noComplianceReportsClean =>
      'لا توجد تقارير التزام مسجلة — سجل نظيف.';

  @override
  String get appealThisDecisionTitle => 'الطعن في هذا القرار';

  @override
  String get appealHint => 'اشرح سبب اعتقادك أن هذا القرار كان خاطئًا';

  @override
  String get submitAppealButton => 'إرسال الطعن';

  @override
  String actionLabel(String action) {
    return 'الإجراء: $action';
  }

  @override
  String appealLabel(String status) {
    return 'الطعن: $status';
  }

  @override
  String get appealButton => 'طعن';

  @override
  String get couldNotFindRecord => 'تعذّر العثور على هذا السجل';

  @override
  String get expiredDocumentsTitle => 'مستندات منتهية الصلاحية';

  @override
  String get documentsExpiringSoonTitle => 'مستندات على وشك الانتهاء';

  @override
  String get docTypeLicense => 'الرخصة';

  @override
  String get docTypePassport => 'جواز السفر';

  @override
  String get docTypeResidency => 'الإقامة';

  @override
  String get docTypeInsurance => 'التأمين';

  @override
  String get docTypeTechnicalInspection => 'الفحص الفني';

  @override
  String get docTypeTradeLicense => 'الرخصة التجارية';

  @override
  String docTypeTruckLabel(String label) {
    return 'شاحنة - $label';
  }

  @override
  String get searchByNameHint => 'ابحث بالاسم...';

  @override
  String couldNotLoadListError(String error) {
    return 'تعذّر تحميل القائمة.\n$error';
  }

  @override
  String get nothingHereRightNow => 'لا يوجد شيء هنا حاليًا.';

  @override
  String docAlertSubtitle(String type, String date) {
    return '$type · تنتهي في $date';
  }

  @override
  String get resolveReportTitle => 'حل التقرير';

  @override
  String get decisionDismiss => 'رفض التقرير';

  @override
  String get decisionUphold => 'تأييد التقرير';

  @override
  String get actionWarning => 'تحذير';

  @override
  String get actionSuspension => 'إيقاف مؤقت';

  @override
  String get actionBan => 'حظر';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get complianceTitle => 'الالتزام';

  @override
  String get tabReports => 'التقارير';

  @override
  String get tabAppeals => 'الطعون';

  @override
  String get noReportsPendingReview => 'لا توجد تقارير بانتظار المراجعة';

  @override
  String get noPendingAppeals => 'لا توجد طعون معلقة';

  @override
  String get resolveButton => 'حل';

  @override
  String get rejectAppealButton => 'رفض الطعن';

  @override
  String get acceptAppealButton => 'قبول الطعن';

  @override
  String driverHashLabel(String id) {
    return 'السائق #$id';
  }

  @override
  String get requestChangesDialogTitle => 'طلب تعديلات';

  @override
  String get requestChangesReasonHint =>
      'السبب (مثال: صورة غير واضحة، مستند خاطئ، منتهي الصلاحية)';

  @override
  String get sendBackButton => 'إعادة الإرسال';

  @override
  String get documentRenewalTitle => 'تجديد المستند';

  @override
  String userHashLabel(String id) {
    return 'المستخدم #$id';
  }

  @override
  String get oldDocumentTitle => 'المستند القديم';

  @override
  String get newDocumentTitle => 'المستند الجديد';

  @override
  String get fieldStatus => 'الحالة';

  @override
  String get noPreviousDocument => 'لا يوجد مستند سابق مسجل';

  @override
  String get fieldExpiryDate => 'تاريخ الانتهاء';

  @override
  String get fieldNewExpiryDate => 'تاريخ الانتهاء الجديد';

  @override
  String get fieldSubmitted => 'تاريخ الإرسال';

  @override
  String get statusPendingReview => 'بانتظار المراجعة';

  @override
  String get requestChangesButton => 'طلب تعديلات';

  @override
  String get approveButton => 'موافقة';

  @override
  String get previewDocumentButton => 'معاينة المستند';

  @override
  String get shipmentTrackingTitle => 'تتبع الشحنة';

  @override
  String get addCommentTooltip => 'إضافة تعليق';

  @override
  String get liveLabel => 'مباشر';

  @override
  String get deliveryStatusAwaitingConfirmation => 'بانتظار التأكيد';

  @override
  String get deliveryStatusConfirmed => 'مؤكد';

  @override
  String get deliveryStatusDisputed => 'متنازع عليه';

  @override
  String get deliveryStatusNotDelivered => 'لم يتم التسليم';

  @override
  String receivedByLabel(String name) {
    return 'استلمها: $name';
  }

  @override
  String get addCommentDialogTitle => 'إضافة تعليق';

  @override
  String get addCommentHint => 'مثال: عطل بالشاحنة، إغلاق طريق...';

  @override
  String get commentAddedMsg => 'تمت إضافة التعليق';

  @override
  String get failedToAddComment => 'فشل إضافة التعليق';

  @override
  String get failedGeneric => 'فشل';

  @override
  String get deliveryRecordedMsg =>
      'تم تسجيل التسليم — بانتظار تأكيد الشركة قبل صرف المستحقات';

  @override
  String get captureProofOfDeliveryButton => 'التقاط إثبات التسليم';

  @override
  String markAsLabel(String label) {
    return 'تحديد كـ: $label';
  }

  @override
  String get noGpsFixUpdatesAutomatically =>
      'لا يوجد تحديد موقع بعد — سيتحدث تلقائيًا بمجرد أن يرسل السائق موقعه';

  @override
  String get docStatusExpired => 'منتهي الصلاحية';

  @override
  String get docStatusExpiringSoon => 'على وشك الانتهاء';

  @override
  String get docStatusValid => 'ساري المفعول';

  @override
  String get docStatusChangesRequired => 'مطلوب تعديلات';

  @override
  String get docStatusNotUploaded => 'لم يُرفع بعد';

  @override
  String uploadDialogTitle(String label) {
    return 'رفع $label';
  }

  @override
  String get chooseFileHint => 'اختر ملفًا (PDF/JPG/PNG)';

  @override
  String get expiryDateOptionalHint => 'تاريخ الانتهاء (اختياري)';

  @override
  String get uploadButton => 'رفع';

  @override
  String renewDialogTitle(String label) {
    return 'تجديد $label';
  }

  @override
  String get newExpiryDateHint => 'تاريخ الانتهاء الجديد';

  @override
  String get submitForReviewButton => 'إرسال للمراجعة';

  @override
  String get driverDocumentsTabLabel => 'مستندات السائق';

  @override
  String get truckDocumentsTabLabel => 'مستندات الشاحنة';

  @override
  String get couldNotLoadTruckDocs => 'تعذّر تحميل مستندات الشاحنة';

  @override
  String get noTruckRegisteredYet => 'لا توجد شاحنة مسجلة بعد';

  @override
  String get renewingSubmitsForReviewNote =>
      'تجديد المستند هنا يرسله لمراجعة الإدارة — يُطبَّق بعد الموافقة عليه.';

  @override
  String get vehicleLicenseLabel => 'رخصة المركبة';

  @override
  String expDateLabel(String date) {
    return 'تنتهي في $date';
  }

  @override
  String get viewButton => 'عرض';

  @override
  String get renewButton => 'تجديد';

  @override
  String get couldNotLoadDocumentsMsg => 'تعذّر تحميل المستندات';

  @override
  String get mandatoryDocsBlockNote =>
      'المستندات الإلزامية المفقودة أو منتهية الصلاحية أو التي على وشك الانتهاء (الرخصة، جواز السفر، الإقامة) ستمنع حسابك من مطابقته مع الشحنات حتى يتم تجديدها والموافقة عليها.';
}

import 'locale_controller.dart';

/// Display-only EN/AR translation for the bounded option lists
/// DriverRegisterScreen offers where the *value actually submitted to the
/// backend* is a literal string (Truck::TRUCK_TYPES, the free-text
/// health-condition labels) rather than a separate internal key — unlike
/// kDriverDestinationOptions, which already maps an internal key
/// ('internal_uae', ...) to an English label and sends the key.
///
/// These maps only ever affect what's *shown* in the picker sheets and the
/// selected-value display; CompleteDriverRegistrationScreen.dart still
/// stores and submits the original English constant from
/// kDriverTruckTypes/kHealthConditionOptions to
/// ApiService.completeDriverRegistration() untouched — translating what
/// gets sent would be a schema/business-logic change, out of scope here
/// (see the task's "do not change" list).
const Map<String, String> kTruckTypeLabelsAr = {
  '3 Ton pick up': 'بيك أب 3 طن',
  '7 Ton pick up': 'بيك أب 7 طن',
  '10 Ton pick up': 'بيك أب 10 طن',
  'Trailer 40 FT-12M-Open': 'مقطورة 40 قدم - 12م - مكشوفة',
  'Trailer 40 FT-12M-Box': 'مقطورة 40 قدم - 12م - صندوق',
  'Trailer 50 FT-15M-Open': 'مقطورة 50 قدم - 15م - مكشوفة',
  'Curtain Trailer 13.5M': 'مقطورة ستائرية 13.5م',
  'Curtain Trailer 15M': 'مقطورة ستائرية 15م',
  'Reefer Trailer': 'مقطورة مبردة',
  'Lowbed Trailer - 25 Tons': 'مقطورة لوبد - 25 طن',
  'Car Career': 'ناقلة سيارات',
};

const Map<String, String> kHealthConditionLabelsAr = {
  'Healthy / no conditions': 'سليم / لا توجد حالات صحية',
  'Diabetes': 'السكري',
  'Heart disease': 'أمراض القلب',
  'High blood pressure': 'ضغط الدم المرتفع',
  'Epilepsy / seizure disorder': 'الصرع / اضطراب النوبات',
  'Vision impairment': 'ضعف البصر',
  'Hearing impairment': 'ضعف السمع',
  'Respiratory condition (e.g. asthma)': 'حالة تنفسية (مثل الربو)',
  'Back / spinal issue': 'مشكلة في الظهر / العمود الفقري',
  'Other': 'أخرى',
};

/// Parallel to DriverRegisterScreen's kDriverDestinationOptions (internal
/// key -> English label). Same key set; the internal key is what's
/// actually submitted (`destinations: _destinations.toList()`), so this
/// is a pure display-layer addition.
const Map<String, String> kDriverDestinationLabelsAr = {
  'internal_uae': 'داخل الإمارات',
  'saudi_arabia': 'السعودية',
  'oman': 'عُمان',
  'kuwait': 'الكويت',
  'bahrain': 'البحرين',
  'jordan': 'الأردن',
  'lebanon': 'لبنان',
  'syria': 'سوريا',
  'egypt': 'مصر',
  'iraq': 'العراق',
  'yemen': 'اليمن',
};

/// Shipment.stageLabels (internal/external tracking-timeline stage names)
/// are a static const English map on the Shipment model itself — keying off
/// the exact English string here (same pattern as kTruckTypeLabelsAr) is a
/// display-only addition; the model's stage *numbers* (what's actually
/// compared/advanced) are never touched.
const Map<String, String> kShipmentStageLabelsAr = {
  'Going to load': 'التوجه للتحميل',
  'Loading': 'جارٍ التحميل',
  'To destination': 'في الطريق إلى الوجهة',
  'Offloading': 'جارٍ التفريغ',
  'Uploading delivery note': 'رفع إشعار التسليم',
  'Completed': 'مكتمل',
  'To border': 'في الطريق إلى الحدود',
  'Crossing the border': 'عبور الحدود',
};

String localizedStageLabel(String english) =>
    LocaleController.isArabic ? (kShipmentStageLabelsAr[english] ?? english) : english;

/// kDriverDocumentTypes (models/DriverDocument.dart) — same display-only
/// pattern: keyed by the exact English label, submission still uses
/// DriverDocumentType.key ('license', 'passport', ...) untouched.
const Map<String, String> kDriverDocTypeLabelsAr = {
  'Driving License': 'رخصة القيادة',
  'Passport': 'جواز السفر',
  'Residency': 'الإقامة',
  'ID Card': 'بطاقة الهوية',
  'Medical Certificate': 'الشهادة الطبية',
  'Other': 'أخرى',
};

String localizedDriverDocType(String english) =>
    LocaleController.isArabic ? (kDriverDocTypeLabelsAr[english] ?? english) : english;

String localizedTruckType(String english) =>
    LocaleController.isArabic ? (kTruckTypeLabelsAr[english] ?? english) : english;

String localizedHealthCondition(String english) =>
    LocaleController.isArabic ? (kHealthConditionLabelsAr[english] ?? english) : english;

/// [key] is the internal destination key ('internal_uae', ...), [enLabel]
/// is DriverRegisterScreen's own English label for it
/// (kDriverDestinationOptions[key]) — passed in rather than re-imported to
/// avoid a circular import between DriverRegisterScreen.dart and this file.
String localizedDestination(String key, String enLabel) =>
    LocaleController.isArabic ? (kDriverDestinationLabelsAr[key] ?? enLabel) : enLabel;

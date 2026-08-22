import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'FMS'**
  String get appName;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get commonUpload;

  /// No description provided for @commonUploadHintFormats.
  ///
  /// In en, this message translates to:
  /// **'PDF/JPG/PNG'**
  String get commonUploadHintFormats;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @languageSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingTitle;

  /// No description provided for @languageSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app\'s display language'**
  String get languageSettingSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get languagePickerTitle;

  /// No description provided for @logOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOutLabel;

  /// No description provided for @logOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOutTitle;

  /// No description provided for @logOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logOutConfirmMessage;

  /// No description provided for @logOutBlockedActiveTrip.
  ///
  /// In en, this message translates to:
  /// **'You can\'t log out while a trip is in progress. Finish or hand off the trip first.'**
  String get logOutBlockedActiveTrip;

  /// No description provided for @logOutTooltipBlocked.
  ///
  /// In en, this message translates to:
  /// **'Log out (unavailable during an active trip)'**
  String get logOutTooltipBlocked;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FMS'**
  String get loginWelcomeTitle;

  /// No description provided for @loginWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your account'**
  String get loginWelcomeSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordSnack.
  ///
  /// In en, this message translates to:
  /// **'Contact your admin to reset your password'**
  String get forgotPasswordSnack;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @featureSecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure & Reliable'**
  String get featureSecureTitle;

  /// No description provided for @featureSecureDesc.
  ///
  /// In en, this message translates to:
  /// **'Your data protected at the highest level'**
  String get featureSecureDesc;

  /// No description provided for @featureEasyTitle.
  ///
  /// In en, this message translates to:
  /// **'Easy Management'**
  String get featureEasyTitle;

  /// No description provided for @featureEasyDesc.
  ///
  /// In en, this message translates to:
  /// **'Track your shipments in real time'**
  String get featureEasyDesc;

  /// No description provided for @featureReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Reports'**
  String get featureReportsTitle;

  /// No description provided for @featureReportsDesc.
  ///
  /// In en, this message translates to:
  /// **'Accurate analytics and reports'**
  String get featureReportsDesc;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @errorFillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get errorFillAllFields;

  /// No description provided for @loggingInTitle.
  ///
  /// In en, this message translates to:
  /// **'Logging you in...'**
  String get loggingInTitle;

  /// No description provided for @loggingInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment'**
  String get loggingInSubtitle;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your\naccount.'**
  String get createAccountTitle;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the kind of account you need'**
  String get createAccountSubtitle;

  /// No description provided for @roleCompanyTitle.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get roleCompanyTitle;

  /// No description provided for @roleCompanySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ship your cargo — request trucks and track deliveries'**
  String get roleCompanySubtitle;

  /// No description provided for @roleDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Individual (Driver)'**
  String get roleDriverTitle;

  /// No description provided for @roleDriverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drive your own truck — get matched with shipments'**
  String get roleDriverSubtitle;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @stepXofY.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepXofY(int current, int total);

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @stepAccountInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get stepAccountInfoTitle;

  /// No description provided for @stepAccountInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your account details'**
  String get stepAccountInfoSubtitle;

  /// No description provided for @stepReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Your Information'**
  String get stepReviewTitle;

  /// No description provided for @stepReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please review all information before submitting'**
  String get stepReviewSubtitle;

  /// No description provided for @documentsNotice.
  ///
  /// In en, this message translates to:
  /// **'All documents must be clear and valid. Expired documents are not accepted.'**
  String get documentsNotice;

  /// No description provided for @reviewCannotEditNotice.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be able to edit this after submission.'**
  String get reviewCannotEditNotice;

  /// No description provided for @submitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get submitForReview;

  /// No description provided for @validationFillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get validationFillRequired;

  /// No description provided for @validationInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get validationInvalidEmail;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @errorSubmitGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while submitting: {error}'**
  String errorSubmitGeneric(String error);

  /// No description provided for @companyRegStepCompanyTitle.
  ///
  /// In en, this message translates to:
  /// **'Company Information'**
  String get companyRegStepCompanyTitle;

  /// No description provided for @companyRegStepCompanySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your company'**
  String get companyRegStepCompanySubtitle;

  /// No description provided for @companyRegStepDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Company Documents'**
  String get companyRegStepDocumentsTitle;

  /// No description provided for @companyRegStepDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All documents are mandatory'**
  String get companyRegStepDocumentsSubtitle;

  /// No description provided for @companyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get companyNameLabel;

  /// No description provided for @companyNameHint.
  ///
  /// In en, this message translates to:
  /// **'Global Logistics LLC'**
  String get companyNameHint;

  /// No description provided for @companyEmailHint.
  ///
  /// In en, this message translates to:
  /// **'contact@company.com'**
  String get companyEmailHint;

  /// No description provided for @companyAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Conditions and Privacy Policy'**
  String get companyAgreeTerms;

  /// No description provided for @companyPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get companyPhoneLabel;

  /// No description provided for @companyPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'+971 4 123 4567'**
  String get companyPhoneHint;

  /// No description provided for @companyAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Company Address'**
  String get companyAddressLabel;

  /// No description provided for @companyAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Street, city, country'**
  String get companyAddressHint;

  /// No description provided for @tradeLicenseLabel.
  ///
  /// In en, this message translates to:
  /// **'Trade License'**
  String get tradeLicenseLabel;

  /// No description provided for @tradeLicenseUploaded.
  ///
  /// In en, this message translates to:
  /// **'Trade license uploaded'**
  String get tradeLicenseUploaded;

  /// No description provided for @noDocumentUploaded.
  ///
  /// In en, this message translates to:
  /// **'No document uploaded'**
  String get noDocumentUploaded;

  /// No description provided for @validationAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms & Conditions'**
  String get validationAgreeTerms;

  /// No description provided for @validationCompanyPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter your company phone number'**
  String get validationCompanyPhone;

  /// No description provided for @validationCompanyAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter your company address'**
  String get validationCompanyAddress;

  /// No description provided for @validationAttachLicense.
  ///
  /// In en, this message translates to:
  /// **'Please attach your trade license'**
  String get validationAttachLicense;

  /// No description provided for @driverRegStepDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Information'**
  String get driverRegStepDriverTitle;

  /// No description provided for @driverRegStepDriverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All fields are mandatory'**
  String get driverRegStepDriverSubtitle;

  /// No description provided for @driverRegStepDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Documents'**
  String get driverRegStepDocumentsTitle;

  /// No description provided for @driverRegStepDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All documents are mandatory'**
  String get driverRegStepDocumentsSubtitle;

  /// No description provided for @driverRegStepHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health & Coverage'**
  String get driverRegStepHealthTitle;

  /// No description provided for @driverRegStepHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your health and work coverage'**
  String get driverRegStepHealthSubtitle;

  /// No description provided for @driverRegStepTruckTitle.
  ///
  /// In en, this message translates to:
  /// **'Truck Information'**
  String get driverRegStepTruckTitle;

  /// No description provided for @driverRegStepTruckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your truck details'**
  String get driverRegStepTruckSubtitle;

  /// No description provided for @driverRegStepTruckDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'Truck Documents'**
  String get driverRegStepTruckDocsTitle;

  /// No description provided for @driverRegStepTruckDocsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All documents are mandatory'**
  String get driverRegStepTruckDocsSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Mohamed Ali'**
  String get fullNameHint;

  /// No description provided for @driverEmailHint.
  ///
  /// In en, this message translates to:
  /// **'mohamed.ali@example.com'**
  String get driverEmailHint;

  /// No description provided for @driverAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Conditions'**
  String get driverAgreeTerms;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeLabel;

  /// No description provided for @phoneCountryTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone country'**
  String get phoneCountryTitle;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'50 123 4567'**
  String get phoneNumberHint;

  /// No description provided for @nationalityLabel.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get nationalityLabel;

  /// No description provided for @nationalityHint.
  ///
  /// In en, this message translates to:
  /// **'Select nationality'**
  String get nationalityHint;

  /// No description provided for @nationalityTitle.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get nationalityTitle;

  /// No description provided for @dateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirthLabel;

  /// No description provided for @dateOfBirthHint.
  ///
  /// In en, this message translates to:
  /// **'15 / 05 / 1992'**
  String get dateOfBirthHint;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @driverLicenseNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver License Number'**
  String get driverLicenseNumberLabel;

  /// No description provided for @driverLicenseNumberHint.
  ///
  /// In en, this message translates to:
  /// **'D1234567'**
  String get driverLicenseNumberHint;

  /// No description provided for @searchCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Search country'**
  String get searchCountryHint;

  /// No description provided for @docLicenseFront.
  ///
  /// In en, this message translates to:
  /// **'Driving license — front'**
  String get docLicenseFront;

  /// No description provided for @docLicenseBack.
  ///
  /// In en, this message translates to:
  /// **'Driving license — back (optional)'**
  String get docLicenseBack;

  /// No description provided for @docPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport (first page)'**
  String get docPassport;

  /// No description provided for @docResidency.
  ///
  /// In en, this message translates to:
  /// **'Emirates ID / Residency'**
  String get docResidency;

  /// No description provided for @docDriverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Driver photo (optional)'**
  String get docDriverPhoto;

  /// No description provided for @docDriverPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'A clear portrait photo'**
  String get docDriverPhotoHint;

  /// No description provided for @expiryDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiryDateLabel;

  /// No description provided for @expiryDateHint.
  ///
  /// In en, this message translates to:
  /// **'dd/mm/yyyy'**
  String get expiryDateHint;

  /// No description provided for @healthStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Health Status'**
  String get healthStatusLabel;

  /// No description provided for @healthStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Select any conditions'**
  String get healthStatusHint;

  /// No description provided for @healthStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Health status'**
  String get healthStatusTitle;

  /// No description provided for @describeOtherCondition.
  ///
  /// In en, this message translates to:
  /// **'Describe the other condition'**
  String get describeOtherCondition;

  /// No description provided for @bloodTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get bloodTypeLabel;

  /// No description provided for @bloodTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select blood type'**
  String get bloodTypeHint;

  /// No description provided for @bloodTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Blood type'**
  String get bloodTypeTitle;

  /// No description provided for @workDestinationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Work Destinations'**
  String get workDestinationsLabel;

  /// No description provided for @workDestinationsHint.
  ///
  /// In en, this message translates to:
  /// **'Countries you operate in'**
  String get workDestinationsHint;

  /// No description provided for @workDestinationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Work destinations'**
  String get workDestinationsTitle;

  /// No description provided for @truckTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Truck Type'**
  String get truckTypeLabel;

  /// No description provided for @truckTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select truck type'**
  String get truckTypeHint;

  /// No description provided for @truckTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Truck type'**
  String get truckTypeTitle;

  /// No description provided for @truckPlateLabel.
  ///
  /// In en, this message translates to:
  /// **'Truck Plate / Number'**
  String get truckPlateLabel;

  /// No description provided for @truckPlateHint.
  ///
  /// In en, this message translates to:
  /// **'C 12345'**
  String get truckPlateHint;

  /// No description provided for @permitTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Permit Type (optional)'**
  String get permitTypeLabel;

  /// No description provided for @docVehicleReg.
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration'**
  String get docVehicleReg;

  /// No description provided for @docInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance (optional)'**
  String get docInsurance;

  /// No description provided for @docInspection.
  ///
  /// In en, this message translates to:
  /// **'Technical inspection (optional)'**
  String get docInspection;

  /// No description provided for @truckDocsNotice.
  ///
  /// In en, this message translates to:
  /// **'Make sure the vehicle registration is valid — expired documents are not accepted.'**
  String get truckDocsNotice;

  /// No description provided for @reviewAccountInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get reviewAccountInfoTitle;

  /// No description provided for @reviewDriverInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Information'**
  String get reviewDriverInfoTitle;

  /// No description provided for @reviewDriverDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Documents'**
  String get reviewDriverDocsTitle;

  /// No description provided for @reviewCompanyInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Company Information'**
  String get reviewCompanyInfoTitle;

  /// No description provided for @reviewTruckInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Truck Information'**
  String get reviewTruckInfoTitle;

  /// No description provided for @reviewTruckDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'Truck Documents'**
  String get reviewTruckDocsTitle;

  /// No description provided for @uploadedCountOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{count}/{total} uploaded'**
  String uploadedCountOfTotal(int count, int total);

  /// No description provided for @licenseNumberPrefix.
  ///
  /// In en, this message translates to:
  /// **'License #{number}'**
  String licenseNumberPrefix(String number);

  /// No description provided for @driverValidationAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms of Service and Privacy Policy'**
  String get driverValidationAgreeTerms;

  /// No description provided for @driverValidationPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number (digits only)'**
  String get driverValidationPhone;

  /// No description provided for @driverValidationNationality.
  ///
  /// In en, this message translates to:
  /// **'Please select your nationality'**
  String get driverValidationNationality;

  /// No description provided for @driverValidationDob.
  ///
  /// In en, this message translates to:
  /// **'Please select your date of birth'**
  String get driverValidationDob;

  /// No description provided for @driverValidationAge.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 18 and 65'**
  String get driverValidationAge;

  /// No description provided for @driverValidationLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your driving license number'**
  String get driverValidationLicenseNumber;

  /// No description provided for @driverValidationLicenseDoc.
  ///
  /// In en, this message translates to:
  /// **'Please attach your driving license (front) and its expiry date'**
  String get driverValidationLicenseDoc;

  /// No description provided for @driverValidationPassportDoc.
  ///
  /// In en, this message translates to:
  /// **'Please attach your passport and its expiry date'**
  String get driverValidationPassportDoc;

  /// No description provided for @driverValidationResidencyDoc.
  ///
  /// In en, this message translates to:
  /// **'Please attach your Emirates ID / residency and its expiry date'**
  String get driverValidationResidencyDoc;

  /// No description provided for @driverValidationBloodType.
  ///
  /// In en, this message translates to:
  /// **'Please select your blood type'**
  String get driverValidationBloodType;

  /// No description provided for @driverValidationDestinations.
  ///
  /// In en, this message translates to:
  /// **'Please pick at least one destination you work on'**
  String get driverValidationDestinations;

  /// No description provided for @driverValidationTruckType.
  ///
  /// In en, this message translates to:
  /// **'Please select your truck type'**
  String get driverValidationTruckType;

  /// No description provided for @driverValidationTruckPlate.
  ///
  /// In en, this message translates to:
  /// **'Please enter your truck plate/number'**
  String get driverValidationTruckPlate;

  /// No description provided for @driverValidationVehicleRegDoc.
  ///
  /// In en, this message translates to:
  /// **'Please attach the vehicle registration file'**
  String get driverValidationVehicleRegDoc;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your\nemail.'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}'**
  String otpSubtitle(String email);

  /// No description provided for @otpEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we emailed you'**
  String get otpEnterCode;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResendCode;

  /// No description provided for @otpResendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String otpResendCodeIn(int seconds);

  /// No description provided for @otpResentTo.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent to {email}'**
  String otpResentTo(String email);

  /// No description provided for @otpSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String otpSomethingWrong(String error);

  /// No description provided for @forceChangePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new\npassword.'**
  String get forceChangePasswordTitle;

  /// No description provided for @forceChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For security, you must set your own password before continuing.'**
  String get forceChangePasswordSubtitle;

  /// No description provided for @temporaryPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get temporaryPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPasswordLabel;

  /// No description provided for @passwordRequirementsHint.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters, upper & lower case, a number and a symbol.'**
  String get passwordRequirementsHint;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navShipments.
  ///
  /// In en, this message translates to:
  /// **'Shipments'**
  String get navShipments;

  /// No description provided for @navWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get navWallet;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get navFinance;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get navApprovals;

  /// No description provided for @navMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// No description provided for @navOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get navOffers;

  /// No description provided for @navDrivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get navDrivers;

  /// No description provided for @navCompanies.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get navCompanies;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @drawerDrivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get drawerDrivers;

  /// No description provided for @drawerCompanies.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get drawerCompanies;

  /// No description provided for @drawerOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get drawerOffers;

  /// No description provided for @drawerWorkDestinations.
  ///
  /// In en, this message translates to:
  /// **'Work Destinations'**
  String get drawerWorkDestinations;

  /// No description provided for @drawerReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get drawerReports;

  /// No description provided for @drawerNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get drawerNotifications;

  /// No description provided for @drawerActivityLog.
  ///
  /// In en, this message translates to:
  /// **'Activity Log'**
  String get drawerActivityLog;

  /// No description provided for @drawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawerSettings;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get roleSuperAdmin;

  /// No description provided for @roleSubAdmin.
  ///
  /// In en, this message translates to:
  /// **'Sub Admin'**
  String get roleSubAdmin;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No settings are available for your current permissions.'**
  String get settingsNoneAvailable;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionAdministration.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get settingsSectionAdministration;

  /// No description provided for @settingsSectionFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance & Payments'**
  String get settingsSectionFinance;

  /// No description provided for @settingsSectionRecycleBin.
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin'**
  String get settingsSectionRecycleBin;

  /// No description provided for @adminAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Accounts'**
  String get adminAccountsTitle;

  /// No description provided for @adminAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create sub-admins, manage permissions, suspend or remove them'**
  String get adminAccountsSubtitle;

  /// No description provided for @profileEditRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Edit Requests'**
  String get profileEditRequestsTitle;

  /// No description provided for @profileEditRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review driver/company self-service changes before they apply'**
  String get profileEditRequestsSubtitle;

  /// No description provided for @financeTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get financeTileTitle;

  /// No description provided for @financeTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review top-ups, driver payouts, and set company credit limits'**
  String get financeTileSubtitle;

  /// No description provided for @priceListTitle.
  ///
  /// In en, this message translates to:
  /// **'Price List'**
  String get priceListTitle;

  /// No description provided for @priceListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Finance Admin: export/import the central price matrix'**
  String get priceListSubtitle;

  /// No description provided for @zonePricingTitle.
  ///
  /// In en, this message translates to:
  /// **'Zone Pricing'**
  String get zonePricingTitle;

  /// No description provided for @zonePricingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Pricing Engine: review historical lanes, adjust market %'**
  String get zonePricingSubtitle;

  /// No description provided for @platformSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Settings'**
  String get platformSettingsTitle;

  /// No description provided for @platformSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Super Admin only — profit margin, matching weights/timeout, driver-ops defaults'**
  String get platformSettingsSubtitle;

  /// No description provided for @deletedDriversTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted Drivers'**
  String get deletedDriversTitle;

  /// No description provided for @deletedDriversSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore drivers removed from the system'**
  String get deletedDriversSubtitle;

  /// No description provided for @deletedCompaniesTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted Companies'**
  String get deletedCompaniesTitle;

  /// No description provided for @deletedCompaniesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore companies removed from the system'**
  String get deletedCompaniesSubtitle;

  /// No description provided for @couldntConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect'**
  String get couldntConnectTitle;

  /// No description provided for @couldntConnectBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re still signed in — this just couldn\'t reach the server. Check your connection and try again.'**
  String get couldntConnectBody;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @greetingComma.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String greetingComma(String greeting, String name);

  /// No description provided for @driveSafe.
  ///
  /// In en, this message translates to:
  /// **'Drive safe!'**
  String get driveSafe;

  /// No description provided for @activeTripBanner.
  ///
  /// In en, this message translates to:
  /// **'Active Trip — location sharing is on. Logout is unavailable until it ends.'**
  String get activeTripBanner;

  /// No description provided for @complianceExpiringTitle.
  ///
  /// In en, this message translates to:
  /// **'Document expiring soon'**
  String get complianceExpiringTitle;

  /// No description provided for @complianceExpiringBody.
  ///
  /// In en, this message translates to:
  /// **'A document is expiring soon — renew it now to avoid losing new shipment offers.'**
  String get complianceExpiringBody;

  /// No description provided for @compliancePendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Renewal under review'**
  String get compliancePendingTitle;

  /// No description provided for @compliancePendingBody.
  ///
  /// In en, this message translates to:
  /// **'Your renewal was submitted and is awaiting admin approval — you won\'t receive new shipment offers until it\'s approved.'**
  String get compliancePendingBody;

  /// No description provided for @complianceActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Action needed'**
  String get complianceActionTitle;

  /// No description provided for @complianceActionBody.
  ///
  /// In en, this message translates to:
  /// **'A document has expired — renew it now to keep receiving new shipment offers.'**
  String get complianceActionBody;

  /// No description provided for @walletBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalanceLabel;

  /// No description provided for @couldNotLoadWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Could not load wallet balance — showing AED 0 for now.'**
  String get couldNotLoadWalletBalance;

  /// No description provided for @quickOverview.
  ///
  /// In en, this message translates to:
  /// **'Quick Overview'**
  String get quickOverview;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @statActiveTrips.
  ///
  /// In en, this message translates to:
  /// **'Active Trips'**
  String get statActiveTrips;

  /// No description provided for @statUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statUpcoming;

  /// No description provided for @statCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statCompleted;

  /// No description provided for @statPendingPayments.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get statPendingPayments;

  /// No description provided for @currentTripLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Trip'**
  String get currentTripLabel;

  /// No description provided for @recentNotifications.
  ///
  /// In en, this message translates to:
  /// **'Recent Notifications'**
  String get recentNotifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @couldNotLoadShipments.
  ///
  /// In en, this message translates to:
  /// **'Could not load your shipments.\n{error}'**
  String couldNotLoadShipments(String error);

  /// No description provided for @viewTracking.
  ///
  /// In en, this message translates to:
  /// **'View Tracking'**
  String get viewTracking;

  /// No description provided for @companyHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what\'s moving today'**
  String get companyHomeSubtitle;

  /// No description provided for @blockedCreateShipmentExpiring.
  ///
  /// In en, this message translates to:
  /// **'Your trade license is expiring soon — renew it to avoid losing the ability to create shipments.'**
  String get blockedCreateShipmentExpiring;

  /// No description provided for @blockedCreateShipmentPending.
  ///
  /// In en, this message translates to:
  /// **'Your trade license renewal is still pending admin review.'**
  String get blockedCreateShipmentPending;

  /// No description provided for @blockedCreateShipmentExpired.
  ///
  /// In en, this message translates to:
  /// **'Your trade license has expired — renew it to create new shipments.'**
  String get blockedCreateShipmentExpired;

  /// No description provided for @trackAShipmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Track a Shipment'**
  String get trackAShipmentTitle;

  /// No description provided for @companyComplianceExpiringTitle.
  ///
  /// In en, this message translates to:
  /// **'Trade license expiring soon'**
  String get companyComplianceExpiringTitle;

  /// No description provided for @companyCompliancePendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Renewal under review'**
  String get companyCompliancePendingTitle;

  /// No description provided for @companyComplianceActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get companyComplianceActionTitle;

  /// No description provided for @companyComplianceExpiringBody.
  ///
  /// In en, this message translates to:
  /// **'Renew it before it expires to avoid losing the ability to create new shipments.'**
  String get companyComplianceExpiringBody;

  /// No description provided for @companyCompliancePendingBody.
  ///
  /// In en, this message translates to:
  /// **'Your renewed trade license was submitted and is awaiting admin approval.'**
  String get companyCompliancePendingBody;

  /// No description provided for @companyComplianceActionBody.
  ///
  /// In en, this message translates to:
  /// **'Renew your Trade License to create new shipments.'**
  String get companyComplianceActionBody;

  /// No description provided for @trackLiveShipmentOne.
  ///
  /// In en, this message translates to:
  /// **'Track Live Shipment'**
  String get trackLiveShipmentOne;

  /// No description provided for @trackLiveShipmentsMany.
  ///
  /// In en, this message translates to:
  /// **'Track {count} Live Shipments'**
  String trackLiveShipmentsMany(int count);

  /// No description provided for @onTheRoadNow.
  ///
  /// In en, this message translates to:
  /// **'On the road now — tap to view the live map'**
  String get onTheRoadNow;

  /// No description provided for @statActiveShipments.
  ///
  /// In en, this message translates to:
  /// **'Active Shipments'**
  String get statActiveShipments;

  /// No description provided for @statInTransit.
  ///
  /// In en, this message translates to:
  /// **'In Transit'**
  String get statInTransit;

  /// No description provided for @statPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statPending;

  /// No description provided for @statDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statDelivered;

  /// No description provided for @createShipment.
  ///
  /// In en, this message translates to:
  /// **'Create Shipment'**
  String get createShipment;

  /// No description provided for @createShipmentBlocked.
  ///
  /// In en, this message translates to:
  /// **'Create Shipment (Blocked)'**
  String get createShipmentBlocked;

  /// No description provided for @viewMyOffers.
  ///
  /// In en, this message translates to:
  /// **'View My Offers'**
  String get viewMyOffers;

  /// No description provided for @recentShipments.
  ///
  /// In en, this message translates to:
  /// **'Recent Shipments'**
  String get recentShipments;

  /// No description provided for @noShipmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No shipments yet'**
  String get noShipmentsYet;

  /// No description provided for @weekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

  /// No description provided for @monthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// No description provided for @monthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// No description provided for @monthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// No description provided for @monthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// No description provided for @monthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// No description provided for @monthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// No description provided for @monthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// No description provided for @monthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// No description provided for @monthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// No description provided for @monthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// No description provided for @todayLabelFormat.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {month} {day}, {year}'**
  String todayLabelFormat(String weekday, String month, int day, int year);

  /// No description provided for @couldNotLoadDashboardStats.
  ///
  /// In en, this message translates to:
  /// **'Could not load dashboard stats.\n{error}'**
  String couldNotLoadDashboardStats(String error);

  /// No description provided for @statPendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get statPendingApprovals;

  /// No description provided for @statDocumentRenewals.
  ///
  /// In en, this message translates to:
  /// **'Document Renewals'**
  String get statDocumentRenewals;

  /// No description provided for @statChangesRequired.
  ///
  /// In en, this message translates to:
  /// **'Changes Required'**
  String get statChangesRequired;

  /// No description provided for @statActiveDrivers.
  ///
  /// In en, this message translates to:
  /// **'Active Drivers'**
  String get statActiveDrivers;

  /// No description provided for @statAvailableTrucks.
  ///
  /// In en, this message translates to:
  /// **'Available Trucks'**
  String get statAvailableTrucks;

  /// No description provided for @statActiveCompanies.
  ///
  /// In en, this message translates to:
  /// **'Active Companies'**
  String get statActiveCompanies;

  /// No description provided for @statCompletedThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Completed This Month'**
  String get statCompletedThisMonth;

  /// No description provided for @importantAlerts.
  ///
  /// In en, this message translates to:
  /// **'Important Alerts'**
  String get importantAlerts;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up — no alerts right now.'**
  String get allCaughtUp;

  /// No description provided for @myShipmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Shipments'**
  String get myShipmentsTitle;

  /// No description provided for @tabAllCount.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String tabAllCount(int count);

  /// No description provided for @tabActiveCount.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String tabActiveCount(int count);

  /// No description provided for @tabCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String tabCompletedCount(int count);

  /// No description provided for @tabCancelledCount.
  ///
  /// In en, this message translates to:
  /// **'Cancelled ({count})'**
  String tabCancelledCount(int count);

  /// No description provided for @failedToLoadShipments.
  ///
  /// In en, this message translates to:
  /// **'Failed to load shipments'**
  String get failedToLoadShipments;

  /// No description provided for @noShipmentsHere.
  ///
  /// In en, this message translates to:
  /// **'No shipments here'**
  String get noShipmentsHere;

  /// No description provided for @shipmentsMatchingFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'Shipments matching this filter will appear here.'**
  String get shipmentsMatchingFilterEmpty;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @contactInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInformationTitle;

  /// No description provided for @accountSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSectionTitle;

  /// No description provided for @personalInformationLabel.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformationLabel;

  /// No description provided for @personalInformationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name, phone & email'**
  String get personalInformationSubtitle;

  /// No description provided for @bankDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank Details'**
  String get bankDetailsLabel;

  /// No description provided for @bankDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where your payouts are sent'**
  String get bankDetailsSubtitle;

  /// No description provided for @changePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordLabel;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your login password'**
  String get changePasswordSubtitle;

  /// No description provided for @helpSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupportLabel;

  /// No description provided for @helpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Call, WhatsApp, email & FAQs'**
  String get helpSupportSubtitle;

  /// No description provided for @financeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get financeSectionTitle;

  /// No description provided for @myBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'My Balance'**
  String get myBalanceLabel;

  /// No description provided for @myPerformanceTitle.
  ///
  /// In en, this message translates to:
  /// **'My Performance'**
  String get myPerformanceTitle;

  /// No description provided for @statCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statCompletedLabel;

  /// No description provided for @statCancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statCancelledLabel;

  /// No description provided for @ratingComplianceTitle.
  ///
  /// In en, this message translates to:
  /// **'Rating & Compliance'**
  String get ratingComplianceTitle;

  /// No description provided for @documentsCoverageTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents & Coverage'**
  String get documentsCoverageTitle;

  /// No description provided for @myDocumentsLabel.
  ///
  /// In en, this message translates to:
  /// **'My Documents'**
  String get myDocumentsLabel;

  /// No description provided for @myDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'License, passport, residency & more'**
  String get myDocumentsSubtitle;

  /// No description provided for @myTruckLabel.
  ///
  /// In en, this message translates to:
  /// **'My Truck'**
  String get myTruckLabel;

  /// No description provided for @myTruckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plate, capacity & document expiry'**
  String get myTruckSubtitle;

  /// No description provided for @myDestinationsLabel.
  ///
  /// In en, this message translates to:
  /// **'My Destinations'**
  String get myDestinationsLabel;

  /// No description provided for @myDestinationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Countries you cover — used for matching'**
  String get myDestinationsSubtitle;

  /// No description provided for @myTrucksTitle.
  ///
  /// In en, this message translates to:
  /// **'My Trucks'**
  String get myTrucksTitle;

  /// No description provided for @addTruckLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Truck'**
  String get addTruckLabel;

  /// No description provided for @couldNotLoadTrucks.
  ///
  /// In en, this message translates to:
  /// **'Could not load trucks'**
  String get couldNotLoadTrucks;

  /// No description provided for @noTrucksAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No trucks added yet. Add your truck so you can be matched with shipments.'**
  String get noTrucksAddedYet;

  /// No description provided for @roleUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get roleUserFallback;

  /// No description provided for @roleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get roleDriver;

  /// No description provided for @roleCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get roleCompany;

  /// No description provided for @newTradeLicenseExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'New trade license expiry date'**
  String get newTradeLicenseExpiryDate;

  /// No description provided for @licenseStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get licenseStatusExpired;

  /// No description provided for @licenseStatusExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get licenseStatusExpiringSoon;

  /// No description provided for @licenseStatusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get licenseStatusPendingReview;

  /// No description provided for @licenseStatusValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get licenseStatusValid;

  /// No description provided for @daysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days}d overdue'**
  String daysOverdue(int days);

  /// No description provided for @expiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get expiresToday;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days}d left'**
  String daysLeft(int days);

  /// No description provided for @editCompanyInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Company Info'**
  String get editCompanyInfoTitle;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @companyInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Company Information'**
  String get companyInformationTitle;

  /// No description provided for @phoneLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabelShort;

  /// No description provided for @notUploadedYet.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded yet'**
  String get notUploadedYet;

  /// No description provided for @tradeLicenseOnFile.
  ///
  /// In en, this message translates to:
  /// **'Trade license on file'**
  String get tradeLicenseOnFile;

  /// No description provided for @uploadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploadingEllipsis;

  /// No description provided for @uploadTradeLicense.
  ///
  /// In en, this message translates to:
  /// **'Upload Trade License'**
  String get uploadTradeLicense;

  /// No description provided for @renewTradeLicense.
  ///
  /// In en, this message translates to:
  /// **'Renew Trade License'**
  String get renewTradeLicense;

  /// No description provided for @financeLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Balance, credit limit & top-ups'**
  String get financeLinkSubtitle;

  /// No description provided for @notificationsLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shipment & account updates'**
  String get notificationsLinkSubtitle;

  /// No description provided for @accountStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accountStatusActive;

  /// No description provided for @accountStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get accountStatusSuspended;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @couldNotLoadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications: {error}'**
  String couldNotLoadNotifications(String error);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get filterUnread;

  /// No description provided for @noUnreadNotifications.
  ///
  /// In en, this message translates to:
  /// **'No unread notifications'**
  String get noUnreadNotifications;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeDaysAgo(int days);

  /// No description provided for @addShipmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Shipment'**
  String get addShipmentTitle;

  /// No description provided for @addShipmentStepRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get addShipmentStepRoute;

  /// No description provided for @addShipmentStepCargo.
  ///
  /// In en, this message translates to:
  /// **'Cargo Details'**
  String get addShipmentStepCargo;

  /// No description provided for @addShipmentStepTruckPricing.
  ///
  /// In en, this message translates to:
  /// **'Truck & Pricing'**
  String get addShipmentStepTruckPricing;

  /// No description provided for @addShipmentStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review & Submit'**
  String get addShipmentStepReview;

  /// No description provided for @addShipmentSubtitleRoute.
  ///
  /// In en, this message translates to:
  /// **'Where is this shipment going?'**
  String get addShipmentSubtitleRoute;

  /// No description provided for @addShipmentSubtitleCargo.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s being shipped'**
  String get addShipmentSubtitleCargo;

  /// No description provided for @addShipmentSubtitleTruckPricing.
  ///
  /// In en, this message translates to:
  /// **'What kind of truck, and what will you pay?'**
  String get addShipmentSubtitleTruckPricing;

  /// No description provided for @addShipmentSubtitleReview.
  ///
  /// In en, this message translates to:
  /// **'Check everything before creating the offer'**
  String get addShipmentSubtitleReview;

  /// No description provided for @addShipmentFailedToLoadZones.
  ///
  /// In en, this message translates to:
  /// **'Failed to load zones: {error}'**
  String addShipmentFailedToLoadZones(String error);

  /// No description provided for @addShipmentSelectPickupZone.
  ///
  /// In en, this message translates to:
  /// **'Please select a pickup zone'**
  String get addShipmentSelectPickupZone;

  /// No description provided for @addShipmentSelectDropoffZone.
  ///
  /// In en, this message translates to:
  /// **'Please select a drop-off zone'**
  String get addShipmentSelectDropoffZone;

  /// No description provided for @addShipmentWeightMustBeNumber.
  ///
  /// In en, this message translates to:
  /// **'Weight must be a number'**
  String get addShipmentWeightMustBeNumber;

  /// No description provided for @addShipmentSelectTruckTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a required truck type'**
  String get addShipmentSelectTruckTypeRequired;

  /// No description provided for @addShipmentDomestic.
  ///
  /// In en, this message translates to:
  /// **'Domestic shipment'**
  String get addShipmentDomestic;

  /// No description provided for @addShipmentCrossBorder.
  ///
  /// In en, this message translates to:
  /// **'Cross-border shipment'**
  String get addShipmentCrossBorder;

  /// No description provided for @addShipmentPickupLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get addShipmentPickupLabel;

  /// No description provided for @addShipmentDropoffLabel.
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get addShipmentDropoffLabel;

  /// No description provided for @addShipmentPickupCountry.
  ///
  /// In en, this message translates to:
  /// **'Pickup Country'**
  String get addShipmentPickupCountry;

  /// No description provided for @addShipmentPickupCity.
  ///
  /// In en, this message translates to:
  /// **'Pickup City'**
  String get addShipmentPickupCity;

  /// No description provided for @addShipmentPickupZone.
  ///
  /// In en, this message translates to:
  /// **'Pickup Zone'**
  String get addShipmentPickupZone;

  /// No description provided for @addShipmentDropoffCountry.
  ///
  /// In en, this message translates to:
  /// **'Drop-off Country'**
  String get addShipmentDropoffCountry;

  /// No description provided for @addShipmentDropoffCity.
  ///
  /// In en, this message translates to:
  /// **'Drop-off City'**
  String get addShipmentDropoffCity;

  /// No description provided for @addShipmentDropoffZone.
  ///
  /// In en, this message translates to:
  /// **'Drop-off Zone'**
  String get addShipmentDropoffZone;

  /// No description provided for @addShipmentPickupAddressOptional.
  ///
  /// In en, this message translates to:
  /// **'Pickup Address (optional)'**
  String get addShipmentPickupAddressOptional;

  /// No description provided for @addShipmentDropoffAddressOptional.
  ///
  /// In en, this message translates to:
  /// **'Drop-off Address (optional)'**
  String get addShipmentDropoffAddressOptional;

  /// No description provided for @addShipmentAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Building, street, landmark…'**
  String get addShipmentAddressHint;

  /// No description provided for @addShipmentSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select a country'**
  String get addShipmentSelectCountry;

  /// No description provided for @addShipmentSelectCountryFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a country first'**
  String get addShipmentSelectCountryFirst;

  /// No description provided for @addShipmentSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Select a city'**
  String get addShipmentSelectCity;

  /// No description provided for @addShipmentSelectCityFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a city first'**
  String get addShipmentSelectCityFirst;

  /// No description provided for @addShipmentSelectZone.
  ///
  /// In en, this message translates to:
  /// **'Select a zone'**
  String get addShipmentSelectZone;

  /// No description provided for @addShipmentWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get addShipmentWeightKg;

  /// No description provided for @addShipmentCargoDescription.
  ///
  /// In en, this message translates to:
  /// **'Cargo Description'**
  String get addShipmentCargoDescription;

  /// No description provided for @addShipmentCargoDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — what\'s being shipped'**
  String get addShipmentCargoDescriptionHint;

  /// No description provided for @addShipmentRequiredTruckType.
  ///
  /// In en, this message translates to:
  /// **'Required Truck Type'**
  String get addShipmentRequiredTruckType;

  /// No description provided for @addShipmentSelectTruckType.
  ///
  /// In en, this message translates to:
  /// **'Select a truck type'**
  String get addShipmentSelectTruckType;

  /// No description provided for @addShipmentRequiresPermit.
  ///
  /// In en, this message translates to:
  /// **'Requires special permit'**
  String get addShipmentRequiresPermit;

  /// No description provided for @addShipmentHazardousCargo.
  ///
  /// In en, this message translates to:
  /// **'Hazardous cargo'**
  String get addShipmentHazardousCargo;

  /// No description provided for @addShipmentFragileCargo.
  ///
  /// In en, this message translates to:
  /// **'Fragile cargo'**
  String get addShipmentFragileCargo;

  /// No description provided for @addShipmentPricingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get addShipmentPricingLabel;

  /// No description provided for @addShipmentPricingSelectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a pickup zone, drop-off zone, and truck type to see a price suggestion.'**
  String get addShipmentPricingSelectPrompt;

  /// No description provided for @addShipmentPricingNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Price suggestion not loaded yet.'**
  String get addShipmentPricingNotLoaded;

  /// No description provided for @addShipmentPricingNoHistorical.
  ///
  /// In en, this message translates to:
  /// **'No historical pricing for this lane — our team will review and set a price shortly after you submit.'**
  String get addShipmentPricingNoHistorical;

  /// No description provided for @addShipmentNoOptionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No options available'**
  String get addShipmentNoOptionsAvailable;

  /// No description provided for @addShipmentNoZonesForCity.
  ///
  /// In en, this message translates to:
  /// **'No zones available for this city'**
  String get addShipmentNoZonesForCity;

  /// No description provided for @addShipmentHistoricalReference.
  ///
  /// In en, this message translates to:
  /// **'Historical reference: {value}'**
  String addShipmentHistoricalReference(String value);

  /// No description provided for @addShipmentTypicalRange.
  ///
  /// In en, this message translates to:
  /// **'Typical range: {value}'**
  String addShipmentTypicalRange(String value);

  /// No description provided for @addShipmentPastTrips.
  ///
  /// In en, this message translates to:
  /// **'{count} past trips'**
  String addShipmentPastTrips(int count);

  /// No description provided for @addShipmentYourPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Price (AED, charged to you)'**
  String get addShipmentYourPriceLabel;

  /// No description provided for @addShipmentYourPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Defaults to the historical reference — you may change it'**
  String get addShipmentYourPriceHint;

  /// No description provided for @addShipmentCreateOfferButton.
  ///
  /// In en, this message translates to:
  /// **'Create Offer'**
  String get addShipmentCreateOfferButton;

  /// No description provided for @addShipmentReviewType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get addShipmentReviewType;

  /// No description provided for @addShipmentReviewOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get addShipmentReviewOrigin;

  /// No description provided for @addShipmentReviewDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get addShipmentReviewDestination;

  /// No description provided for @addShipmentReviewWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get addShipmentReviewWeight;

  /// No description provided for @addShipmentReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get addShipmentReviewDescription;

  /// No description provided for @addShipmentReviewTruckType.
  ///
  /// In en, this message translates to:
  /// **'Truck Type'**
  String get addShipmentReviewTruckType;

  /// No description provided for @addShipmentReviewSpecialPermit.
  ///
  /// In en, this message translates to:
  /// **'Special Permit'**
  String get addShipmentReviewSpecialPermit;

  /// No description provided for @addShipmentReviewHazardous.
  ///
  /// In en, this message translates to:
  /// **'Hazardous'**
  String get addShipmentReviewHazardous;

  /// No description provided for @addShipmentReviewFragile.
  ///
  /// In en, this message translates to:
  /// **'Fragile'**
  String get addShipmentReviewFragile;

  /// No description provided for @addShipmentReviewYourPrice.
  ///
  /// In en, this message translates to:
  /// **'Your Price'**
  String get addShipmentReviewYourPrice;

  /// No description provided for @addShipmentDomesticShort.
  ///
  /// In en, this message translates to:
  /// **'Domestic'**
  String get addShipmentDomesticShort;

  /// No description provided for @addShipmentCrossBorderShort.
  ///
  /// In en, this message translates to:
  /// **'Cross-border'**
  String get addShipmentCrossBorderShort;

  /// No description provided for @addShipmentSetByCrm.
  ///
  /// In en, this message translates to:
  /// **'Set by CRM after review'**
  String get addShipmentSetByCrm;

  /// No description provided for @addShipmentSuccessNoAutoPrice.
  ///
  /// In en, this message translates to:
  /// **'Offer created — no automatic price found, CRM will set one shortly'**
  String get addShipmentSuccessNoAutoPrice;

  /// No description provided for @addShipmentSuccessMatching.
  ///
  /// In en, this message translates to:
  /// **'Offer created — matching drivers now'**
  String get addShipmentSuccessMatching;

  /// No description provided for @addShipmentSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String addShipmentSomethingWentWrong(String error);

  /// No description provided for @companyShipmentsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by tracking #, ID, or route...'**
  String get companyShipmentsSearchHint;

  /// No description provided for @tabPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get tabPendingLabel;

  /// No description provided for @tabLiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get tabLiveLabel;

  /// No description provided for @tabDeliveredLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get tabDeliveredLabel;

  /// No description provided for @adminShipmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipments'**
  String get adminShipmentsTitle;

  /// No description provided for @adminShipmentsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by tracking no., company, driver...'**
  String get adminShipmentsSearchHint;

  /// No description provided for @adminShipmentsChipActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminShipmentsChipActive;

  /// No description provided for @adminShipmentsChipDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get adminShipmentsChipDelivered;

  /// No description provided for @adminShipmentsChipCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get adminShipmentsChipCancelled;

  /// No description provided for @adminShipmentsNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No shipments found'**
  String get adminShipmentsNoneFound;

  /// No description provided for @adminShipmentsWaitingForDriver.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver'**
  String get adminShipmentsWaitingForDriver;

  /// No description provided for @shipmentDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipment Details'**
  String get shipmentDetailsTitle;

  /// No description provided for @rateDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate this driver'**
  String get rateDriverTitle;

  /// No description provided for @commentOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get commentOptionalHint;

  /// No description provided for @reportDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Report driver'**
  String get reportDriverTitle;

  /// No description provided for @describeWhatHappenedHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened'**
  String get describeWhatHappenedHint;

  /// No description provided for @reviewProofOfDeliveryButton.
  ///
  /// In en, this message translates to:
  /// **'Review Proof of Delivery'**
  String get reviewProofOfDeliveryButton;

  /// No description provided for @viewTrackingTimelineButton.
  ///
  /// In en, this message translates to:
  /// **'View Tracking Timeline'**
  String get viewTrackingTimelineButton;

  /// No description provided for @reportDriverButton.
  ///
  /// In en, this message translates to:
  /// **'Report driver'**
  String get reportDriverButton;

  /// No description provided for @awaitingYourConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your confirmation'**
  String get awaitingYourConfirmation;

  /// No description provided for @underAdminReview.
  ///
  /// In en, this message translates to:
  /// **'Under admin review'**
  String get underAdminReview;

  /// No description provided for @sectionRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get sectionRoute;

  /// No description provided for @sectionShipmentInfo.
  ///
  /// In en, this message translates to:
  /// **'Shipment Info'**
  String get sectionShipmentInfo;

  /// No description provided for @sectionTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get sectionTimeline;

  /// No description provided for @fieldShipmentId.
  ///
  /// In en, this message translates to:
  /// **'Shipment ID'**
  String get fieldShipmentId;

  /// No description provided for @fieldCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get fieldCreated;

  /// No description provided for @fieldPickupTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup Time'**
  String get fieldPickupTime;

  /// No description provided for @fieldDeliveredAt.
  ///
  /// In en, this message translates to:
  /// **'Delivered At'**
  String get fieldDeliveredAt;

  /// No description provided for @yourReportedProblem.
  ///
  /// In en, this message translates to:
  /// **'Your reported problem'**
  String get yourReportedProblem;

  /// No description provided for @availableShipmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Available Shipments'**
  String get availableShipmentsTitle;

  /// No description provided for @availabilityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availabilityAvailable;

  /// No description provided for @availabilityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get availabilityUnavailable;

  /// No description provided for @couldNotUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Could not update status'**
  String get couldNotUpdateStatus;

  /// No description provided for @searchByLocationLoadType.
  ///
  /// In en, this message translates to:
  /// **'Search by location, load type...'**
  String get searchByLocationLoadType;

  /// No description provided for @tabNearbyCount.
  ///
  /// In en, this message translates to:
  /// **'Nearby ({count})'**
  String tabNearbyCount(int count);

  /// No description provided for @tabSavedCount.
  ///
  /// In en, this message translates to:
  /// **'Saved ({count})'**
  String tabSavedCount(int count);

  /// No description provided for @couldNotLoadOffers.
  ///
  /// In en, this message translates to:
  /// **'Could not load offers'**
  String get couldNotLoadOffers;

  /// No description provided for @noSavedOffersYet.
  ///
  /// In en, this message translates to:
  /// **'No saved offers yet.'**
  String get noSavedOffersYet;

  /// No description provided for @noNearbyOffersRightNow.
  ///
  /// In en, this message translates to:
  /// **'No nearby offers with pickup coordinates right now.'**
  String get noNearbyOffersRightNow;

  /// No description provided for @noMatchingOffersRightNow.
  ///
  /// In en, this message translates to:
  /// **'No matching offers right now.'**
  String get noMatchingOffersRightNow;

  /// No description provided for @tagPermit.
  ///
  /// In en, this message translates to:
  /// **'permit'**
  String get tagPermit;

  /// No description provided for @tagHazardous.
  ///
  /// In en, this message translates to:
  /// **'hazardous'**
  String get tagHazardous;

  /// No description provided for @tagFragile.
  ///
  /// In en, this message translates to:
  /// **'fragile'**
  String get tagFragile;

  /// No description provided for @distanceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String distanceKmAway(String km);

  /// No description provided for @priceLabelAed.
  ///
  /// In en, this message translates to:
  /// **'Price: {price} AED'**
  String priceLabelAed(String price);

  /// No description provided for @detailsButton.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsButton;

  /// No description provided for @acceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButton;

  /// No description provided for @declineOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this offer?'**
  String get declineOfferTitle;

  /// No description provided for @declineOfferBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be matched with this shipment again unless it\'s re-offered.'**
  String get declineOfferBody;

  /// No description provided for @commonDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get commonDecline;

  /// No description provided for @commonSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get commonSaved;

  /// No description provided for @failedToDeclineOffer.
  ///
  /// In en, this message translates to:
  /// **'Failed to decline offer'**
  String get failedToDeclineOffer;

  /// No description provided for @statusOffered.
  ///
  /// In en, this message translates to:
  /// **'Offered'**
  String get statusOffered;

  /// No description provided for @postedByCompany.
  ///
  /// In en, this message translates to:
  /// **'Posted by {name}'**
  String postedByCompany(String name);

  /// No description provided for @sectionLoadInformation.
  ///
  /// In en, this message translates to:
  /// **'Load Information'**
  String get sectionLoadInformation;

  /// No description provided for @fieldOrderType.
  ///
  /// In en, this message translates to:
  /// **'Order Type'**
  String get fieldOrderType;

  /// No description provided for @fieldPickupZone.
  ///
  /// In en, this message translates to:
  /// **'Pickup Zone'**
  String get fieldPickupZone;

  /// No description provided for @fieldDropoffZone.
  ///
  /// In en, this message translates to:
  /// **'Drop-off Zone'**
  String get fieldDropoffZone;

  /// No description provided for @requirementSpecialPermit.
  ///
  /// In en, this message translates to:
  /// **'Special permit'**
  String get requirementSpecialPermit;

  /// No description provided for @requirementHazardousCargo.
  ///
  /// In en, this message translates to:
  /// **'Hazardous cargo'**
  String get requirementHazardousCargo;

  /// No description provided for @requirementFragileCargo.
  ///
  /// In en, this message translates to:
  /// **'Fragile cargo'**
  String get requirementFragileCargo;

  /// No description provided for @fieldRequirements.
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get fieldRequirements;

  /// No description provided for @sectionCargoDescription.
  ///
  /// In en, this message translates to:
  /// **'Cargo Description'**
  String get sectionCargoDescription;

  /// No description provided for @sectionPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get sectionPayment;

  /// No description provided for @fieldPriceToYou.
  ///
  /// In en, this message translates to:
  /// **'Price to you'**
  String get fieldPriceToYou;

  /// No description provided for @toBeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'To be confirmed'**
  String get toBeConfirmed;

  /// No description provided for @acceptShipmentButton.
  ///
  /// In en, this message translates to:
  /// **'Accept Shipment'**
  String get acceptShipmentButton;

  /// No description provided for @myShipmentOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'My Shipment Offers'**
  String get myShipmentOffersTitle;

  /// No description provided for @newOfferButton.
  ///
  /// In en, this message translates to:
  /// **'New Offer'**
  String get newOfferButton;

  /// No description provided for @failedToLoadOffers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load offers'**
  String get failedToLoadOffers;

  /// No description provided for @noOffersYet.
  ///
  /// In en, this message translates to:
  /// **'No offers yet'**
  String get noOffersYet;

  /// No description provided for @tapNewOfferHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New Offer\" to request a shipment.'**
  String get tapNewOfferHint;

  /// No description provided for @offerStatusMatchingDrivers.
  ///
  /// In en, this message translates to:
  /// **'Matching drivers'**
  String get offerStatusMatchingDrivers;

  /// No description provided for @offerStatusAwaitingPrice.
  ///
  /// In en, this message translates to:
  /// **'Awaiting price'**
  String get offerStatusAwaitingPrice;

  /// No description provided for @offerStatusEscalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get offerStatusEscalated;

  /// No description provided for @offerStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get offerStatusAccepted;

  /// No description provided for @offerStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get offerStatusCancelled;

  /// No description provided for @offerStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get offerStatusExpired;

  /// No description provided for @raisePriceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Raise price to client'**
  String get raisePriceDialogTitle;

  /// No description provided for @newPriceAedLabel.
  ///
  /// In en, this message translates to:
  /// **'New price (AED)'**
  String get newPriceAedLabel;

  /// No description provided for @cancelOfferDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel offer'**
  String get cancelOfferDialogTitle;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @cancelOfferButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Offer'**
  String get cancelOfferButton;

  /// No description provided for @offerCancelledMsg.
  ///
  /// In en, this message translates to:
  /// **'Offer cancelled'**
  String get offerCancelledMsg;

  /// No description provided for @failedToCancelOffer.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel offer'**
  String get failedToCancelOffer;

  /// No description provided for @eligibleDriversCount.
  ///
  /// In en, this message translates to:
  /// **'{count} eligible driver(s)'**
  String eligibleDriversCount(int count);

  /// No description provided for @priceToClientLabel.
  ///
  /// In en, this message translates to:
  /// **'Price to client: {price} AED'**
  String priceToClientLabel(String price);

  /// No description provided for @manualSuffix.
  ///
  /// In en, this message translates to:
  /// **' (manual)'**
  String get manualSuffix;

  /// No description provided for @raisePriceButton.
  ///
  /// In en, this message translates to:
  /// **'Raise price'**
  String get raisePriceButton;

  /// No description provided for @cancelThisOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this offer?'**
  String get cancelThisOfferTitle;

  /// No description provided for @cancellationReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Cancellation reason'**
  String get cancellationReasonHint;

  /// No description provided for @couldNotCancelOffer.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the offer'**
  String get couldNotCancelOffer;

  /// No description provided for @notFoundLabel.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFoundLabel;

  /// No description provided for @waitingForDriverCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Driver'**
  String get waitingForDriverCardTitle;

  /// No description provided for @findingBestMatchedDrivers.
  ///
  /// In en, this message translates to:
  /// **'We are finding the best matched drivers for this shipment.'**
  String get findingBestMatchedDrivers;

  /// No description provided for @statEligibleDrivers.
  ///
  /// In en, this message translates to:
  /// **'Eligible Drivers'**
  String get statEligibleDrivers;

  /// No description provided for @statOffersSent.
  ///
  /// In en, this message translates to:
  /// **'Offers Sent'**
  String get statOffersSent;

  /// No description provided for @statCurrentRound.
  ///
  /// In en, this message translates to:
  /// **'Current Round'**
  String get statCurrentRound;

  /// No description provided for @cancellationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancellation'**
  String get cancellationSectionTitle;

  /// No description provided for @fieldReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get fieldReason;

  /// No description provided for @fieldCancelledBy.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by'**
  String get fieldCancelledBy;

  /// No description provided for @fieldCancelledAt.
  ///
  /// In en, this message translates to:
  /// **'Cancelled at'**
  String get fieldCancelledAt;

  /// No description provided for @pricingReferenceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing Reference (Smart Pricing Engine)'**
  String get pricingReferenceSectionTitle;

  /// No description provided for @fieldHistoricalReference.
  ///
  /// In en, this message translates to:
  /// **'Historical reference'**
  String get fieldHistoricalReference;

  /// No description provided for @fieldTypicalRange.
  ///
  /// In en, this message translates to:
  /// **'Typical range'**
  String get fieldTypicalRange;

  /// No description provided for @fieldConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get fieldConfidence;

  /// No description provided for @fieldMarketAdjustmentApplied.
  ///
  /// In en, this message translates to:
  /// **'Market adjustment applied'**
  String get fieldMarketAdjustmentApplied;

  /// No description provided for @fieldCompanyWasCharged.
  ///
  /// In en, this message translates to:
  /// **'Company was charged'**
  String get fieldCompanyWasCharged;

  /// No description provided for @matchingTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Matching Timeline'**
  String get matchingTimelineTitle;

  /// No description provided for @noMatchingRoundsYet.
  ///
  /// In en, this message translates to:
  /// **'No matching rounds yet.'**
  String get noMatchingRoundsYet;

  /// No description provided for @roundAcceptedBy.
  ///
  /// In en, this message translates to:
  /// **'Accepted by {name}'**
  String roundAcceptedBy(String name);

  /// No description provided for @roundAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get roundAccepted;

  /// No description provided for @roundNoAcceptance.
  ///
  /// In en, this message translates to:
  /// **'No acceptance'**
  String get roundNoAcceptance;

  /// No description provided for @roundWaitingForResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for response'**
  String get roundWaitingForResponse;

  /// No description provided for @roundNotifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Round {round} • {count} driver(s) notified'**
  String roundNotifiedLabel(String round, String count);

  /// No description provided for @decisionApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Approved'**
  String get decisionApprovedTitle;

  /// No description provided for @decisionChangesRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes Requested'**
  String get decisionChangesRequestedTitle;

  /// No description provided for @decisionRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Rejected'**
  String get decisionRejectedTitle;

  /// No description provided for @decisionApprovedMessageDriver.
  ///
  /// In en, this message translates to:
  /// **'{name} has been approved and can now use the app and be matched with shipments.'**
  String decisionApprovedMessageDriver(String name);

  /// No description provided for @decisionApprovedMessageCompany.
  ///
  /// In en, this message translates to:
  /// **'{name} has been approved and can now use the app.'**
  String decisionApprovedMessageCompany(String name);

  /// No description provided for @decisionChangesRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} has been notified of the changes needed and can resubmit once they\'re fixed.'**
  String decisionChangesRequiredMessage(String name);

  /// No description provided for @decisionRejectedMessageDriver.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s driver registration has been rejected. They have been notified.'**
  String decisionRejectedMessageDriver(String name);

  /// No description provided for @decisionRejectedMessageCompany.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s company registration has been rejected. They have been notified.'**
  String decisionRejectedMessageCompany(String name);

  /// No description provided for @backToRequestsButton.
  ///
  /// In en, this message translates to:
  /// **'Back to Requests'**
  String get backToRequestsButton;

  /// No description provided for @cancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get cancelledLabel;

  /// No description provided for @cancellationSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Summary'**
  String get cancellationSummaryTitle;

  /// No description provided for @financialImpactTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Impact'**
  String get financialImpactTitle;

  /// No description provided for @fieldDriverAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get fieldDriverAssigned;

  /// No description provided for @fieldStageReached.
  ///
  /// In en, this message translates to:
  /// **'Stage reached'**
  String get fieldStageReached;

  /// No description provided for @fieldClientPrice.
  ///
  /// In en, this message translates to:
  /// **'Client Price'**
  String get fieldClientPrice;

  /// No description provided for @fieldDriverPrice.
  ///
  /// In en, this message translates to:
  /// **'Driver Price'**
  String get fieldDriverPrice;

  /// No description provided for @deliveredLabel.
  ///
  /// In en, this message translates to:
  /// **'DELIVERED'**
  String get deliveredLabel;

  /// No description provided for @statDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get statDistance;

  /// No description provided for @statDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get statDuration;

  /// No description provided for @statPickupTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup Time'**
  String get statPickupTime;

  /// No description provided for @statDeliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Delivery Time'**
  String get statDeliveryTime;

  /// No description provided for @tripTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Timeline'**
  String get tripTimelineTitle;

  /// No description provided for @driverAndTruckTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver & Truck'**
  String get driverAndTruckTitle;

  /// No description provided for @fieldDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get fieldDriverLabel;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @fieldTruck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get fieldTruck;

  /// No description provided for @financialSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get financialSummaryTitle;

  /// No description provided for @fieldCommission.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get fieldCommission;

  /// No description provided for @proofOfDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Proof of Delivery'**
  String get proofOfDeliveryTitle;

  /// No description provided for @receiverLabel.
  ///
  /// In en, this message translates to:
  /// **'Receiver: {name}'**
  String receiverLabel(String name);

  /// No description provided for @documentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Document unavailable'**
  String get documentUnavailable;

  /// No description provided for @viewDeliveryDocument.
  ///
  /// In en, this message translates to:
  /// **'View delivery document'**
  String get viewDeliveryDocument;

  /// No description provided for @signatureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Signature unavailable'**
  String get signatureUnavailable;

  /// No description provided for @noUpdateYet.
  ///
  /// In en, this message translates to:
  /// **'no update yet'**
  String get noUpdateYet;

  /// No description provided for @minAgoFull.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minAgoFull(int minutes);

  /// No description provided for @lastLocationUpdateLabel.
  ///
  /// In en, this message translates to:
  /// **'Last location update: {ago}'**
  String lastLocationUpdateLabel(String ago);

  /// No description provided for @shipmentProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipment Progress'**
  String get shipmentProgressTitle;

  /// No description provided for @sectionShipmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Shipment Details'**
  String get sectionShipmentDetails;

  /// No description provided for @fieldNeedsPermit.
  ///
  /// In en, this message translates to:
  /// **'Needs Permit'**
  String get fieldNeedsPermit;

  /// No description provided for @fieldRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get fieldRating;

  /// No description provided for @companySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get companySectionTitle;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @noLocationDataYet.
  ///
  /// In en, this message translates to:
  /// **'No location data available for this shipment yet'**
  String get noLocationDataYet;

  /// No description provided for @neverLabel.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get neverLabel;

  /// No description provided for @liveTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Tracking'**
  String get liveTrackingTitle;

  /// No description provided for @updatedAgoLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated {ago}'**
  String updatedAgoLabel(String ago);

  /// No description provided for @noGpsFixYet.
  ///
  /// In en, this message translates to:
  /// **'No GPS fix yet'**
  String get noGpsFixYet;

  /// No description provided for @noGpsPositionYetBody.
  ///
  /// In en, this message translates to:
  /// **'The driver hasn\'t reported a GPS position yet — this updates automatically once they do (the app reports location while a shipment is in progress).'**
  String get noGpsPositionYetBody;

  /// No description provided for @complianceReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance Reports'**
  String get complianceReportsTitle;

  /// No description provided for @couldNotLoadReports.
  ///
  /// In en, this message translates to:
  /// **'Could not load reports'**
  String get couldNotLoadReports;

  /// No description provided for @noComplianceReportsClean.
  ///
  /// In en, this message translates to:
  /// **'No compliance reports on file — clean record.'**
  String get noComplianceReportsClean;

  /// No description provided for @appealThisDecisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appeal this decision'**
  String get appealThisDecisionTitle;

  /// No description provided for @appealHint.
  ///
  /// In en, this message translates to:
  /// **'Explain why you believe this decision was wrong'**
  String get appealHint;

  /// No description provided for @submitAppealButton.
  ///
  /// In en, this message translates to:
  /// **'Submit appeal'**
  String get submitAppealButton;

  /// No description provided for @actionLabel.
  ///
  /// In en, this message translates to:
  /// **'Action: {action}'**
  String actionLabel(String action);

  /// No description provided for @appealLabel.
  ///
  /// In en, this message translates to:
  /// **'Appeal: {status}'**
  String appealLabel(String status);

  /// No description provided for @appealButton.
  ///
  /// In en, this message translates to:
  /// **'Appeal'**
  String get appealButton;

  /// No description provided for @couldNotFindRecord.
  ///
  /// In en, this message translates to:
  /// **'Could not find this record'**
  String get couldNotFindRecord;

  /// No description provided for @expiredDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Expired Documents'**
  String get expiredDocumentsTitle;

  /// No description provided for @documentsExpiringSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents Expiring Soon'**
  String get documentsExpiringSoonTitle;

  /// No description provided for @docTypeLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get docTypeLicense;

  /// No description provided for @docTypePassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get docTypePassport;

  /// No description provided for @docTypeResidency.
  ///
  /// In en, this message translates to:
  /// **'Residency'**
  String get docTypeResidency;

  /// No description provided for @docTypeInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get docTypeInsurance;

  /// No description provided for @docTypeTechnicalInspection.
  ///
  /// In en, this message translates to:
  /// **'Technical Inspection'**
  String get docTypeTechnicalInspection;

  /// No description provided for @docTypeTradeLicense.
  ///
  /// In en, this message translates to:
  /// **'Trade License'**
  String get docTypeTradeLicense;

  /// No description provided for @docTypeTruckLabel.
  ///
  /// In en, this message translates to:
  /// **'Truck {label}'**
  String docTypeTruckLabel(String label);

  /// No description provided for @searchByNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get searchByNameHint;

  /// No description provided for @couldNotLoadListError.
  ///
  /// In en, this message translates to:
  /// **'Could not load list.\n{error}'**
  String couldNotLoadListError(String error);

  /// No description provided for @nothingHereRightNow.
  ///
  /// In en, this message translates to:
  /// **'Nothing here right now.'**
  String get nothingHereRightNow;

  /// No description provided for @docAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{type} · exp. {date}'**
  String docAlertSubtitle(String type, String date);

  /// No description provided for @resolveReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve report'**
  String get resolveReportTitle;

  /// No description provided for @decisionDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get decisionDismiss;

  /// No description provided for @decisionUphold.
  ///
  /// In en, this message translates to:
  /// **'Uphold'**
  String get decisionUphold;

  /// No description provided for @actionWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get actionWarning;

  /// No description provided for @actionSuspension.
  ///
  /// In en, this message translates to:
  /// **'Suspension'**
  String get actionSuspension;

  /// No description provided for @actionBan.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get actionBan;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @complianceTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get complianceTitle;

  /// No description provided for @tabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get tabReports;

  /// No description provided for @tabAppeals.
  ///
  /// In en, this message translates to:
  /// **'Appeals'**
  String get tabAppeals;

  /// No description provided for @noReportsPendingReview.
  ///
  /// In en, this message translates to:
  /// **'No reports pending review'**
  String get noReportsPendingReview;

  /// No description provided for @noPendingAppeals.
  ///
  /// In en, this message translates to:
  /// **'No pending appeals'**
  String get noPendingAppeals;

  /// No description provided for @resolveButton.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolveButton;

  /// No description provided for @rejectAppealButton.
  ///
  /// In en, this message translates to:
  /// **'Reject appeal'**
  String get rejectAppealButton;

  /// No description provided for @acceptAppealButton.
  ///
  /// In en, this message translates to:
  /// **'Accept appeal'**
  String get acceptAppealButton;

  /// No description provided for @driverHashLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver #{id}'**
  String driverHashLabel(String id);

  /// No description provided for @requestChangesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request changes'**
  String get requestChangesDialogTitle;

  /// No description provided for @requestChangesReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (e.g. blurry photo, wrong document, expired)'**
  String get requestChangesReasonHint;

  /// No description provided for @sendBackButton.
  ///
  /// In en, this message translates to:
  /// **'Send Back'**
  String get sendBackButton;

  /// No description provided for @documentRenewalTitle.
  ///
  /// In en, this message translates to:
  /// **'Document Renewal'**
  String get documentRenewalTitle;

  /// No description provided for @userHashLabel.
  ///
  /// In en, this message translates to:
  /// **'User #{id}'**
  String userHashLabel(String id);

  /// No description provided for @oldDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Old Document'**
  String get oldDocumentTitle;

  /// No description provided for @newDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'New Document'**
  String get newDocumentTitle;

  /// No description provided for @fieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fieldStatus;

  /// No description provided for @noPreviousDocument.
  ///
  /// In en, this message translates to:
  /// **'No previous document on file'**
  String get noPreviousDocument;

  /// No description provided for @fieldExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get fieldExpiryDate;

  /// No description provided for @fieldNewExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'New Expiry Date'**
  String get fieldNewExpiryDate;

  /// No description provided for @fieldSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get fieldSubmitted;

  /// No description provided for @statusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get statusPendingReview;

  /// No description provided for @requestChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Request Changes'**
  String get requestChangesButton;

  /// No description provided for @approveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveButton;

  /// No description provided for @previewDocumentButton.
  ///
  /// In en, this message translates to:
  /// **'Preview Document'**
  String get previewDocumentButton;

  /// No description provided for @shipmentTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipment Tracking'**
  String get shipmentTrackingTitle;

  /// No description provided for @addCommentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add comment'**
  String get addCommentTooltip;

  /// No description provided for @liveLabel.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveLabel;

  /// No description provided for @deliveryStatusAwaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get deliveryStatusAwaitingConfirmation;

  /// No description provided for @deliveryStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get deliveryStatusConfirmed;

  /// No description provided for @deliveryStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get deliveryStatusDisputed;

  /// No description provided for @deliveryStatusNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'Not delivered'**
  String get deliveryStatusNotDelivered;

  /// No description provided for @receivedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Received by: {name}'**
  String receivedByLabel(String name);

  /// No description provided for @addCommentDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get addCommentDialogTitle;

  /// No description provided for @addCommentHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. truck breakdown, road closure...'**
  String get addCommentHint;

  /// No description provided for @commentAddedMsg.
  ///
  /// In en, this message translates to:
  /// **'Comment added'**
  String get commentAddedMsg;

  /// No description provided for @failedToAddComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to add comment'**
  String get failedToAddComment;

  /// No description provided for @failedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedGeneric;

  /// No description provided for @deliveryRecordedMsg.
  ///
  /// In en, this message translates to:
  /// **'Delivery recorded — awaiting company confirmation before payout'**
  String get deliveryRecordedMsg;

  /// No description provided for @captureProofOfDeliveryButton.
  ///
  /// In en, this message translates to:
  /// **'Capture proof of delivery'**
  String get captureProofOfDeliveryButton;

  /// No description provided for @markAsLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark as: {label}'**
  String markAsLabel(String label);

  /// No description provided for @noGpsFixUpdatesAutomatically.
  ///
  /// In en, this message translates to:
  /// **'No GPS fix yet — updates automatically once the driver reports one'**
  String get noGpsFixUpdatesAutomatically;

  /// No description provided for @docStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get docStatusExpired;

  /// No description provided for @docStatusExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get docStatusExpiringSoon;

  /// No description provided for @docStatusValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get docStatusValid;

  /// No description provided for @docStatusChangesRequired.
  ///
  /// In en, this message translates to:
  /// **'Changes Required'**
  String get docStatusChangesRequired;

  /// No description provided for @docStatusNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Not Uploaded'**
  String get docStatusNotUploaded;

  /// No description provided for @uploadDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload {label}'**
  String uploadDialogTitle(String label);

  /// No description provided for @chooseFileHint.
  ///
  /// In en, this message translates to:
  /// **'Choose file (PDF/JPG/PNG)'**
  String get chooseFileHint;

  /// No description provided for @expiryDateOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Expiry date (optional)'**
  String get expiryDateOptionalHint;

  /// No description provided for @uploadButton.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadButton;

  /// No description provided for @renewDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Renew {label}'**
  String renewDialogTitle(String label);

  /// No description provided for @newExpiryDateHint.
  ///
  /// In en, this message translates to:
  /// **'New expiry date'**
  String get newExpiryDateHint;

  /// No description provided for @submitForReviewButton.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get submitForReviewButton;

  /// No description provided for @driverDocumentsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver Documents'**
  String get driverDocumentsTabLabel;

  /// No description provided for @truckDocumentsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Truck Documents'**
  String get truckDocumentsTabLabel;

  /// No description provided for @couldNotLoadTruckDocs.
  ///
  /// In en, this message translates to:
  /// **'Could not load truck documents'**
  String get couldNotLoadTruckDocs;

  /// No description provided for @noTruckRegisteredYet.
  ///
  /// In en, this message translates to:
  /// **'No truck registered yet'**
  String get noTruckRegisteredYet;

  /// No description provided for @renewingSubmitsForReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Renewing a document here submits it for admin review — it applies once approved.'**
  String get renewingSubmitsForReviewNote;

  /// No description provided for @vehicleLicenseLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle License'**
  String get vehicleLicenseLabel;

  /// No description provided for @expDateLabel.
  ///
  /// In en, this message translates to:
  /// **'exp. {date}'**
  String expDateLabel(String date);

  /// No description provided for @viewButton.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewButton;

  /// No description provided for @renewButton.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get renewButton;

  /// No description provided for @couldNotLoadDocumentsMsg.
  ///
  /// In en, this message translates to:
  /// **'Could not load documents'**
  String get couldNotLoadDocumentsMsg;

  /// No description provided for @mandatoryDocsBlockNote.
  ///
  /// In en, this message translates to:
  /// **'Missing, expired, or expiring-soon mandatory documents (license, passport, residency) will block your account from being matched with shipments until renewed and approved.'**
  String get mandatoryDocsBlockNote;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

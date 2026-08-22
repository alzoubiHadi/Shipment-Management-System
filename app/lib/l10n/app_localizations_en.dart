// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FMS';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDone => 'Done';

  @override
  String get commonNext => 'Next';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonUpload => 'Upload';

  @override
  String get commonUploadHintFormats => 'PDF/JPG/PNG';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonView => 'View';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonSkip => 'Skip';

  @override
  String get languageSettingTitle => 'Language';

  @override
  String get languageSettingSubtitle => 'Choose the app\'s display language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languagePickerTitle => 'Select language';

  @override
  String get logOutLabel => 'Log Out';

  @override
  String get logOutTitle => 'Log out';

  @override
  String get logOutConfirmMessage => 'Are you sure you want to log out?';

  @override
  String get logOutBlockedActiveTrip =>
      'You can\'t log out while a trip is in progress. Finish or hand off the trip first.';

  @override
  String get logOutTooltipBlocked =>
      'Log out (unavailable during an active trip)';

  @override
  String get loginWelcomeTitle => 'Welcome to FMS';

  @override
  String get loginWelcomeSubtitle => 'Sign in to access your account';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get forgotPasswordSnack => 'Contact your admin to reset your password';

  @override
  String get logIn => 'Log In';

  @override
  String get featureSecureTitle => 'Secure & Reliable';

  @override
  String get featureSecureDesc => 'Your data protected at the highest level';

  @override
  String get featureEasyTitle => 'Easy Management';

  @override
  String get featureEasyDesc => 'Track your shipments in real time';

  @override
  String get featureReportsTitle => 'Smart Reports';

  @override
  String get featureReportsDesc => 'Accurate analytics and reports';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get errorFillAllFields => 'Please fill in all fields';

  @override
  String get loggingInTitle => 'Logging you in...';

  @override
  String get loggingInSubtitle => 'Please wait a moment';

  @override
  String get createAccountTitle => 'Create your\naccount.';

  @override
  String get createAccountSubtitle => 'Choose the kind of account you need';

  @override
  String get roleCompanyTitle => 'Company';

  @override
  String get roleCompanySubtitle =>
      'Ship your cargo — request trucks and track deliveries';

  @override
  String get roleDriverTitle => 'Individual (Driver)';

  @override
  String get roleDriverSubtitle =>
      'Drive your own truck — get matched with shipments';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String stepXofY(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get stepAccountInfoTitle => 'Account Information';

  @override
  String get stepAccountInfoSubtitle => 'Enter your account details';

  @override
  String get stepReviewTitle => 'Review Your Information';

  @override
  String get stepReviewSubtitle =>
      'Please review all information before submitting';

  @override
  String get documentsNotice =>
      'All documents must be clear and valid. Expired documents are not accepted.';

  @override
  String get reviewCannotEditNotice =>
      'You won\'t be able to edit this after submission.';

  @override
  String get submitForReview => 'Submit for Review';

  @override
  String get validationFillRequired => 'Please fill in all required fields';

  @override
  String get validationInvalidEmail => 'Please enter a valid email address';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String errorSubmitGeneric(String error) {
    return 'Something went wrong while submitting: $error';
  }

  @override
  String get companyRegStepCompanyTitle => 'Company Information';

  @override
  String get companyRegStepCompanySubtitle => 'Tell us about your company';

  @override
  String get companyRegStepDocumentsTitle => 'Company Documents';

  @override
  String get companyRegStepDocumentsSubtitle => 'All documents are mandatory';

  @override
  String get companyNameLabel => 'Company Name';

  @override
  String get companyNameHint => 'Global Logistics LLC';

  @override
  String get companyEmailHint => 'contact@company.com';

  @override
  String get companyAgreeTerms =>
      'I agree to the Terms & Conditions and Privacy Policy';

  @override
  String get companyPhoneLabel => 'Phone Number';

  @override
  String get companyPhoneHint => '+971 4 123 4567';

  @override
  String get companyAddressLabel => 'Company Address';

  @override
  String get companyAddressHint => 'Street, city, country';

  @override
  String get tradeLicenseLabel => 'Trade License';

  @override
  String get tradeLicenseUploaded => 'Trade license uploaded';

  @override
  String get noDocumentUploaded => 'No document uploaded';

  @override
  String get validationAgreeTerms => 'Please agree to the Terms & Conditions';

  @override
  String get validationCompanyPhone => 'Please enter your company phone number';

  @override
  String get validationCompanyAddress => 'Please enter your company address';

  @override
  String get validationAttachLicense => 'Please attach your trade license';

  @override
  String get driverRegStepDriverTitle => 'Driver Information';

  @override
  String get driverRegStepDriverSubtitle => 'All fields are mandatory';

  @override
  String get driverRegStepDocumentsTitle => 'Driver Documents';

  @override
  String get driverRegStepDocumentsSubtitle => 'All documents are mandatory';

  @override
  String get driverRegStepHealthTitle => 'Health & Coverage';

  @override
  String get driverRegStepHealthSubtitle =>
      'Tell us about your health and work coverage';

  @override
  String get driverRegStepTruckTitle => 'Truck Information';

  @override
  String get driverRegStepTruckSubtitle => 'Enter your truck details';

  @override
  String get driverRegStepTruckDocsTitle => 'Truck Documents';

  @override
  String get driverRegStepTruckDocsSubtitle => 'All documents are mandatory';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get fullNameHint => 'Mohamed Ali';

  @override
  String get driverEmailHint => 'mohamed.ali@example.com';

  @override
  String get driverAgreeTerms => 'I agree to the Terms & Conditions';

  @override
  String get codeLabel => 'Code';

  @override
  String get phoneCountryTitle => 'Phone country';

  @override
  String get phoneNumberLabel => 'Phone Number';

  @override
  String get phoneNumberHint => '50 123 4567';

  @override
  String get nationalityLabel => 'Nationality';

  @override
  String get nationalityHint => 'Select nationality';

  @override
  String get nationalityTitle => 'Nationality';

  @override
  String get dateOfBirthLabel => 'Date of Birth';

  @override
  String get dateOfBirthHint => '15 / 05 / 1992';

  @override
  String get ageLabel => 'Age';

  @override
  String get driverLicenseNumberLabel => 'Driver License Number';

  @override
  String get driverLicenseNumberHint => 'D1234567';

  @override
  String get searchCountryHint => 'Search country';

  @override
  String get docLicenseFront => 'Driving license — front';

  @override
  String get docLicenseBack => 'Driving license — back (optional)';

  @override
  String get docPassport => 'Passport (first page)';

  @override
  String get docResidency => 'Emirates ID / Residency';

  @override
  String get docDriverPhoto => 'Driver photo (optional)';

  @override
  String get docDriverPhotoHint => 'A clear portrait photo';

  @override
  String get expiryDateLabel => 'Expiry Date';

  @override
  String get expiryDateHint => 'dd/mm/yyyy';

  @override
  String get healthStatusLabel => 'Health Status';

  @override
  String get healthStatusHint => 'Select any conditions';

  @override
  String get healthStatusTitle => 'Health status';

  @override
  String get describeOtherCondition => 'Describe the other condition';

  @override
  String get bloodTypeLabel => 'Blood Type';

  @override
  String get bloodTypeHint => 'Select blood type';

  @override
  String get bloodTypeTitle => 'Blood type';

  @override
  String get workDestinationsLabel => 'Work Destinations';

  @override
  String get workDestinationsHint => 'Countries you operate in';

  @override
  String get workDestinationsTitle => 'Work destinations';

  @override
  String get truckTypeLabel => 'Truck Type';

  @override
  String get truckTypeHint => 'Select truck type';

  @override
  String get truckTypeTitle => 'Truck type';

  @override
  String get truckPlateLabel => 'Truck Plate / Number';

  @override
  String get truckPlateHint => 'C 12345';

  @override
  String get permitTypeLabel => 'Permit Type (optional)';

  @override
  String get docVehicleReg => 'Vehicle registration';

  @override
  String get docInsurance => 'Insurance (optional)';

  @override
  String get docInspection => 'Technical inspection (optional)';

  @override
  String get truckDocsNotice =>
      'Make sure the vehicle registration is valid — expired documents are not accepted.';

  @override
  String get reviewAccountInfoTitle => 'Account Information';

  @override
  String get reviewDriverInfoTitle => 'Driver Information';

  @override
  String get reviewDriverDocsTitle => 'Driver Documents';

  @override
  String get reviewCompanyInfoTitle => 'Company Information';

  @override
  String get reviewTruckInfoTitle => 'Truck Information';

  @override
  String get reviewTruckDocsTitle => 'Truck Documents';

  @override
  String uploadedCountOfTotal(int count, int total) {
    return '$count/$total uploaded';
  }

  @override
  String licenseNumberPrefix(String number) {
    return 'License #$number';
  }

  @override
  String get driverValidationAgreeTerms =>
      'Please agree to the Terms of Service and Privacy Policy';

  @override
  String get driverValidationPhone =>
      'Please enter a valid phone number (digits only)';

  @override
  String get driverValidationNationality => 'Please select your nationality';

  @override
  String get driverValidationDob => 'Please select your date of birth';

  @override
  String get driverValidationAge => 'Age must be between 18 and 65';

  @override
  String get driverValidationLicenseNumber =>
      'Please enter your driving license number';

  @override
  String get driverValidationLicenseDoc =>
      'Please attach your driving license (front) and its expiry date';

  @override
  String get driverValidationPassportDoc =>
      'Please attach your passport and its expiry date';

  @override
  String get driverValidationResidencyDoc =>
      'Please attach your Emirates ID / residency and its expiry date';

  @override
  String get driverValidationBloodType => 'Please select your blood type';

  @override
  String get driverValidationDestinations =>
      'Please pick at least one destination you work on';

  @override
  String get driverValidationTruckType => 'Please select your truck type';

  @override
  String get driverValidationTruckPlate =>
      'Please enter your truck plate/number';

  @override
  String get driverValidationVehicleRegDoc =>
      'Please attach the vehicle registration file';

  @override
  String get otpTitle => 'Verify your\nemail.';

  @override
  String otpSubtitle(String email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get otpEnterCode => 'Enter the code we emailed you';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpResendCode => 'Resend code';

  @override
  String otpResendCodeIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String otpResentTo(String email) {
    return 'A new code has been sent to $email';
  }

  @override
  String otpSomethingWrong(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get forceChangePasswordTitle => 'Set a new\npassword.';

  @override
  String get forceChangePasswordSubtitle =>
      'For security, you must set your own password before continuing.';

  @override
  String get temporaryPasswordLabel => 'Temporary password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get passwordRequirementsHint =>
      'Minimum 8 characters, upper & lower case, a number and a symbol.';

  @override
  String get updatePassword => 'Update password';

  @override
  String get navHome => 'Home';

  @override
  String get navShipments => 'Shipments';

  @override
  String get navWallet => 'Wallet';

  @override
  String get navProfile => 'Profile';

  @override
  String get navFinance => 'Finance';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navApprovals => 'Approvals';

  @override
  String get navMenu => 'Menu';

  @override
  String get navOffers => 'Offers';

  @override
  String get navDrivers => 'Drivers';

  @override
  String get navCompanies => 'Companies';

  @override
  String get navReports => 'Reports';

  @override
  String get drawerDrivers => 'Drivers';

  @override
  String get drawerCompanies => 'Companies';

  @override
  String get drawerOffers => 'Offers';

  @override
  String get drawerWorkDestinations => 'Work Destinations';

  @override
  String get drawerReports => 'Reports';

  @override
  String get drawerNotifications => 'Notifications';

  @override
  String get drawerActivityLog => 'Activity Log';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get roleSuperAdmin => 'Super Admin';

  @override
  String get roleSubAdmin => 'Sub Admin';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNoneAvailable =>
      'No settings are available for your current permissions.';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionAdministration => 'Administration';

  @override
  String get settingsSectionFinance => 'Finance & Payments';

  @override
  String get settingsSectionRecycleBin => 'Recycle Bin';

  @override
  String get adminAccountsTitle => 'Admin Accounts';

  @override
  String get adminAccountsSubtitle =>
      'Create sub-admins, manage permissions, suspend or remove them';

  @override
  String get profileEditRequestsTitle => 'Profile Edit Requests';

  @override
  String get profileEditRequestsSubtitle =>
      'Review driver/company self-service changes before they apply';

  @override
  String get financeTileTitle => 'Finance';

  @override
  String get financeTileSubtitle =>
      'Review top-ups, driver payouts, and set company credit limits';

  @override
  String get priceListTitle => 'Price List';

  @override
  String get priceListSubtitle =>
      'Finance Admin: export/import the central price matrix';

  @override
  String get zonePricingTitle => 'Zone Pricing';

  @override
  String get zonePricingSubtitle =>
      'Smart Pricing Engine: review historical lanes, adjust market %';

  @override
  String get platformSettingsTitle => 'Platform Settings';

  @override
  String get platformSettingsSubtitle =>
      'Super Admin only — profit margin, matching weights/timeout, driver-ops defaults';

  @override
  String get deletedDriversTitle => 'Deleted Drivers';

  @override
  String get deletedDriversSubtitle =>
      'Restore drivers removed from the system';

  @override
  String get deletedCompaniesTitle => 'Deleted Companies';

  @override
  String get deletedCompaniesSubtitle =>
      'Restore companies removed from the system';

  @override
  String get couldntConnectTitle => 'Couldn\'t connect';

  @override
  String get couldntConnectBody =>
      'You\'re still signed in — this just couldn\'t reach the server. Check your connection and try again.';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String greetingComma(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get driveSafe => 'Drive safe!';

  @override
  String get activeTripBanner =>
      'Active Trip — location sharing is on. Logout is unavailable until it ends.';

  @override
  String get complianceExpiringTitle => 'Document expiring soon';

  @override
  String get complianceExpiringBody =>
      'A document is expiring soon — renew it now to avoid losing new shipment offers.';

  @override
  String get compliancePendingTitle => 'Renewal under review';

  @override
  String get compliancePendingBody =>
      'Your renewal was submitted and is awaiting admin approval — you won\'t receive new shipment offers until it\'s approved.';

  @override
  String get complianceActionTitle => 'Action needed';

  @override
  String get complianceActionBody =>
      'A document has expired — renew it now to keep receiving new shipment offers.';

  @override
  String get walletBalanceLabel => 'Wallet Balance';

  @override
  String get couldNotLoadWalletBalance =>
      'Could not load wallet balance — showing AED 0 for now.';

  @override
  String get quickOverview => 'Quick Overview';

  @override
  String get viewAll => 'View All';

  @override
  String get statActiveTrips => 'Active Trips';

  @override
  String get statUpcoming => 'Upcoming';

  @override
  String get statCompleted => 'Completed';

  @override
  String get statPendingPayments => 'Pending Payments';

  @override
  String get currentTripLabel => 'Current Trip';

  @override
  String get recentNotifications => 'Recent Notifications';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String couldNotLoadShipments(String error) {
    return 'Could not load your shipments.\n$error';
  }

  @override
  String get viewTracking => 'View Tracking';

  @override
  String get companyHomeSubtitle => 'Here\'s what\'s moving today';

  @override
  String get blockedCreateShipmentExpiring =>
      'Your trade license is expiring soon — renew it to avoid losing the ability to create shipments.';

  @override
  String get blockedCreateShipmentPending =>
      'Your trade license renewal is still pending admin review.';

  @override
  String get blockedCreateShipmentExpired =>
      'Your trade license has expired — renew it to create new shipments.';

  @override
  String get trackAShipmentTitle => 'Track a Shipment';

  @override
  String get companyComplianceExpiringTitle => 'Trade license expiring soon';

  @override
  String get companyCompliancePendingTitle => 'Renewal under review';

  @override
  String get companyComplianceActionTitle => 'Action Required';

  @override
  String get companyComplianceExpiringBody =>
      'Renew it before it expires to avoid losing the ability to create new shipments.';

  @override
  String get companyCompliancePendingBody =>
      'Your renewed trade license was submitted and is awaiting admin approval.';

  @override
  String get companyComplianceActionBody =>
      'Renew your Trade License to create new shipments.';

  @override
  String get trackLiveShipmentOne => 'Track Live Shipment';

  @override
  String trackLiveShipmentsMany(int count) {
    return 'Track $count Live Shipments';
  }

  @override
  String get onTheRoadNow => 'On the road now — tap to view the live map';

  @override
  String get statActiveShipments => 'Active Shipments';

  @override
  String get statInTransit => 'In Transit';

  @override
  String get statPending => 'Pending';

  @override
  String get statDelivered => 'Delivered';

  @override
  String get createShipment => 'Create Shipment';

  @override
  String get createShipmentBlocked => 'Create Shipment (Blocked)';

  @override
  String get viewMyOffers => 'View My Offers';

  @override
  String get recentShipments => 'Recent Shipments';

  @override
  String get noShipmentsYet => 'No shipments yet';

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdayTuesday => 'Tuesday';

  @override
  String get weekdayWednesday => 'Wednesday';

  @override
  String get weekdayThursday => 'Thursday';

  @override
  String get weekdayFriday => 'Friday';

  @override
  String get weekdaySaturday => 'Saturday';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String get monthJanuary => 'January';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthMarch => 'March';

  @override
  String get monthApril => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'June';

  @override
  String get monthJuly => 'July';

  @override
  String get monthAugust => 'August';

  @override
  String get monthSeptember => 'September';

  @override
  String get monthOctober => 'October';

  @override
  String get monthNovember => 'November';

  @override
  String get monthDecember => 'December';

  @override
  String todayLabelFormat(String weekday, String month, int day, int year) {
    return '$weekday, $month $day, $year';
  }

  @override
  String couldNotLoadDashboardStats(String error) {
    return 'Could not load dashboard stats.\n$error';
  }

  @override
  String get statPendingApprovals => 'Pending Approvals';

  @override
  String get statDocumentRenewals => 'Document Renewals';

  @override
  String get statChangesRequired => 'Changes Required';

  @override
  String get statActiveDrivers => 'Active Drivers';

  @override
  String get statAvailableTrucks => 'Available Trucks';

  @override
  String get statActiveCompanies => 'Active Companies';

  @override
  String get statCompletedThisMonth => 'Completed This Month';

  @override
  String get importantAlerts => 'Important Alerts';

  @override
  String get allCaughtUp => 'All caught up — no alerts right now.';

  @override
  String get myShipmentsTitle => 'My Shipments';

  @override
  String tabAllCount(int count) {
    return 'All ($count)';
  }

  @override
  String tabActiveCount(int count) {
    return 'Active ($count)';
  }

  @override
  String tabCompletedCount(int count) {
    return 'Completed ($count)';
  }

  @override
  String tabCancelledCount(int count) {
    return 'Cancelled ($count)';
  }

  @override
  String get failedToLoadShipments => 'Failed to load shipments';

  @override
  String get noShipmentsHere => 'No shipments here';

  @override
  String get shipmentsMatchingFilterEmpty =>
      'Shipments matching this filter will appear here.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get contactInformationTitle => 'Contact Information';

  @override
  String get accountSectionTitle => 'Account';

  @override
  String get personalInformationLabel => 'Personal Information';

  @override
  String get personalInformationSubtitle => 'Name, phone & email';

  @override
  String get bankDetailsLabel => 'Bank Details';

  @override
  String get bankDetailsSubtitle => 'Where your payouts are sent';

  @override
  String get changePasswordLabel => 'Change Password';

  @override
  String get changePasswordSubtitle => 'Update your login password';

  @override
  String get helpSupportLabel => 'Help & Support';

  @override
  String get helpSupportSubtitle => 'Call, WhatsApp, email & FAQs';

  @override
  String get financeSectionTitle => 'Finance';

  @override
  String get myBalanceLabel => 'My Balance';

  @override
  String get myPerformanceTitle => 'My Performance';

  @override
  String get statCompletedLabel => 'Completed';

  @override
  String get statCancelledLabel => 'Cancelled';

  @override
  String get ratingComplianceTitle => 'Rating & Compliance';

  @override
  String get documentsCoverageTitle => 'Documents & Coverage';

  @override
  String get myDocumentsLabel => 'My Documents';

  @override
  String get myDocumentsSubtitle => 'License, passport, residency & more';

  @override
  String get myTruckLabel => 'My Truck';

  @override
  String get myTruckSubtitle => 'Plate, capacity & document expiry';

  @override
  String get myDestinationsLabel => 'My Destinations';

  @override
  String get myDestinationsSubtitle =>
      'Countries you cover — used for matching';

  @override
  String get myTrucksTitle => 'My Trucks';

  @override
  String get addTruckLabel => 'Add Truck';

  @override
  String get couldNotLoadTrucks => 'Could not load trucks';

  @override
  String get noTrucksAddedYet =>
      'No trucks added yet. Add your truck so you can be matched with shipments.';

  @override
  String get roleUserFallback => 'User';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleCompany => 'Company';

  @override
  String get newTradeLicenseExpiryDate => 'New trade license expiry date';

  @override
  String get licenseStatusExpired => 'Expired';

  @override
  String get licenseStatusExpiringSoon => 'Expiring Soon';

  @override
  String get licenseStatusPendingReview => 'Pending Review';

  @override
  String get licenseStatusValid => 'Valid';

  @override
  String daysOverdue(int days) {
    return '${days}d overdue';
  }

  @override
  String get expiresToday => 'Expires today';

  @override
  String daysLeft(int days) {
    return '${days}d left';
  }

  @override
  String get editCompanyInfoTitle => 'Edit Company Info';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get companyInformationTitle => 'Company Information';

  @override
  String get phoneLabelShort => 'Phone';

  @override
  String get notUploadedYet => 'Not uploaded yet';

  @override
  String get tradeLicenseOnFile => 'Trade license on file';

  @override
  String get uploadingEllipsis => 'Uploading…';

  @override
  String get uploadTradeLicense => 'Upload Trade License';

  @override
  String get renewTradeLicense => 'Renew Trade License';

  @override
  String get financeLinkSubtitle => 'Balance, credit limit & top-ups';

  @override
  String get notificationsLinkSubtitle => 'Shipment & account updates';

  @override
  String get accountStatusActive => 'Active';

  @override
  String get accountStatusSuspended => 'Suspended';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String couldNotLoadNotifications(String error) {
    return 'Could not load notifications: $error';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterUnread => 'Unread';

  @override
  String get noUnreadNotifications => 'No unread notifications';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get addShipmentTitle => 'Create Shipment';

  @override
  String get addShipmentStepRoute => 'Route';

  @override
  String get addShipmentStepCargo => 'Cargo Details';

  @override
  String get addShipmentStepTruckPricing => 'Truck & Pricing';

  @override
  String get addShipmentStepReview => 'Review & Submit';

  @override
  String get addShipmentSubtitleRoute => 'Where is this shipment going?';

  @override
  String get addShipmentSubtitleCargo => 'Tell us what\'s being shipped';

  @override
  String get addShipmentSubtitleTruckPricing =>
      'What kind of truck, and what will you pay?';

  @override
  String get addShipmentSubtitleReview =>
      'Check everything before creating the offer';

  @override
  String addShipmentFailedToLoadZones(String error) {
    return 'Failed to load zones: $error';
  }

  @override
  String get addShipmentSelectPickupZone => 'Please select a pickup zone';

  @override
  String get addShipmentSelectDropoffZone => 'Please select a drop-off zone';

  @override
  String get addShipmentWeightMustBeNumber => 'Weight must be a number';

  @override
  String get addShipmentSelectTruckTypeRequired =>
      'Please select a required truck type';

  @override
  String get addShipmentDomestic => 'Domestic shipment';

  @override
  String get addShipmentCrossBorder => 'Cross-border shipment';

  @override
  String get addShipmentPickupLabel => 'Pickup';

  @override
  String get addShipmentDropoffLabel => 'Drop-off';

  @override
  String get addShipmentPickupCountry => 'Pickup Country';

  @override
  String get addShipmentPickupCity => 'Pickup City';

  @override
  String get addShipmentPickupZone => 'Pickup Zone';

  @override
  String get addShipmentDropoffCountry => 'Drop-off Country';

  @override
  String get addShipmentDropoffCity => 'Drop-off City';

  @override
  String get addShipmentDropoffZone => 'Drop-off Zone';

  @override
  String get addShipmentPickupAddressOptional => 'Pickup Address (optional)';

  @override
  String get addShipmentDropoffAddressOptional => 'Drop-off Address (optional)';

  @override
  String get addShipmentAddressHint => 'Building, street, landmark…';

  @override
  String get addShipmentSelectCountry => 'Select a country';

  @override
  String get addShipmentSelectCountryFirst => 'Select a country first';

  @override
  String get addShipmentSelectCity => 'Select a city';

  @override
  String get addShipmentSelectCityFirst => 'Select a city first';

  @override
  String get addShipmentSelectZone => 'Select a zone';

  @override
  String get addShipmentWeightKg => 'Weight (kg)';

  @override
  String get addShipmentCargoDescription => 'Cargo Description';

  @override
  String get addShipmentCargoDescriptionHint =>
      'Optional — what\'s being shipped';

  @override
  String get addShipmentRequiredTruckType => 'Required Truck Type';

  @override
  String get addShipmentSelectTruckType => 'Select a truck type';

  @override
  String get addShipmentRequiresPermit => 'Requires special permit';

  @override
  String get addShipmentHazardousCargo => 'Hazardous cargo';

  @override
  String get addShipmentFragileCargo => 'Fragile cargo';

  @override
  String get addShipmentPricingLabel => 'Pricing';

  @override
  String get addShipmentPricingSelectPrompt =>
      'Select a pickup zone, drop-off zone, and truck type to see a price suggestion.';

  @override
  String get addShipmentPricingNotLoaded => 'Price suggestion not loaded yet.';

  @override
  String get addShipmentPricingNoHistorical =>
      'No historical pricing for this lane — our team will review and set a price shortly after you submit.';

  @override
  String get addShipmentNoOptionsAvailable => 'No options available';

  @override
  String get addShipmentNoZonesForCity => 'No zones available for this city';

  @override
  String addShipmentHistoricalReference(String value) {
    return 'Historical reference: $value';
  }

  @override
  String addShipmentTypicalRange(String value) {
    return 'Typical range: $value';
  }

  @override
  String addShipmentPastTrips(int count) {
    return '$count past trips';
  }

  @override
  String get addShipmentYourPriceLabel => 'Your Price (AED, charged to you)';

  @override
  String get addShipmentYourPriceHint =>
      'Defaults to the historical reference — you may change it';

  @override
  String get addShipmentCreateOfferButton => 'Create Offer';

  @override
  String get addShipmentReviewType => 'Type';

  @override
  String get addShipmentReviewOrigin => 'Origin';

  @override
  String get addShipmentReviewDestination => 'Destination';

  @override
  String get addShipmentReviewWeight => 'Weight';

  @override
  String get addShipmentReviewDescription => 'Description';

  @override
  String get addShipmentReviewTruckType => 'Truck Type';

  @override
  String get addShipmentReviewSpecialPermit => 'Special Permit';

  @override
  String get addShipmentReviewHazardous => 'Hazardous';

  @override
  String get addShipmentReviewFragile => 'Fragile';

  @override
  String get addShipmentReviewYourPrice => 'Your Price';

  @override
  String get addShipmentDomesticShort => 'Domestic';

  @override
  String get addShipmentCrossBorderShort => 'Cross-border';

  @override
  String get addShipmentSetByCrm => 'Set by CRM after review';

  @override
  String get addShipmentSuccessNoAutoPrice =>
      'Offer created — no automatic price found, CRM will set one shortly';

  @override
  String get addShipmentSuccessMatching =>
      'Offer created — matching drivers now';

  @override
  String addShipmentSomethingWentWrong(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get companyShipmentsSearchHint =>
      'Search by tracking #, ID, or route...';

  @override
  String get tabPendingLabel => 'Pending';

  @override
  String get tabLiveLabel => 'Live';

  @override
  String get tabDeliveredLabel => 'Delivered';

  @override
  String get adminShipmentsTitle => 'Shipments';

  @override
  String get adminShipmentsSearchHint =>
      'Search by tracking no., company, driver...';

  @override
  String get adminShipmentsChipActive => 'Active';

  @override
  String get adminShipmentsChipDelivered => 'Delivered';

  @override
  String get adminShipmentsChipCancelled => 'Cancelled';

  @override
  String get adminShipmentsNoneFound => 'No shipments found';

  @override
  String get adminShipmentsWaitingForDriver => 'Waiting for driver';

  @override
  String get shipmentDetailsTitle => 'Shipment Details';

  @override
  String get rateDriverTitle => 'Rate this driver';

  @override
  String get commentOptionalHint => 'Comment (optional)';

  @override
  String get reportDriverTitle => 'Report driver';

  @override
  String get describeWhatHappenedHint => 'Describe what happened';

  @override
  String get reviewProofOfDeliveryButton => 'Review Proof of Delivery';

  @override
  String get viewTrackingTimelineButton => 'View Tracking Timeline';

  @override
  String get reportDriverButton => 'Report driver';

  @override
  String get awaitingYourConfirmation => 'Awaiting your confirmation';

  @override
  String get underAdminReview => 'Under admin review';

  @override
  String get sectionRoute => 'Route';

  @override
  String get sectionShipmentInfo => 'Shipment Info';

  @override
  String get sectionTimeline => 'Timeline';

  @override
  String get fieldShipmentId => 'Shipment ID';

  @override
  String get fieldCreated => 'Created';

  @override
  String get fieldPickupTime => 'Pickup Time';

  @override
  String get fieldDeliveredAt => 'Delivered At';

  @override
  String get yourReportedProblem => 'Your reported problem';

  @override
  String get availableShipmentsTitle => 'Available Shipments';

  @override
  String get availabilityAvailable => 'Available';

  @override
  String get availabilityUnavailable => 'Unavailable';

  @override
  String get couldNotUpdateStatus => 'Could not update status';

  @override
  String get searchByLocationLoadType => 'Search by location, load type...';

  @override
  String tabNearbyCount(int count) {
    return 'Nearby ($count)';
  }

  @override
  String tabSavedCount(int count) {
    return 'Saved ($count)';
  }

  @override
  String get couldNotLoadOffers => 'Could not load offers';

  @override
  String get noSavedOffersYet => 'No saved offers yet.';

  @override
  String get noNearbyOffersRightNow =>
      'No nearby offers with pickup coordinates right now.';

  @override
  String get noMatchingOffersRightNow => 'No matching offers right now.';

  @override
  String get tagPermit => 'permit';

  @override
  String get tagHazardous => 'hazardous';

  @override
  String get tagFragile => 'fragile';

  @override
  String distanceKmAway(String km) {
    return '$km km away';
  }

  @override
  String priceLabelAed(String price) {
    return 'Price: $price AED';
  }

  @override
  String get detailsButton => 'Details';

  @override
  String get acceptButton => 'Accept';

  @override
  String get declineOfferTitle => 'Decline this offer?';

  @override
  String get declineOfferBody =>
      'You won\'t be matched with this shipment again unless it\'s re-offered.';

  @override
  String get commonDecline => 'Decline';

  @override
  String get commonSaved => 'Saved';

  @override
  String get failedToDeclineOffer => 'Failed to decline offer';

  @override
  String get statusOffered => 'Offered';

  @override
  String postedByCompany(String name) {
    return 'Posted by $name';
  }

  @override
  String get sectionLoadInformation => 'Load Information';

  @override
  String get fieldOrderType => 'Order Type';

  @override
  String get fieldPickupZone => 'Pickup Zone';

  @override
  String get fieldDropoffZone => 'Drop-off Zone';

  @override
  String get requirementSpecialPermit => 'Special permit';

  @override
  String get requirementHazardousCargo => 'Hazardous cargo';

  @override
  String get requirementFragileCargo => 'Fragile cargo';

  @override
  String get fieldRequirements => 'Requirements';

  @override
  String get sectionCargoDescription => 'Cargo Description';

  @override
  String get sectionPayment => 'Payment';

  @override
  String get fieldPriceToYou => 'Price to you';

  @override
  String get toBeConfirmed => 'To be confirmed';

  @override
  String get acceptShipmentButton => 'Accept Shipment';

  @override
  String get myShipmentOffersTitle => 'My Shipment Offers';

  @override
  String get newOfferButton => 'New Offer';

  @override
  String get failedToLoadOffers => 'Failed to load offers';

  @override
  String get noOffersYet => 'No offers yet';

  @override
  String get tapNewOfferHint => 'Tap \"New Offer\" to request a shipment.';

  @override
  String get offerStatusMatchingDrivers => 'Matching drivers';

  @override
  String get offerStatusAwaitingPrice => 'Awaiting price';

  @override
  String get offerStatusEscalated => 'Escalated';

  @override
  String get offerStatusAccepted => 'Accepted';

  @override
  String get offerStatusCancelled => 'Cancelled';

  @override
  String get offerStatusExpired => 'Expired';

  @override
  String get raisePriceDialogTitle => 'Raise price to client';

  @override
  String get newPriceAedLabel => 'New price (AED)';

  @override
  String get cancelOfferDialogTitle => 'Cancel offer';

  @override
  String get reasonLabel => 'Reason';

  @override
  String get commonBack => 'Back';

  @override
  String get cancelOfferButton => 'Cancel Offer';

  @override
  String get offerCancelledMsg => 'Offer cancelled';

  @override
  String get failedToCancelOffer => 'Failed to cancel offer';

  @override
  String eligibleDriversCount(int count) {
    return '$count eligible driver(s)';
  }

  @override
  String priceToClientLabel(String price) {
    return 'Price to client: $price AED';
  }

  @override
  String get manualSuffix => ' (manual)';

  @override
  String get raisePriceButton => 'Raise price';

  @override
  String get cancelThisOfferTitle => 'Cancel this offer?';

  @override
  String get cancellationReasonHint => 'Cancellation reason';

  @override
  String get couldNotCancelOffer => 'Could not cancel the offer';

  @override
  String get notFoundLabel => 'Not found';

  @override
  String get waitingForDriverCardTitle => 'Waiting for Driver';

  @override
  String get findingBestMatchedDrivers =>
      'We are finding the best matched drivers for this shipment.';

  @override
  String get statEligibleDrivers => 'Eligible Drivers';

  @override
  String get statOffersSent => 'Offers Sent';

  @override
  String get statCurrentRound => 'Current Round';

  @override
  String get cancellationSectionTitle => 'Cancellation';

  @override
  String get fieldReason => 'Reason';

  @override
  String get fieldCancelledBy => 'Cancelled by';

  @override
  String get fieldCancelledAt => 'Cancelled at';

  @override
  String get pricingReferenceSectionTitle =>
      'Pricing Reference (Smart Pricing Engine)';

  @override
  String get fieldHistoricalReference => 'Historical reference';

  @override
  String get fieldTypicalRange => 'Typical range';

  @override
  String get fieldConfidence => 'Confidence';

  @override
  String get fieldMarketAdjustmentApplied => 'Market adjustment applied';

  @override
  String get fieldCompanyWasCharged => 'Company was charged';

  @override
  String get matchingTimelineTitle => 'Matching Timeline';

  @override
  String get noMatchingRoundsYet => 'No matching rounds yet.';

  @override
  String roundAcceptedBy(String name) {
    return 'Accepted by $name';
  }

  @override
  String get roundAccepted => 'Accepted';

  @override
  String get roundNoAcceptance => 'No acceptance';

  @override
  String get roundWaitingForResponse => 'Waiting for response';

  @override
  String roundNotifiedLabel(String round, String count) {
    return 'Round $round • $count driver(s) notified';
  }

  @override
  String get decisionApprovedTitle => 'Request Approved';

  @override
  String get decisionChangesRequestedTitle => 'Changes Requested';

  @override
  String get decisionRejectedTitle => 'Request Rejected';

  @override
  String decisionApprovedMessageDriver(String name) {
    return '$name has been approved and can now use the app and be matched with shipments.';
  }

  @override
  String decisionApprovedMessageCompany(String name) {
    return '$name has been approved and can now use the app.';
  }

  @override
  String decisionChangesRequiredMessage(String name) {
    return '$name has been notified of the changes needed and can resubmit once they\'re fixed.';
  }

  @override
  String decisionRejectedMessageDriver(String name) {
    return '$name\'s driver registration has been rejected. They have been notified.';
  }

  @override
  String decisionRejectedMessageCompany(String name) {
    return '$name\'s company registration has been rejected. They have been notified.';
  }

  @override
  String get backToRequestsButton => 'Back to Requests';

  @override
  String get cancelledLabel => 'CANCELLED';

  @override
  String get cancellationSummaryTitle => 'Cancellation Summary';

  @override
  String get financialImpactTitle => 'Financial Impact';

  @override
  String get fieldDriverAssigned => 'Driver assigned';

  @override
  String get fieldStageReached => 'Stage reached';

  @override
  String get fieldClientPrice => 'Client Price';

  @override
  String get fieldDriverPrice => 'Driver Price';

  @override
  String get deliveredLabel => 'DELIVERED';

  @override
  String get statDistance => 'Distance';

  @override
  String get statDuration => 'Duration';

  @override
  String get statPickupTime => 'Pickup Time';

  @override
  String get statDeliveryTime => 'Delivery Time';

  @override
  String get tripTimelineTitle => 'Trip Timeline';

  @override
  String get driverAndTruckTitle => 'Driver & Truck';

  @override
  String get fieldDriverLabel => 'Driver';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldTruck => 'Truck';

  @override
  String get financialSummaryTitle => 'Financial Summary';

  @override
  String get fieldCommission => 'Commission';

  @override
  String get proofOfDeliveryTitle => 'Proof of Delivery';

  @override
  String receiverLabel(String name) {
    return 'Receiver: $name';
  }

  @override
  String get documentUnavailable => 'Document unavailable';

  @override
  String get viewDeliveryDocument => 'View delivery document';

  @override
  String get signatureUnavailable => 'Signature unavailable';

  @override
  String get noUpdateYet => 'no update yet';

  @override
  String minAgoFull(int minutes) {
    return '$minutes min ago';
  }

  @override
  String lastLocationUpdateLabel(String ago) {
    return 'Last location update: $ago';
  }

  @override
  String get shipmentProgressTitle => 'Shipment Progress';

  @override
  String get sectionShipmentDetails => 'Shipment Details';

  @override
  String get fieldNeedsPermit => 'Needs Permit';

  @override
  String get fieldRating => 'Rating';

  @override
  String get companySectionTitle => 'Company';

  @override
  String get fieldName => 'Name';

  @override
  String get noLocationDataYet =>
      'No location data available for this shipment yet';

  @override
  String get neverLabel => 'never';

  @override
  String get liveTrackingTitle => 'Live Tracking';

  @override
  String updatedAgoLabel(String ago) {
    return 'Updated $ago';
  }

  @override
  String get noGpsFixYet => 'No GPS fix yet';

  @override
  String get noGpsPositionYetBody =>
      'The driver hasn\'t reported a GPS position yet — this updates automatically once they do (the app reports location while a shipment is in progress).';

  @override
  String get complianceReportsTitle => 'Compliance Reports';

  @override
  String get couldNotLoadReports => 'Could not load reports';

  @override
  String get noComplianceReportsClean =>
      'No compliance reports on file — clean record.';

  @override
  String get appealThisDecisionTitle => 'Appeal this decision';

  @override
  String get appealHint => 'Explain why you believe this decision was wrong';

  @override
  String get submitAppealButton => 'Submit appeal';

  @override
  String actionLabel(String action) {
    return 'Action: $action';
  }

  @override
  String appealLabel(String status) {
    return 'Appeal: $status';
  }

  @override
  String get appealButton => 'Appeal';

  @override
  String get couldNotFindRecord => 'Could not find this record';

  @override
  String get expiredDocumentsTitle => 'Expired Documents';

  @override
  String get documentsExpiringSoonTitle => 'Documents Expiring Soon';

  @override
  String get docTypeLicense => 'License';

  @override
  String get docTypePassport => 'Passport';

  @override
  String get docTypeResidency => 'Residency';

  @override
  String get docTypeInsurance => 'Insurance';

  @override
  String get docTypeTechnicalInspection => 'Technical Inspection';

  @override
  String get docTypeTradeLicense => 'Trade License';

  @override
  String docTypeTruckLabel(String label) {
    return 'Truck $label';
  }

  @override
  String get searchByNameHint => 'Search by name...';

  @override
  String couldNotLoadListError(String error) {
    return 'Could not load list.\n$error';
  }

  @override
  String get nothingHereRightNow => 'Nothing here right now.';

  @override
  String docAlertSubtitle(String type, String date) {
    return '$type · exp. $date';
  }

  @override
  String get resolveReportTitle => 'Resolve report';

  @override
  String get decisionDismiss => 'Dismiss';

  @override
  String get decisionUphold => 'Uphold';

  @override
  String get actionWarning => 'Warning';

  @override
  String get actionSuspension => 'Suspension';

  @override
  String get actionBan => 'Ban';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get complianceTitle => 'Compliance';

  @override
  String get tabReports => 'Reports';

  @override
  String get tabAppeals => 'Appeals';

  @override
  String get noReportsPendingReview => 'No reports pending review';

  @override
  String get noPendingAppeals => 'No pending appeals';

  @override
  String get resolveButton => 'Resolve';

  @override
  String get rejectAppealButton => 'Reject appeal';

  @override
  String get acceptAppealButton => 'Accept appeal';

  @override
  String driverHashLabel(String id) {
    return 'Driver #$id';
  }

  @override
  String get requestChangesDialogTitle => 'Request changes';

  @override
  String get requestChangesReasonHint =>
      'Reason (e.g. blurry photo, wrong document, expired)';

  @override
  String get sendBackButton => 'Send Back';

  @override
  String get documentRenewalTitle => 'Document Renewal';

  @override
  String userHashLabel(String id) {
    return 'User #$id';
  }

  @override
  String get oldDocumentTitle => 'Old Document';

  @override
  String get newDocumentTitle => 'New Document';

  @override
  String get fieldStatus => 'Status';

  @override
  String get noPreviousDocument => 'No previous document on file';

  @override
  String get fieldExpiryDate => 'Expiry Date';

  @override
  String get fieldNewExpiryDate => 'New Expiry Date';

  @override
  String get fieldSubmitted => 'Submitted';

  @override
  String get statusPendingReview => 'Pending Review';

  @override
  String get requestChangesButton => 'Request Changes';

  @override
  String get approveButton => 'Approve';

  @override
  String get previewDocumentButton => 'Preview Document';

  @override
  String get shipmentTrackingTitle => 'Shipment Tracking';

  @override
  String get addCommentTooltip => 'Add comment';

  @override
  String get liveLabel => 'Live';

  @override
  String get deliveryStatusAwaitingConfirmation => 'Awaiting confirmation';

  @override
  String get deliveryStatusConfirmed => 'Confirmed';

  @override
  String get deliveryStatusDisputed => 'Disputed';

  @override
  String get deliveryStatusNotDelivered => 'Not delivered';

  @override
  String receivedByLabel(String name) {
    return 'Received by: $name';
  }

  @override
  String get addCommentDialogTitle => 'Add a comment';

  @override
  String get addCommentHint => 'e.g. truck breakdown, road closure...';

  @override
  String get commentAddedMsg => 'Comment added';

  @override
  String get failedToAddComment => 'Failed to add comment';

  @override
  String get failedGeneric => 'Failed';

  @override
  String get deliveryRecordedMsg =>
      'Delivery recorded — awaiting company confirmation before payout';

  @override
  String get captureProofOfDeliveryButton => 'Capture proof of delivery';

  @override
  String markAsLabel(String label) {
    return 'Mark as: $label';
  }

  @override
  String get noGpsFixUpdatesAutomatically =>
      'No GPS fix yet — updates automatically once the driver reports one';

  @override
  String get docStatusExpired => 'Expired';

  @override
  String get docStatusExpiringSoon => 'Expiring Soon';

  @override
  String get docStatusValid => 'Valid';

  @override
  String get docStatusChangesRequired => 'Changes Required';

  @override
  String get docStatusNotUploaded => 'Not Uploaded';

  @override
  String uploadDialogTitle(String label) {
    return 'Upload $label';
  }

  @override
  String get chooseFileHint => 'Choose file (PDF/JPG/PNG)';

  @override
  String get expiryDateOptionalHint => 'Expiry date (optional)';

  @override
  String get uploadButton => 'Upload';

  @override
  String renewDialogTitle(String label) {
    return 'Renew $label';
  }

  @override
  String get newExpiryDateHint => 'New expiry date';

  @override
  String get submitForReviewButton => 'Submit for Review';

  @override
  String get driverDocumentsTabLabel => 'Driver Documents';

  @override
  String get truckDocumentsTabLabel => 'Truck Documents';

  @override
  String get couldNotLoadTruckDocs => 'Could not load truck documents';

  @override
  String get noTruckRegisteredYet => 'No truck registered yet';

  @override
  String get renewingSubmitsForReviewNote =>
      'Renewing a document here submits it for admin review — it applies once approved.';

  @override
  String get vehicleLicenseLabel => 'Vehicle License';

  @override
  String expDateLabel(String date) {
    return 'exp. $date';
  }

  @override
  String get viewButton => 'View';

  @override
  String get renewButton => 'Renew';

  @override
  String get couldNotLoadDocumentsMsg => 'Could not load documents';

  @override
  String get mandatoryDocsBlockNote =>
      'Missing, expired, or expiring-soon mandatory documents (license, passport, residency) will block your account from being matched with shipments until renewed and approved.';
}

/// Static list of countries (English name + ISO2 code + international
/// dialing code), used for the driver registration form's nationality
/// dropdown and phone-number country picker. No package/network dependency
/// — a fixed reference list like this doesn't need to be fetched live.
class CountryInfo {
  final String name;
  final String iso2;
  final String dialCode;

  const CountryInfo(this.name, this.iso2, this.dialCode);

  /// e.g. "United Arab Emirates (+971)"
  String get displayWithDialCode => '$name (+$dialCode)';

  @override
  String toString() => name;
}

const List<CountryInfo> kCountries = [
  CountryInfo('Afghanistan', 'AF', '93'),
  CountryInfo('Albania', 'AL', '355'),
  CountryInfo('Algeria', 'DZ', '213'),
  CountryInfo('Andorra', 'AD', '376'),
  CountryInfo('Angola', 'AO', '244'),
  CountryInfo('Argentina', 'AR', '54'),
  CountryInfo('Armenia', 'AM', '374'),
  CountryInfo('Australia', 'AU', '61'),
  CountryInfo('Austria', 'AT', '43'),
  CountryInfo('Azerbaijan', 'AZ', '994'),
  CountryInfo('Bahrain', 'BH', '973'),
  CountryInfo('Bangladesh', 'BD', '880'),
  CountryInfo('Belarus', 'BY', '375'),
  CountryInfo('Belgium', 'BE', '32'),
  CountryInfo('Benin', 'BJ', '229'),
  CountryInfo('Bhutan', 'BT', '975'),
  CountryInfo('Bolivia', 'BO', '591'),
  CountryInfo('Bosnia and Herzegovina', 'BA', '387'),
  CountryInfo('Botswana', 'BW', '267'),
  CountryInfo('Brazil', 'BR', '55'),
  CountryInfo('Brunei', 'BN', '673'),
  CountryInfo('Bulgaria', 'BG', '359'),
  CountryInfo('Burkina Faso', 'BF', '226'),
  CountryInfo('Burundi', 'BI', '257'),
  CountryInfo('Cambodia', 'KH', '855'),
  CountryInfo('Cameroon', 'CM', '237'),
  CountryInfo('Canada', 'CA', '1'),
  CountryInfo('Chad', 'TD', '235'),
  CountryInfo('Chile', 'CL', '56'),
  CountryInfo('China', 'CN', '86'),
  CountryInfo('Colombia', 'CO', '57'),
  CountryInfo('Comoros', 'KM', '269'),
  CountryInfo('Congo (DRC)', 'CD', '243'),
  CountryInfo('Congo (Republic)', 'CG', '242'),
  CountryInfo('Costa Rica', 'CR', '506'),
  CountryInfo("Côte d'Ivoire", 'CI', '225'),
  CountryInfo('Croatia', 'HR', '385'),
  CountryInfo('Cuba', 'CU', '53'),
  CountryInfo('Cyprus', 'CY', '357'),
  CountryInfo('Czech Republic', 'CZ', '420'),
  CountryInfo('Denmark', 'DK', '45'),
  CountryInfo('Djibouti', 'DJ', '253'),
  CountryInfo('Dominican Republic', 'DO', '1'),
  CountryInfo('Ecuador', 'EC', '593'),
  CountryInfo('Egypt', 'EG', '20'),
  CountryInfo('El Salvador', 'SV', '503'),
  CountryInfo('Eritrea', 'ER', '291'),
  CountryInfo('Estonia', 'EE', '372'),
  CountryInfo('Ethiopia', 'ET', '251'),
  CountryInfo('Fiji', 'FJ', '679'),
  CountryInfo('Finland', 'FI', '358'),
  CountryInfo('France', 'FR', '33'),
  CountryInfo('Gabon', 'GA', '241'),
  CountryInfo('Gambia', 'GM', '220'),
  CountryInfo('Georgia', 'GE', '995'),
  CountryInfo('Germany', 'DE', '49'),
  CountryInfo('Ghana', 'GH', '233'),
  CountryInfo('Greece', 'GR', '30'),
  CountryInfo('Guatemala', 'GT', '502'),
  CountryInfo('Guinea', 'GN', '224'),
  CountryInfo('Haiti', 'HT', '509'),
  CountryInfo('Honduras', 'HN', '504'),
  CountryInfo('Hungary', 'HU', '36'),
  CountryInfo('Iceland', 'IS', '354'),
  CountryInfo('India', 'IN', '91'),
  CountryInfo('Indonesia', 'ID', '62'),
  CountryInfo('Iran', 'IR', '98'),
  CountryInfo('Iraq', 'IQ', '964'),
  CountryInfo('Ireland', 'IE', '353'),
  CountryInfo('Israel', 'IL', '972'),
  CountryInfo('Italy', 'IT', '39'),
  CountryInfo('Jamaica', 'JM', '1'),
  CountryInfo('Japan', 'JP', '81'),
  CountryInfo('Jordan', 'JO', '962'),
  CountryInfo('Kazakhstan', 'KZ', '7'),
  CountryInfo('Kenya', 'KE', '254'),
  CountryInfo('Kuwait', 'KW', '965'),
  CountryInfo('Kyrgyzstan', 'KG', '996'),
  CountryInfo('Laos', 'LA', '856'),
  CountryInfo('Latvia', 'LV', '371'),
  CountryInfo('Lebanon', 'LB', '961'),
  CountryInfo('Lesotho', 'LS', '266'),
  CountryInfo('Liberia', 'LR', '231'),
  CountryInfo('Libya', 'LY', '218'),
  CountryInfo('Liechtenstein', 'LI', '423'),
  CountryInfo('Lithuania', 'LT', '370'),
  CountryInfo('Luxembourg', 'LU', '352'),
  CountryInfo('Madagascar', 'MG', '261'),
  CountryInfo('Malawi', 'MW', '265'),
  CountryInfo('Malaysia', 'MY', '60'),
  CountryInfo('Maldives', 'MV', '960'),
  CountryInfo('Mali', 'ML', '223'),
  CountryInfo('Malta', 'MT', '356'),
  CountryInfo('Mauritania', 'MR', '222'),
  CountryInfo('Mauritius', 'MU', '230'),
  CountryInfo('Mexico', 'MX', '52'),
  CountryInfo('Moldova', 'MD', '373'),
  CountryInfo('Monaco', 'MC', '377'),
  CountryInfo('Mongolia', 'MN', '976'),
  CountryInfo('Montenegro', 'ME', '382'),
  CountryInfo('Morocco', 'MA', '212'),
  CountryInfo('Mozambique', 'MZ', '258'),
  CountryInfo('Myanmar', 'MM', '95'),
  CountryInfo('Namibia', 'NA', '264'),
  CountryInfo('Nepal', 'NP', '977'),
  CountryInfo('Netherlands', 'NL', '31'),
  CountryInfo('New Zealand', 'NZ', '64'),
  CountryInfo('Nicaragua', 'NI', '505'),
  CountryInfo('Niger', 'NE', '227'),
  CountryInfo('Nigeria', 'NG', '234'),
  CountryInfo('North Korea', 'KP', '850'),
  CountryInfo('North Macedonia', 'MK', '389'),
  CountryInfo('Norway', 'NO', '47'),
  CountryInfo('Oman', 'OM', '968'),
  CountryInfo('Pakistan', 'PK', '92'),
  CountryInfo('Palestine', 'PS', '970'),
  CountryInfo('Panama', 'PA', '507'),
  CountryInfo('Papua New Guinea', 'PG', '675'),
  CountryInfo('Paraguay', 'PY', '595'),
  CountryInfo('Peru', 'PE', '51'),
  CountryInfo('Philippines', 'PH', '63'),
  CountryInfo('Poland', 'PL', '48'),
  CountryInfo('Portugal', 'PT', '351'),
  CountryInfo('Qatar', 'QA', '974'),
  CountryInfo('Romania', 'RO', '40'),
  CountryInfo('Russia', 'RU', '7'),
  CountryInfo('Rwanda', 'RW', '250'),
  CountryInfo('Saudi Arabia', 'SA', '966'),
  CountryInfo('Senegal', 'SN', '221'),
  CountryInfo('Serbia', 'RS', '381'),
  CountryInfo('Sierra Leone', 'SL', '232'),
  CountryInfo('Singapore', 'SG', '65'),
  CountryInfo('Slovakia', 'SK', '421'),
  CountryInfo('Slovenia', 'SI', '386'),
  CountryInfo('Somalia', 'SO', '252'),
  CountryInfo('South Africa', 'ZA', '27'),
  CountryInfo('South Korea', 'KR', '82'),
  CountryInfo('South Sudan', 'SS', '211'),
  CountryInfo('Spain', 'ES', '34'),
  CountryInfo('Sri Lanka', 'LK', '94'),
  CountryInfo('Sudan', 'SD', '249'),
  CountryInfo('Suriname', 'SR', '597'),
  CountryInfo('Sweden', 'SE', '46'),
  CountryInfo('Switzerland', 'CH', '41'),
  CountryInfo('Syria', 'SY', '963'),
  CountryInfo('Taiwan', 'TW', '886'),
  CountryInfo('Tajikistan', 'TJ', '992'),
  CountryInfo('Tanzania', 'TZ', '255'),
  CountryInfo('Thailand', 'TH', '66'),
  CountryInfo('Togo', 'TG', '228'),
  CountryInfo('Tunisia', 'TN', '216'),
  CountryInfo('Turkey', 'TR', '90'),
  CountryInfo('Turkmenistan', 'TM', '993'),
  CountryInfo('Uganda', 'UG', '256'),
  CountryInfo('Ukraine', 'UA', '380'),
  CountryInfo('United Arab Emirates', 'AE', '971'),
  CountryInfo('United Kingdom', 'GB', '44'),
  CountryInfo('United States', 'US', '1'),
  CountryInfo('Uruguay', 'UY', '598'),
  CountryInfo('Uzbekistan', 'UZ', '998'),
  CountryInfo('Venezuela', 'VE', '58'),
  CountryInfo('Vietnam', 'VN', '84'),
  CountryInfo('Yemen', 'YE', '967'),
  CountryInfo('Zambia', 'ZM', '260'),
  CountryInfo('Zimbabwe', 'ZW', '263'),
];

/// Simple E.164-ish validation for the local-number part typed after the
/// country dial code is picked separately — digits only, 6 to 12 of them
/// (covers virtually every real national number length without being
/// country-specific, which would need a much heavier package).
bool isValidLocalPhoneNumber(String value) {
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digitsOnly.length >= 6 && digitsOnly.length <= 12 && digitsOnly == value.trim();
}

/// The country the country-code picker defaults to whenever there's no
/// better signal (a fresh registration form, or an existing phone number
/// that doesn't parse) — UAE, since that's this platform's home market.
CountryInfo get defaultPhoneCountry => kCountries.firstWhere((c) => c.iso2 == 'AE');

/// 2026-08-28 (registration/phone-edit consistency fix): every screen that
/// collects a phone number now splits it into a country-code picker + a
/// plain national-number field instead of one free-text box, so the value
/// actually sent to the backend is always a clean, unambiguous
/// "+<dialCode><digits>" string — this is what combines those two parts at
/// submit time. Strips anything that isn't a digit out of the typed
/// national number first (spaces, dashes, a stray leading 0, etc. are all
/// dropped) so two people typing the same number differently still store
/// identically.
String combinePhoneNumber(CountryInfo country, String nationalNumber) {
  final digits = nationalNumber.replaceAll(RegExp(r'[^0-9]'), '');
  return '+${country.dialCode}$digits';
}

/// The reverse of [combinePhoneNumber] — splits an already-stored full
/// phone string (e.g. "+971501234567", however it happened to get saved
/// under an older, single-field version of a form) back into a country +
/// national-number pair so an edit screen can pre-fill both parts of the
/// split field correctly. Matches the LONGEST known dial code first
/// (essential: '1' would otherwise wrongly match before '971' does, since
/// "971..." also starts with digit sequences that happen to overlap
/// shorter codes). Falls back to [defaultPhoneCountry] with every digit of
/// the stored value treated as the national number when nothing matches
/// (e.g. a legacy value saved before any country-code concept existed, or
/// one missing its leading '+') — never throws, never returns something
/// that can't be re-combined.
(CountryInfo, String) splitPhoneNumber(String? stored) {
  final raw = (stored ?? '').trim();
  if (raw.startsWith('+')) {
    final digits = raw.substring(1);
    final byLongestCode = [...kCountries]..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    for (final c in byLongestCode) {
      if (digits.startsWith(c.dialCode)) {
        return (c, digits.substring(c.dialCode.length));
      }
    }
  }
  return (defaultPhoneCountry, raw.replaceAll(RegExp(r'[^0-9]'), ''));
}

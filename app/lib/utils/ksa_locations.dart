/// Curated city lists for the Create Shipment wizard's Origin/Destination
/// Country + City dropdowns (2026-08-17 feedback: pickup and drop-off
/// should both be dropdowns, not free text).
///
/// The company isn't restricted to one home country (confirmed with the
/// user), so Origin/Destination offer the full country list (see
/// `kCountries` in `countries.dart`) — but a real, curated City dropdown
/// only exists for the countries this business actually operates lanes in
/// today (Saudi Arabia, UAE, and the 9 cross-border countries already in
/// the backend's Destinations price matrix). For any other country, the
/// City field falls back to free text rather than pretending to have a
/// full gazetteer for the entire world — same "real data over a fake full
/// dataset" call made elsewhere in this app.
const Map<String, List<String>> kCitiesByCountry = {
  'Saudi Arabia': [
    'Riyadh',
    'Diriyah',
    'Al Kharj',
    'Dawadmi',
    'Jeddah',
    'Mecca',
    'Taif',
    'Rabigh',
    'Al Qunfudhah',
    'Medina',
    'Yanbu',
    'Dammam',
    'Khobar',
    'Dhahran',
    'Jubail',
    'Qatif',
    'Al-Ahsa (Hofuf)',
    'Ras Tanura',
    'Buraidah',
    'Unaizah',
    'Tabuk',
    'Duba',
    'Hail',
    'Abha',
    'Khamis Mushait',
    'Bisha',
    'Najran',
    'Jazan',
    'Al Bahah',
    'Sakaka (Al Jouf)',
    'Arar',
    'Hafar Al-Batin',
    'Wadi ad-Dawasir',
  ],
  'United Arab Emirates': [
    'Dubai',
    'Abu Dhabi',
    'Sharjah',
    'Ajman',
    'Umm Al Quwain',
    'Ras Al Khaimah',
    'Fujairah',
    'Al Ain',
    'Khalifa City',
    'Jebel Ali',
    'Hassyan',
    'Musaffah',
    'Ruwais',
  ],
  'Kuwait': ['Kuwait City', 'Al Ahmadi', 'Hawalli', 'Al Farwaniyah', 'Al Jahra', 'Mubarak Al-Kabeer', 'Shuwaikh Port'],
  'Bahrain': ['Manama', 'Riffa', 'Muharraq', 'Hamad Town', 'Isa Town', 'Khalifa Bin Salman Port'],
  'Oman': ['Muscat', 'Sohar', 'Salalah', 'Nizwa', 'Sur', 'Duqm'],
  'Jordan': ['Amman', 'Zarqa', 'Irbid', 'Aqaba'],
  'Lebanon': ['Beirut', 'Tripoli', 'Sidon', 'Tyre'],
  'Syria': ['Damascus', 'Aleppo', 'Homs', 'Latakia'],
  'Egypt': ['Cairo', 'Alexandria', 'Suez', 'Port Said', 'Giza'],
  'Iraq': ['Baghdad', 'Basra', 'Erbil', 'Najaf', 'Mosul'],
  'Yemen': ['Sanaa', 'Aden', 'Hodeidah', 'Taiz'],
};

/// Cities for a country if we have a curated list, else null (caller falls
/// back to a free-text city field).
List<String>? citiesFor(String? country) => kCitiesByCountry[country];

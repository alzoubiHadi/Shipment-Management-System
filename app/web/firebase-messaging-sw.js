// Required by firebase_messaging for Flutter Web: handles push delivery
// while no browser tab is focused/open. flutterfire configure does NOT
// generate this file automatically — it must exist at web/firebase-messaging-sw.js
// with these exact values, matching the firebaseConfig block that
// `flutterfire configure` writes into lib/firebase_options.dart for the
// web platform (project ID, API key, sender ID, app ID). Copy those five
// values from firebase_options.dart's FirebaseOptions(... web ...) block
// once it's generated — this file can't import that Dart file directly.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAu3vkxDZCg2MV6oGSkRMg6KVQ-y5whyhg',
  authDomain: 'sfms-d63e9.firebaseapp.com',
  projectId: 'sfms-d63e9',
  storageBucket: 'sfms-d63e9.firebasestorage.app',
  messagingSenderId: '264682360658',
  appId: '1:264682360658:web:c007b9ebe52faed0e6348b',
});

const messaging = firebase.messaging();

// Centralized, localization-ready user-facing message helpers.
//
// Every API service should route its error text through the two functions
// below instead of showing `data['message']`, `response.body`, or
// `e.toString()` straight to the UI. Keeping that logic here means this is
// the one file that needs to change when Arabic strings are added later —
// individual services and screens never need to know where a message came
// from or what language it's in.
//
// Design rules these follow:
//  - Never surface a raw Dart exception, HTTP status code, or response body.
//  - Prefer a clean, short message the backend already wrote for people
//    (Laravel validation/business-rule messages are usually fine to show).
//  - Fall back to a generic, status-appropriate sentence when the backend
//    didn't provide anything usable (framework defaults like
//    "Unauthenticated.", empty bodies, non-JSON error pages, etc.).
//
// 2026-08-22 (Arabic localization pass): the sentences THIS file writes
// itself (network failures, the per-status fallbacks, the 401/validation
// wording) are now bilingual, switched on LocaleController.isArabic — a
// plain read of the same global ValueNotifier<Locale> main.dart already
// uses, no BuildContext needed, so none of the ~15 call sites across the
// API service layer had to change. Backend-authored text (Laravel
// validation messages, `data['message']`) is passed through unmodified in
// whatever language the backend wrote it in — the backend does not yet
// localize its own responses, so that one category of user-facing text is
// not reliably bilingual yet. See the final completion report.

import 'dart:async';
import 'dart:io';

import '../l10n/locale_controller.dart';

/// Turns a caught exception (network failure, timeout, non-JSON response,
/// etc. — anything from a `catch (e)` around an http call) into a short,
/// user-safe sentence. Never surface `e` itself: its `toString()` includes
/// raw platform/error-class details (socket errors, stack info) that mean
/// nothing to an end user.
String networkErrorMessage(Object e) {
  final ar = LocaleController.isArabic;
  if (e is TimeoutException) {
    return ar
        ? 'استغرق الطلب وقتًا طويلاً. يرجى التحقق من اتصالك والمحاولة مرة أخرى.'
        : 'The request took too long. Please check your connection and try again.';
  }
  if (e is SocketException) {
    return ar
        ? 'تعذر الاتصال. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.'
        : 'Unable to connect. Please check your internet connection and try again.';
  }
  if (e is FormatException) {
    // Typically jsonDecode() choking on a non-JSON body (an HTML gateway
    // error page from a cold-starting/overloaded server, for example).
    return ar
        ? 'الخدمة غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى بعد قليل.'
        : 'The service is temporarily unavailable. Please try again in a moment.';
  }
  final text = e.toString();
  if (text.contains('SocketException') || text.contains('Network is unreachable') || text.contains('Failed host lookup')) {
    return ar
        ? 'تعذر الاتصال. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.'
        : 'Unable to connect. Please check your internet connection and try again.';
  }
  if (text.contains('ClientException') || text.contains('Connection closed') || text.contains('Connection reset')) {
    return ar ? 'تعذر الوصول إلى الخادم. يرجى المحاولة مرة أخرى.' : 'Unable to reach the server. Please try again.';
  }
  return ar ? 'حدث خطأ ما. يرجى المحاولة مرة أخرى.' : 'Something went wrong. Please try again.';
}

/// Builds a user-safe message for a non-2xx API response.
///
/// [data] is the decoded JSON body (or null if it couldn't be decoded).
/// [statusCode] is the HTTP status. [context] lets a handful of call sites
/// (currently just login) ask for wording specific to that action instead
/// of the generic default. [fallback] overrides the generic per-status
/// sentence when a caller wants a more specific one (e.g. "Could not
/// update profile") while everything else about this function still
/// applies (validation-error extraction, 401 handling, etc.). [fallback]
/// is caller-supplied English/Arabic text (pass an already-localized
/// string) — this function does not translate it for you.
String apiErrorMessage(
  Map<String, dynamic>? data,
  int statusCode, {
  String context = 'default',
  String? fallback,
}) {
  final ar = LocaleController.isArabic;

  // Session/token problems are handled the same way almost everywhere:
  // the backend's own text here is either a framework default
  // ("Unauthenticated.") or not something a user should have to parse.
  // Login is the one exception — there, 401 means "wrong email/password",
  // not "your session expired".
  if (statusCode == 401) {
    if (context == 'login') {
      return ar ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.' : 'Incorrect email or password. Please try again.';
    }
    return ar ? 'انتهت صلاحية جلستك. يرجى تسجيل الدخول مرة أخرى.' : 'Your session has expired. Please log in again.';
  }

  // Validation failures: Laravel returns {message, errors: {field: [reason]}}.
  // The per-field reasons are meant to be read by the user, so keep them —
  // just don't lead with a bare "Validation failed" when there's nothing
  // useful in front of it. NOTE: the per-field reasons themselves come
  // straight from the backend, which does not localize its validation
  // messages yet — they will show in English even in Arabic mode. See the
  // final completion report.
  if (data != null && data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
    final buffer = StringBuffer();
    final backendMessage = data['message']?.toString();
    if (backendMessage != null && backendMessage.isNotEmpty && backendMessage != 'Validation failed') {
      buffer.write(backendMessage);
    } else {
      buffer.write(ar ? 'يرجى التحقق مما يلي:' : 'Please check the following:');
    }
    for (final value in (data['errors'] as Map).values) {
      if (value is List && value.isNotEmpty) buffer.write('\n${value.first}');
    }
    return buffer.toString();
  }

  final backendMessage = data?['message']?.toString();
  if (backendMessage != null && backendMessage.trim().isNotEmpty) {
    return backendMessage;
  }

  if (fallback != null && fallback.isNotEmpty) return fallback;

  switch (statusCode) {
    case 403:
      return ar ? 'ليست لديك صلاحية للقيام بذلك.' : "You don't have permission to do that.";
    case 404:
      return ar ? 'تعذر العثور على العنصر المطلوب.' : 'The requested item could not be found.';
    case 409:
      return ar ? 'لم يعد بالإمكان إتمام هذا الإجراء — ربما تغيّر الوضع بالفعل.' : 'This action can no longer be completed — it may have already changed.';
    case 422:
      return ar ? 'يرجى التحقق من المعلومات التي أدخلتها والمحاولة مرة أخرى.' : 'Please check the information you entered and try again.';
    case 429:
      return ar ? 'محاولات كثيرة جدًا. يرجى الانتظار قليلاً والمحاولة مرة أخرى.' : 'Too many attempts. Please wait a moment and try again.';
    default:
      if (statusCode >= 500) {
        return ar ? 'الخدمة غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى لاحقًا.' : 'The service is temporarily unavailable. Please try again later.';
      }
      return ar ? 'حدث خطأ ما. يرجى المحاولة مرة أخرى.' : 'Something went wrong. Please try again.';
  }
}

/// Centralized EN/AR labels for the shipment/driver/company/document status
/// values the backend sends as raw enum strings (e.g. Shipment.status,
/// approval_status, compliance_status) — one lookup table instead of each
/// screen hand-rolling its own switch/if-chain per status word, several of
/// which already existed independently (Profile.dart's compliance color
/// switch, CompanyProfileScreen's account/license status text, etc.).
/// Display-only: screens must keep filtering/comparing against the raw
/// English key from the backend (e.g. `status == 'pending'`), never against
/// this label — see [statusLabel]'s docblock.
const Map<String, String> _statusLabelsAr = {
  'pending': 'قيد الانتظار',
  'approved': 'مقبول',
  'rejected': 'مرفوض',
  'active': 'نشط',
  'inactive': 'غير نشط',
  'suspended': 'موقوف',
  'changes_required': 'مطلوب تعديلات',
  'completed': 'مكتمل',
  'cancelled': 'ملغى',
  'in_progress': 'قيد التنفيذ',
  'delivered': 'تم التسليم',
  'matched': 'تمت المطابقة',
  'offered': 'تم العرض',
  'accepted': 'مقبول',
  'expired': 'منتهي الصلاحية',
  'warning': 'تحذير',
  'draft': 'مسودة',
  'published': 'منشور',
  'assigned': 'تم التعيين',
  'paid': 'مدفوع',
  'unpaid': 'غير مدفوع',
  'processing': 'قيد المعالجة',
  'failed': 'فشل',
};

const Map<String, String> _statusLabelsEn = {
  'pending': 'Pending',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'active': 'Active',
  'inactive': 'Inactive',
  'suspended': 'Suspended',
  'changes_required': 'Changes Required',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
  'in_progress': 'In Progress',
  'delivered': 'Delivered',
  'matched': 'Matched',
  'offered': 'Offered',
  'accepted': 'Accepted',
  'expired': 'Expired',
  'warning': 'Warning',
  'draft': 'Draft',
  'published': 'Published',
  'assigned': 'Assigned',
  'paid': 'Paid',
  'unpaid': 'Unpaid',
  'processing': 'Processing',
  'failed': 'Failed',
};

/// Localizes a raw backend status/enum string (e.g. `'changes_required'`,
/// `'pending'`) for display. [raw] is matched case-insensitively; anything
/// not in the table falls back to a title-cased version of the raw value
/// (never a raw untranslated snake_case string, never a crash) so a status
/// the backend adds later doesn't silently look broken — it just won't be
/// translated until this table is extended.
///
/// Callers must keep comparing/filtering against [raw] itself (the
/// original English enum value from the API), never against this label —
/// this only changes what's shown on screen, exactly like every other
/// function in this file.
///
/// Named `enumStatusLabel` rather than `statusLabel` deliberately —
/// `API/config.dart` already defines a same-named `statusLabel(dynamic
/// status)` for numeric Shipment.status codes (0-5), used across ~8
/// shipment screens (ShipmentPageAdmin, CompnayShipments,
/// DriverDashboardScreen, ...). Reusing the name would be an ambiguous
/// top-level import the moment a screen imports both files. The two are
/// intentionally NOT merged: config.dart's version is paired with
/// `statusValue()`, a reverse label->int lookup keyed on the exact English
/// string (see ShipmentPageAdmin._onManage) — translating its output would
/// silently break that reverse lookup and send the wrong status code to
/// the server. That coupling is a pre-existing design issue out of scope
/// for a localization-only pass; see the completion report.
String enumStatusLabel(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final key = raw.trim().toLowerCase();
  final table = LocaleController.isArabic ? _statusLabelsAr : _statusLabelsEn;
  final hit = table[key];
  if (hit != null) return hit;
  // Unknown status: title-case each underscore-separated word as a safe
  // English-only fallback (matches this file's existing behavior before
  // localization — better than leaking 'changes_required' verbatim).
  return key.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

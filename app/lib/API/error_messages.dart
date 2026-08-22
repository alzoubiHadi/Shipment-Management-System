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

import 'dart:async';
import 'dart:io';

/// Turns a caught exception (network failure, timeout, non-JSON response,
/// etc. — anything from a `catch (e)` around an http call) into a short,
/// user-safe sentence. Never surface `e` itself: its `toString()` includes
/// raw platform/error-class details (socket errors, stack info) that mean
/// nothing to an end user.
String networkErrorMessage(Object e) {
  if (e is TimeoutException) {
    return 'The request took too long. Please check your connection and try again.';
  }
  if (e is SocketException) {
    return 'Unable to connect. Please check your internet connection and try again.';
  }
  if (e is FormatException) {
    // Typically jsonDecode() choking on a non-JSON body (an HTML gateway
    // error page from a cold-starting/overloaded server, for example).
    return 'The service is temporarily unavailable. Please try again in a moment.';
  }
  final text = e.toString();
  if (text.contains('SocketException') || text.contains('Network is unreachable') || text.contains('Failed host lookup')) {
    return 'Unable to connect. Please check your internet connection and try again.';
  }
  if (text.contains('ClientException') || text.contains('Connection closed') || text.contains('Connection reset')) {
    return 'Unable to reach the server. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

/// Builds a user-safe message for a non-2xx API response.
///
/// [data] is the decoded JSON body (or null if it couldn't be decoded).
/// [statusCode] is the HTTP status. [context] lets a handful of call sites
/// (currently just login) ask for wording specific to that action instead
/// of the generic default. [fallback] overrides the generic per-status
/// sentence when a caller wants a more specific one (e.g. "Could not
/// update profile") while everything else about this function still
/// applies (validation-error extraction, 401 handling, etc.).
String apiErrorMessage(
  Map<String, dynamic>? data,
  int statusCode, {
  String context = 'default',
  String? fallback,
}) {
  // Session/token problems are handled the same way almost everywhere:
  // the backend's own text here is either a framework default
  // ("Unauthenticated.") or not something a user should have to parse.
  // Login is the one exception — there, 401 means "wrong email/password",
  // not "your session expired".
  if (statusCode == 401) {
    return context == 'login'
        ? 'Incorrect email or password. Please try again.'
        : 'Your session has expired. Please log in again.';
  }

  // Validation failures: Laravel returns {message, errors: {field: [reason]}}.
  // The per-field reasons are meant to be read by the user, so keep them —
  // just don't lead with a bare "Validation failed" when there's nothing
  // useful in front of it.
  if (data != null && data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
    final buffer = StringBuffer();
    final backendMessage = data['message']?.toString();
    if (backendMessage != null && backendMessage.isNotEmpty && backendMessage != 'Validation failed') {
      buffer.write(backendMessage);
    } else {
      buffer.write('Please check the following:');
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
      return "You don't have permission to do that.";
    case 404:
      return 'The requested item could not be found.';
    case 409:
      return 'This action can no longer be completed — it may have already changed.';
    case 422:
      return 'Please check the information you entered and try again.';
    case 429:
      return 'Too many attempts. Please wait a moment and try again.';
    default:
      if (statusCode >= 500) {
        return 'The service is temporarily unavailable. Please try again later.';
      }
      return 'Something went wrong. Please try again.';
  }
}

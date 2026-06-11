import '../graphql/graphql_client.dart';
import '../l10n/app_strings.dart';

/// Maps a thrown auth error to a user-facing message, localizing the machine
/// codes the verification / password-reset mutations return (other backend
/// messages, e.g. "Invalid credentials", are already human-readable and pass
/// through unchanged).
String authErrorMessage(Object error, AppStrings t) {
  if (error is AuthFailedException) {
    return switch (error.message) {
      'code_invalid' => t.codeInvalid,
      'code_expired' => t.codeExpired,
      'too_many_attempts' => t.codeTooManyAttempts,
      'resend_too_soon' => t.codeResendTooSoon,
      _ => error.message,
    };
  }
  if (error is GraphQLException) return error.message;
  return t.authGenericError;
}

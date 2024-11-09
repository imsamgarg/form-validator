import 'i18n/all.dart';
import 'locale.dart';
import 'validator_options.dart';

typedef StringValidationCallback = String? Function(String? value);
typedef ValidationCallback<T> = String? Function(T? value);

// C# Action<T>
typedef Action<T> = Function(T builder);

// For backwards compatibility
typedef ValidationBuilder = GenericValidationBuilder<String>;
typedef StringValidationBuilder = GenericValidationBuilder<String>;

class GenericValidationBuilder<T> {
  GenericValidationBuilder({
    this.optional = false,
    this.requiredMessage,
    ValidatorOptions? options,
    String? localeName,
    FormValidatorLocale? locale,
  })  : _locale = locale ??
            (localeName == null ? globalLocale : createLocale(localeName)),
        _options = options ?? globalOptions {
    ArgumentError.checkNotNull(_locale, 'locale');
    // Unless a builder is optional, the first thing we do is to add a
    // [required] validator. All subsequent validators should expect
    // a non-null argument.
    if (!optional) required(requiredMessage);
  }

  static ValidatorOptions globalOptions = ValidatorOptions();

  static FormValidatorLocale globalLocale = createLocale('default');
  static void setLocale(String localeName) {
    globalLocale = createLocale(localeName);
  }

  final bool optional;
  final String? requiredMessage;
  final FormValidatorLocale _locale;
  final List<ValidationCallback<T>> validations = [];
  final ValidatorOptions _options;

  /// Clears validation list and adds required validation if
  /// [optional] is false
  GenericValidationBuilder<T> reset() {
    validations.clear();
    if (optional != true) {
      required(requiredMessage);
    }
    return this;
  }

  /// Adds new item to [validations] list, returns this instance
  GenericValidationBuilder<T> add(ValidationCallback<T> validator) {
    validations.add(validator);
    return this;
  }

  /// Tests [value] against defined [validations]
  String? test(T? value) {
    for (var validate in validations) {
      // Return null if field is optional and value is null
      if (optional && (value == null || (value is String && value.isEmpty))) {
        return null;
      }

      // Otherwise execute validations
      final result = validate(value);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  /// Returns a validator function for FormInput
  ValidationCallback<T> build() => test;

  /// Throws error only if [left] and [right] validators throw error same time.
  /// If [reverse] is true left builder's error will be displayed otherwise
  /// right builder's error. Because this is default behaviour on most of the
  /// programming languages.
  GenericValidationBuilder<T> or(
    Action<GenericValidationBuilder<T>> left,
    Action<GenericValidationBuilder<T>> right, {
    bool reverse = false,
  }) {
    // Create
    final v1 = GenericValidationBuilder<T>(locale: _locale);
    final v2 = GenericValidationBuilder<T>(locale: _locale);

    // Configure
    left(v1);
    right(v2);

    // Build
    final v1cb = v1.build();
    final v2cb = v2.build();

    // Test
    return add((value) {
      final leftResult = v1cb(value);
      if (leftResult == null) {
        return null;
      }
      final rightResult = v2cb(value);
      if (rightResult == null) {
        return null;
      }
      return reverse == true ? leftResult : rightResult;
    });
  }

  /// Value must not be null
  GenericValidationBuilder required([String? message]) =>
      add((v) => v == null || (v is String && v.isEmpty)
          ? message ?? _locale.required()
          : null);
}

extension StringValidationBuilderExt on GenericValidationBuilder<String> {
  /// Checks if two values match
  StringValidationBuilder match(String? otherValue, [String? message]) =>
      add((v) => v == otherValue ? null : message ?? _locale.noMatch());

  /// Value length must be greater than or equal to [minLength]
  StringValidationBuilder minLength(int minLength, [String? message]) =>
      add((v) => v!.length < minLength
          ? message ?? _locale.minLength(v, minLength)
          : null);

  /// Value length must be less than or equal to [maxLength]
  StringValidationBuilder maxLength(int maxLength, [String? message]) =>
      add((v) => v!.length > maxLength
          ? message ?? _locale.maxLength(v, maxLength)
          : null);

  /// Value must match [regExp]
  StringValidationBuilder regExp(RegExp regExp, String message) =>
      add((v) => regExp.hasMatch(v!) ? null : message);

  /// Value must be a well formatted email
  StringValidationBuilder email([String? message]) => add((v) =>
      _options.emailRegExp.hasMatch(v!) ? null : message ?? _locale.email(v));

  // needed for short circuiting the full validation
  static final RegExp _anyLetter = RegExp(r'[A-Za-z]');
  static final RegExp _nonDigitsExp = RegExp(r'[^\d]');

  /// Value must be a well formatted phone number
  StringValidationBuilder phone([String? message]) =>
      add((v) => !_anyLetter.hasMatch(v!) &&
              _options.phoneRegExp.hasMatch(v.replaceAll(_nonDigitsExp, ''))
          ? null
          : message ?? _locale.phoneNumber(v));

  /// Value must be a well formatted IPv4 address
  StringValidationBuilder ip([String? message]) => add((v) =>
      _options.ipv4RegExp.hasMatch(v!) ? null : message ?? _locale.ip(v));

  /// Value must be a well formatted IPv6 address
  StringValidationBuilder ipv6([String? message]) => add((v) =>
      _options.ipv6RegExp.hasMatch(v!) ? null : message ?? _locale.ipv6(v));

  /// Value must be a well formatted URL address
  StringValidationBuilder url([String? message]) => add((v) =>
      _options.urlRegExp.hasMatch(v!) ? null : message ?? _locale.url(v));
}

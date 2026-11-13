import '../../../core/format/date_format.dart';

/// Los datos personales de un usuario. Todos son opcionales en la base de
/// datos; la app decide cuáles pide (nombre y apellido al registrarse).
class ProfileData {
  const ProfileData({
    this.firstName,
    this.lastName,
    this.birthDate,
    this.profession,
    this.monthlyIncome,
    this.monthlyIncomeCurrency,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    birthDate: json['birth_date'] == null
        ? null
        : DateTime.parse(json['birth_date'] as String),
    profession: json['profession'] as String?,
    monthlyIncome: (json['monthly_income'] as num?)?.toString(),
    monthlyIncomeCurrency: json['monthly_income_currency'] as String?,
  );

  final String? firstName;
  final String? lastName;

  /// La fecha de nacimiento: se guarda en vez de la edad para que no se
  /// desactualice.
  final DateTime? birthDate;
  final String? profession;

  /// El ingreso mensual promedio (o sueldo) como decimal exacto en texto, y su
  /// moneda. Van juntos; sin ingreso, los dos son nulos.
  final String? monthlyIncome;
  final String? monthlyIncomeCurrency;

  /// Lo que se manda al registrarse, en los metadatos del usuario: la base de
  /// datos arma el perfil con esto en la misma transacción que la cuenta. Solo
  /// van los datos que se dieron.
  Map<String, String> toSignUpMetadata() => {
    if (_filled(firstName)) 'first_name': firstName!.trim(),
    if (_filled(lastName)) 'last_name': lastName!.trim(),
    if (birthDate != null) 'birth_date': toDbDate(birthDate!),
    if (_filled(profession)) 'profession': profession!.trim(),
    if (_filled(monthlyIncome)) ...{
      'monthly_income': monthlyIncome!,
      'monthly_income_currency': monthlyIncomeCurrency ?? 'COP',
    },
  };

  static bool _filled(String? value) =>
      value != null && value.trim().isNotEmpty;
}

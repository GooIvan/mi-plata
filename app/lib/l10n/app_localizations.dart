import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
    Locale('es'),
    Locale('en'),
  ];

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @commonSaveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get commonSaveChanges;

  /// No description provided for @commonEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get commonEdit;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// No description provided for @commonArchive.
  ///
  /// In es, this message translates to:
  /// **'Archivar'**
  String get commonArchive;

  /// No description provided for @commonRestore.
  ///
  /// In es, this message translates to:
  /// **'Restaurar'**
  String get commonRestore;

  /// No description provided for @commonUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get commonUndo;

  /// No description provided for @commonOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones'**
  String get commonOptions;

  /// Enlace de una sección con elementos en femenino (cuentas, deudas)
  ///
  /// In es, this message translates to:
  /// **'Ver todas'**
  String get commonSeeAll;

  /// Enlace de una sección con elementos en masculino (movimientos, presupuestos)
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get commonSeeAllMasculine;

  /// No description provided for @commonShowArchived.
  ///
  /// In es, this message translates to:
  /// **'Mostrar archivadas'**
  String get commonShowArchived;

  /// No description provided for @commonHideArchived.
  ///
  /// In es, this message translates to:
  /// **'Ocultar archivadas'**
  String get commonHideArchived;

  /// No description provided for @commonIncomes.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get commonIncomes;

  /// No description provided for @commonExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get commonExpenses;

  /// No description provided for @commonNoCategory.
  ///
  /// In es, this message translates to:
  /// **'Sin categoría'**
  String get commonNoCategory;

  /// No description provided for @commonLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la operación. Revisa tu conexión e intenta de nuevo.'**
  String get commonLoadError;

  /// No description provided for @commonSessionExpired.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró. Vuelve a iniciar sesión.'**
  String get commonSessionExpired;

  /// No description provided for @commonNameTooLong.
  ///
  /// In es, this message translates to:
  /// **'Usa {max} caracteres o menos'**
  String commonNameTooLong(int max);

  /// No description provided for @commonInvalidAmount.
  ///
  /// In es, this message translates to:
  /// **'Monto no válido. Ejemplo: 1.500.000 o 1500,50'**
  String get commonInvalidAmount;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get yesterday;

  /// No description provided for @authEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordRepeatLabel.
  ///
  /// In es, this message translates to:
  /// **'Repite la contraseña'**
  String get authPasswordRepeatLabel;

  /// No description provided for @authShowPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get authHidePassword;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para continuar'**
  String get authLoginSubtitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta para empezar'**
  String get authRegisterSubtitle;

  /// No description provided for @authLoginButton.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get authLoginButton;

  /// No description provided for @authRegisterButton.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get authRegisterButton;

  /// No description provided for @authGoToRegister.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? Regístrate'**
  String get authGoToRegister;

  /// No description provided for @authGoToLogin.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? Inicia sesión'**
  String get authGoToLogin;

  /// No description provided for @authConfirmEmailSent.
  ///
  /// In es, this message translates to:
  /// **'Te enviamos un correo para confirmar tu cuenta. Después podrás iniciar sesión.'**
  String get authConfirmEmailSent;

  /// No description provided for @authEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'El correo no es válido'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get authPasswordRequired;

  /// No description provided for @authNewPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Crea una contraseña'**
  String get authNewPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'Usa al menos {min} caracteres'**
  String authPasswordTooShort(int min);

  /// No description provided for @authPasswordRepeatRequired.
  ///
  /// In es, this message translates to:
  /// **'Repite tu contraseña'**
  String get authPasswordRepeatRequired;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get authPasswordMismatch;

  /// No description provided for @authErrorOffline.
  ///
  /// In es, this message translates to:
  /// **'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.'**
  String get authErrorOffline;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña incorrectos.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailExists.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta con ese correo.'**
  String get authErrorEmailExists;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña es muy débil. Usa una más larga o más variada.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu correo antes de iniciar sesión.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorRateLimit.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Espera un momento e intenta de nuevo.'**
  String get authErrorRateLimit;

  /// No description provided for @authErrorSignupDisabled.
  ///
  /// In es, this message translates to:
  /// **'El registro de usuarios está deshabilitado.'**
  String get authErrorSignupDisabled;

  /// No description provided for @authErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la operación. Intenta de nuevo.'**
  String get authErrorGeneric;

  /// No description provided for @dashboardTotalMoney.
  ///
  /// In es, this message translates to:
  /// **'Dinero total'**
  String get dashboardTotalMoney;

  /// No description provided for @dashboardLoadMoneyError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar tu dinero.'**
  String get dashboardLoadMoneyError;

  /// No description provided for @dashboardNoAccounts.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes cuentas'**
  String get dashboardNoAccounts;

  /// No description provided for @dashboardAccountsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{En {count} cuenta} other{En {count} cuentas}}'**
  String dashboardAccountsCount(int count);

  /// No description provided for @dashboardRecentTransactions.
  ///
  /// In es, this message translates to:
  /// **'Últimos movimientos'**
  String get dashboardRecentTransactions;

  /// No description provided for @dashboardNoTransactions.
  ///
  /// In es, this message translates to:
  /// **'Aún no registras movimientos.'**
  String get dashboardNoTransactions;

  /// No description provided for @dashboardDebtsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las deudas.'**
  String get dashboardDebtsLoadError;

  /// No description provided for @dashboardDebtsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Registra lo que debes o te deben'**
  String get dashboardDebtsEmpty;

  /// No description provided for @dashboardYouOwe.
  ///
  /// In es, this message translates to:
  /// **'Debes'**
  String get dashboardYouOwe;

  /// No description provided for @dashboardOwedToYou.
  ///
  /// In es, this message translates to:
  /// **'Te deben'**
  String get dashboardOwedToYou;

  /// No description provided for @dashboardSummaryTooltip.
  ///
  /// In es, this message translates to:
  /// **'Resumen mensual'**
  String get dashboardSummaryTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In es, this message translates to:
  /// **'Idioma del teléfono'**
  String get settingsLanguageSystem;

  /// El nombre de cada idioma se escribe en ese idioma
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get settingsLanguageSpanish;

  /// El nombre de cada idioma se escribe en ese idioma
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión'**
  String get settingsSession;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada como {email}'**
  String settingsSignedInAs(String email);

  /// No description provided for @settingsSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get settingsSignOut;

  /// No description provided for @budgetsTitle.
  ///
  /// In es, this message translates to:
  /// **'Presupuestos'**
  String get budgetsTitle;

  /// No description provided for @budgetsStatusOk.
  ///
  /// In es, this message translates to:
  /// **'Quedan {amount}'**
  String budgetsStatusOk(String amount);

  /// No description provided for @budgetsStatusAtLimit.
  ///
  /// In es, this message translates to:
  /// **'Llegaste al límite'**
  String get budgetsStatusAtLimit;

  /// No description provided for @budgetsStatusNear.
  ///
  /// In es, this message translates to:
  /// **'Cerca del límite: quedan {amount}'**
  String budgetsStatusNear(String amount);

  /// No description provided for @budgetsStatusOver.
  ///
  /// In es, this message translates to:
  /// **'Te pasaste por {amount}'**
  String budgetsStatusOver(String amount);

  /// No description provided for @budgetsAlertOver.
  ///
  /// In es, this message translates to:
  /// **'Superaste el presupuesto de {category}: {spent} de {limit}.'**
  String budgetsAlertOver(String category, String spent, String limit);

  /// No description provided for @budgetsAlertNear.
  ///
  /// In es, this message translates to:
  /// **'Vas en {percent} % del presupuesto de {category} ({spent} de {limit}).'**
  String budgetsAlertNear(
    int percent,
    String category,
    String spent,
    String limit,
  );

  /// No description provided for @budgetsThisCategory.
  ///
  /// In es, this message translates to:
  /// **'esta categoría'**
  String get budgetsThisCategory;

  /// No description provided for @budgetsOverCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} categoría superada} other{{count} categorías superadas}}'**
  String budgetsOverCount(int count);

  /// No description provided for @budgetsNearCount.
  ///
  /// In es, this message translates to:
  /// **'{count} cerca del límite'**
  String budgetsNearCount(int count);

  /// Va después de lo gastado: "$300.000 de $500.000"
  ///
  /// In es, this message translates to:
  /// **'de {limit}'**
  String budgetsOfLimit(String limit);

  /// No description provided for @accountsTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuentas'**
  String get accountsTitle;

  /// No description provided for @accountsNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva cuenta'**
  String get accountsNew;

  /// No description provided for @accountsEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar cuenta'**
  String get accountsEdit;

  /// No description provided for @accountsCreateButton.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get accountsCreateButton;

  /// No description provided for @accountsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes cuentas.\nCrea la primera para empezar.'**
  String get accountsEmpty;

  /// No description provided for @accountsAllArchived.
  ///
  /// In es, this message translates to:
  /// **'Todas tus cuentas están archivadas.'**
  String get accountsAllArchived;

  /// No description provided for @accountsArchivedMessage.
  ///
  /// In es, this message translates to:
  /// **'Cuenta archivada'**
  String get accountsArchivedMessage;

  /// No description provided for @accountsRestoredMessage.
  ///
  /// In es, this message translates to:
  /// **'Cuenta restaurada'**
  String get accountsRestoredMessage;

  /// No description provided for @accountsArchivedTag.
  ///
  /// In es, this message translates to:
  /// **'Archivada'**
  String get accountsArchivedTag;

  /// No description provided for @accountsArchivedName.
  ///
  /// In es, this message translates to:
  /// **'{name} (archivada)'**
  String accountsArchivedName(String name);

  /// No description provided for @accountsNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get accountsNameLabel;

  /// No description provided for @accountsNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Bancolombia ahorros'**
  String get accountsNameHint;

  /// No description provided for @accountsTypeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get accountsTypeLabel;

  /// No description provided for @accountsInitialBalanceLabel.
  ///
  /// In es, this message translates to:
  /// **'Saldo inicial'**
  String get accountsInitialBalanceLabel;

  /// No description provided for @accountsInitialBalanceHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 1.500.000'**
  String get accountsInitialBalanceHint;

  /// No description provided for @accountsInitialBalanceHelper.
  ///
  /// In es, this message translates to:
  /// **'Déjalo vacío si empieza en cero'**
  String get accountsInitialBalanceHelper;

  /// No description provided for @accountsChoose.
  ///
  /// In es, this message translates to:
  /// **'Elige una cuenta'**
  String get accountsChoose;

  /// No description provided for @accountTypeCash.
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In es, this message translates to:
  /// **'Banco'**
  String get accountTypeBank;

  /// No description provided for @accountTypeWallet.
  ///
  /// In es, this message translates to:
  /// **'Billetera digital'**
  String get accountTypeWallet;

  /// No description provided for @accountTypeCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta'**
  String get accountTypeCard;

  /// No description provided for @accountsNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ponle un nombre a la cuenta'**
  String get accountsNameRequired;

  /// No description provided for @accountsErrorDuplicateName.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes una cuenta activa con ese nombre.'**
  String get accountsErrorDuplicateName;

  /// No description provided for @accountsErrorInvalidData.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos: el nombre no puede estar vacío.'**
  String get accountsErrorInvalidData;

  /// No description provided for @accountsErrorAmountTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El monto es demasiado grande.'**
  String get accountsErrorAmountTooLarge;

  /// No description provided for @commonArchivedTag.
  ///
  /// In es, this message translates to:
  /// **'Archivada'**
  String get commonArchivedTag;

  /// No description provided for @categoriesTitle.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get categoriesTitle;

  /// No description provided for @categoriesNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría'**
  String get categoriesNew;

  /// No description provided for @categoriesCreateButton.
  ///
  /// In es, this message translates to:
  /// **'Crear categoría'**
  String get categoriesCreateButton;

  /// No description provided for @categoriesArchivedMessage.
  ///
  /// In es, this message translates to:
  /// **'Categoría archivada'**
  String get categoriesArchivedMessage;

  /// No description provided for @categoriesRestoredMessage.
  ///
  /// In es, this message translates to:
  /// **'Categoría restaurada'**
  String get categoriesRestoredMessage;

  /// No description provided for @categoriesNewOfType.
  ///
  /// In es, this message translates to:
  /// **'{type, select, expense{Nueva categoría de gasto} income{Nueva categoría de ingreso} other{Nueva categoría}}'**
  String categoriesNewOfType(String type);

  /// No description provided for @categoriesEditOfType.
  ///
  /// In es, this message translates to:
  /// **'{type, select, expense{Editar categoría de gasto} income{Editar categoría de ingreso} other{Editar categoría}}'**
  String categoriesEditOfType(String type);

  /// No description provided for @categoriesEmptyOfType.
  ///
  /// In es, this message translates to:
  /// **'{type, select, expense{Aún no tienes categorías de gasto.} income{Aún no tienes categorías de ingreso.} other{Aún no tienes categorías.}}'**
  String categoriesEmptyOfType(String type);

  /// No description provided for @categoriesAllArchivedOfType.
  ///
  /// In es, this message translates to:
  /// **'{type, select, expense{Todas tus categorías de gasto están archivadas.} income{Todas tus categorías de ingreso están archivadas.} other{Todas tus categorías están archivadas.}}'**
  String categoriesAllArchivedOfType(String type);

  /// No description provided for @categoriesNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get categoriesNameLabel;

  /// No description provided for @categoriesNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Mascotas'**
  String get categoriesNameHint;

  /// No description provided for @categoriesNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ponle un nombre a la categoría'**
  String get categoriesNameRequired;

  /// No description provided for @categoriesErrorDuplicateName.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes una categoría activa con ese nombre.'**
  String get categoriesErrorDuplicateName;

  /// No description provided for @categoriesErrorInvalidData.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos: el nombre no puede estar vacío.'**
  String get categoriesErrorInvalidData;

  /// No description provided for @commonAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get commonAccount;

  /// No description provided for @commonCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get commonCategory;

  /// No description provided for @commonAmount.
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get commonAmount;

  /// No description provided for @commonDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get commonDate;

  /// No description provided for @commonAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get commonAll;

  /// No description provided for @commonTransfers.
  ///
  /// In es, this message translates to:
  /// **'Transferencias'**
  String get commonTransfers;

  /// No description provided for @commonClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get commonClear;

  /// No description provided for @commonApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get commonApply;

  /// No description provided for @transactionTypeIncome.
  ///
  /// In es, this message translates to:
  /// **'Ingreso'**
  String get transactionTypeIncome;

  /// No description provided for @transactionTypeExpense.
  ///
  /// In es, this message translates to:
  /// **'Gasto'**
  String get transactionTypeExpense;

  /// No description provided for @transactionTypeTransfer.
  ///
  /// In es, this message translates to:
  /// **'Transferencia'**
  String get transactionTypeTransfer;

  /// No description provided for @transactionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get transactionsTitle;

  /// No description provided for @transactionsNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo movimiento'**
  String get transactionsNew;

  /// No description provided for @transactionsEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar movimiento'**
  String get transactionsEdit;

  /// No description provided for @transactionsRecord.
  ///
  /// In es, this message translates to:
  /// **'Registrar'**
  String get transactionsRecord;

  /// No description provided for @transactionsRecordOne.
  ///
  /// In es, this message translates to:
  /// **'Registrar movimiento'**
  String get transactionsRecordOne;

  /// No description provided for @transactionsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no registras movimientos.\nAnota el primero.'**
  String get transactionsEmpty;

  /// No description provided for @transactionsNoMatches.
  ///
  /// In es, this message translates to:
  /// **'No hay movimientos con estos filtros.'**
  String get transactionsNoMatches;

  /// No description provided for @transactionsClearFilters.
  ///
  /// In es, this message translates to:
  /// **'Limpiar filtros'**
  String get transactionsClearFilters;

  /// No description provided for @transactionsSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get transactionsSearch;

  /// No description provided for @transactionsSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en la descripción'**
  String get transactionsSearchHint;

  /// No description provided for @transactionsSearchClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar búsqueda'**
  String get transactionsSearchClose;

  /// No description provided for @transactionsFilter.
  ///
  /// In es, this message translates to:
  /// **'Filtrar'**
  String get transactionsFilter;

  /// No description provided for @transactionsRemoveFilter.
  ///
  /// In es, this message translates to:
  /// **'Quitar filtro: {label}'**
  String transactionsRemoveFilter(String label);

  /// No description provided for @transactionsLoadMoreError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar más movimientos.'**
  String get transactionsLoadMoreError;

  /// No description provided for @transactionsDateHelp.
  ///
  /// In es, this message translates to:
  /// **'Fecha del movimiento'**
  String get transactionsDateHelp;

  /// No description provided for @transactionsAmountHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 150.000'**
  String get transactionsAmountHint;

  /// No description provided for @transactionsFrom.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get transactionsFrom;

  /// No description provided for @transactionsTo.
  ///
  /// In es, this message translates to:
  /// **'Hacia'**
  String get transactionsTo;

  /// No description provided for @transactionsNeedAnotherAccount.
  ///
  /// In es, this message translates to:
  /// **'Necesitas otra cuenta para transferir'**
  String get transactionsNeedAnotherAccount;

  /// No description provided for @transactionsChooseDestination.
  ///
  /// In es, this message translates to:
  /// **'Elige la cuenta de destino'**
  String get transactionsChooseDestination;

  /// No description provided for @transactionsNeedAccountFirst.
  ///
  /// In es, this message translates to:
  /// **'Primero crea una cuenta para registrar movimientos.'**
  String get transactionsNeedAccountFirst;

  /// No description provided for @transactionsDescriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get transactionsDescriptionLabel;

  /// No description provided for @transactionsDescriptionHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Mercado de la semana'**
  String get transactionsDescriptionHint;

  /// No description provided for @transactionsDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Eliminar movimiento'**
  String get transactionsDeleteTooltip;

  /// No description provided for @transactionsDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este movimiento?'**
  String get transactionsDeleteTitle;

  /// No description provided for @transactionsDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'El saldo de tus cuentas se recalculará sin este movimiento.'**
  String get transactionsDeleteBody;

  /// No description provided for @transactionsDeleteBodyWithWarning.
  ///
  /// In es, this message translates to:
  /// **'El saldo de tus cuentas se recalculará sin este movimiento.\n\nAtención:\n{warnings}'**
  String transactionsDeleteBodyWithWarning(String warnings);

  /// No description provided for @transactionsDeleted.
  ///
  /// In es, this message translates to:
  /// **'Movimiento eliminado'**
  String get transactionsDeleted;

  /// No description provided for @negativeBalanceMessage.
  ///
  /// In es, this message translates to:
  /// **'{account} quedará en {balance}.'**
  String negativeBalanceMessage(String account, String balance);

  /// No description provided for @negativeBalanceAdvice.
  ///
  /// In es, this message translates to:
  /// **'Si el monto es correcto, puedes continuar.'**
  String get negativeBalanceAdvice;

  /// No description provided for @negativeBalanceFix.
  ///
  /// In es, this message translates to:
  /// **'Corregir'**
  String get negativeBalanceFix;

  /// No description provided for @negativeBalanceRecordTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Registrar de todos modos?'**
  String get negativeBalanceRecordTitle;

  /// No description provided for @negativeBalanceSaveTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Guardar de todos modos?'**
  String get negativeBalanceSaveTitle;

  /// No description provided for @negativeBalanceRecordAnyway.
  ///
  /// In es, this message translates to:
  /// **'Registrar igual'**
  String get negativeBalanceRecordAnyway;

  /// No description provided for @negativeBalanceSaveAnyway.
  ///
  /// In es, this message translates to:
  /// **'Guardar igual'**
  String get negativeBalanceSaveAnyway;

  /// No description provided for @transactionsFilterTitle.
  ///
  /// In es, this message translates to:
  /// **'Filtrar movimientos'**
  String get transactionsFilterTitle;

  /// No description provided for @transactionsFilterAllAccounts.
  ///
  /// In es, this message translates to:
  /// **'Todas las cuentas'**
  String get transactionsFilterAllAccounts;

  /// No description provided for @transactionsFilterAllCategories.
  ///
  /// In es, this message translates to:
  /// **'Todas las categorías'**
  String get transactionsFilterAllCategories;

  /// No description provided for @transactionsFilterDates.
  ///
  /// In es, this message translates to:
  /// **'Fechas'**
  String get transactionsFilterDates;

  /// No description provided for @transactionsFilterRemoveDates.
  ///
  /// In es, this message translates to:
  /// **'Quitar las fechas'**
  String get transactionsFilterRemoveDates;

  /// No description provided for @transactionsFilterAnyDate.
  ///
  /// In es, this message translates to:
  /// **'Cualquier fecha'**
  String get transactionsFilterAnyDate;

  /// No description provided for @transactionsFilterRangeHelp.
  ///
  /// In es, this message translates to:
  /// **'Rango de fechas'**
  String get transactionsFilterRangeHelp;

  /// No description provided for @transactionsRangeBetween.
  ///
  /// In es, this message translates to:
  /// **'del {from} al {to}'**
  String transactionsRangeBetween(String from, String to);

  /// No description provided for @transactionsRangeSince.
  ///
  /// In es, this message translates to:
  /// **'desde el {from}'**
  String transactionsRangeSince(String from);

  /// No description provided for @transactionsRangeUntil.
  ///
  /// In es, this message translates to:
  /// **'hasta el {to}'**
  String transactionsRangeUntil(String to);

  /// No description provided for @transactionsAmountRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el monto'**
  String get transactionsAmountRequired;

  /// No description provided for @transactionsAmountNegative.
  ///
  /// In es, this message translates to:
  /// **'El monto no puede ser negativo'**
  String get transactionsAmountNegative;

  /// No description provided for @transactionsAmountZero.
  ///
  /// In es, this message translates to:
  /// **'El monto debe ser mayor que cero'**
  String get transactionsAmountZero;

  /// No description provided for @transactionsErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos del movimiento: el monto, las cuentas y la categoría.'**
  String get transactionsErrorInvalid;

  /// No description provided for @transactionsErrorMissingReference.
  ///
  /// In es, this message translates to:
  /// **'La cuenta o la categoría ya no existe. Vuelve a abrir el formulario.'**
  String get transactionsErrorMissingReference;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @debtsTitle.
  ///
  /// In es, this message translates to:
  /// **'Deudas'**
  String get debtsTitle;

  /// No description provided for @debtsTabOwe.
  ///
  /// In es, this message translates to:
  /// **'Debo'**
  String get debtsTabOwe;

  /// No description provided for @debtsTabOwed.
  ///
  /// In es, this message translates to:
  /// **'Me deben'**
  String get debtsTabOwed;

  /// No description provided for @debtsNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva deuda'**
  String get debtsNew;

  /// No description provided for @debtsEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar deuda'**
  String get debtsEdit;

  /// No description provided for @debtsRegister.
  ///
  /// In es, this message translates to:
  /// **'Registrar deuda'**
  String get debtsRegister;

  /// No description provided for @debtsEmptyPayable.
  ///
  /// In es, this message translates to:
  /// **'Aún no registras deudas que debas.'**
  String get debtsEmptyPayable;

  /// No description provided for @debtsEmptyReceivable.
  ///
  /// In es, this message translates to:
  /// **'Aún no registras deudas que te deban.'**
  String get debtsEmptyReceivable;

  /// No description provided for @debtsAllArchived.
  ///
  /// In es, this message translates to:
  /// **'Todas tus deudas de esta lista están archivadas.'**
  String get debtsAllArchived;

  /// No description provided for @debtsTotalPayable.
  ///
  /// In es, this message translates to:
  /// **'Debes en total'**
  String get debtsTotalPayable;

  /// No description provided for @debtsTotalReceivable.
  ///
  /// In es, this message translates to:
  /// **'Te deben en total'**
  String get debtsTotalReceivable;

  /// No description provided for @debtsOfAmount.
  ///
  /// In es, this message translates to:
  /// **'de {amount}'**
  String debtsOfAmount(String amount);

  /// No description provided for @debtStatusSettled.
  ///
  /// In es, this message translates to:
  /// **'Saldada'**
  String get debtStatusSettled;

  /// No description provided for @debtStatusNoDueDate.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha de vencimiento'**
  String get debtStatusNoDueDate;

  /// No description provided for @debtStatusOverdue.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, one{Vencida hace {days} día} other{Vencida hace {days} días}}'**
  String debtStatusOverdue(int days);

  /// No description provided for @debtStatusDueToday.
  ///
  /// In es, this message translates to:
  /// **'Vence hoy'**
  String get debtStatusDueToday;

  /// No description provided for @debtStatusDueTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Vence mañana'**
  String get debtStatusDueTomorrow;

  /// No description provided for @debtStatusDueInDays.
  ///
  /// In es, this message translates to:
  /// **'Vence en {days} días'**
  String debtStatusDueInDays(int days);

  /// No description provided for @debtStatusDueOn.
  ///
  /// In es, this message translates to:
  /// **'Vence el {date}'**
  String debtStatusDueOn(String date);

  /// No description provided for @debtsPickStartHelp.
  ///
  /// In es, this message translates to:
  /// **'Fecha de inicio'**
  String get debtsPickStartHelp;

  /// No description provided for @debtsPickDueHelp.
  ///
  /// In es, this message translates to:
  /// **'Fecha de vencimiento'**
  String get debtsPickDueHelp;

  /// No description provided for @debtsCounterpartyPayable.
  ///
  /// In es, this message translates to:
  /// **'A quién le debes'**
  String get debtsCounterpartyPayable;

  /// No description provided for @debtsCounterpartyReceivable.
  ///
  /// In es, this message translates to:
  /// **'Quién te debe'**
  String get debtsCounterpartyReceivable;

  /// No description provided for @debtsCounterpartyHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Juan'**
  String get debtsCounterpartyHint;

  /// No description provided for @debtsAmountLabel.
  ///
  /// In es, this message translates to:
  /// **'Monto total'**
  String get debtsAmountLabel;

  /// No description provided for @debtsAmountHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 500.000'**
  String get debtsAmountHint;

  /// No description provided for @debtsStartLabel.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get debtsStartLabel;

  /// No description provided for @debtsDueLabel.
  ///
  /// In es, this message translates to:
  /// **'Vencimiento (opcional)'**
  String get debtsDueLabel;

  /// No description provided for @debtsNoDate.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha'**
  String get debtsNoDate;

  /// No description provided for @debtsRemoveDue.
  ///
  /// In es, this message translates to:
  /// **'Quitar la fecha de vencimiento'**
  String get debtsRemoveDue;

  /// No description provided for @debtsNotesLabel.
  ///
  /// In es, this message translates to:
  /// **'Notas (opcional)'**
  String get debtsNotesLabel;

  /// No description provided for @debtsRegisterMoney.
  ///
  /// In es, this message translates to:
  /// **'Registrar el dinero en una cuenta'**
  String get debtsRegisterMoney;

  /// No description provided for @debtsRegisterMoneyNeedAccount.
  ///
  /// In es, this message translates to:
  /// **'Primero crea una cuenta.'**
  String get debtsRegisterMoneyNeedAccount;

  /// No description provided for @debtsRegisterMoneyPayable.
  ///
  /// In es, this message translates to:
  /// **'El dinero que te prestaron entra a la cuenta.'**
  String get debtsRegisterMoneyPayable;

  /// No description provided for @debtsRegisterMoneyReceivable.
  ///
  /// In es, this message translates to:
  /// **'El dinero que prestaste sale de la cuenta.'**
  String get debtsRegisterMoneyReceivable;

  /// No description provided for @debtsReceiveIn.
  ///
  /// In es, this message translates to:
  /// **'Recibir en'**
  String get debtsReceiveIn;

  /// No description provided for @debtsTakeFrom.
  ///
  /// In es, this message translates to:
  /// **'Sacar de'**
  String get debtsTakeFrom;

  /// No description provided for @debtsCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear deuda'**
  String get debtsCreate;

  /// No description provided for @debtsLockedNote.
  ///
  /// In es, this message translates to:
  /// **'El sentido y el inicio no se pueden cambiar. El monto no puede ser menor a lo ya pagado.'**
  String get debtsLockedNote;

  /// No description provided for @debtsCounterpartyRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe el nombre de la persona'**
  String get debtsCounterpartyRequired;

  /// No description provided for @debtsDueBeforeStart.
  ///
  /// In es, this message translates to:
  /// **'El vencimiento no puede ser anterior al inicio'**
  String get debtsDueBeforeStart;

  /// No description provided for @debtsPaymentExceeds.
  ///
  /// In es, this message translates to:
  /// **'No puede superar lo pendiente ({remaining})'**
  String debtsPaymentExceeds(String remaining);

  /// No description provided for @debtsAmountBelowPaid.
  ///
  /// In es, this message translates to:
  /// **'No puede ser menor a lo ya pagado ({paid})'**
  String debtsAmountBelowPaid(String paid);

  /// No description provided for @debtsArchivedMessage.
  ///
  /// In es, this message translates to:
  /// **'Deuda archivada'**
  String get debtsArchivedMessage;

  /// No description provided for @debtsRestoredMessage.
  ///
  /// In es, this message translates to:
  /// **'Deuda restaurada'**
  String get debtsRestoredMessage;

  /// No description provided for @debtsGone.
  ///
  /// In es, this message translates to:
  /// **'Esta deuda ya no existe.'**
  String get debtsGone;

  /// No description provided for @debtsRecordPayment.
  ///
  /// In es, this message translates to:
  /// **'Registrar abono'**
  String get debtsRecordPayment;

  /// No description provided for @debtsIsSettledNote.
  ///
  /// In es, this message translates to:
  /// **'Esta deuda ya está saldada.'**
  String get debtsIsSettledNote;

  /// No description provided for @debtsIsArchivedNote.
  ///
  /// In es, this message translates to:
  /// **'Está archivada: restáurala para registrar abonos.'**
  String get debtsIsArchivedNote;

  /// No description provided for @debtsPaymentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Abonos'**
  String get debtsPaymentsTitle;

  /// No description provided for @debtsYouOweTo.
  ///
  /// In es, this message translates to:
  /// **'Le debes a {name}'**
  String debtsYouOweTo(String name);

  /// No description provided for @debtsOwesYou.
  ///
  /// In es, this message translates to:
  /// **'{name} te debe'**
  String debtsOwesYou(String name);

  /// No description provided for @debtsRemainingWord.
  ///
  /// In es, this message translates to:
  /// **'pendiente'**
  String get debtsRemainingWord;

  /// No description provided for @debtsPaidAmount.
  ///
  /// In es, this message translates to:
  /// **'Pagado {amount}'**
  String debtsPaidAmount(String amount);

  /// No description provided for @debtsTotalAmount.
  ///
  /// In es, this message translates to:
  /// **'Total {amount}'**
  String debtsTotalAmount(String amount);

  /// No description provided for @debtsSince.
  ///
  /// In es, this message translates to:
  /// **'Desde el {date}'**
  String debtsSince(String date);

  /// No description provided for @debtsPaymentDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este abono?'**
  String get debtsPaymentDeleteTitle;

  /// No description provided for @debtsPaymentDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se elimina también su movimiento y el saldo de la cuenta se recalcula.'**
  String get debtsPaymentDeleteBody;

  /// No description provided for @debtsPaymentDeleted.
  ///
  /// In es, this message translates to:
  /// **'Abono eliminado'**
  String get debtsPaymentDeleted;

  /// No description provided for @debtsPaymentsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay abonos.'**
  String get debtsPaymentsEmpty;

  /// No description provided for @debtsPaymentDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Eliminar abono'**
  String get debtsPaymentDeleteTooltip;

  /// No description provided for @debtsPaySheetTitlePayable.
  ///
  /// In es, this message translates to:
  /// **'Abonar a {name}'**
  String debtsPaySheetTitlePayable(String name);

  /// No description provided for @debtsPaymentDescriptionPayable.
  ///
  /// In es, this message translates to:
  /// **'Abono a {name}'**
  String debtsPaymentDescriptionPayable(String name);

  /// No description provided for @debtsPaymentDescriptionReceivable.
  ///
  /// In es, this message translates to:
  /// **'Abono de {name}'**
  String debtsPaymentDescriptionReceivable(String name);

  /// No description provided for @debtsPendingAmount.
  ///
  /// In es, this message translates to:
  /// **'Pendiente: {amount}'**
  String debtsPendingAmount(String amount);

  /// No description provided for @debtsPaymentAmountLabel.
  ///
  /// In es, this message translates to:
  /// **'Monto del abono'**
  String get debtsPaymentAmountLabel;

  /// No description provided for @debtsPaymentAmountHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 100.000'**
  String get debtsPaymentAmountHint;

  /// No description provided for @debtsPayAll.
  ///
  /// In es, this message translates to:
  /// **'Pagar todo'**
  String get debtsPayAll;

  /// No description provided for @debtsCollectAll.
  ///
  /// In es, this message translates to:
  /// **'Cobrar todo'**
  String get debtsCollectAll;

  /// No description provided for @debtsNeedCurrencyAccount.
  ///
  /// In es, this message translates to:
  /// **'Primero crea una cuenta en {currency} para registrar el abono.'**
  String debtsNeedCurrencyAccount(String currency);

  /// No description provided for @debtsPayFrom.
  ///
  /// In es, this message translates to:
  /// **'Pagar desde'**
  String get debtsPayFrom;

  /// No description provided for @debtsPaymentDateHelp.
  ///
  /// In es, this message translates to:
  /// **'Fecha del abono'**
  String get debtsPaymentDateHelp;

  /// No description provided for @debtsErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos de la deuda: el monto y las fechas.'**
  String get debtsErrorInvalid;

  /// No description provided for @debtsErrorMissingReference.
  ///
  /// In es, this message translates to:
  /// **'La cuenta o la deuda ya no existe. Vuelve a abrir la pantalla.'**
  String get debtsErrorMissingReference;

  /// No description provided for @commonPercent.
  ///
  /// In es, this message translates to:
  /// **'{percent} %'**
  String commonPercent(int percent);

  /// No description provided for @commonPercentUnderOne.
  ///
  /// In es, this message translates to:
  /// **'<1 %'**
  String get commonPercentUnderOne;

  /// No description provided for @summaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen mensual'**
  String get summaryTitle;

  /// No description provided for @summaryNoData.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay movimientos para resumir.\nRegistra ingresos y gastos para ver tu resumen.'**
  String get summaryNoData;

  /// No description provided for @summaryPreviousMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes anterior'**
  String get summaryPreviousMonth;

  /// No description provided for @summaryNextMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes siguiente'**
  String get summaryNextMonth;

  /// No description provided for @summaryBalanceOfMonth.
  ///
  /// In es, this message translates to:
  /// **'Balance del mes'**
  String get summaryBalanceOfMonth;

  /// No description provided for @summaryBalanceUp.
  ///
  /// In es, this message translates to:
  /// **'Ingresaste más de lo que gastaste'**
  String get summaryBalanceUp;

  /// No description provided for @summaryBalanceDown.
  ///
  /// In es, this message translates to:
  /// **'Gastaste más de lo que ingresaste'**
  String get summaryBalanceDown;

  /// No description provided for @summaryBalanceEven.
  ///
  /// In es, this message translates to:
  /// **'Ingresos y gastos iguales'**
  String get summaryBalanceEven;

  /// No description provided for @summaryWhereMoneyGoes.
  ///
  /// In es, this message translates to:
  /// **'¿En qué se va el dinero?'**
  String get summaryWhereMoneyGoes;

  /// No description provided for @summaryWhereMoneyComes.
  ///
  /// In es, this message translates to:
  /// **'¿De dónde viene?'**
  String get summaryWhereMoneyComes;

  /// No description provided for @summaryNoExpensesMonth.
  ///
  /// In es, this message translates to:
  /// **'No hay gastos en este mes.'**
  String get summaryNoExpensesMonth;

  /// No description provided for @summaryNoIncomeMonth.
  ///
  /// In es, this message translates to:
  /// **'No hay ingresos en este mes.'**
  String get summaryNoIncomeMonth;

  /// No description provided for @summaryOtherCategories.
  ///
  /// In es, this message translates to:
  /// **'Otras'**
  String get summaryOtherCategories;

  /// No description provided for @summaryBudgetsLink.
  ///
  /// In es, this message translates to:
  /// **'Cuánto llevas gastado de lo que planeaste'**
  String get summaryBudgetsLink;

  /// No description provided for @summaryHistoryError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la evolución del dinero.'**
  String get summaryHistoryError;

  /// No description provided for @summaryLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el resumen. Revisa tu conexión e intenta de nuevo.'**
  String get summaryLoadError;

  /// No description provided for @summarySameAs.
  ///
  /// In es, this message translates to:
  /// **'Igual que en {month}'**
  String summarySameAs(String month);

  /// No description provided for @summaryZeroIn.
  ///
  /// In es, this message translates to:
  /// **'\$0 en {month}'**
  String summaryZeroIn(String month);

  /// No description provided for @summaryNoExpensesIn.
  ///
  /// In es, this message translates to:
  /// **'Sin gastos en {month}'**
  String summaryNoExpensesIn(String month);

  /// No description provided for @summaryNoIncomeIn.
  ///
  /// In es, this message translates to:
  /// **'Sin ingresos en {month}'**
  String summaryNoIncomeIn(String month);

  /// No description provided for @summaryMoreThan.
  ///
  /// In es, this message translates to:
  /// **'{amount} más que en {month}'**
  String summaryMoreThan(String amount, String month);

  /// No description provided for @summaryLessThan.
  ///
  /// In es, this message translates to:
  /// **'{amount} menos que en {month}'**
  String summaryLessThan(String amount, String month);

  /// No description provided for @summaryPaceTitle.
  ///
  /// In es, this message translates to:
  /// **'Ritmo de gasto'**
  String get summaryPaceTitle;

  /// No description provided for @summaryDailyAverage.
  ///
  /// In es, this message translates to:
  /// **'Promedio por día'**
  String get summaryDailyAverage;

  /// No description provided for @summaryProjectedClose.
  ///
  /// In es, this message translates to:
  /// **'A este ritmo, el mes cerrará en'**
  String get summaryProjectedClose;

  /// No description provided for @summaryProjection.
  ///
  /// In es, this message translates to:
  /// **'Proyección: {comparison}'**
  String summaryProjection(String comparison);

  /// No description provided for @summaryCalculatedPartial.
  ///
  /// In es, this message translates to:
  /// **'Calculado sobre {counted} de {total} días del mes.'**
  String summaryCalculatedPartial(int counted, int total);

  /// No description provided for @summaryCalculatedFull.
  ///
  /// In es, this message translates to:
  /// **'Calculado sobre los {total} días del mes.'**
  String summaryCalculatedFull(int total);

  /// No description provided for @summaryTrendTitle.
  ///
  /// In es, this message translates to:
  /// **'Ingresos vs. gastos'**
  String get summaryTrendTitle;

  /// No description provided for @summaryLastMonths.
  ///
  /// In es, this message translates to:
  /// **'Últimos {count} meses'**
  String summaryLastMonths(int count);

  /// No description provided for @summaryTrendSemantics.
  ///
  /// In es, this message translates to:
  /// **'Gráfico de barras con los ingresos y los gastos de los últimos {count} meses. La misma información está disponible como tabla.'**
  String summaryTrendSemantics(int count);

  /// No description provided for @summaryTrendTooltip.
  ///
  /// In es, this message translates to:
  /// **'{month}\n{series}: {amount}'**
  String summaryTrendTooltip(String month, String series, String amount);

  /// No description provided for @summaryHideTable.
  ///
  /// In es, this message translates to:
  /// **'Ocultar tabla'**
  String get summaryHideTable;

  /// No description provided for @summaryShowTable.
  ///
  /// In es, this message translates to:
  /// **'Ver como tabla'**
  String get summaryShowTable;

  /// No description provided for @summaryTableMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get summaryTableMonth;

  /// No description provided for @summaryHistorySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Al cierre de cada mes'**
  String get summaryHistorySubtitle;

  /// No description provided for @summaryHistorySemantics.
  ///
  /// In es, this message translates to:
  /// **'Gráfico de línea con el dinero total al cierre de cada uno de los últimos {count} meses. La misma información está disponible como tabla.'**
  String summaryHistorySemantics(int count);

  /// No description provided for @summaryHistoryHideTable.
  ///
  /// In es, this message translates to:
  /// **'Ocultar tabla de saldos'**
  String get summaryHistoryHideTable;

  /// No description provided for @summaryHistoryShowTable.
  ///
  /// In es, this message translates to:
  /// **'Ver saldos como tabla'**
  String get summaryHistoryShowTable;

  /// No description provided for @summaryHistoryTableClosing.
  ///
  /// In es, this message translates to:
  /// **'Cierre de'**
  String get summaryHistoryTableClosing;

  /// No description provided for @summarySincePrevious.
  ///
  /// In es, this message translates to:
  /// **'el mes anterior'**
  String get summarySincePrevious;

  /// No description provided for @summarySinceMonths.
  ///
  /// In es, this message translates to:
  /// **'hace {months} meses'**
  String summarySinceMonths(int months);

  /// No description provided for @summaryDeltaUp.
  ///
  /// In es, this message translates to:
  /// **'{amount} más que {since}'**
  String summaryDeltaUp(String amount, String since);

  /// No description provided for @summaryDeltaDown.
  ///
  /// In es, this message translates to:
  /// **'{amount} menos que {since}'**
  String summaryDeltaDown(String amount, String since);

  /// No description provided for @summaryDeltaSame.
  ///
  /// In es, this message translates to:
  /// **'Igual que {since}'**
  String summaryDeltaSame(String since);

  /// No description provided for @budgetsNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo presupuesto'**
  String get budgetsNew;

  /// No description provided for @budgetsEmptyEditable.
  ///
  /// In es, this message translates to:
  /// **'Define cuánto quieres gastar al mes en cada categoría y ve cómo vas.'**
  String get budgetsEmptyEditable;

  /// No description provided for @budgetsEmptyPast.
  ///
  /// In es, this message translates to:
  /// **'No había presupuestos ni gastos en este mes.'**
  String get budgetsEmptyPast;

  /// No description provided for @budgetsDefine.
  ///
  /// In es, this message translates to:
  /// **'Definir un presupuesto'**
  String get budgetsDefine;

  /// No description provided for @budgetsGoToCurrentMonth.
  ///
  /// In es, this message translates to:
  /// **'Ir al mes actual'**
  String get budgetsGoToCurrentMonth;

  /// No description provided for @budgetsWithBudget.
  ///
  /// In es, this message translates to:
  /// **'Con presupuesto'**
  String get budgetsWithBudget;

  /// No description provided for @budgetsWithoutBudget.
  ///
  /// In es, this message translates to:
  /// **'Gastos sin presupuesto'**
  String get budgetsWithoutBudget;

  /// No description provided for @budgetsTapToDefine.
  ///
  /// In es, this message translates to:
  /// **'Toca para definir un presupuesto'**
  String get budgetsTapToDefine;

  /// No description provided for @budgetsTotalTitle.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto total'**
  String get budgetsTotalTitle;

  /// No description provided for @budgetsTotalOf.
  ///
  /// In es, this message translates to:
  /// **'de {amount} presupuestados'**
  String budgetsTotalOf(String amount);

  /// No description provided for @budgetsFormTitleFixed.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto de {name}'**
  String budgetsFormTitleFixed(String name);

  /// No description provided for @budgetsFormTheCategory.
  ///
  /// In es, this message translates to:
  /// **'la categoría'**
  String get budgetsFormTheCategory;

  /// No description provided for @budgetsFormAppliesFrom.
  ///
  /// In es, this message translates to:
  /// **'Rige desde {month} de {year} en adelante, hasta que lo cambies. Los meses anteriores no se tocan.'**
  String budgetsFormAppliesFrom(String month, int year);

  /// No description provided for @budgetsFormAllBudgeted.
  ///
  /// In es, this message translates to:
  /// **'Todas tus categorías de gasto ya tienen presupuesto.'**
  String get budgetsFormAllBudgeted;

  /// No description provided for @budgetsFormChooseCategory.
  ///
  /// In es, this message translates to:
  /// **'Elige una categoría'**
  String get budgetsFormChooseCategory;

  /// No description provided for @budgetsFormCategoryLabel.
  ///
  /// In es, this message translates to:
  /// **'Categoría de gasto'**
  String get budgetsFormCategoryLabel;

  /// No description provided for @budgetsFormAmountLabel.
  ///
  /// In es, this message translates to:
  /// **'Monto mensual'**
  String get budgetsFormAmountLabel;

  /// No description provided for @budgetsFormAmountHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 800.000'**
  String get budgetsFormAmountHint;

  /// No description provided for @budgetsFormRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar el presupuesto'**
  String get budgetsFormRemove;

  /// No description provided for @budgetsErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa el monto del presupuesto.'**
  String get budgetsErrorInvalid;

  /// No description provided for @budgetsErrorMissingCategory.
  ///
  /// In es, this message translates to:
  /// **'La categoría ya no existe. Vuelve a abrir la pantalla.'**
  String get budgetsErrorMissingCategory;

  /// No description provided for @budgetsPercent.
  ///
  /// In es, this message translates to:
  /// **'{percent} %'**
  String budgetsPercent(int percent);

  /// No description provided for @dbErrorTransactionCategoryMismatch.
  ///
  /// In es, this message translates to:
  /// **'La categoría elegida no corresponde a este tipo de movimiento'**
  String get dbErrorTransactionCategoryMismatch;

  /// No description provided for @dbErrorTransferCurrencyMismatch.
  ///
  /// In es, this message translates to:
  /// **'Una transferencia requiere cuentas de la misma moneda'**
  String get dbErrorTransferCurrencyMismatch;

  /// No description provided for @dbErrorBudgetExpenseOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo las categorías de gasto pueden tener presupuesto'**
  String get dbErrorBudgetExpenseOnly;

  /// No description provided for @dbErrorPaymentDirectionMismatch.
  ///
  /// In es, this message translates to:
  /// **'El abono no corresponde al tipo de deuda'**
  String get dbErrorPaymentDirectionMismatch;

  /// No description provided for @dbErrorPaymentCurrencyMismatch.
  ///
  /// In es, this message translates to:
  /// **'El abono debe ser de una cuenta en la moneda de la deuda'**
  String get dbErrorPaymentCurrencyMismatch;

  /// No description provided for @dbErrorPaymentExceedsRemaining.
  ///
  /// In es, this message translates to:
  /// **'El abono supera lo que falta por pagar'**
  String get dbErrorPaymentExceedsRemaining;

  /// No description provided for @dbErrorDebtAmountBelowPaid.
  ///
  /// In es, this message translates to:
  /// **'El monto no puede ser menor a lo que ya se ha pagado'**
  String get dbErrorDebtAmountBelowPaid;

  /// No description provided for @dbErrorDebtDirectionLocked.
  ///
  /// In es, this message translates to:
  /// **'No se puede cambiar el sentido de una deuda que ya tiene abonos'**
  String get dbErrorDebtDirectionLocked;

  /// No description provided for @dbErrorPaymentTypeLocked.
  ///
  /// In es, this message translates to:
  /// **'Este movimiento es el abono de una deuda: no se puede cambiar su tipo'**
  String get dbErrorPaymentTypeLocked;

  /// No description provided for @dbErrorDebtArchived.
  ///
  /// In es, this message translates to:
  /// **'La deuda está archivada: restáurala para registrar abonos'**
  String get dbErrorDebtArchived;

  /// Descripción del movimiento cuando me prestan dinero
  ///
  /// In es, this message translates to:
  /// **'Préstamo de {name}'**
  String debtsLoanDescriptionPayable(String name);

  /// Descripción del movimiento cuando presto dinero
  ///
  /// In es, this message translates to:
  /// **'Préstamo a {name}'**
  String debtsLoanDescriptionReceivable(String name);

  /// No description provided for @currencyNameCop.
  ///
  /// In es, this message translates to:
  /// **'Peso colombiano'**
  String get currencyNameCop;

  /// No description provided for @currencyNameUsd.
  ///
  /// In es, this message translates to:
  /// **'Dólar estadounidense'**
  String get currencyNameUsd;

  /// No description provided for @currencyNameEur.
  ///
  /// In es, this message translates to:
  /// **'Euro'**
  String get currencyNameEur;

  /// No description provided for @currencyNameMxn.
  ///
  /// In es, this message translates to:
  /// **'Peso mexicano'**
  String get currencyNameMxn;

  /// No description provided for @currencyNameArs.
  ///
  /// In es, this message translates to:
  /// **'Peso argentino'**
  String get currencyNameArs;

  /// No description provided for @currencyNameBrl.
  ///
  /// In es, this message translates to:
  /// **'Real brasileño'**
  String get currencyNameBrl;

  /// No description provided for @currencyNameClp.
  ///
  /// In es, this message translates to:
  /// **'Peso chileno'**
  String get currencyNameClp;

  /// No description provided for @currencyNamePen.
  ///
  /// In es, this message translates to:
  /// **'Sol peruano'**
  String get currencyNamePen;

  /// No description provided for @currencyNameGbp.
  ///
  /// In es, this message translates to:
  /// **'Libra esterlina'**
  String get currencyNameGbp;

  /// No description provided for @currencyNameCad.
  ///
  /// In es, this message translates to:
  /// **'Dólar canadiense'**
  String get currencyNameCad;

  /// No description provided for @currencyLabel.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get currencyLabel;

  /// No description provided for @currencyOption.
  ///
  /// In es, this message translates to:
  /// **'{code} · {name}'**
  String currencyOption(String code, String name);

  /// No description provided for @currencyMissingRates.
  ///
  /// In es, this message translates to:
  /// **'Sin tasa de cambio para {currencies}: no se incluye en el total.'**
  String currencyMissingRates(String currencies);

  /// No description provided for @currencyMissingRatesAction.
  ///
  /// In es, this message translates to:
  /// **'Definir'**
  String get currencyMissingRatesAction;

  /// No description provided for @settingsCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get settingsCurrency;

  /// No description provided for @settingsBaseCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda base'**
  String get settingsBaseCurrency;

  /// No description provided for @settingsBaseCurrencyValue.
  ///
  /// In es, this message translates to:
  /// **'{code} · {name}'**
  String settingsBaseCurrencyValue(String code, String name);

  /// No description provided for @settingsExchangeRates.
  ///
  /// In es, this message translates to:
  /// **'Tasas de cambio'**
  String get settingsExchangeRates;

  /// No description provided for @settingsExchangeRatesHelp.
  ///
  /// In es, this message translates to:
  /// **'Cuánto vale cada moneda en tu moneda base'**
  String get settingsExchangeRatesHelp;

  /// No description provided for @baseCurrencyTitle.
  ///
  /// In es, this message translates to:
  /// **'Moneda base'**
  String get baseCurrencyTitle;

  /// No description provided for @baseCurrencyIntro.
  ///
  /// In es, this message translates to:
  /// **'Todo tu dinero, tus resúmenes y tus presupuestos se muestran en esta moneda.'**
  String get baseCurrencyIntro;

  /// No description provided for @baseCurrencyRateLabel.
  ///
  /// In es, this message translates to:
  /// **'1 {next} vale ({previous})'**
  String baseCurrencyRateLabel(String next, String previous);

  /// No description provided for @baseCurrencyRateHelp.
  ///
  /// In es, this message translates to:
  /// **'Hace falta para pasar tus tasas y presupuestos a {next}.'**
  String baseCurrencyRateHelp(String next);

  /// No description provided for @baseCurrencyChangeButton.
  ///
  /// In es, this message translates to:
  /// **'Cambiar moneda base'**
  String get baseCurrencyChangeButton;

  /// No description provided for @ratesTitle.
  ///
  /// In es, this message translates to:
  /// **'Tasas de cambio'**
  String get ratesTitle;

  /// No description provided for @ratesIntro.
  ///
  /// In es, this message translates to:
  /// **'Para sumar el dinero de tus cuentas en otras monedas, define cuánto vale cada una en {base}. Los totales usan la tasa de hoy.'**
  String ratesIntro(String base);

  /// No description provided for @ratesEmpty.
  ///
  /// In es, this message translates to:
  /// **'No tienes cuentas ni deudas en otras monedas.\nCuando las tengas, define aquí sus tasas.'**
  String get ratesEmpty;

  /// No description provided for @ratesNoRate.
  ///
  /// In es, this message translates to:
  /// **'Sin tasa'**
  String get ratesNoRate;

  /// No description provided for @ratesOneEquals.
  ///
  /// In es, this message translates to:
  /// **'1 {currency} = {amount}'**
  String ratesOneEquals(String currency, String amount);

  /// No description provided for @ratesUpdatedToday.
  ///
  /// In es, this message translates to:
  /// **'Actualizada hoy'**
  String get ratesUpdatedToday;

  /// No description provided for @ratesUpdatedYesterday.
  ///
  /// In es, this message translates to:
  /// **'Actualizada ayer'**
  String get ratesUpdatedYesterday;

  /// No description provided for @ratesUpdatedDaysAgo.
  ///
  /// In es, this message translates to:
  /// **'Actualizada hace {days} días'**
  String ratesUpdatedDaysAgo(int days);

  /// No description provided for @ratesAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar tasa'**
  String get ratesAdd;

  /// No description provided for @ratesFormTitle.
  ///
  /// In es, this message translates to:
  /// **'Tasa de {currency}'**
  String ratesFormTitle(String currency);

  /// No description provided for @ratesFormAmountLabel.
  ///
  /// In es, this message translates to:
  /// **'1 {currency} vale'**
  String ratesFormAmountLabel(String currency);

  /// No description provided for @ratesFormHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 4.000'**
  String get ratesFormHint;

  /// No description provided for @ratesFormInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe una tasa mayor que cero. Ejemplo: 4.012,5'**
  String get ratesFormInvalid;

  /// No description provided for @ratesFormRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar la tasa'**
  String get ratesFormRemove;

  /// No description provided for @ratesFormChooseCurrency.
  ///
  /// In es, this message translates to:
  /// **'Elige una moneda'**
  String get ratesFormChooseCurrency;

  /// No description provided for @ratesErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa la tasa: tiene que ser mayor que cero.'**
  String get ratesErrorInvalid;

  /// No description provided for @accountsCurrencyLocked.
  ///
  /// In es, this message translates to:
  /// **'La moneda de una cuenta no se puede cambiar.'**
  String get accountsCurrencyLocked;

  /// No description provided for @accountsRateLabel.
  ///
  /// In es, this message translates to:
  /// **'1 {currency} vale (opcional)'**
  String accountsRateLabel(String currency);

  /// No description provided for @accountsRateHelp.
  ///
  /// In es, this message translates to:
  /// **'Sin tasa, esta cuenta no suma al dinero total.'**
  String get accountsRateHelp;

  /// No description provided for @transactionsAmountOut.
  ///
  /// In es, this message translates to:
  /// **'Monto que sale ({currency})'**
  String transactionsAmountOut(String currency);

  /// No description provided for @transactionsAmountIn.
  ///
  /// In es, this message translates to:
  /// **'Monto que llega ({currency})'**
  String transactionsAmountIn(String currency);

  /// No description provided for @transactionsImpliedRate.
  ///
  /// In es, this message translates to:
  /// **'1 {from} = {rate} {to}'**
  String transactionsImpliedRate(String from, String rate, String to);

  /// No description provided for @transactionsReceives.
  ///
  /// In es, this message translates to:
  /// **'recibe {amount}'**
  String transactionsReceives(String amount);

  /// No description provided for @summaryConvertedNote.
  ///
  /// In es, this message translates to:
  /// **'Los montos en otras monedas se pasan a {base} con la tasa de hoy.'**
  String summaryConvertedNote(String base);

  /// No description provided for @dbErrorRateForBaseCurrency.
  ///
  /// In es, this message translates to:
  /// **'La moneda base no necesita tasa de cambio'**
  String get dbErrorRateForBaseCurrency;

  /// No description provided for @dbErrorBaseRateRequired.
  ///
  /// In es, this message translates to:
  /// **'Hace falta la tasa de la moneda nueva para convertir tus tasas y presupuestos'**
  String get dbErrorBaseRateRequired;

  /// No description provided for @dbErrorTransferDestinationRequired.
  ///
  /// In es, this message translates to:
  /// **'Una transferencia entre monedas distintas necesita el monto que llega'**
  String get dbErrorTransferDestinationRequired;

  /// No description provided for @dbErrorTransferDestinationUnexpected.
  ///
  /// In es, this message translates to:
  /// **'El monto que llega solo se indica en transferencias entre monedas distintas'**
  String get dbErrorTransferDestinationUnexpected;

  /// No description provided for @recurringTitle.
  ///
  /// In es, this message translates to:
  /// **'Pagos recurrentes'**
  String get recurringTitle;

  /// No description provided for @recurringNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo pago recurrente'**
  String get recurringNew;

  /// No description provided for @recurringEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar pago recurrente'**
  String get recurringEdit;

  /// No description provided for @recurringCreateButton.
  ///
  /// In es, this message translates to:
  /// **'Crear pago recurrente'**
  String get recurringCreateButton;

  /// No description provided for @recurringEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no registras pagos recurrentes.\nAnota tus suscripciones, el arriendo y lo que pagas cada cierto tiempo.'**
  String get recurringEmpty;

  /// No description provided for @recurringEmptyAction.
  ///
  /// In es, this message translates to:
  /// **'Registrar pago recurrente'**
  String get recurringEmptyAction;

  /// No description provided for @recurringDashboardEmpty.
  ///
  /// In es, this message translates to:
  /// **'Registra tus suscripciones y el arriendo'**
  String get recurringDashboardEmpty;

  /// No description provided for @recurringNothingSoon.
  ///
  /// In es, this message translates to:
  /// **'No tienes pagos próximos.'**
  String get recurringNothingSoon;

  /// No description provided for @recurringNextOne.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: {name} · {date}'**
  String recurringNextOne(String name, String date);

  /// No description provided for @recurringSectionActive.
  ///
  /// In es, this message translates to:
  /// **'Activos'**
  String get recurringSectionActive;

  /// No description provided for @recurringSectionOther.
  ///
  /// In es, this message translates to:
  /// **'En pausa o terminados'**
  String get recurringSectionOther;

  /// No description provided for @recurringStatusOverdue.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, one{Vencido hace {days} día} other{Vencido hace {days} días}}'**
  String recurringStatusOverdue(int days);

  /// No description provided for @recurringStatusToday.
  ///
  /// In es, this message translates to:
  /// **'Pago próximo: vence hoy'**
  String get recurringStatusToday;

  /// No description provided for @recurringStatusTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Pago próximo: vence mañana'**
  String get recurringStatusTomorrow;

  /// No description provided for @recurringStatusSoon.
  ///
  /// In es, this message translates to:
  /// **'Pago próximo: vence en {days} días'**
  String recurringStatusSoon(int days);

  /// No description provided for @recurringStatusLater.
  ///
  /// In es, this message translates to:
  /// **'Próximo pago el {date}'**
  String recurringStatusLater(String date);

  /// No description provided for @recurringStatusPaused.
  ///
  /// In es, this message translates to:
  /// **'En pausa'**
  String get recurringStatusPaused;

  /// No description provided for @recurringStatusFinished.
  ///
  /// In es, this message translates to:
  /// **'Terminado'**
  String get recurringStatusFinished;

  /// No description provided for @recurrenceEveryWeek.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{Cada semana} other{Cada {n} semanas}}'**
  String recurrenceEveryWeek(int n);

  /// No description provided for @recurrenceEveryMonth.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{Cada mes} other{Cada {n} meses}}'**
  String recurrenceEveryMonth(int n);

  /// No description provided for @recurrenceEveryYear.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{Cada año} other{Cada {n} años}}'**
  String recurrenceEveryYear(int n);

  /// No description provided for @recurringNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get recurringNameLabel;

  /// No description provided for @recurringNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Netflix, Arriendo'**
  String get recurringNameHint;

  /// No description provided for @recurringNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ponle un nombre al pago'**
  String get recurringNameRequired;

  /// No description provided for @recurringAccountLabel.
  ///
  /// In es, this message translates to:
  /// **'Se paga desde'**
  String get recurringAccountLabel;

  /// No description provided for @recurringFrequencyLabel.
  ///
  /// In es, this message translates to:
  /// **'Frecuencia'**
  String get recurringFrequencyLabel;

  /// No description provided for @recurringNextLabel.
  ///
  /// In es, this message translates to:
  /// **'Próximo pago'**
  String get recurringNextLabel;

  /// No description provided for @recurringNextHelp.
  ///
  /// In es, this message translates to:
  /// **'La fecha en que toca pagarlo. Después se calcula sola.'**
  String get recurringNextHelp;

  /// No description provided for @recurringEndLabel.
  ///
  /// In es, this message translates to:
  /// **'Termina (opcional)'**
  String get recurringEndLabel;

  /// No description provided for @recurringNoEnd.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha final'**
  String get recurringNoEnd;

  /// No description provided for @recurringRemoveEnd.
  ///
  /// In es, this message translates to:
  /// **'Quitar la fecha final'**
  String get recurringRemoveEnd;

  /// No description provided for @recurringPickNextHelp.
  ///
  /// In es, this message translates to:
  /// **'Fecha del próximo pago'**
  String get recurringPickNextHelp;

  /// No description provided for @recurringPickEndHelp.
  ///
  /// In es, this message translates to:
  /// **'Fecha final'**
  String get recurringPickEndHelp;

  /// No description provided for @recurringEndBeforeNext.
  ///
  /// In es, this message translates to:
  /// **'La fecha final no puede ser anterior al próximo pago'**
  String get recurringEndBeforeNext;

  /// No description provided for @recurringReminderNote.
  ///
  /// In es, this message translates to:
  /// **'No se descuenta nada hasta que confirmes que pagaste.'**
  String get recurringReminderNote;

  /// No description provided for @recurringPayAction.
  ///
  /// In es, this message translates to:
  /// **'Ya pagué'**
  String get recurringPayAction;

  /// No description provided for @recurringSkipAction.
  ///
  /// In es, this message translates to:
  /// **'Omitir este pago'**
  String get recurringSkipAction;

  /// No description provided for @recurringPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get recurringPause;

  /// No description provided for @recurringResume.
  ///
  /// In es, this message translates to:
  /// **'Reanudar'**
  String get recurringResume;

  /// No description provided for @recurringDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get recurringDelete;

  /// No description provided for @recurringDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este pago recurrente?'**
  String get recurringDeleteTitle;

  /// No description provided for @recurringDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Los pagos que ya registraste se conservan.'**
  String get recurringDeleteBody;

  /// No description provided for @recurringPausedMessage.
  ///
  /// In es, this message translates to:
  /// **'Pago pausado'**
  String get recurringPausedMessage;

  /// No description provided for @recurringResumedMessage.
  ///
  /// In es, this message translates to:
  /// **'Pago reanudado'**
  String get recurringResumedMessage;

  /// No description provided for @recurringDeletedMessage.
  ///
  /// In es, this message translates to:
  /// **'Pago recurrente eliminado'**
  String get recurringDeletedMessage;

  /// No description provided for @recurringGone.
  ///
  /// In es, this message translates to:
  /// **'Este pago recurrente ya no existe.'**
  String get recurringGone;

  /// No description provided for @recurringHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Pagos registrados'**
  String get recurringHistoryTitle;

  /// No description provided for @recurringHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has registrado ningún pago.'**
  String get recurringHistoryEmpty;

  /// No description provided for @recurringEndsOn.
  ///
  /// In es, this message translates to:
  /// **'Termina el {date}'**
  String recurringEndsOn(String date);

  /// No description provided for @recurringConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Pago de {name}'**
  String recurringConfirmTitle(String name);

  /// No description provided for @recurringConfirmButton.
  ///
  /// In es, this message translates to:
  /// **'Confirmar pago'**
  String get recurringConfirmButton;

  /// No description provided for @recurringConfirmDateHelp.
  ///
  /// In es, this message translates to:
  /// **'Fecha del pago'**
  String get recurringConfirmDateHelp;

  /// No description provided for @recurringConfirmedMessage.
  ///
  /// In es, this message translates to:
  /// **'Pago registrado'**
  String get recurringConfirmedMessage;

  /// No description provided for @recurringSkippedMessage.
  ///
  /// In es, this message translates to:
  /// **'Pago omitido'**
  String get recurringSkippedMessage;

  /// No description provided for @recurringErrorGone.
  ///
  /// In es, this message translates to:
  /// **'El pago recurrente ya no existe. Vuelve a abrir la pantalla.'**
  String get recurringErrorGone;

  /// No description provided for @recurringErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos del pago: el nombre, el monto y las fechas.'**
  String get recurringErrorInvalid;

  /// No description provided for @dbErrorRecurringFinished.
  ///
  /// In es, this message translates to:
  /// **'Este pago recurrente ya terminó'**
  String get dbErrorRecurringFinished;

  /// No description provided for @dbErrorRecurringCategory.
  ///
  /// In es, this message translates to:
  /// **'Solo las categorías de gasto sirven en un pago recurrente'**
  String get dbErrorRecurringCategory;

  /// No description provided for @debtsInstallmentsSwitch.
  ///
  /// In es, this message translates to:
  /// **'Pagar en cuotas'**
  String get debtsInstallmentsSwitch;

  /// No description provided for @debtsInstallmentsSwitchHelp.
  ///
  /// In es, this message translates to:
  /// **'Te avisamos cuándo toca cada cuota y la registras como abono a la deuda.'**
  String get debtsInstallmentsSwitchHelp;

  /// No description provided for @debtsInstallmentsCount.
  ///
  /// In es, this message translates to:
  /// **'Número de cuotas'**
  String get debtsInstallmentsCount;

  /// No description provided for @debtsInstallmentsCountHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 12'**
  String get debtsInstallmentsCountHint;

  /// No description provided for @debtsInstallmentsCountInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe cuántas cuotas son (de 1 a 360)'**
  String get debtsInstallmentsCountInvalid;

  /// No description provided for @debtsInstallmentsAmount.
  ///
  /// In es, this message translates to:
  /// **'Valor de cada cuota'**
  String get debtsInstallmentsAmount;

  /// No description provided for @debtsInstallmentsAmountHelp.
  ///
  /// In es, this message translates to:
  /// **'Normalmente, el total dividido entre las cuotas.'**
  String get debtsInstallmentsAmountHelp;

  /// No description provided for @debtsInstallmentsFrequency.
  ///
  /// In es, this message translates to:
  /// **'Cada cuánto'**
  String get debtsInstallmentsFrequency;

  /// No description provided for @debtsInstallmentsFirst.
  ///
  /// In es, this message translates to:
  /// **'Primera cuota'**
  String get debtsInstallmentsFirst;

  /// No description provided for @debtsInstallmentsFirstHelp.
  ///
  /// In es, this message translates to:
  /// **'Fecha de la primera cuota'**
  String get debtsInstallmentsFirstHelp;

  /// No description provided for @debtsInstallmentsPayFrom.
  ///
  /// In es, this message translates to:
  /// **'Pagar las cuotas desde'**
  String get debtsInstallmentsPayFrom;

  /// No description provided for @installmentNumber.
  ///
  /// In es, this message translates to:
  /// **'Cuota {number} de {total}'**
  String installmentNumber(int number, int total);

  /// No description provided for @debtsPlanTitle.
  ///
  /// In es, this message translates to:
  /// **'Plan de cuotas'**
  String get debtsPlanTitle;

  /// No description provided for @recurringDebtRemaining.
  ///
  /// In es, this message translates to:
  /// **'Falta por pagar: {amount}'**
  String recurringDebtRemaining(String amount);

  /// No description provided for @recurringDeletePlanBody.
  ///
  /// In es, this message translates to:
  /// **'La deuda y los abonos que ya registraste se conservan.'**
  String get recurringDeletePlanBody;

  /// No description provided for @dbErrorInstallmentDirection.
  ///
  /// In es, this message translates to:
  /// **'Solo las deudas que debes pueden pagarse en cuotas'**
  String get dbErrorInstallmentDirection;

  /// No description provided for @dbErrorInstallmentCurrency.
  ///
  /// In es, this message translates to:
  /// **'La cuenta de las cuotas tiene que ser de la moneda de la deuda'**
  String get dbErrorInstallmentCurrency;

  /// No description provided for @goalsTitle.
  ///
  /// In es, this message translates to:
  /// **'Metas de ahorro'**
  String get goalsTitle;

  /// No description provided for @goalsNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva meta'**
  String get goalsNew;

  /// No description provided for @goalsEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar meta'**
  String get goalsEdit;

  /// No description provided for @goalsCreateButton.
  ///
  /// In es, this message translates to:
  /// **'Crear meta'**
  String get goalsCreateButton;

  /// No description provided for @goalsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes metas. Una meta es una cantidad que quieres juntar en una cuenta: lo que ahorras es el saldo de esa cuenta.'**
  String get goalsEmpty;

  /// No description provided for @goalsAllArchived.
  ///
  /// In es, this message translates to:
  /// **'Todas tus metas están archivadas.'**
  String get goalsAllArchived;

  /// No description provided for @goalsDashboardEmpty.
  ///
  /// In es, this message translates to:
  /// **'Junta plata para algo: crea una meta de ahorro.'**
  String get goalsDashboardEmpty;

  /// No description provided for @goalsNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get goalsNameLabel;

  /// No description provided for @goalsNameHint.
  ///
  /// In es, this message translates to:
  /// **'Viaje, moto, fondo de emergencia'**
  String get goalsNameHint;

  /// No description provided for @goalsNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe el nombre de la meta'**
  String get goalsNameRequired;

  /// No description provided for @goalsTargetLabel.
  ///
  /// In es, this message translates to:
  /// **'Cuánto quieres juntar'**
  String get goalsTargetLabel;

  /// No description provided for @goalsTargetPositive.
  ///
  /// In es, this message translates to:
  /// **'La meta tiene que ser mayor que cero'**
  String get goalsTargetPositive;

  /// No description provided for @goalsAccountLabel.
  ///
  /// In es, this message translates to:
  /// **'Cuenta donde ahorras'**
  String get goalsAccountLabel;

  /// No description provided for @goalsAccountHelp.
  ///
  /// In es, this message translates to:
  /// **'Lo que llevas ahorrado es el saldo de esta cuenta. Para ahorrar, pasa plata a ella.'**
  String get goalsAccountHelp;

  /// No description provided for @goalsAccountLocked.
  ///
  /// In es, this message translates to:
  /// **'La cuenta de una meta no se cambia.'**
  String get goalsAccountLocked;

  /// No description provided for @goalsAccountRequired.
  ///
  /// In es, this message translates to:
  /// **'Elige la cuenta de la meta'**
  String get goalsAccountRequired;

  /// No description provided for @goalsNoFreeAccount.
  ///
  /// In es, this message translates to:
  /// **'No tienes una cuenta libre: cada cuenta sirve para una sola meta y las tarjetas no sirven.'**
  String get goalsNoFreeAccount;

  /// No description provided for @goalsNewAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear una cuenta nueva'**
  String get goalsNewAccount;

  /// No description provided for @goalsDeadlineLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha límite (opcional)'**
  String get goalsDeadlineLabel;

  /// No description provided for @goalsDeadlineNone.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha'**
  String get goalsDeadlineNone;

  /// No description provided for @goalsDeadlineClear.
  ///
  /// In es, this message translates to:
  /// **'Quitar la fecha'**
  String get goalsDeadlineClear;

  /// No description provided for @goalsSavedOf.
  ///
  /// In es, this message translates to:
  /// **'{saved} de {target}'**
  String goalsSavedOf(String saved, String target);

  /// No description provided for @goalsRemaining.
  ///
  /// In es, this message translates to:
  /// **'Faltan {amount}'**
  String goalsRemaining(String amount);

  /// No description provided for @goalsDaysLeft.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{vence hoy} one{queda {count} día} other{quedan {count} días}}'**
  String goalsDaysLeft(int count);

  /// No description provided for @goalsStatusReached.
  ///
  /// In es, this message translates to:
  /// **'¡Meta cumplida!'**
  String get goalsStatusReached;

  /// No description provided for @goalsStatusOverdue.
  ///
  /// In es, this message translates to:
  /// **'Venció el {date} · faltan {amount}'**
  String goalsStatusOverdue(String date, String amount);

  /// No description provided for @goalsArchivedLabel.
  ///
  /// In es, this message translates to:
  /// **'Archivada'**
  String get goalsArchivedLabel;

  /// No description provided for @goalsAccountArchivedNote.
  ///
  /// In es, this message translates to:
  /// **'La cuenta {name} está archivada: ya no puedes ahorrar en ella.'**
  String goalsAccountArchivedNote(String name);

  /// No description provided for @goalsSuggestMonthly.
  ///
  /// In es, this message translates to:
  /// **'Para llegar a tiempo, ahorra {amount} al mes.'**
  String goalsSuggestMonthly(String amount);

  /// No description provided for @goalsSuggestBefore.
  ///
  /// In es, this message translates to:
  /// **'Para llegar a tiempo, ahorra {amount} antes del {date}.'**
  String goalsSuggestBefore(String amount, String date);

  /// No description provided for @goalsDeadlineOn.
  ///
  /// In es, this message translates to:
  /// **'Para el {date}'**
  String goalsDeadlineOn(String date);

  /// No description provided for @goalsReachedHint.
  ///
  /// In es, this message translates to:
  /// **'Cuando ya no la necesites, archívala para liberar su cuenta.'**
  String get goalsReachedHint;

  /// No description provided for @goalsSave.
  ///
  /// In es, this message translates to:
  /// **'Ahorrar'**
  String get goalsSave;

  /// No description provided for @goalsWithdraw.
  ///
  /// In es, this message translates to:
  /// **'Sacar'**
  String get goalsWithdraw;

  /// No description provided for @goalsAccountRow.
  ///
  /// In es, this message translates to:
  /// **'Cuenta: {name}'**
  String goalsAccountRow(String name);

  /// No description provided for @goalsHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Movimientos de la meta'**
  String get goalsHistoryTitle;

  /// No description provided for @goalsHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has ahorrado nada en esta cuenta.'**
  String get goalsHistoryEmpty;

  /// No description provided for @goalsMovementFrom.
  ///
  /// In es, this message translates to:
  /// **'Desde {account}'**
  String goalsMovementFrom(String account);

  /// No description provided for @goalsMovementTo.
  ///
  /// In es, this message translates to:
  /// **'Hacia {account}'**
  String goalsMovementTo(String account);

  /// No description provided for @goalsArchive.
  ///
  /// In es, this message translates to:
  /// **'Archivar'**
  String get goalsArchive;

  /// No description provided for @goalsRestore.
  ///
  /// In es, this message translates to:
  /// **'Restaurar'**
  String get goalsRestore;

  /// No description provided for @goalsArchivedMessage.
  ///
  /// In es, this message translates to:
  /// **'Meta archivada'**
  String get goalsArchivedMessage;

  /// No description provided for @goalsRestoredMessage.
  ///
  /// In es, this message translates to:
  /// **'Meta restaurada'**
  String get goalsRestoredMessage;

  /// No description provided for @goalsGone.
  ///
  /// In es, this message translates to:
  /// **'Esta meta ya no existe.'**
  String get goalsGone;

  /// No description provided for @goalsErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos de la meta.'**
  String get goalsErrorInvalid;

  /// No description provided for @goalsErrorAccountTaken.
  ///
  /// In es, this message translates to:
  /// **'Esa cuenta ya tiene otra meta activa.'**
  String get goalsErrorAccountTaken;

  /// No description provided for @goalsErrorMissingAccount.
  ///
  /// In es, this message translates to:
  /// **'La cuenta elegida ya no existe.'**
  String get goalsErrorMissingAccount;

  /// No description provided for @dbErrorGoalAccountCard.
  ///
  /// In es, this message translates to:
  /// **'Una tarjeta no puede ser la cuenta de una meta de ahorro'**
  String get dbErrorGoalAccountCard;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navGoals.
  ///
  /// In es, this message translates to:
  /// **'Metas'**
  String get navGoals;

  /// No description provided for @navMore.
  ///
  /// In es, this message translates to:
  /// **'Más'**
  String get navMore;

  /// No description provided for @navTransactions.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get navTransactions;

  /// No description provided for @accountsCardLimitLabel.
  ///
  /// In es, this message translates to:
  /// **'Cupo (opcional)'**
  String get accountsCardLimitLabel;

  /// No description provided for @accountsCardLimitHelper.
  ///
  /// In es, this message translates to:
  /// **'Lo máximo que te deja gastar el banco con la tarjeta'**
  String get accountsCardLimitHelper;

  /// No description provided for @accountsCardLimitInvalid.
  ///
  /// In es, this message translates to:
  /// **'El cupo tiene que ser un monto mayor que cero'**
  String get accountsCardLimitInvalid;

  /// No description provided for @accountsCardStatementDayLabel.
  ///
  /// In es, this message translates to:
  /// **'Día de corte (opcional)'**
  String get accountsCardStatementDayLabel;

  /// No description provided for @accountsCardStatementDayHelper.
  ///
  /// In es, this message translates to:
  /// **'El día del mes en que cierra tu extracto'**
  String get accountsCardStatementDayHelper;

  /// No description provided for @accountsCardPaymentDayLabel.
  ///
  /// In es, this message translates to:
  /// **'Día límite de pago (opcional)'**
  String get accountsCardPaymentDayLabel;

  /// No description provided for @accountsCardPaymentDayHelper.
  ///
  /// In es, this message translates to:
  /// **'El día del mes hasta el que debes pagar'**
  String get accountsCardPaymentDayHelper;

  /// No description provided for @accountsCardDayInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe un día del 1 al 31'**
  String get accountsCardDayInvalid;

  /// No description provided for @accountsCardDaysTogether.
  ///
  /// In es, this message translates to:
  /// **'Indica los dos días, o deja los dos vacíos'**
  String get accountsCardDaysTogether;

  /// No description provided for @accountsCardInitialBalanceHelper.
  ///
  /// In es, this message translates to:
  /// **'Lo que ya debes, con signo menos (ej: -200.000). Vacío si empieza en cero'**
  String get accountsCardInitialBalanceHelper;

  /// No description provided for @accountsCardUsedOf.
  ///
  /// In es, this message translates to:
  /// **'Usado {used} de {limit}'**
  String accountsCardUsedOf(String used, String limit);

  /// No description provided for @accountsCardAvailable.
  ///
  /// In es, this message translates to:
  /// **'Disponible {amount}'**
  String accountsCardAvailable(String amount);

  /// No description provided for @accountsCardOverLimit.
  ///
  /// In es, this message translates to:
  /// **'Te pasaste del cupo por {amount}'**
  String accountsCardOverLimit(String amount);

  /// No description provided for @accountsCardDates.
  ///
  /// In es, this message translates to:
  /// **'Corte {statement} · Pagar antes del {payment}'**
  String accountsCardDates(String statement, String payment);

  /// No description provided for @dashboardCardDebt.
  ///
  /// In es, this message translates to:
  /// **'Debes en tarjetas {amount}'**
  String dashboardCardDebt(String amount);

  /// No description provided for @creditLimitMessage.
  ///
  /// In es, this message translates to:
  /// **'{account} quedaría {amount} por encima de su cupo.'**
  String creditLimitMessage(String account, String amount);

  /// No description provided for @accountsCardDue.
  ///
  /// In es, this message translates to:
  /// **'Por pagar del último corte: {amount}'**
  String accountsCardDue(String amount);

  /// No description provided for @accountsCardOverdue.
  ///
  /// In es, this message translates to:
  /// **'Vencido desde el {date}: {amount}'**
  String accountsCardOverdue(String date, String amount);

  /// No description provided for @accountsCardPaidUp.
  ///
  /// In es, this message translates to:
  /// **'Al día con el último corte'**
  String get accountsCardPaidUp;

  /// No description provided for @accountsCardPay.
  ///
  /// In es, this message translates to:
  /// **'Pagar'**
  String get accountsCardPay;

  /// No description provided for @dashboardCardPaymentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Pagos de tarjetas'**
  String get dashboardCardPaymentsTitle;

  /// No description provided for @dashboardCardDueToday.
  ///
  /// In es, this message translates to:
  /// **'Vence hoy'**
  String get dashboardCardDueToday;

  /// No description provided for @dashboardCardDueTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Vence mañana'**
  String get dashboardCardDueTomorrow;

  /// No description provided for @dashboardCardDueIn.
  ///
  /// In es, this message translates to:
  /// **'Vence en {days} días'**
  String dashboardCardDueIn(int days);

  /// No description provided for @dashboardCardDueOn.
  ///
  /// In es, this message translates to:
  /// **'{when} · {date}'**
  String dashboardCardDueOn(String when, String date);

  /// No description provided for @dashboardCardOverdue.
  ///
  /// In es, this message translates to:
  /// **'Vencido desde el {date}'**
  String dashboardCardOverdue(String date);
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

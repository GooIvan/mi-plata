// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSaveChanges => 'Guardar cambios';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonArchive => 'Archivar';

  @override
  String get commonRestore => 'Restaurar';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get commonOptions => 'Opciones';

  @override
  String get commonSeeAll => 'Ver todas';

  @override
  String get commonSeeAllMasculine => 'Ver todos';

  @override
  String get commonShowArchived => 'Mostrar archivadas';

  @override
  String get commonHideArchived => 'Ocultar archivadas';

  @override
  String get commonIncomes => 'Ingresos';

  @override
  String get commonExpenses => 'Gastos';

  @override
  String get commonNoCategory => 'Sin categoría';

  @override
  String get commonLoadError =>
      'No se pudo completar la operación. Revisa tu conexión e intenta de nuevo.';

  @override
  String get commonSessionExpired =>
      'Tu sesión expiró. Vuelve a iniciar sesión.';

  @override
  String commonNameTooLong(int max) {
    return 'Usa $max caracteres o menos';
  }

  @override
  String get commonInvalidAmount =>
      'Monto no válido. Ejemplo: 1.500.000 o 1500,50';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authPasswordRepeatLabel => 'Repite la contraseña';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authLoginSubtitle => 'Inicia sesión para continuar';

  @override
  String get authRegisterSubtitle => 'Crea tu cuenta para empezar';

  @override
  String get authLoginButton => 'Entrar';

  @override
  String get authRegisterButton => 'Crear cuenta';

  @override
  String get authGoToRegister => '¿No tienes cuenta? Regístrate';

  @override
  String get authGoToLogin => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authConfirmEmailSent =>
      'Te enviamos un correo para confirmar tu cuenta. Después podrás iniciar sesión.';

  @override
  String get authEmailRequired => 'Ingresa tu correo';

  @override
  String get authEmailInvalid => 'El correo no es válido';

  @override
  String get authPasswordRequired => 'Ingresa tu contraseña';

  @override
  String get authNewPasswordRequired => 'Crea una contraseña';

  @override
  String authPasswordTooShort(int min) {
    return 'Usa al menos $min caracteres';
  }

  @override
  String get authPasswordRepeatRequired => 'Repite tu contraseña';

  @override
  String get authPasswordMismatch => 'Las contraseñas no coinciden';

  @override
  String get authErrorOffline =>
      'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.';

  @override
  String get authErrorInvalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get authErrorEmailExists => 'Ya existe una cuenta con ese correo.';

  @override
  String get authErrorWeakPassword =>
      'La contraseña es muy débil. Usa una más larga o más variada.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirma tu correo antes de iniciar sesión.';

  @override
  String get authErrorRateLimit =>
      'Demasiados intentos. Espera un momento e intenta de nuevo.';

  @override
  String get authErrorSignupDisabled =>
      'El registro de usuarios está deshabilitado.';

  @override
  String get authErrorGeneric =>
      'No se pudo completar la operación. Intenta de nuevo.';

  @override
  String get dashboardTotalMoney => 'Dinero total';

  @override
  String get dashboardLoadMoneyError => 'No se pudo cargar tu dinero.';

  @override
  String get dashboardNoAccounts => 'Aún no tienes cuentas';

  @override
  String dashboardAccountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En $count cuentas',
      one: 'En $count cuenta',
    );
    return '$_temp0';
  }

  @override
  String get dashboardRecentTransactions => 'Últimos movimientos';

  @override
  String get dashboardNoTransactions => 'Aún no registras movimientos.';

  @override
  String get dashboardDebtsLoadError => 'No se pudieron cargar las deudas.';

  @override
  String get dashboardDebtsEmpty => 'Registra lo que debes o te deben';

  @override
  String get dashboardYouOwe => 'Debes';

  @override
  String get dashboardOwedToYou => 'Te deben';

  @override
  String get dashboardSummaryTooltip => 'Resumen mensual';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Idioma del teléfono';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsSession => 'Sesión';

  @override
  String settingsSignedInAs(String email) {
    return 'Sesión iniciada como $email';
  }

  @override
  String get settingsSignOut => 'Cerrar sesión';

  @override
  String get budgetsTitle => 'Presupuestos';

  @override
  String budgetsStatusOk(String amount) {
    return 'Quedan $amount';
  }

  @override
  String get budgetsStatusAtLimit => 'Llegaste al límite';

  @override
  String budgetsStatusNear(String amount) {
    return 'Cerca del límite: quedan $amount';
  }

  @override
  String budgetsStatusOver(String amount) {
    return 'Te pasaste por $amount';
  }

  @override
  String budgetsAlertOver(String category, String spent, String limit) {
    return 'Superaste el presupuesto de $category: $spent de $limit.';
  }

  @override
  String budgetsAlertNear(
    int percent,
    String category,
    String spent,
    String limit,
  ) {
    return 'Vas en $percent % del presupuesto de $category ($spent de $limit).';
  }

  @override
  String get budgetsThisCategory => 'esta categoría';

  @override
  String budgetsOverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categorías superadas',
      one: '$count categoría superada',
    );
    return '$_temp0';
  }

  @override
  String budgetsNearCount(int count) {
    return '$count cerca del límite';
  }

  @override
  String budgetsOfLimit(String limit) {
    return 'de $limit';
  }

  @override
  String get accountsTitle => 'Cuentas';

  @override
  String get accountsNew => 'Nueva cuenta';

  @override
  String get accountsEdit => 'Editar cuenta';

  @override
  String get accountsCreateButton => 'Crear cuenta';

  @override
  String get accountsEmpty =>
      'Aún no tienes cuentas.\nCrea la primera para empezar.';

  @override
  String get accountsAllArchived => 'Todas tus cuentas están archivadas.';

  @override
  String get accountsArchivedMessage => 'Cuenta archivada';

  @override
  String get accountsRestoredMessage => 'Cuenta restaurada';

  @override
  String get accountsArchivedTag => 'Archivada';

  @override
  String accountsArchivedName(String name) {
    return '$name (archivada)';
  }

  @override
  String get accountsNameLabel => 'Nombre';

  @override
  String get accountsNameHint => 'Ej: Bancolombia ahorros';

  @override
  String get accountsTypeLabel => 'Tipo';

  @override
  String get accountsInitialBalanceLabel => 'Saldo inicial';

  @override
  String get accountsInitialBalanceHint => 'Ej: 1.500.000';

  @override
  String get accountsInitialBalanceHelper => 'Déjalo vacío si empieza en cero';

  @override
  String get accountsChoose => 'Elige una cuenta';

  @override
  String get accountTypeCash => 'Efectivo';

  @override
  String get accountTypeBank => 'Banco';

  @override
  String get accountTypeWallet => 'Billetera digital';

  @override
  String get accountTypeCard => 'Tarjeta';

  @override
  String get accountsNameRequired => 'Ponle un nombre a la cuenta';

  @override
  String get accountsErrorDuplicateName =>
      'Ya tienes una cuenta activa con ese nombre.';

  @override
  String get accountsErrorInvalidData =>
      'Revisa los datos: el nombre no puede estar vacío.';

  @override
  String get accountsErrorAmountTooLarge => 'El monto es demasiado grande.';

  @override
  String get commonArchivedTag => 'Archivada';

  @override
  String get categoriesTitle => 'Categorías';

  @override
  String get categoriesNew => 'Nueva categoría';

  @override
  String get categoriesCreateButton => 'Crear categoría';

  @override
  String get categoriesArchivedMessage => 'Categoría archivada';

  @override
  String get categoriesRestoredMessage => 'Categoría restaurada';

  @override
  String categoriesNewOfType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'expense': 'Nueva categoría de gasto',
      'income': 'Nueva categoría de ingreso',
      'other': 'Nueva categoría',
    });
    return '$_temp0';
  }

  @override
  String categoriesEditOfType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'expense': 'Editar categoría de gasto',
      'income': 'Editar categoría de ingreso',
      'other': 'Editar categoría',
    });
    return '$_temp0';
  }

  @override
  String categoriesEmptyOfType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'expense': 'Aún no tienes categorías de gasto.',
      'income': 'Aún no tienes categorías de ingreso.',
      'other': 'Aún no tienes categorías.',
    });
    return '$_temp0';
  }

  @override
  String categoriesAllArchivedOfType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'expense': 'Todas tus categorías de gasto están archivadas.',
      'income': 'Todas tus categorías de ingreso están archivadas.',
      'other': 'Todas tus categorías están archivadas.',
    });
    return '$_temp0';
  }

  @override
  String get categoriesNameLabel => 'Nombre';

  @override
  String get categoriesNameHint => 'Ej: Mascotas';

  @override
  String get categoriesNameRequired => 'Ponle un nombre a la categoría';

  @override
  String get categoriesErrorDuplicateName =>
      'Ya tienes una categoría activa con ese nombre.';

  @override
  String get categoriesErrorInvalidData =>
      'Revisa los datos: el nombre no puede estar vacío.';

  @override
  String get commonAccount => 'Cuenta';

  @override
  String get commonCategory => 'Categoría';

  @override
  String get commonAmount => 'Monto';

  @override
  String get commonDate => 'Fecha';

  @override
  String get commonAll => 'Todos';

  @override
  String get commonTransfers => 'Transferencias';

  @override
  String get commonClear => 'Limpiar';

  @override
  String get commonApply => 'Aplicar';

  @override
  String get transactionTypeIncome => 'Ingreso';

  @override
  String get transactionTypeExpense => 'Gasto';

  @override
  String get transactionTypeTransfer => 'Transferencia';

  @override
  String get transactionsTitle => 'Movimientos';

  @override
  String get transactionsNew => 'Nuevo movimiento';

  @override
  String get transactionsEdit => 'Editar movimiento';

  @override
  String get transactionsRecord => 'Registrar';

  @override
  String get transactionsRecordOne => 'Registrar movimiento';

  @override
  String get transactionsEmpty =>
      'Aún no registras movimientos.\nAnota el primero.';

  @override
  String get transactionsNoMatches => 'No hay movimientos con estos filtros.';

  @override
  String get transactionsClearFilters => 'Limpiar filtros';

  @override
  String get transactionsSearch => 'Buscar';

  @override
  String get transactionsSearchHint => 'Buscar en la descripción';

  @override
  String get transactionsSearchClose => 'Cerrar búsqueda';

  @override
  String get transactionsFilter => 'Filtrar';

  @override
  String transactionsRemoveFilter(String label) {
    return 'Quitar filtro: $label';
  }

  @override
  String get transactionsLoadMoreError =>
      'No se pudieron cargar más movimientos.';

  @override
  String get transactionsDateHelp => 'Fecha del movimiento';

  @override
  String get transactionsAmountHint => 'Ej: 150.000';

  @override
  String get transactionsFrom => 'Desde';

  @override
  String get transactionsTo => 'Hacia';

  @override
  String get transactionsNeedAnotherAccount =>
      'Necesitas otra cuenta para transferir';

  @override
  String get transactionsChooseDestination => 'Elige la cuenta de destino';

  @override
  String get transactionsNeedAccountFirst =>
      'Primero crea una cuenta para registrar movimientos.';

  @override
  String get transactionsDescriptionLabel => 'Descripción (opcional)';

  @override
  String get transactionsDescriptionHint => 'Ej: Mercado de la semana';

  @override
  String get transactionsDeleteTooltip => 'Eliminar movimiento';

  @override
  String get transactionsDeleteTitle => '¿Eliminar este movimiento?';

  @override
  String get transactionsDeleteBody =>
      'El saldo de tus cuentas se recalculará sin este movimiento.';

  @override
  String transactionsDeleteBodyWithWarning(String warnings) {
    return 'El saldo de tus cuentas se recalculará sin este movimiento.\n\nAtención:\n$warnings';
  }

  @override
  String get transactionsDeleted => 'Movimiento eliminado';

  @override
  String negativeBalanceMessage(String account, String balance) {
    return '$account quedará en $balance.';
  }

  @override
  String get negativeBalanceAdvice =>
      'Si el monto es correcto, puedes continuar.';

  @override
  String get negativeBalanceFix => 'Corregir';

  @override
  String get negativeBalanceRecordTitle => '¿Registrar de todos modos?';

  @override
  String get negativeBalanceSaveTitle => '¿Guardar de todos modos?';

  @override
  String get negativeBalanceRecordAnyway => 'Registrar igual';

  @override
  String get negativeBalanceSaveAnyway => 'Guardar igual';

  @override
  String get transactionsFilterTitle => 'Filtrar movimientos';

  @override
  String get transactionsFilterAllAccounts => 'Todas las cuentas';

  @override
  String get transactionsFilterAllCategories => 'Todas las categorías';

  @override
  String get transactionsFilterDates => 'Fechas';

  @override
  String get transactionsFilterRemoveDates => 'Quitar las fechas';

  @override
  String get transactionsFilterAnyDate => 'Cualquier fecha';

  @override
  String get transactionsFilterRangeHelp => 'Rango de fechas';

  @override
  String transactionsRangeBetween(String from, String to) {
    return 'del $from al $to';
  }

  @override
  String transactionsRangeSince(String from) {
    return 'desde el $from';
  }

  @override
  String transactionsRangeUntil(String to) {
    return 'hasta el $to';
  }

  @override
  String get transactionsAmountRequired => 'Ingresa el monto';

  @override
  String get transactionsAmountNegative => 'El monto no puede ser negativo';

  @override
  String get transactionsAmountZero => 'El monto debe ser mayor que cero';

  @override
  String get transactionsErrorInvalid =>
      'Revisa los datos del movimiento: el monto, las cuentas y la categoría.';

  @override
  String get transactionsErrorMissingReference =>
      'La cuenta o la categoría ya no existe. Vuelve a abrir el formulario.';

  @override
  String get commonBack => 'Volver';

  @override
  String get debtsTitle => 'Deudas';

  @override
  String get debtsTabOwe => 'Debo';

  @override
  String get debtsTabOwed => 'Me deben';

  @override
  String get debtsNew => 'Nueva deuda';

  @override
  String get debtsEdit => 'Editar deuda';

  @override
  String get debtsRegister => 'Registrar deuda';

  @override
  String get debtsEmptyPayable => 'Aún no registras deudas que debas.';

  @override
  String get debtsEmptyReceivable => 'Aún no registras deudas que te deban.';

  @override
  String get debtsAllArchived =>
      'Todas tus deudas de esta lista están archivadas.';

  @override
  String get debtsTotalPayable => 'Debes en total';

  @override
  String get debtsTotalReceivable => 'Te deben en total';

  @override
  String debtsOfAmount(String amount) {
    return 'de $amount';
  }

  @override
  String get debtStatusSettled => 'Saldada';

  @override
  String get debtStatusNoDueDate => 'Sin fecha de vencimiento';

  @override
  String debtStatusOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Vencida hace $days días',
      one: 'Vencida hace $days día',
    );
    return '$_temp0';
  }

  @override
  String get debtStatusDueToday => 'Vence hoy';

  @override
  String get debtStatusDueTomorrow => 'Vence mañana';

  @override
  String debtStatusDueInDays(int days) {
    return 'Vence en $days días';
  }

  @override
  String debtStatusDueOn(String date) {
    return 'Vence el $date';
  }

  @override
  String get debtsPickStartHelp => 'Fecha de inicio';

  @override
  String get debtsPickDueHelp => 'Fecha de vencimiento';

  @override
  String get debtsCounterpartyPayable => 'A quién le debes';

  @override
  String get debtsCounterpartyReceivable => 'Quién te debe';

  @override
  String get debtsCounterpartyHint => 'Ej: Juan';

  @override
  String get debtsAmountLabel => 'Monto total';

  @override
  String get debtsAmountHint => 'Ej: 500.000';

  @override
  String get debtsStartLabel => 'Inicio';

  @override
  String get debtsDueLabel => 'Vencimiento (opcional)';

  @override
  String get debtsNoDate => 'Sin fecha';

  @override
  String get debtsRemoveDue => 'Quitar la fecha de vencimiento';

  @override
  String get debtsNotesLabel => 'Notas (opcional)';

  @override
  String get debtsRegisterMoney => 'Registrar el dinero en una cuenta';

  @override
  String get debtsRegisterMoneyNeedAccount => 'Primero crea una cuenta.';

  @override
  String get debtsRegisterMoneyPayable =>
      'El dinero que te prestaron entra a la cuenta.';

  @override
  String get debtsRegisterMoneyReceivable =>
      'El dinero que prestaste sale de la cuenta.';

  @override
  String get debtsReceiveIn => 'Recibir en';

  @override
  String get debtsTakeFrom => 'Sacar de';

  @override
  String get debtsCreate => 'Crear deuda';

  @override
  String get debtsLockedNote =>
      'El sentido y el inicio no se pueden cambiar. El monto no puede ser menor a lo ya pagado.';

  @override
  String get debtsCounterpartyRequired => 'Escribe el nombre de la persona';

  @override
  String get debtsDueBeforeStart =>
      'El vencimiento no puede ser anterior al inicio';

  @override
  String debtsPaymentExceeds(String remaining) {
    return 'No puede superar lo pendiente ($remaining)';
  }

  @override
  String debtsAmountBelowPaid(String paid) {
    return 'No puede ser menor a lo ya pagado ($paid)';
  }

  @override
  String get debtsArchivedMessage => 'Deuda archivada';

  @override
  String get debtsRestoredMessage => 'Deuda restaurada';

  @override
  String get debtsGone => 'Esta deuda ya no existe.';

  @override
  String get debtsRecordPayment => 'Registrar abono';

  @override
  String get debtsIsSettledNote => 'Esta deuda ya está saldada.';

  @override
  String get debtsIsArchivedNote =>
      'Está archivada: restáurala para registrar abonos.';

  @override
  String get debtsPaymentsTitle => 'Abonos';

  @override
  String debtsYouOweTo(String name) {
    return 'Le debes a $name';
  }

  @override
  String debtsOwesYou(String name) {
    return '$name te debe';
  }

  @override
  String get debtsRemainingWord => 'pendiente';

  @override
  String debtsPaidAmount(String amount) {
    return 'Pagado $amount';
  }

  @override
  String debtsTotalAmount(String amount) {
    return 'Total $amount';
  }

  @override
  String debtsSince(String date) {
    return 'Desde el $date';
  }

  @override
  String get debtsPaymentDeleteTitle => '¿Eliminar este abono?';

  @override
  String get debtsPaymentDeleteBody =>
      'Se elimina también su movimiento y el saldo de la cuenta se recalcula.';

  @override
  String get debtsPaymentDeleted => 'Abono eliminado';

  @override
  String get debtsPaymentsEmpty => 'Aún no hay abonos.';

  @override
  String get debtsPaymentDeleteTooltip => 'Eliminar abono';

  @override
  String debtsPaySheetTitlePayable(String name) {
    return 'Abonar a $name';
  }

  @override
  String debtsPaymentDescriptionPayable(String name) {
    return 'Abono a $name';
  }

  @override
  String debtsPaymentDescriptionReceivable(String name) {
    return 'Abono de $name';
  }

  @override
  String debtsPendingAmount(String amount) {
    return 'Pendiente: $amount';
  }

  @override
  String get debtsPaymentAmountLabel => 'Monto del abono';

  @override
  String get debtsPaymentAmountHint => 'Ej: 100.000';

  @override
  String get debtsPayAll => 'Pagar todo';

  @override
  String get debtsCollectAll => 'Cobrar todo';

  @override
  String debtsNeedCurrencyAccount(String currency) {
    return 'Primero crea una cuenta en $currency para registrar el abono.';
  }

  @override
  String get debtsPayFrom => 'Pagar desde';

  @override
  String get debtsPaymentDateHelp => 'Fecha del abono';

  @override
  String get debtsErrorInvalid =>
      'Revisa los datos de la deuda: el monto y las fechas.';

  @override
  String get debtsErrorMissingReference =>
      'La cuenta o la deuda ya no existe. Vuelve a abrir la pantalla.';

  @override
  String commonPercent(int percent) {
    return '$percent %';
  }

  @override
  String get commonPercentUnderOne => '<1 %';

  @override
  String get summaryTitle => 'Resumen mensual';

  @override
  String get summaryNoData =>
      'Aún no hay movimientos para resumir.\nRegistra ingresos y gastos para ver tu resumen.';

  @override
  String get summaryPreviousMonth => 'Mes anterior';

  @override
  String get summaryNextMonth => 'Mes siguiente';

  @override
  String get summaryBalanceOfMonth => 'Balance del mes';

  @override
  String get summaryBalanceUp => 'Ingresaste más de lo que gastaste';

  @override
  String get summaryBalanceDown => 'Gastaste más de lo que ingresaste';

  @override
  String get summaryBalanceEven => 'Ingresos y gastos iguales';

  @override
  String get summaryWhereMoneyGoes => '¿En qué se va el dinero?';

  @override
  String get summaryWhereMoneyComes => '¿De dónde viene?';

  @override
  String get summaryNoExpensesMonth => 'No hay gastos en este mes.';

  @override
  String get summaryNoIncomeMonth => 'No hay ingresos en este mes.';

  @override
  String get summaryOtherCategories => 'Otras';

  @override
  String get summaryBudgetsLink => 'Cuánto llevas gastado de lo que planeaste';

  @override
  String get summaryHistoryError =>
      'No se pudo cargar la evolución del dinero.';

  @override
  String get summaryLoadError =>
      'No se pudo cargar el resumen. Revisa tu conexión e intenta de nuevo.';

  @override
  String summarySameAs(String month) {
    return 'Igual que en $month';
  }

  @override
  String summaryZeroIn(String month) {
    return '\$0 en $month';
  }

  @override
  String summaryNoExpensesIn(String month) {
    return 'Sin gastos en $month';
  }

  @override
  String summaryNoIncomeIn(String month) {
    return 'Sin ingresos en $month';
  }

  @override
  String summaryMoreThan(String amount, String month) {
    return '$amount más que en $month';
  }

  @override
  String summaryLessThan(String amount, String month) {
    return '$amount menos que en $month';
  }

  @override
  String get summaryPaceTitle => 'Ritmo de gasto';

  @override
  String get summaryDailyAverage => 'Promedio por día';

  @override
  String get summaryProjectedClose => 'A este ritmo, el mes cerrará en';

  @override
  String summaryProjection(String comparison) {
    return 'Proyección: $comparison';
  }

  @override
  String summaryCalculatedPartial(int counted, int total) {
    return 'Calculado sobre $counted de $total días del mes.';
  }

  @override
  String summaryCalculatedFull(int total) {
    return 'Calculado sobre los $total días del mes.';
  }

  @override
  String get summaryTrendTitle => 'Ingresos vs. gastos';

  @override
  String summaryLastMonths(int count) {
    return 'Últimos $count meses';
  }

  @override
  String summaryTrendSemantics(int count) {
    return 'Gráfico de barras con los ingresos y los gastos de los últimos $count meses. La misma información está disponible como tabla.';
  }

  @override
  String summaryTrendTooltip(String month, String series, String amount) {
    return '$month\n$series: $amount';
  }

  @override
  String get summaryHideTable => 'Ocultar tabla';

  @override
  String get summaryShowTable => 'Ver como tabla';

  @override
  String get summaryTableMonth => 'Mes';

  @override
  String get summaryHistorySubtitle => 'Al cierre de cada mes';

  @override
  String summaryHistorySemantics(int count) {
    return 'Gráfico de línea con el dinero total al cierre de cada uno de los últimos $count meses. La misma información está disponible como tabla.';
  }

  @override
  String get summaryHistoryHideTable => 'Ocultar tabla de saldos';

  @override
  String get summaryHistoryShowTable => 'Ver saldos como tabla';

  @override
  String get summaryHistoryTableClosing => 'Cierre de';

  @override
  String get summarySincePrevious => 'el mes anterior';

  @override
  String summarySinceMonths(int months) {
    return 'hace $months meses';
  }

  @override
  String summaryDeltaUp(String amount, String since) {
    return '$amount más que $since';
  }

  @override
  String summaryDeltaDown(String amount, String since) {
    return '$amount menos que $since';
  }

  @override
  String summaryDeltaSame(String since) {
    return 'Igual que $since';
  }

  @override
  String get budgetsNew => 'Nuevo presupuesto';

  @override
  String get budgetsEmptyEditable =>
      'Define cuánto quieres gastar al mes en cada categoría y ve cómo vas.';

  @override
  String get budgetsEmptyPast => 'No había presupuestos ni gastos en este mes.';

  @override
  String get budgetsDefine => 'Definir un presupuesto';

  @override
  String get budgetsGoToCurrentMonth => 'Ir al mes actual';

  @override
  String get budgetsWithBudget => 'Con presupuesto';

  @override
  String get budgetsWithoutBudget => 'Gastos sin presupuesto';

  @override
  String get budgetsTapToDefine => 'Toca para definir un presupuesto';

  @override
  String get budgetsTotalTitle => 'Presupuesto total';

  @override
  String budgetsTotalOf(String amount) {
    return 'de $amount presupuestados';
  }

  @override
  String budgetsFormTitleFixed(String name) {
    return 'Presupuesto de $name';
  }

  @override
  String get budgetsFormTheCategory => 'la categoría';

  @override
  String budgetsFormAppliesFrom(String month, int year) {
    return 'Rige desde $month de $year en adelante, hasta que lo cambies. Los meses anteriores no se tocan.';
  }

  @override
  String get budgetsFormAllBudgeted =>
      'Todas tus categorías de gasto ya tienen presupuesto.';

  @override
  String get budgetsFormChooseCategory => 'Elige una categoría';

  @override
  String get budgetsFormCategoryLabel => 'Categoría de gasto';

  @override
  String get budgetsFormAmountLabel => 'Monto mensual';

  @override
  String get budgetsFormAmountHint => 'Ej: 800.000';

  @override
  String get budgetsFormRemove => 'Quitar el presupuesto';

  @override
  String get budgetsErrorInvalid => 'Revisa el monto del presupuesto.';

  @override
  String get budgetsErrorMissingCategory =>
      'La categoría ya no existe. Vuelve a abrir la pantalla.';

  @override
  String budgetsPercent(int percent) {
    return '$percent %';
  }

  @override
  String get dbErrorTransactionCategoryMismatch =>
      'La categoría elegida no corresponde a este tipo de movimiento';

  @override
  String get dbErrorTransferCurrencyMismatch =>
      'Una transferencia requiere cuentas de la misma moneda';

  @override
  String get dbErrorBudgetExpenseOnly =>
      'Solo las categorías de gasto pueden tener presupuesto';

  @override
  String get dbErrorPaymentDirectionMismatch =>
      'El abono no corresponde al tipo de deuda';

  @override
  String get dbErrorPaymentCurrencyMismatch =>
      'El abono debe ser de una cuenta en la moneda de la deuda';

  @override
  String get dbErrorPaymentExceedsRemaining =>
      'El abono supera lo que falta por pagar';

  @override
  String get dbErrorDebtAmountBelowPaid =>
      'El monto no puede ser menor a lo que ya se ha pagado';

  @override
  String get dbErrorDebtDirectionLocked =>
      'No se puede cambiar el sentido de una deuda que ya tiene abonos';

  @override
  String get dbErrorPaymentTypeLocked =>
      'Este movimiento es el abono de una deuda: no se puede cambiar su tipo';

  @override
  String get dbErrorDebtArchived =>
      'La deuda está archivada: restáurala para registrar abonos';

  @override
  String debtsLoanDescriptionPayable(String name) {
    return 'Préstamo de $name';
  }

  @override
  String debtsLoanDescriptionReceivable(String name) {
    return 'Préstamo a $name';
  }

  @override
  String get currencyNameCop => 'Peso colombiano';

  @override
  String get currencyNameUsd => 'Dólar estadounidense';

  @override
  String get currencyNameEur => 'Euro';

  @override
  String get currencyNameMxn => 'Peso mexicano';

  @override
  String get currencyNameArs => 'Peso argentino';

  @override
  String get currencyNameBrl => 'Real brasileño';

  @override
  String get currencyNameClp => 'Peso chileno';

  @override
  String get currencyNamePen => 'Sol peruano';

  @override
  String get currencyNameGbp => 'Libra esterlina';

  @override
  String get currencyNameCad => 'Dólar canadiense';

  @override
  String get currencyLabel => 'Moneda';

  @override
  String currencyOption(String code, String name) {
    return '$code · $name';
  }

  @override
  String currencyMissingRates(String currencies) {
    return 'Sin tasa de cambio para $currencies: no se incluye en el total.';
  }

  @override
  String get currencyMissingRatesAction => 'Definir';

  @override
  String get settingsCurrency => 'Moneda';

  @override
  String get settingsBaseCurrency => 'Moneda base';

  @override
  String settingsBaseCurrencyValue(String code, String name) {
    return '$code · $name';
  }

  @override
  String get settingsExchangeRates => 'Tasas de cambio';

  @override
  String get settingsExchangeRatesHelp =>
      'Cuánto vale cada moneda en tu moneda base';

  @override
  String get baseCurrencyTitle => 'Moneda base';

  @override
  String get baseCurrencyIntro =>
      'Todo tu dinero, tus resúmenes y tus presupuestos se muestran en esta moneda.';

  @override
  String baseCurrencyRateLabel(String next, String previous) {
    return '1 $next vale ($previous)';
  }

  @override
  String baseCurrencyRateHelp(String next) {
    return 'Hace falta para pasar tus tasas y presupuestos a $next.';
  }

  @override
  String get baseCurrencyChangeButton => 'Cambiar moneda base';

  @override
  String get ratesTitle => 'Tasas de cambio';

  @override
  String ratesIntro(String base) {
    return 'Para sumar el dinero de tus cuentas en otras monedas, define cuánto vale cada una en $base. Los totales usan la tasa de hoy.';
  }

  @override
  String get ratesEmpty =>
      'No tienes cuentas ni deudas en otras monedas.\nCuando las tengas, define aquí sus tasas.';

  @override
  String get ratesNoRate => 'Sin tasa';

  @override
  String ratesOneEquals(String currency, String amount) {
    return '1 $currency = $amount';
  }

  @override
  String get ratesUpdatedToday => 'Actualizada hoy';

  @override
  String get ratesUpdatedYesterday => 'Actualizada ayer';

  @override
  String ratesUpdatedDaysAgo(int days) {
    return 'Actualizada hace $days días';
  }

  @override
  String get ratesAdd => 'Agregar tasa';

  @override
  String ratesFormTitle(String currency) {
    return 'Tasa de $currency';
  }

  @override
  String ratesFormAmountLabel(String currency) {
    return '1 $currency vale';
  }

  @override
  String get ratesFormHint => 'Ej: 4.000';

  @override
  String get ratesFormInvalid =>
      'Escribe una tasa mayor que cero. Ejemplo: 4.012,5';

  @override
  String get ratesFormRemove => 'Quitar la tasa';

  @override
  String get ratesFormChooseCurrency => 'Elige una moneda';

  @override
  String get ratesErrorInvalid =>
      'Revisa la tasa: tiene que ser mayor que cero.';

  @override
  String get accountsCurrencyLocked =>
      'La moneda de una cuenta no se puede cambiar.';

  @override
  String accountsRateLabel(String currency) {
    return '1 $currency vale (opcional)';
  }

  @override
  String get accountsRateHelp =>
      'Sin tasa, esta cuenta no suma al dinero total.';

  @override
  String transactionsAmountOut(String currency) {
    return 'Monto que sale ($currency)';
  }

  @override
  String transactionsAmountIn(String currency) {
    return 'Monto que llega ($currency)';
  }

  @override
  String transactionsImpliedRate(String from, String rate, String to) {
    return '1 $from = $rate $to';
  }

  @override
  String transactionsReceives(String amount) {
    return 'recibe $amount';
  }

  @override
  String summaryConvertedNote(String base) {
    return 'Los montos en otras monedas se pasan a $base con la tasa de hoy.';
  }

  @override
  String get dbErrorRateForBaseCurrency =>
      'La moneda base no necesita tasa de cambio';

  @override
  String get dbErrorBaseRateRequired =>
      'Hace falta la tasa de la moneda nueva para convertir tus tasas y presupuestos';

  @override
  String get dbErrorTransferDestinationRequired =>
      'Una transferencia entre monedas distintas necesita el monto que llega';

  @override
  String get dbErrorTransferDestinationUnexpected =>
      'El monto que llega solo se indica en transferencias entre monedas distintas';

  @override
  String get recurringTitle => 'Pagos recurrentes';

  @override
  String get recurringNew => 'Nuevo pago recurrente';

  @override
  String get recurringEdit => 'Editar pago recurrente';

  @override
  String get recurringCreateButton => 'Crear pago recurrente';

  @override
  String get recurringEmpty =>
      'Aún no registras pagos recurrentes.\nAnota tus suscripciones, el arriendo y lo que pagas cada cierto tiempo.';

  @override
  String get recurringEmptyAction => 'Registrar pago recurrente';

  @override
  String get recurringDashboardEmpty =>
      'Registra tus suscripciones y el arriendo';

  @override
  String get recurringNothingSoon => 'No tienes pagos próximos.';

  @override
  String recurringNextOne(String name, String date) {
    return 'Siguiente: $name · $date';
  }

  @override
  String get recurringSectionActive => 'Activos';

  @override
  String get recurringSectionOther => 'En pausa o terminados';

  @override
  String recurringStatusOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Vencido hace $days días',
      one: 'Vencido hace $days día',
    );
    return '$_temp0';
  }

  @override
  String get recurringStatusToday => 'Pago próximo: vence hoy';

  @override
  String get recurringStatusTomorrow => 'Pago próximo: vence mañana';

  @override
  String recurringStatusSoon(int days) {
    return 'Pago próximo: vence en $days días';
  }

  @override
  String recurringStatusLater(String date) {
    return 'Próximo pago el $date';
  }

  @override
  String get recurringStatusPaused => 'En pausa';

  @override
  String get recurringStatusFinished => 'Terminado';

  @override
  String recurrenceEveryWeek(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Cada $n semanas',
      one: 'Cada semana',
    );
    return '$_temp0';
  }

  @override
  String recurrenceEveryMonth(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Cada $n meses',
      one: 'Cada mes',
    );
    return '$_temp0';
  }

  @override
  String recurrenceEveryYear(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Cada $n años',
      one: 'Cada año',
    );
    return '$_temp0';
  }

  @override
  String get recurringNameLabel => 'Nombre';

  @override
  String get recurringNameHint => 'Ej: Netflix, Arriendo';

  @override
  String get recurringNameRequired => 'Ponle un nombre al pago';

  @override
  String get recurringAccountLabel => 'Se paga desde';

  @override
  String get recurringFrequencyLabel => 'Frecuencia';

  @override
  String get recurringNextLabel => 'Próximo pago';

  @override
  String get recurringNextHelp =>
      'La fecha en que toca pagarlo. Después se calcula sola.';

  @override
  String get recurringEndLabel => 'Termina (opcional)';

  @override
  String get recurringNoEnd => 'Sin fecha final';

  @override
  String get recurringRemoveEnd => 'Quitar la fecha final';

  @override
  String get recurringPickNextHelp => 'Fecha del próximo pago';

  @override
  String get recurringPickEndHelp => 'Fecha final';

  @override
  String get recurringEndBeforeNext =>
      'La fecha final no puede ser anterior al próximo pago';

  @override
  String get recurringReminderNote =>
      'No se descuenta nada hasta que confirmes que pagaste.';

  @override
  String get recurringPayAction => 'Ya pagué';

  @override
  String get recurringSkipAction => 'Omitir este pago';

  @override
  String get recurringPause => 'Pausar';

  @override
  String get recurringResume => 'Reanudar';

  @override
  String get recurringDelete => 'Eliminar';

  @override
  String get recurringDeleteTitle => '¿Eliminar este pago recurrente?';

  @override
  String get recurringDeleteBody =>
      'Los pagos que ya registraste se conservan.';

  @override
  String get recurringPausedMessage => 'Pago pausado';

  @override
  String get recurringResumedMessage => 'Pago reanudado';

  @override
  String get recurringDeletedMessage => 'Pago recurrente eliminado';

  @override
  String get recurringGone => 'Este pago recurrente ya no existe.';

  @override
  String get recurringHistoryTitle => 'Pagos registrados';

  @override
  String get recurringHistoryEmpty => 'Aún no has registrado ningún pago.';

  @override
  String recurringEndsOn(String date) {
    return 'Termina el $date';
  }

  @override
  String recurringConfirmTitle(String name) {
    return 'Pago de $name';
  }

  @override
  String get recurringConfirmButton => 'Confirmar pago';

  @override
  String get recurringConfirmDateHelp => 'Fecha del pago';

  @override
  String get recurringConfirmedMessage => 'Pago registrado';

  @override
  String get recurringSkippedMessage => 'Pago omitido';

  @override
  String get recurringErrorGone =>
      'El pago recurrente ya no existe. Vuelve a abrir la pantalla.';

  @override
  String get recurringErrorInvalid =>
      'Revisa los datos del pago: el nombre, el monto y las fechas.';

  @override
  String get dbErrorRecurringFinished => 'Este pago recurrente ya terminó';

  @override
  String get dbErrorRecurringCategory =>
      'Solo las categorías de gasto sirven en un pago recurrente';

  @override
  String get debtsInstallmentsSwitch => 'Pagar en cuotas';

  @override
  String get debtsInstallmentsSwitchHelp =>
      'Te avisamos cuándo toca cada cuota y la registras como abono a la deuda.';

  @override
  String get debtsInstallmentsCount => 'Número de cuotas';

  @override
  String get debtsInstallmentsCountHint => 'Ej: 12';

  @override
  String get debtsInstallmentsCountInvalid =>
      'Escribe cuántas cuotas son (de 1 a 360)';

  @override
  String get debtsInstallmentsAmount => 'Valor de cada cuota';

  @override
  String get debtsInstallmentsAmountHelp =>
      'Normalmente, el total dividido entre las cuotas.';

  @override
  String get debtsInstallmentsFrequency => 'Cada cuánto';

  @override
  String get debtsInstallmentsFirst => 'Primera cuota';

  @override
  String get debtsInstallmentsFirstHelp => 'Fecha de la primera cuota';

  @override
  String get debtsInstallmentsPayFrom => 'Pagar las cuotas desde';

  @override
  String installmentNumber(int number, int total) {
    return 'Cuota $number de $total';
  }

  @override
  String get debtsPlanTitle => 'Plan de cuotas';

  @override
  String recurringDebtRemaining(String amount) {
    return 'Falta por pagar: $amount';
  }

  @override
  String get recurringDeletePlanBody =>
      'La deuda y los abonos que ya registraste se conservan.';

  @override
  String get dbErrorInstallmentDirection =>
      'Solo las deudas que debes pueden pagarse en cuotas';

  @override
  String get dbErrorInstallmentCurrency =>
      'La cuenta de las cuotas tiene que ser de la moneda de la deuda';

  @override
  String get goalsTitle => 'Metas de ahorro';

  @override
  String get goalsNew => 'Nueva meta';

  @override
  String get goalsEdit => 'Editar meta';

  @override
  String get goalsCreateButton => 'Crear meta';

  @override
  String get goalsEmpty =>
      'Aún no tienes metas. Una meta es una cantidad que quieres juntar en una cuenta: lo que ahorras es el saldo de esa cuenta.';

  @override
  String get goalsAllArchived => 'Todas tus metas están archivadas.';

  @override
  String get goalsDashboardEmpty =>
      'Junta plata para algo: crea una meta de ahorro.';

  @override
  String get goalsNameLabel => 'Nombre';

  @override
  String get goalsNameHint => 'Viaje, moto, fondo de emergencia';

  @override
  String get goalsNameRequired => 'Escribe el nombre de la meta';

  @override
  String get goalsTargetLabel => 'Cuánto quieres juntar';

  @override
  String get goalsTargetPositive => 'La meta tiene que ser mayor que cero';

  @override
  String get goalsAccountLabel => 'Cuenta donde ahorras';

  @override
  String get goalsAccountHelp =>
      'Lo que llevas ahorrado es el saldo de esta cuenta. Para ahorrar, pasa plata a ella.';

  @override
  String get goalsAccountLocked => 'La cuenta de una meta no se cambia.';

  @override
  String get goalsAccountRequired => 'Elige la cuenta de la meta';

  @override
  String get goalsNoFreeAccount =>
      'No tienes una cuenta libre: cada cuenta sirve para una sola meta y las tarjetas no sirven.';

  @override
  String get goalsNewAccount => 'Crear una cuenta nueva';

  @override
  String get goalsDeadlineLabel => 'Fecha límite (opcional)';

  @override
  String get goalsDeadlineNone => 'Sin fecha';

  @override
  String get goalsDeadlineClear => 'Quitar la fecha';

  @override
  String goalsSavedOf(String saved, String target) {
    return '$saved de $target';
  }

  @override
  String goalsRemaining(String amount) {
    return 'Faltan $amount';
  }

  @override
  String goalsDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'quedan $count días',
      one: 'queda $count día',
      zero: 'vence hoy',
    );
    return '$_temp0';
  }

  @override
  String get goalsStatusReached => '¡Meta cumplida!';

  @override
  String goalsStatusOverdue(String date, String amount) {
    return 'Venció el $date · faltan $amount';
  }

  @override
  String get goalsArchivedLabel => 'Archivada';

  @override
  String goalsAccountArchivedNote(String name) {
    return 'La cuenta $name está archivada: ya no puedes ahorrar en ella.';
  }

  @override
  String goalsSuggestMonthly(String amount) {
    return 'Para llegar a tiempo, ahorra $amount al mes.';
  }

  @override
  String goalsSuggestBefore(String amount, String date) {
    return 'Para llegar a tiempo, ahorra $amount antes del $date.';
  }

  @override
  String goalsDeadlineOn(String date) {
    return 'Para el $date';
  }

  @override
  String get goalsReachedHint =>
      'Cuando ya no la necesites, archívala para liberar su cuenta.';

  @override
  String get goalsSave => 'Ahorrar';

  @override
  String get goalsWithdraw => 'Sacar';

  @override
  String goalsAccountRow(String name) {
    return 'Cuenta: $name';
  }

  @override
  String get goalsHistoryTitle => 'Movimientos de la meta';

  @override
  String get goalsHistoryEmpty =>
      'Todavía no has ahorrado nada en esta cuenta.';

  @override
  String goalsMovementFrom(String account) {
    return 'Desde $account';
  }

  @override
  String goalsMovementTo(String account) {
    return 'Hacia $account';
  }

  @override
  String get goalsArchive => 'Archivar';

  @override
  String get goalsRestore => 'Restaurar';

  @override
  String get goalsArchivedMessage => 'Meta archivada';

  @override
  String get goalsRestoredMessage => 'Meta restaurada';

  @override
  String get goalsGone => 'Esta meta ya no existe.';

  @override
  String get goalsErrorInvalid => 'Revisa los datos de la meta.';

  @override
  String get goalsErrorAccountTaken => 'Esa cuenta ya tiene otra meta activa.';

  @override
  String get goalsErrorMissingAccount => 'La cuenta elegida ya no existe.';

  @override
  String get dbErrorGoalAccountCard =>
      'Una tarjeta no puede ser la cuenta de una meta de ahorro';

  @override
  String get navHome => 'Inicio';

  @override
  String get navGoals => 'Metas';

  @override
  String get navMore => 'Más';

  @override
  String get navTransactions => 'Actividad';

  @override
  String get accountsCardLimitLabel => 'Cupo (opcional)';

  @override
  String get accountsCardLimitHelper =>
      'Lo máximo que te deja gastar el banco con la tarjeta';

  @override
  String get accountsCardLimitInvalid =>
      'El cupo tiene que ser un monto mayor que cero';

  @override
  String get accountsCardStatementDayLabel => 'Día de corte (opcional)';

  @override
  String get accountsCardStatementDayHelper =>
      'El día del mes en que cierra tu extracto';

  @override
  String get accountsCardPaymentDayLabel => 'Día límite de pago (opcional)';

  @override
  String get accountsCardPaymentDayHelper =>
      'El día del mes hasta el que debes pagar';

  @override
  String get accountsCardDayInvalid => 'Escribe un día del 1 al 31';

  @override
  String get accountsCardDaysTogether =>
      'Indica los dos días, o deja los dos vacíos';

  @override
  String get accountsCardInitialBalanceHelper =>
      'Lo que ya debes, con signo menos (ej: -200.000). Vacío si empieza en cero';

  @override
  String accountsCardUsedOf(String used, String limit) {
    return 'Usado $used de $limit';
  }

  @override
  String accountsCardAvailable(String amount) {
    return 'Disponible $amount';
  }

  @override
  String accountsCardOverLimit(String amount) {
    return 'Te pasaste del cupo por $amount';
  }

  @override
  String accountsCardDates(String statement, String payment) {
    return 'Corte $statement · Pagar antes del $payment';
  }

  @override
  String dashboardCardDebt(String amount) {
    return 'Debes en tarjetas $amount';
  }

  @override
  String creditLimitMessage(String account, String amount) {
    return '$account quedaría $amount por encima de su cupo.';
  }

  @override
  String accountsCardDue(String amount) {
    return 'Por pagar del último corte: $amount';
  }

  @override
  String accountsCardOverdue(String date, String amount) {
    return 'Vencido desde el $date: $amount';
  }

  @override
  String get accountsCardPaidUp => 'Al día con el último corte';

  @override
  String get accountsCardPay => 'Pagar';

  @override
  String get dashboardCardPaymentsTitle => 'Pagos de tarjetas';

  @override
  String get dashboardCardDueToday => 'Vence hoy';

  @override
  String get dashboardCardDueTomorrow => 'Vence mañana';

  @override
  String dashboardCardDueIn(int days) {
    return 'Vence en $days días';
  }

  @override
  String dashboardCardDueOn(String when, String date) {
    return '$when · $date';
  }

  @override
  String dashboardCardOverdue(String date) {
    return 'Vencido desde el $date';
  }
}

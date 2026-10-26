import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_type.dart';

/// Cuánto cambió el saldo de [accountId] por [transaction], en centavos:
/// positivo si entró plata, negativo si salió, cero si no lo toca.
///
/// En una transferencia entre monedas distintas, a la cuenta de destino llega
/// `destinationAmount`, no lo que salió.
int accountDeltaCents(Transaction transaction, String accountId) {
  int cents(double value) => (value * 100).round();

  switch (transaction.type) {
    case TransactionType.income:
      return transaction.accountId == accountId ? cents(transaction.amount) : 0;
    case TransactionType.expense:
      return transaction.accountId == accountId
          ? -cents(transaction.amount)
          : 0;
    case TransactionType.transfer:
      var delta = 0;
      if (transaction.accountId == accountId) {
        delta -= cents(transaction.amount);
      }
      if (transaction.destinationAccountId == accountId) {
        delta += cents(transaction.destinationAmount ?? transaction.amount);
      }
      return delta;
  }
}

/// Desactiva el reintento automático de Riverpod 3: cuando algo falla, la
/// pantalla muestra el error y ofrece un botón para reintentar.
Duration? noRetry(int retryCount, Object error) => null;

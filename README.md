# QR Wallet — prototipo responsive

## Ejecutar

```bash
npm install
npm run dev
```

Abrir la URL local que muestra Vite.

## Alcance

Prototipo React de interfaz y lógica **exclusivamente local en memoria**. Incluye saldos ficticios, transferencias simuladas, historial y QR de identificación. Al recargar, se reinicia todo. **No incluye** backend, persistencia, autenticación real, escaneo de cámara, roles administrativos ni operaciones monetarias reales.

## Para producción

Implementar API autenticada, base PostgreSQL, libro mayor de doble entrada, transacciones SQL atómicas con bloqueo de filas, idempotencia, permisos y auditoría; QR con identificador opaco y validación del destinatario; HTTPS, protección antiabuso, límites y conciliación. No confiar nunca en saldos ni transferencias calculadas por el navegador.

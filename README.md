# Banco QR v2 — CLP virtual

Evolución del repositorio https://github.com/ruminot21/Banco-qr. No procesa dinero real.

## Instalación desde Android + GitHub + Vercel

1. Crea un proyecto Supabase (https://supabase.com/dashboard).
2. En Supabase SQL Editor, ejecuta `schema.sql` completo una sola vez en un proyecto NUEVO. En Authentication > Providers habilita Email; para pruebas puedes desactivar temporalmente la confirmación de email.
3. En Project Settings > API copia Project URL y la publishable key (o anon key). Nunca uses la service_role key en Vite.
4. Sube estos archivos a la raíz de tu repositorio GitHub `Banco-qr`, reemplazando los anteriores. También sube `schema.sql` y `.env.example` (sin credenciales).
5. En Vercel > Project > Settings > Environment Variables añade `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` con los valores del paso 3. Luego Redeploy. Framework Vite, build `npm run build`, output `dist`.
6. En Supabase > Authentication > URL Configuration configura Site URL a tu dominio de Vercel y añade el dominio a Redirect URLs.
7. Registra dos cuentas diferentes en dos teléfonos. En SQL Editor, localiza el UUID de la cuenta administradora en Authentication > Users y ejecuta `update public.profiles set role='admin' where id='UUID_REAL';`.
8. Entra como admin, copia el UUID del usuario desde su pantalla admin (o consulta `select id,display_name from public.profiles;` en SQL Editor), acredita CLP virtual y prueba enviar/recibir.

## Notas de seguridad

- QR identifica una cuenta; no autoriza pagos. La cámara requiere HTTPS y permiso del usuario.
- La RPC valida identidad, saldo, monto, receptor, unicidad e idempotencia bajo bloqueo transaccional. Las políticas RLS impiden leer saldos ajenos y las escrituras directas no están habilitadas.
- Admin solo se habilita manualmente en SQL; los ajustes tienen registro de auditoría.
- Las operaciones no tienen valor monetario. Para operar con fondos reales se necesita diseño regulatorio, KYC, antifraude, auditoría y conciliación.
- La versión es MVP de prueba, no apta para producción financiera. Se recomienda revisar límites, gestión de abuso, UX de errores, reversos y seguridad antes de abrirla al público.

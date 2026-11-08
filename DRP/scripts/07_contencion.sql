-- =====================================================================
-- DRP BANCO | SCRIPT 07: CONTENCION
-- Usuario:  root
-- Objetivo: bloquear las escrituras de la aplicacion
-- root conserva escritura porque tiene privilegio SUPER.
-- =====================================================================

-- 1. Base de datos en solo lectura para usuarios de aplicacion
SET GLOBAL read_only = ON;
SHOW VARIABLES LIKE 'read_only';

-- 2. Sesiones abiertas del usuario de aplicacion
SELECT id, user, host, db, command, time
  FROM information_schema.PROCESSLIST
 WHERE user = 'app_banco';

-- 3. Generar las sentencias KILL (copiar y ejecutar el resultado)
SELECT CONCAT('KILL ', id, ';') AS ejecutar
  FROM information_schema.PROCESSLIST
 WHERE user = 'app_banco';

-- 4. PRUEBA (en la sesion de app_banco): este UPDATE ahora debe fallar con
--    ERROR 1290: The MySQL server is running with the --read-only option
-- UPDATE banco_db.cuentas SET saldo = 1 WHERE id_cuenta = 1;

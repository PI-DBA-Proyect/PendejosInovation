-- =====================================================================
-- DRP BANCO | SCRIPT 12: REAPERTURA DEL SERVICIO Y CIERRE DEL INCIDENTE
-- Usuario:  root
-- Objetivo: reabrir el servicio y cerrar el incidente
-- =====================================================================
SET SQL_SAFE_UPDATES = 0;

-- 1. Reabrir escrituras para la aplicacion
SET GLOBAL read_only = OFF;
SHOW VARIABLES LIKE 'read_only';

-- 2. Medida preventiva: modo seguro por defecto para nuevas sesiones.
--    SET PERSIST: se mantiene tras reiniciar el servicio.
SET PERSIST sql_safe_updates = ON;

-- 3. Cerrar el incidente
UPDATE drp_monitor.bitacora_incidentes
   SET estatus = 'RESUELTO',
       fecha_resolucion = NOW(),
       descripcion = CONCAT(descripcion, ' | Resuelto con DRP: contencion, recuperacion y validacion OK')
 WHERE estatus IN ('ABIERTO','EN_ATENCION');

-- 4. Reporte final
SELECT id_incidente, tipo_incidente, severidad,
       fecha_deteccion, fecha_resolucion,
       TIMESTAMPDIFF(MINUTE, fecha_deteccion, fecha_resolucion) AS minutos_hasta_resolver
  FROM drp_monitor.bitacora_incidentes
 ORDER BY id_incidente;

-- 5. Prueba de que la app opera normal (como app_banco):
-- UPDATE banco_db.cuentas SET saldo = saldo + 1 WHERE id_cuenta = 1;

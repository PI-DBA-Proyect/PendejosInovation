-- =====================================================================
-- DRP BANCO | SCRIPT 10: RECUPERACION RAPIDA DESDE AUDITORIA (PLAN B)
-- Usuario:  root
-- Objetivo: devolver a cada cuenta el saldo previo al UPDATE danino
-- =====================================================================
SET SQL_SAFE_UPDATES = 0;
-- Estos cambios se auditan como RESTAURACION. Si el script se interrumpe,
-- cerrar la sesion: la variable seguiria en 1 y marcaria cambios ajenos.
SET @drp_restauracion = 1;

-- 1. Identificar la sentencia danina (la rafaga mas grande)
SELECT fecha INTO @fecha_error
  FROM drp_monitor.auditoria_saldos
 WHERE origen = 'OPERACION'
 GROUP BY fecha
 ORDER BY COUNT(*) DESC
 LIMIT 1;
SELECT @fecha_error AS momento_del_error;

-- 2. Restaurar saldos (solo cuentas que no se movieron despues del error)
START TRANSACTION;
UPDATE banco_db.cuentas c
  JOIN drp_monitor.auditoria_saldos a
    ON a.id_cuenta = c.id_cuenta
   AND a.fecha     = @fecha_error
   AND a.origen    = 'OPERACION'
   SET c.saldo = a.saldo_anterior
 WHERE c.saldo = a.saldo_nuevo;
SELECT ROW_COUNT() AS cuentas_restauradas;
COMMIT;

SET @drp_restauracion = NULL;

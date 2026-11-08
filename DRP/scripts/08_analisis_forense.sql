-- =====================================================================
-- DRP BANCO | SCRIPT 08: ANALISIS FORENSE
-- Usuario:  root
-- Objetivo: identificar usuario, momento, sentencia, monto y posicion en el binlog
-- =====================================================================

-- 1. La sentencia danina: la rafaga mas grande registrada en auditoria
SELECT usuario,
       fecha                AS momento_del_error,
       COUNT(*)             AS cuentas_afectadas,
       SUM(saldo_anterior)  AS monto_desaparecido,
       SUM(saldo_nuevo)     AS monto_resultante
  FROM drp_monitor.auditoria_saldos
 WHERE origen = 'OPERACION'
 GROUP BY usuario, fecha
 ORDER BY cuentas_afectadas DESC
 LIMIT 1;

-- 2. Tiempo de deteccion (MTTD) en segundos
SELECT TIMESTAMPDIFF(SECOND,
         (SELECT fecha FROM drp_monitor.auditoria_saldos
           WHERE origen = 'OPERACION'
           GROUP BY fecha ORDER BY COUNT(*) DESC LIMIT 1),
         (SELECT MIN(fecha_deteccion) FROM drp_monitor.bitacora_incidentes
           WHERE estatus = 'EN_ATENCION')) AS segundos_en_detectar;

-- 3. Binlogs disponibles (el ultimo es el que se esta escribiendo)
SHOW BINARY LOGS;
SHOW MASTER STATUS;     -- En MySQL 8.4+: SHOW BINARY LOG STATUS;

-- 4. Eventos del binlog creado por el respaldo (plantilla: descomentar y editar).
--    Reemplazar NOMBRE-bin.0000XX y POSICION por el archivo y SOURCE_LOG_POS
--    anotados en el script 02.
--    Buscar el evento Rows_query que dice "UPDATE cuentas SET saldo = 0".
--    Unas filas ARRIBA esta el evento Anonymous_Gtid de esa transaccion:
--    su columna Pos es la STOP POSITION para la recuperacion.
--    LIMIT: el UPDATE genera miles de eventos Update_rows; si no aparece,
--    aumentar el LIMIT o avanzar FROM a la ultima Pos mostrada.
-- SHOW BINLOG EVENTS IN 'NOMBRE-bin.0000XX' FROM POSICION LIMIT 50;

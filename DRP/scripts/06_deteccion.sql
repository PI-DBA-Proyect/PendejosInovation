-- =====================================================================
-- DRP BANCO | SCRIPT 06: DETECCION DEL INCIDENTE
-- Usuario:  root
-- Objetivo: revisar las alertas y declarar la contingencia
-- =====================================================================
SET SQL_SAFE_UPDATES = 0;

-- 1. Alertas generadas automaticamente por el evento monitor
SELECT id_incidente, fecha_deteccion, tipo_incidente, severidad,
       valor_esperado, valor_detectado, estatus
  FROM drp_monitor.bitacora_incidentes
 WHERE estatus <> 'RESUELTO'
 ORDER BY id_incidente;

-- 2. Evidencia rapida: rafagas de cambios agrupadas por sentencia
SELECT usuario, fecha, origen, COUNT(*) AS cuentas_modificadas
  FROM drp_monitor.auditoria_saldos
 GROUP BY usuario, fecha, origen
 ORDER BY fecha DESC
 LIMIT 10;

-- 3. Declarar la contingencia: el incidente pasa a EN_ATENCION
UPDATE drp_monitor.bitacora_incidentes
   SET estatus = 'EN_ATENCION'
 WHERE estatus = 'ABIERTO';

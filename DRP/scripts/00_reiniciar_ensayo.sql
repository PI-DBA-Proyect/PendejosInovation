-- =====================================================================
-- DRP BANCO | SCRIPT 00: REINICIAR PARA UN NUEVO ENSAYO
-- Usuario:  root
-- Objetivo: limpiar la bitacora, la auditoria y la linea base
-- =====================================================================
SET GLOBAL read_only = OFF;
RESET PERSIST IF EXISTS sql_safe_updates;   -- Revierte la medida preventiva del script 12
SET GLOBAL sql_safe_updates = OFF;
TRUNCATE TABLE drp_monitor.bitacora_incidentes;
TRUNCATE TABLE drp_monitor.auditoria_saldos;
TRUNCATE TABLE drp_monitor.linea_base_cuentas;
SHOW VARIABLES LIKE 'event_scheduler';      -- Debe ser ON

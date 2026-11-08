-- =====================================================================
-- DRP BANCO | SCRIPT 03: ESTADO NORMAL + LINEA BASE
-- Usuario:  root
-- Objetivo: mostrar la operacion normal y capturar la linea base
-- =====================================================================

-- 1. Asi ve la aplicacion a los clientes
SELECT cl.nombre AS cliente, cu.numero_cuenta, cu.tipo_cuenta, cu.saldo
  FROM banco_db.cuentas cu
  JOIN banco_db.clientes cl ON cl.id_cliente = cu.id_cliente
 ORDER BY cu.id_cuenta
 LIMIT 10;

-- 2. Indicadores generales
SELECT COUNT(*)                   AS total_cuentas,
       COUNT(DISTINCT id_cliente) AS clientes_con_cuenta,
       SUM(saldo)                 AS suma_saldos,
       SUM(saldo = 0)             AS cuentas_saldo_cero
  FROM banco_db.cuentas;

SELECT COUNT(*) AS tarjetas_ligadas_a_cuentas FROM banco_db.tarjetas;

-- 3. Captura de la linea base del dia
INSERT INTO drp_monitor.linea_base_cuentas (total_cuentas, suma_saldos, cuentas_saldo_cero)
SELECT COUNT(*), SUM(saldo), SUM(saldo = 0) FROM banco_db.cuentas;

SELECT * FROM drp_monitor.linea_base_cuentas ORDER BY id_captura DESC LIMIT 1;

-- 4. Monitores activos y sin incidentes abiertos
SHOW VARIABLES LIKE 'event_scheduler';
SHOW EVENTS FROM drp_monitor;
SELECT COUNT(*) AS incidentes_abiertos
  FROM drp_monitor.bitacora_incidentes
 WHERE estatus <> 'RESUELTO';

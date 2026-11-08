-- =====================================================================
-- DRP BANCO | SCRIPT 11: VALIDACION POST-RECUPERACION
-- Usuario:  root
-- Objetivo: confirmar la recuperacion completa de los datos
-- =====================================================================

-- 1. Cuentas afectadas que NO recuperaron su saldo  -> debe ser 0
SELECT fecha INTO @fecha_error
  FROM drp_monitor.auditoria_saldos
 WHERE origen = 'OPERACION'
 GROUP BY fecha ORDER BY COUNT(*) DESC LIMIT 1;

SELECT COUNT(*) AS cuentas_sin_recuperar
  FROM drp_monitor.auditoria_saldos a
  JOIN banco_db.cuentas c ON c.id_cuenta = a.id_cuenta
 WHERE a.fecha  = @fecha_error
   AND a.origen = 'OPERACION'
   AND c.saldo <> a.saldo_anterior;

-- 2. Comparativo contra la linea base
--    diferencia debe ser igual al deposito legitimo del script 04 (15,000.00)
SELECT lb.total_cuentas                           AS cuentas_linea_base,
       (SELECT COUNT(*) FROM banco_db.cuentas)    AS cuentas_actuales,
       lb.suma_saldos                             AS suma_linea_base,
       (SELECT SUM(saldo) FROM banco_db.cuentas)  AS suma_actual,
       (SELECT SUM(saldo) FROM banco_db.cuentas) - lb.suma_saldos AS diferencia,
       lb.cuentas_saldo_cero                      AS ceros_linea_base,
       (SELECT SUM(saldo = 0) FROM banco_db.cuentas) AS ceros_actuales
  FROM drp_monitor.linea_base_cuentas lb
 ORDER BY lb.id_captura DESC LIMIT 1;

-- 3. La operacion legitima posterior al respaldo se conservo (RPO = 0)
SELECT t.id_transaccion, t.id_cuenta, t.tipo_transaccion, t.monto, t.fecha_hora, c.saldo
  FROM banco_db.transacciones t
  JOIN banco_db.cuentas c ON c.id_cuenta = t.id_cuenta
 ORDER BY t.id_transaccion DESC
 LIMIT 1;

-- 4. Lo que vuelve a ver el cliente en la app
SELECT cl.nombre AS cliente, cu.numero_cuenta, cu.saldo
  FROM banco_db.cuentas cu
  JOIN banco_db.clientes cl ON cl.id_cliente = cu.id_cliente
 ORDER BY cu.id_cuenta
 LIMIT 10;

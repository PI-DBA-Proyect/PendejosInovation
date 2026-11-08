-- =====================================================================
-- DRP BANCO | SCRIPT 05: PROVOCAR EL INCIDENTE
-- Usuario:  app_banco
-- Objetivo: simular un ajuste de saldos ejecutado sin WHERE
-- =====================================================================
USE banco_db;

SET SQL_SAFE_UPDATES = 0;          -- el operador desactiva la proteccion
UPDATE cuentas SET saldo = 0;      -- <<< ERROR: falta el WHERE

-- Lo que ahora ve el cliente en la app
SELECT cl.nombre AS cliente, cu.numero_cuenta, cu.saldo
  FROM cuentas cu
  JOIN clientes cl ON cl.id_cliente = cu.id_cliente
 ORDER BY cu.id_cuenta
 LIMIT 10;

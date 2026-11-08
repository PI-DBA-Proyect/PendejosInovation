-- =====================================================================
-- DRP BANCO | SCRIPT 04: OPERACION LEGITIMA POSTERIOR AL RESPALDO
-- Usuario:  app_banco
-- Objetivo: registrar un movimiento posterior al respaldo (prueba de RPO = 0)
-- =====================================================================
USE banco_db;

SET @cuenta := (SELECT MIN(id_cuenta) FROM cuentas);
SET @monto  := 15000.00;

START TRANSACTION;
UPDATE cuentas SET saldo = saldo + @monto WHERE id_cuenta = @cuenta;

INSERT INTO transacciones (id_transaccion, id_cuenta, tipo_transaccion, monto, fecha_hora)
SELECT IFNULL(MAX(id_transaccion), 0) + 1, @cuenta, 'Depósito', @monto, NOW()
  FROM transacciones;
COMMIT;

-- ANOTAR este saldo: debe ser el mismo despues de la recuperacion
SELECT id_cuenta, numero_cuenta, saldo AS saldo_esperado_post_drp
  FROM cuentas WHERE id_cuenta = @cuenta;

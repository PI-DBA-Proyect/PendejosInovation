-- =====================================================================
-- DRP BANCO | SCRIPT 01: ACTIVACION DEL MONITOREO
-- Usuario:  root
-- Objetivo: activar el evento monitor y crear el usuario de aplicacion
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Verificaciones previas (anotar los resultados)
-- ---------------------------------------------------------------------
SHOW VARIABLES LIKE 'log_bin';            -- Debe ser ON
SHOW VARIABLES LIKE 'binlog_format';      -- Debe ser ROW
SHOW VARIABLES LIKE 'log_bin_basename';   -- Ruta y nombre de los binlogs (se usa en la recuperacion)
SHOW VARIABLES LIKE 'gtid_mode';          -- Se espera OFF (valor por defecto)
SELECT VERSION();                         -- Si es menor a 8.0.26 usar --master-data en el script 02

SHOW TABLES FROM drp_monitor;             -- Deben aparecer 4 tablas
SHOW TRIGGERS FROM banco_db;              -- Debe aparecer trg_auditoria_saldo

-- ---------------------------------------------------------------------
-- 2. Parametros del servidor
-- ---------------------------------------------------------------------
-- SET PERSIST: el valor sobrevive a un reinicio del servicio (SET GLOBAL no).
-- binlog_rows_query_log_events solo aplica a sesiones abiertas despues de este punto.
SET PERSIST event_scheduler = ON;                 -- Activa los monitores automaticos
SET PERSIST binlog_rows_query_log_events = ON;    -- Guarda el texto SQL original en el binlog (forense)

-- ---------------------------------------------------------------------
-- 3. Evento monitor (corre cada 30 segundos) con dos reglas independientes
--    Regla 1: demasiados cambios de saldo en 1 minuto (depende del trigger)
--    Regla 2: la suma de saldos cayo mas del X% vs la linea base (no depende del trigger)
-- ---------------------------------------------------------------------
DROP EVENT IF EXISTS drp_monitor.ev_vigila_saldos;
DELIMITER //
CREATE EVENT drp_monitor.ev_vigila_saldos
ON SCHEDULE EVERY 30 SECOND
DO
BEGIN
    DECLARE v_cambios     INT DEFAULT 0;
    DECLARE v_umbral      INT DEFAULT 50;
    DECLARE v_pct         INT DEFAULT 30;
    DECLARE v_suma_base   DECIMAL(16,2) DEFAULT NULL;
    DECLARE v_suma_actual DECIMAL(16,2) DEFAULT 0;

    SELECT valor INTO v_umbral FROM drp_monitor.parametros WHERE nombre = 'UMBRAL_CAMBIOS_MINUTO';
    SELECT valor INTO v_pct    FROM drp_monitor.parametros WHERE nombre = 'PCT_CAIDA_SALDOS';

    -- Regla 1
    SELECT COUNT(*) INTO v_cambios
      FROM drp_monitor.auditoria_saldos
     WHERE origen = 'OPERACION'
       AND fecha >= NOW() - INTERVAL 1 MINUTE;

    IF v_cambios > v_umbral AND NOT EXISTS (
        SELECT 1 FROM drp_monitor.bitacora_incidentes
         WHERE tipo_incidente = 'MODIFICACION_MASIVA'
           AND estatus IN ('ABIERTO','EN_ATENCION')) THEN
        INSERT INTO drp_monitor.bitacora_incidentes
               (tipo_incidente, tabla_afectada, severidad, descripcion, valor_esperado, valor_detectado)
        VALUES ('MODIFICACION_MASIVA', 'cuentas', 'CRITICA',
                'Cantidad anomala de cambios de saldo en el ultimo minuto',
                CONCAT('<= ', v_umbral, ' cambios/min'), CONCAT(v_cambios, ' cambios/min'));
    END IF;

    -- Regla 2
    SELECT suma_saldos INTO v_suma_base
      FROM drp_monitor.linea_base_cuentas
     ORDER BY id_captura DESC LIMIT 1;

    SELECT IFNULL(SUM(saldo), 0) INTO v_suma_actual FROM banco_db.cuentas;

    IF v_suma_base > 0
       AND v_suma_actual < v_suma_base * (1 - v_pct / 100)
       AND NOT EXISTS (
        SELECT 1 FROM drp_monitor.bitacora_incidentes
         WHERE tipo_incidente = 'CAIDA_SALDOS'
           AND estatus IN ('ABIERTO','EN_ATENCION')) THEN
        INSERT INTO drp_monitor.bitacora_incidentes
               (tipo_incidente, tabla_afectada, severidad, descripcion, valor_esperado, valor_detectado)
        VALUES ('CAIDA_SALDOS', 'cuentas', 'CRITICA',
                CONCAT('La suma de saldos cayo mas del ', v_pct, '% respecto a la linea base'),
                CONCAT('$', FORMAT(v_suma_base, 2)), CONCAT('$', FORMAT(v_suma_actual, 2)));
    END IF;
END//
DELIMITER ;

-- ---------------------------------------------------------------------
-- 4. Usuario que simula la aplicacion / operador
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'app_banco'@'localhost';
CREATE USER 'app_banco'@'localhost' IDENTIFIED BY 'AppBanco2026!';
GRANT SELECT, INSERT, UPDATE, DELETE ON banco_db.* TO 'app_banco'@'localhost';

-- ---------------------------------------------------------------------
-- 5. Verificacion final del setup
-- ---------------------------------------------------------------------
SHOW EVENTS FROM drp_monitor;
SHOW VARIABLES LIKE 'event_scheduler';

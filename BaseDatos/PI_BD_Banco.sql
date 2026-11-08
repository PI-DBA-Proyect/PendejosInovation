-- =====================================================================
-- PI BD BANCO | INSTALACION DE banco_db Y drp_monitor
-- Usuario:  root
-- Objetivo: crear, cargar y verificar ambas bases en una sola ejecucion
-- Secciones:
--   [REINSTALACION] 0     Limpieza de una instalacion previa
--   [INSTALACION]   1 - 7 Tablespaces, tablas, carga, llaves, monitoreo,
--                         trigger y verificacion
-- =====================================================================

SET NAMES utf8mb4;


-- #####################################################################
-- [REINSTALACION] 0. LIMPIEZA DE UNA INSTALACION PREVIA
-- #####################################################################
-- Borrar las bases elimina sus tablas y el trigger, y deja vacios los
-- tablespaces generales (estos pertenecen a la instancia, no a la base).
DROP DATABASE IF EXISTS drp_monitor;
DROP DATABASE IF EXISTS banco_db;

-- MySQL no admite "DROP TABLESPACE IF EXISTS" ni ejecutarlo como sentencia
-- preparada: se usa un procedimiento temporal cuyo manejador de errores
-- ignora los tablespaces inexistentes. El procedimiento requiere una base,
-- por eso banco_db se crea en este punto.
CREATE DATABASE banco_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE banco_db;

DROP PROCEDURE IF EXISTS sp_borrar_tablespaces;
DELIMITER //
CREATE PROCEDURE sp_borrar_tablespaces()
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;  -- ignora "no existe"
    DROP TABLESPACE ts_sucursales;
    DROP TABLESPACE ts_empleados;
    DROP TABLESPACE ts_clientes;
    DROP TABLESPACE ts_cuentas;
    DROP TABLESPACE ts_tarjetas;
    DROP TABLESPACE ts_prestamos;
    DROP TABLESPACE ts_inversiones;
    DROP TABLESPACE ts_seguros;
END//
DELIMITER ;
CALL sp_borrar_tablespaces();
DROP PROCEDURE sp_borrar_tablespaces;

-- Resultado esperado: 0 filas
SELECT NAME AS tablespace_residual
  FROM information_schema.INNODB_TABLESPACES
 WHERE NAME LIKE 'ts\_%';


-- #####################################################################
-- [INSTALACION] 1. TABLESPACES
-- #####################################################################
-- Un tablespace general por tabla principal. Los archivos .ibd quedan en
-- el directorio de datos de MySQL (datadir).
CREATE TABLESPACE ts_sucursales  ADD DATAFILE 'ts_sucursales.ibd'  ENGINE=INNODB;
CREATE TABLESPACE ts_empleados   ADD DATAFILE 'ts_empleados.ibd'   ENGINE=INNODB;
CREATE TABLESPACE ts_clientes    ADD DATAFILE 'ts_clientes.ibd'    ENGINE=INNODB;
CREATE TABLESPACE ts_cuentas     ADD DATAFILE 'ts_cuentas.ibd'     ENGINE=INNODB;
CREATE TABLESPACE ts_tarjetas    ADD DATAFILE 'ts_tarjetas.ibd'    ENGINE=INNODB;
CREATE TABLESPACE ts_prestamos   ADD DATAFILE 'ts_prestamos.ibd'   ENGINE=INNODB;
CREATE TABLESPACE ts_inversiones ADD DATAFILE 'ts_inversiones.ibd' ENGINE=INNODB;
CREATE TABLESPACE ts_seguros     ADD DATAFILE 'ts_seguros.ibd'     ENGINE=INNODB;


-- #####################################################################
-- [INSTALACION] 2. TABLAS
-- #####################################################################
-- POR QUE LA PRIMARY KEY SE DECLARA AQUI Y NO DESPUES DE CARGAR:
--   En InnoDB la PRIMARY KEY es el indice agrupado (clustered): las filas
--   se guardan fisicamente ordenadas por ella.
--   * Sin PK, InnoDB crea un indice oculto (GEN_CLUST_INDEX), y un
--     ALTER TABLE ... ADD PRIMARY KEY posterior RECONSTRUYE la tabla
--     completa (copia todas las filas). En transacciones son 2,000,000.
--   * Los archivos vienen ordenados por id, asi que con la PK ya declarada
--     cada fila se agrega al final del indice: la carga es secuencial y
--     no hay reconstruccion.
--   En cambio, los UNIQUE, los indices secundarios y las FOREIGN KEY se
--   agregan DESPUES de la carga (seccion 4): MySQL los construye de golpe
--   ordenando los datos (mas rapido que mantenerlos fila por fila) y, al
--   crear cada FK, valida la integridad de lo que se cargo.

-- Tabla 1
CREATE TABLE sucursales (
    id_sucursal INT          NOT NULL,
    nombre      VARCHAR(100) NOT NULL,
    direccion   VARCHAR(255),
    telefono    VARCHAR(20),
    PRIMARY KEY (id_sucursal)
) TABLESPACE ts_sucursales;

-- Tabla 2
CREATE TABLE empleados (
    id_empleado INT           NOT NULL,
    id_sucursal INT           NOT NULL,
    nombre      VARCHAR(100)  NOT NULL,
    puesto      VARCHAR(50)   NOT NULL,
    salario     DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_empleado)
) TABLESPACE ts_empleados;

-- Tabla 3
CREATE TABLE clientes (
    id_cliente INT          NOT NULL,
    nombre     VARCHAR(100) NOT NULL,
    rfc_curp   VARCHAR(20)  NOT NULL,
    telefono   VARCHAR(20),
    email      VARCHAR(100),
    direccion  VARCHAR(255),
    PRIMARY KEY (id_cliente)
) TABLESPACE ts_clientes;

-- Tabla 4
CREATE TABLE cuentas (
    id_cuenta      INT           NOT NULL,
    id_cliente     INT           NOT NULL,
    id_sucursal    INT           NOT NULL,
    numero_cuenta  VARCHAR(20)   NOT NULL,
    tipo_cuenta    VARCHAR(30)   NOT NULL,
    saldo          DECIMAL(12,2) NOT NULL,
    fecha_apertura DATE          NOT NULL,
    PRIMARY KEY (id_cuenta)
) TABLESPACE ts_cuentas;

-- Tabla 5
CREATE TABLE tarjetas (
    id_tarjeta       INT         NOT NULL,
    id_cuenta        INT         NOT NULL,
    numero_tarjeta   VARCHAR(16) NOT NULL,
    tipo_tarjeta     VARCHAR(20) NOT NULL,
    fecha_expiracion DATE        NOT NULL,
    cvv              VARCHAR(4)  NOT NULL,
    PRIMARY KEY (id_tarjeta)
) TABLESPACE ts_tarjetas;

-- Tabla 6: transacciones (particionada por anio)
--   * SIN TABLESPACE propio: desde MySQL 8.0.13 una tabla particionada no
--     puede vivir en un tablespace general; cada particion usa su propio
--     archivo .ibd (file-per-table).
--   * La PK incluye fecha_hora porque MySQL exige que toda llave unica
--     contenga la columna de particionamiento.
--   * SIN FOREIGN KEY hacia cuentas: InnoDB no admite FK en tablas
--     particionadas. Por eso el indice por id_cuenta se crea a mano en la
--     seccion 4 (con una FK MySQL lo habria creado solo).
CREATE TABLE transacciones (
    id_transaccion   BIGINT        NOT NULL,
    id_cuenta        INT           NOT NULL,
    tipo_transaccion VARCHAR(30)   NOT NULL,
    monto            DECIMAL(12,2) NOT NULL,
    fecha_hora       DATETIME      NOT NULL,
    PRIMARY KEY (id_transaccion, fecha_hora)
)
PARTITION BY RANGE (YEAR(fecha_hora)) (
    PARTITION p2008_2011 VALUES LESS THAN (2012),
    PARTITION p2012_2015 VALUES LESS THAN (2016),
    PARTITION p2016_2019 VALUES LESS THAN (2020),
    PARTITION p2020_2023 VALUES LESS THAN (2024),
    PARTITION p2024_max  VALUES LESS THAN MAXVALUE
);

-- Tabla 7
CREATE TABLE prestamos (
    id_prestamo    INT           NOT NULL,
    id_cliente     INT           NOT NULL,
    id_empleado    INT           NOT NULL,
    monto_otorgado DECIMAL(12,2) NOT NULL,
    tasa_interes   DECIMAL(5,2)  NOT NULL,
    plazo_meses    INT           NOT NULL,
    estatus        VARCHAR(20)   NOT NULL,
    PRIMARY KEY (id_prestamo)
) TABLESPACE ts_prestamos;

-- Tabla 8
CREATE TABLE inversiones (
    id_inversion     INT           NOT NULL,
    id_cliente       INT           NOT NULL,
    monto_invertido  DECIMAL(12,2) NOT NULL,
    tasa_rendimiento DECIMAL(5,2)  NOT NULL,
    plazo_dias       INT           NOT NULL,
    fecha_inicio     DATE          NOT NULL,
    PRIMARY KEY (id_inversion)
) TABLESPACE ts_inversiones;

-- Tabla 9
CREATE TABLE seguros (
    id_seguro       INT           NOT NULL,
    id_cliente      INT           NOT NULL,
    tipo_seguro     VARCHAR(50)   NOT NULL,
    prima_mensual   DECIMAL(10,2) NOT NULL,
    monto_cobertura DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id_seguro)
) TABLESPACE ts_seguros;


-- #####################################################################
-- [INSTALACION] 3. CARGA DE DATOS
-- #####################################################################
-- Carpeta desde la que LOAD DATA puede leer
SHOW VARIABLES LIKE 'secure_file_priv';

-- CHARACTER SET explicito: los datos traen acentos (Debito, Nomina...) y no
-- deben depender del charset por defecto del servidor.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/sucursales.txt'    INTO TABLE sucursales    CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/empleados.txt'     INTO TABLE empleados     CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/clientes.txt'      INTO TABLE clientes      CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/cuentas.txt'       INTO TABLE cuentas       CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/tarjetas.txt'      INTO TABLE tarjetas      CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/transacciones.txt' INTO TABLE transacciones CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/prestamos.txt'     INTO TABLE prestamos     CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/inversiones.txt'   INTO TABLE inversiones   CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/seguros.txt'       INTO TABLE seguros       CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';


-- #####################################################################
-- [INSTALACION] 4. LLAVES UNICAS, FORANEAS E INDICES
-- #####################################################################
-- T2: Empleados
ALTER TABLE empleados
    ADD CONSTRAINT fk_empleados_sucursales
        FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal);

-- T3: Clientes
ALTER TABLE clientes
    ADD CONSTRAINT uq_clientes_rfc   UNIQUE (rfc_curp),
    ADD CONSTRAINT uq_clientes_email UNIQUE (email);

-- T4: Cuentas
ALTER TABLE cuentas
    ADD CONSTRAINT uq_cuentas_numero UNIQUE (numero_cuenta),
    ADD CONSTRAINT fk_cuentas_clientes
        FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    ADD CONSTRAINT fk_cuentas_sucursales
        FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal);

-- T5: Tarjetas
ALTER TABLE tarjetas
    ADD CONSTRAINT uq_tarjetas_numero UNIQUE (numero_tarjeta),
    ADD CONSTRAINT fk_tarjetas_cuentas
        FOREIGN KEY (id_cuenta) REFERENCES cuentas(id_cuenta);

-- T6: Transacciones: indice manual por cuenta (no puede tener FK, ver tabla 6).
--     Sin el, buscar los movimientos de una cuenta recorre las 2M filas.
ALTER TABLE transacciones
    ADD INDEX idx_transacciones_cuenta (id_cuenta);

-- T7: Prestamos
ALTER TABLE prestamos
    ADD CONSTRAINT fk_prestamos_clientes
        FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    ADD CONSTRAINT fk_prestamos_empleados
        FOREIGN KEY (id_empleado) REFERENCES empleados(id_empleado);

-- T8: Inversiones
ALTER TABLE inversiones
    ADD CONSTRAINT fk_inversiones_clientes
        FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente);

-- T9: Seguros
ALTER TABLE seguros
    ADD CONSTRAINT fk_seguros_clientes
        FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente);


-- #####################################################################
-- [INSTALACION] 5. ESQUEMA DE MONITOREO drp_monitor
-- #####################################################################
-- Separado de banco_db a proposito: una restauracion de banco_db (DRP)
-- no borra la evidencia ni la bitacora.
CREATE DATABASE drp_monitor CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE drp_monitor;

-- Bitacora oficial de incidentes
CREATE TABLE bitacora_incidentes (
    id_incidente     INT AUTO_INCREMENT PRIMARY KEY,
    fecha_deteccion  DATETIME DEFAULT CURRENT_TIMESTAMP,
    tipo_incidente   VARCHAR(50),
    tabla_afectada   VARCHAR(64),
    severidad        ENUM('BAJA','MEDIA','ALTA','CRITICA'),
    descripcion      VARCHAR(500),
    valor_esperado   VARCHAR(100),
    valor_detectado  VARCHAR(100),
    estatus          ENUM('ABIERTO','EN_ATENCION','RESUELTO') DEFAULT 'ABIERTO',
    fecha_resolucion DATETIME NULL
);

-- Evidencia: cada cambio de saldo con su valor anterior
CREATE TABLE auditoria_saldos (
    id_auditoria   BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cuenta      INT,
    saldo_anterior DECIMAL(12,2),
    saldo_nuevo    DECIMAL(12,2),
    usuario        VARCHAR(100),
    origen         VARCHAR(20),          -- OPERACION | RESTAURACION
    fecha          DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    INDEX idx_fecha (fecha),
    INDEX idx_cuenta (id_cuenta)
);

-- Umbrales configurables del evento monitor
CREATE TABLE parametros (
    nombre      VARCHAR(50) PRIMARY KEY,
    valor       INT,
    descripcion VARCHAR(200)
);
INSERT INTO parametros VALUES
 ('UMBRAL_CAMBIOS_MINUTO', 50, 'Max. cambios de saldo por minuto antes de alertar'),
 ('PCT_CAIDA_SALDOS',      30, 'Porcentaje de caida de la suma de saldos que dispara alerta');

-- Fotografia diaria de los indicadores de cuentas
CREATE TABLE linea_base_cuentas (
    id_captura         INT AUTO_INCREMENT PRIMARY KEY,
    fecha_captura      DATETIME DEFAULT CURRENT_TIMESTAMP,
    total_cuentas      INT,
    suma_saldos        DECIMAL(16,2),
    cuentas_saldo_cero INT
);


-- #####################################################################
-- [INSTALACION] 6. TRIGGER DE AUDITORIA sobre banco_db.cuentas
-- #####################################################################
-- Se crea DESPUES de la carga. Es AFTER UPDATE, asi que LOAD DATA (INSERT)
-- no lo dispara. @drp_restauracion = 1 marca los cambios hechos por el DRP.
-- CURRENT_TIMESTAMP(3) es constante dentro de una sentencia: todas las filas
-- de un mismo UPDATE comparten "fecha", y asi los scripts DRP agrupan la
-- rafaga del error con GROUP BY fecha.
DELIMITER //
CREATE TRIGGER banco_db.trg_auditoria_saldo
AFTER UPDATE ON banco_db.cuentas
FOR EACH ROW
BEGIN
    IF NOT (OLD.saldo <=> NEW.saldo) THEN
        INSERT INTO drp_monitor.auditoria_saldos
               (id_cuenta, saldo_anterior, saldo_nuevo, usuario, origen)
        VALUES (OLD.id_cuenta, OLD.saldo, NEW.saldo, USER(),
                IF(@drp_restauracion = 1, 'RESTAURACION', 'OPERACION'));
    END IF;
END//
DELIMITER ;


-- #####################################################################
-- [INSTALACION] 7. VERIFICACION FINAL
-- #####################################################################
USE banco_db;

-- 7.1 Filas por tabla. Resultado esperado: igual a las lineas de cada .txt
SELECT 'sucursales'    AS tabla, COUNT(*) AS filas FROM sucursales    UNION ALL
SELECT 'empleados',              COUNT(*)          FROM empleados     UNION ALL
SELECT 'clientes',               COUNT(*)          FROM clientes      UNION ALL
SELECT 'cuentas',                COUNT(*)          FROM cuentas       UNION ALL
SELECT 'tarjetas',               COUNT(*)          FROM tarjetas      UNION ALL
SELECT 'transacciones',          COUNT(*)          FROM transacciones UNION ALL
SELECT 'prestamos',              COUNT(*)          FROM prestamos     UNION ALL
SELECT 'inversiones',            COUNT(*)          FROM inversiones   UNION ALL
SELECT 'seguros',                COUNT(*)          FROM seguros;

-- 7.2 Reparto de transacciones por particion (TABLE_ROWS es aproximado)
SELECT PARTITION_NAME, PARTITION_DESCRIPTION AS menor_que_anio, TABLE_ROWS
  FROM information_schema.PARTITIONS
 WHERE TABLE_SCHEMA = 'banco_db' AND TABLE_NAME = 'transacciones'
 ORDER BY PARTITION_ORDINAL_POSITION;

-- 7.3 Tabla alojada en cada tablespace
SELECT ts.NAME AS tablespace, t.NAME AS tabla
  FROM information_schema.INNODB_TABLESPACES ts
  JOIN information_schema.INNODB_TABLES t ON t.SPACE = ts.SPACE
 WHERE ts.NAME LIKE 'ts\_%'
 ORDER BY ts.NAME;

-- 7.4 Trigger de auditoria y tablas de monitoreo
SHOW TRIGGERS FROM banco_db;
SHOW TABLES FROM drp_monitor;

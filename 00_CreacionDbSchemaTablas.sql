/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: DEFINICIÓN DDL.
*/

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'Com2900G11')
BEGIN
	CREATE DATABASE Com2900G11;
END
GO
USE Com2900G11
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dba')
BEGIN
    EXEC('CREATE SCHEMA dba AUTHORIZATION [dbo]');
END
GO

DROP TABLE IF EXISTS dba.Gasto;
GO
DROP TABLE IF EXISTS dba.Tipo_gasto;
GO
DROP TABLE IF EXISTS dba.Expensa;
GO
DROP TABLE IF EXISTS dba.Pago;
GO
DROP TABLE IF EXISTS dba.Unidad_accesorio;
GO
DROP TABLE IF EXISTS dba.Tipo_unidad_accesorio;
GO
DROP TABLE IF EXISTS dba.Unidad_funcional;
GO
DROP TABLE IF EXISTS dba.Persona;
GO
DROP TABLE IF EXISTS dba.Tipo_persona;
GO
DROP TABLE IF EXISTS dba.Consorcio;
GO

IF OBJECT_ID('dba.Consorcio','U') IS NULL
BEGIN
CREATE TABLE dba.Consorcio (
	id INTEGER PRIMARY KEY IDENTITY,
	nombre VARCHAR(100),
	domicilio VARCHAR(100),
	superficie_total DECIMAL(12,2),

	CONSTRAINT CK_Consorcio_Superficie_NoNeg CHECK (superficie_total IS NULL OR superficie_total >= 0),
	CONSTRAINT CK_Consorcio_Nombre_NoVacio CHECK (nombre IS NULL OR LTRIM(RTRIM(nombre)) <> ''),
	CONSTRAINT CK_Consorcio_Domicilio_NoVacio CHECK (domicilio IS NULL OR LTRIM(RTRIM(domicilio)) <> ''),
	CONSTRAINT UQ_Consorcio_NombreDomicilio UNIQUE (nombre, domicilio)
);
END
GO 

IF OBJECT_ID('dba.Tipo_persona', 'U') IS NULL
BEGIN
CREATE TABLE dba.Tipo_persona (
	id INTEGER PRIMARY KEY,
	tipo CHAR(11),

	CONSTRAINT CK_TipoPersona_Id_Valores CHECK (id IN(0,1))
);
END
GO

IF OBJECT_ID('dba.Persona', 'U') IS NULL
BEGIN
CREATE TABLE dba.Persona (
    dni INT PRIMARY KEY,
    nombre VARCHAR(100),
    apellido VARCHAR(100),
    email VARCHAR(64),
    nro_telefono VARCHAR(64),
    cvu_o_cbu char(22),
    id_tipo_persona INT NOT NULL,

    CONSTRAINT FK_Persona_TipoPersona FOREIGN KEY (id_tipo_persona) REFERENCES dba.Tipo_persona(id) ON DELETE NO ACTION,
    CONSTRAINT CK_Persona_DNI_Rango CHECK (dni BETWEEN 1 AND 999999999),
    CONSTRAINT CK_Persona_Nombre_NoVacio CHECK (nombre IS NULL OR LTRIM(RTRIM(nombre)) <> ''),
    CONSTRAINT CK_Persona_Apellido_NoVacio CHECK (apellido IS NULL OR LTRIM(RTRIM(apellido)) <> ''),
    CONSTRAINT CK_Persona_Email_Formato CHECK (email IS NULL OR email LIKE '%_@_%._%'),
    CONSTRAINT CK_Persona_Tel_Formato CHECK (nro_telefono IS NULL OR RTRIM(nro_telefono) NOT LIKE '%[^0-9 +()\-]%'),
	CONSTRAINT UQ_Persona_CVUCBU UNIQUE (cvu_o_cbu)
);
END
GO

IF OBJECT_ID('dba.Unidad_funcional', 'U') IS NULL
BEGIN
    CREATE TABLE dba.Unidad_funcional (
        id INTEGER PRIMARY KEY IDENTITY,
        id_consorcio INTEGER NOT NULL,
        nro_uf SMALLINT, 
		piso CHAR(2),
        depto CHAR(2),
		coeficiente DECIMAL(12,2),
        superficie DECIMAL(12,2),
		dni_persona INTEGER,

		CONSTRAINT FK_UnidadFuncional_Persona
			FOREIGN KEY (dni_persona) REFERENCES dba.Persona(dni),

        CONSTRAINT FK_UnidadFuncional_Consorcio 
            FOREIGN KEY (id_consorcio) REFERENCES dba.Consorcio(id) ON DELETE CASCADE,

        CONSTRAINT CK_UnidadFuncional_Superficie_NoNeg 
            CHECK (superficie IS NULL OR superficie >= 0),

        CONSTRAINT UQ_UnidadFuncional_ConsorcioPisoDepto 
            UNIQUE (id_consorcio, piso, depto),

		CONSTRAINT UQ_UnidadFuncional_ConsorcioNroUF
			UNIQUE (id_consorcio, nro_uf)
    );
END
GO

IF OBJECT_ID('dba.Tipo_unidad_accesorio', 'U') IS NULL
BEGIN
CREATE TABLE dba.Tipo_unidad_accesorio (
	id INTEGER PRIMARY KEY,
	tipo CHAR(7),

	CONSTRAINT CK_TipoUnidadAccesorio_Tipo_NoVacio  CHECK (tipo IS NULL OR LTRIM(RTRIM(tipo)) <> ''),
	CONSTRAINT CK_TipoUnidadAccesorio_Id_Valores CHECK (id IN(0,1))
);
END
GO

IF OBJECT_ID('dba.Unidad_accesorio', 'U') IS NULL
BEGIN
CREATE TABLE dba.Unidad_accesorio (
	id INTEGER PRIMARY KEY IDENTITY,
	superficie DECIMAL(12,2),
	id_unidad_funcional INTEGER NOT NULL,
	id_tipo_unidad_accesorio INTEGER NOT NULL,

	CONSTRAINT FK_UnidadAccesorio_UF FOREIGN KEY (id_unidad_funcional) REFERENCES dba.Unidad_funcional(id) ON DELETE CASCADE,
	CONSTRAINT FK_UnidadAccesorio_TipoUnidadAccesorio FOREIGN KEY (id_tipo_unidad_accesorio) REFERENCES dba.Tipo_unidad_accesorio(id) ON DELETE CASCADE
);
END
GO

IF OBJECT_ID('dba.Expensa','U') IS NULL
BEGIN
    CREATE TABLE dba.Expensa (
        id INTEGER PRIMARY KEY IDENTITY,
        id_consorcio INTEGER NOT NULL,
        anio SMALLINT,
        mes TINYINT,
        primer_fecha_vto DATE,
        segunda_fecha_vto DATE,

        CONSTRAINT FK_Expensa_Consorcio FOREIGN KEY (id_consorcio) REFERENCES dba.Consorcio(id) ON DELETE CASCADE,
        CONSTRAINT CK_Expensa_Mes CHECK (mes BETWEEN 1 AND 12),
        CONSTRAINT CK_DetalleExpensa_ValidVencimiento CHECK (segunda_fecha_vto IS NULL OR primer_fecha_vto IS NULL OR primer_fecha_vto < segunda_fecha_vto)
    );
END
GO

IF OBJECT_ID('dba.Pago', 'U') IS NULL
BEGIN
CREATE TABLE dba.Pago (
	id INTEGER PRIMARY KEY,
	fecha DATE,
	importe DECIMAL(12,2),
	id_uf INTEGER,

	CONSTRAINT FK_Pago_UF FOREIGN KEY (id_uf) REFERENCES dba.Unidad_funcional(id) ON DELETE CASCADE,
	CONSTRAINT CK_Pago_Importe_Pos CHECK (importe > 0)
);
END
GO 

IF OBJECT_ID('dba.Tipo_gasto', 'U') IS NULL
BEGIN
CREATE TABLE dba.Tipo_gasto (
	id INTEGER PRIMARY KEY,
	tipo CHAR(14),

	CONSTRAINT CK_TipoGasto_Tipo_NoVacio  CHECK (tipo IS NULL OR LTRIM(RTRIM(tipo)) <> ''),
	CONSTRAINT CK_TipoGasto_Id_Valores CHECK (id IN(0,1))
);
END
GO

IF OBJECT_ID('dba.Gasto', 'U') IS NULL
BEGIN
CREATE TABLE dba.Gasto (
	id INTEGER PRIMARY KEY IDENTITY,
	detalle VARCHAR(100),
	importe DECIMAL(12,2),
	cuota_actual TINYINT,
	total_cuotas TINYINT,
	id_tipo_gasto INTEGER NOT NULL,
	id_expensa INTEGER NOT NULL,

	CONSTRAINT FK_Gasto_TipoGasto FOREIGN KEY (id_tipo_gasto) REFERENCES dba.Tipo_gasto(id) ON DELETE CASCADE,
	CONSTRAINT FK_Gasto_Expensa FOREIGN KEY (id_expensa) REFERENCES dba.Expensa(id) ON DELETE CASCADE,
	CONSTRAINT CK_Gasto_Importe_Pos CHECK (importe > 0),
	CONSTRAINT CK_Gasto_CuotaActual_Valida 
            CHECK (
                cuota_actual IS NULL
                OR (cuota_actual >= 1 AND total_cuotas IS NOT NULL AND cuota_actual <= total_cuotas)
            ),
	CONSTRAINT CK_Gasto_TotalCuotas_Pos CHECK (total_cuotas IS NULL OR total_cuotas >= 1),
);
END

/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación de funciones y vistas con datos sensibles enmascarados para poder ocultar información no pública. Creación de los roles requeridos.
*/

USE Com2900G11;
GO

CREATE OR ALTER FUNCTION dba.fn_MaskEmail (@email NVARCHAR(150))
RETURNS NVARCHAR(150)
AS
BEGIN
    IF @email IS NULL RETURN NULL;
    RETURN CONCAT(LEFT(@email, 2), '***@***', RIGHT(@email, 2));
END;
GO

CREATE OR ALTER FUNCTION dba.fn_MaskText (@txt NVARCHAR(100))
RETURNS NVARCHAR(100)
AS
BEGIN
    IF @txt IS NULL RETURN NULL;
    RETURN CONCAT(LEFT(@txt, 1), REPLICATE('*', LEN(@txt)-2), RIGHT(@txt, 1));
END;
GO

CREATE OR ALTER FUNCTION dba.fn_MaskTel (@tel NVARCHAR(25))
RETURNS NVARCHAR(25)
AS
BEGIN
    IF @tel IS NULL RETURN NULL;
    RETURN CONCAT('***-***-', RIGHT(@tel, 3));
END;
GO

CREATE OR ALTER FUNCTION dba.fn_MaskCVUCBU (@cvu_cbu CHAR(22))
RETURNS CHAR(22)
AS
BEGIN
    IF @cvu_cbu IS NULL 
        RETURN NULL;

    RETURN REPLICATE('*', 15) + RIGHT(@cvu_cbu, 7);
END;
GO

CREATE OR ALTER VIEW dba.vw_Persona_Masked
AS
SELECT
    dni,
    dba.fn_MaskText(nombre)       AS nombre,
    dba.fn_MaskText(apellido)     AS apellido,
    dba.fn_MaskEmail(email)       AS email,
    dba.fn_MaskTel(nro_telefono)  AS nro_telefono,
    dba.fn_MaskCVUCBU(cvu_o_cbu)     AS cvu_o_cbu,
    id_tipo_persona
FROM dba.Persona;
GO

CREATE OR ALTER VIEW dba.vw_UnidadFuncional_Masked
AS
SELECT
    uf.id,
    uf.id_consorcio,
    uf.nro_uf,
    uf.piso,
    uf.depto,
    uf.superficie,
    uf.coeficiente,
    uf.dni_persona,
    p.nombre       AS nombre_persona,
    p.apellido     AS apellido_persona
FROM dba.Unidad_funcional uf
LEFT JOIN dba.vw_Persona_Masked p ON p.dni = uf.dni_persona;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dba_AdministrativoGeneral')
BEGIN
    CREATE ROLE dba_AdministrativoGeneral;
    GRANT EXECUTE ON dba.sp_ImportarTXTUnidadFuncional TO dba_AdministrativoGeneral;
    GRANT EXECUTE ON dba.sp_ImportarCSVPersonaUF TO dba_AdministrativoGeneral;
    GRANT EXECUTE ON SCHEMA::dba TO dba_AdministrativoGeneral;
END

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dba_AdministrativoBancario')
BEGIN
    CREATE ROLE dba_AdministrativoBancario;
    GRANT EXECUTE ON dba.sp_ImportarCSV_PagosBanco TO dba_AdministrativoBancario;
    GRANT EXECUTE ON dba.sp_ImportarServiciosJSON TO dba_AdministrativoBancario;
    GRANT EXECUTE ON dba.sp_ImportarCSVPersonas TO dba_AdministrativoBancario;
    GRANT EXECUTE ON SCHEMA::dba TO dba_AdministrativoBancario;
END

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dba_AdministrativoOperativo')
BEGIN
    CREATE ROLE dba_AdministrativoOperativo;
    GRANT EXECUTE ON dba.sp_ImportarTXTUnidadFuncional TO dba_AdministrativoOperativo;
    GRANT EXECUTE ON dba.sp_ImportarCSVPersonaUF TO dba_AdministrativoOperativo;
    GRANT EXECUTE ON SCHEMA::dba TO dba_AdministrativoOperativo;
END

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'dba_Sistemas')
BEGIN
    CREATE ROLE dba_Sistemas;
    GRANT SELECT ON dba.vw_Persona_Masked TO dba_Sistemas;
    GRANT SELECT ON dba.vw_UnidadFuncional_Masked TO dba_Sistemas;
    GRANT EXECUTE ON SCHEMA::dba TO dba_Sistemas;
END


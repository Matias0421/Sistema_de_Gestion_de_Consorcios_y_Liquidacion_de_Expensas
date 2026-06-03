/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación de los índices que se utilizarán para la optimización de las consultas generadas para los reportes de la entrega nro. 6
*/

USE Com2900G11;
GO
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Pago_Fecha' AND object_id = OBJECT_ID('dba.Pago'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pago_Fecha 
    ON dba.Pago(fecha) 
    INCLUDE (id_uf, importe);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Pago_IdUF_Fecha' AND object_id = OBJECT_ID('dba.Pago'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pago_IdUF_Fecha 
    ON dba.Pago(id_uf, fecha) 
    INCLUDE (importe);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Expensa_Anio_Mes' AND object_id = OBJECT_ID('dba.Expensa'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Expensa_Anio_Mes 
    ON dba.Expensa(anio, mes) 
    INCLUDE (id_consorcio, primer_fecha_vto, segunda_fecha_vto);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Expensa_IdConsorcio' AND object_id = OBJECT_ID('dba.Expensa'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Expensa_IdConsorcio 
    ON dba.Expensa(id_consorcio) 
    INCLUDE (anio, mes);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Gasto_IdExpensa' AND object_id = OBJECT_ID('dba.Gasto'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Gasto_IdExpensa 
    ON dba.Gasto(id_expensa) 
    INCLUDE (importe, id_tipo_gasto, detalle);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_UnidadFuncional_IdConsorcio' AND object_id = OBJECT_ID('dba.Unidad_funcional'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_UnidadFuncional_IdConsorcio 
    ON dba.Unidad_funcional(id_consorcio) 
    INCLUDE (id, piso, depto, dni_persona, coeficiente);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_UnidadFuncional_DniPersona' AND object_id = OBJECT_ID('dba.Unidad_funcional'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_UnidadFuncional_DniPersona 
    ON dba.Unidad_funcional(dni_persona) 
    INCLUDE (id, id_consorcio);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Persona_TipoPersona' AND object_id = OBJECT_ID('dba.Persona'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Persona_TipoPersona 
    ON dba.Persona(id_tipo_persona) 
    INCLUDE (dni, nombre, apellido, email, nro_telefono);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Consorcio_Nombre' AND object_id = OBJECT_ID('dba.Consorcio'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Consorcio_Nombre 
    ON dba.Consorcio(nombre) 
    INCLUDE (id, domicilio);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_TipoGasto_Id' AND object_id = OBJECT_ID('dba.Tipo_gasto'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_TipoGasto_Id 
    ON dba.Tipo_gasto(id) 
    INCLUDE (tipo);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Pago_UF_Fecha_Importe' AND object_id = OBJECT_ID('dba.Pago'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pago_UF_Fecha_Importe 
    ON dba.Pago(id_uf, fecha) 
    INCLUDE (importe);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Gasto_TipoGasto_Expensa' AND object_id = OBJECT_ID('dba.Gasto'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Gasto_TipoGasto_Expensa 
    ON dba.Gasto(id_tipo_gasto, id_expensa) 
    INCLUDE (importe);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Pago_UF_Fecha_IncluyeImporte' AND object_id = OBJECT_ID('dba.Pago'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pago_UF_Fecha_IncluyeImporte
    ON dba.Pago(id_uf, fecha)
    INCLUDE (importe);
END;

IF NOT EXISTS (SELECT 1 
               FROM sys.indexes 
               WHERE name = 'IX_Gasto_TipoGasto_IncluyeImporte' AND object_id = OBJECT_ID('dba.Gasto'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Gasto_TipoGasto_IncluyeImporte
    ON dba.Gasto(id_tipo_gasto, id_expensa)
    INCLUDE (importe, detalle);
END;

GO

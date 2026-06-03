/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del SP para la importación de los pagos registrados que posee la administración.
*/

USE Com2900G11
GO
SET NOCOUNT ON
GO

USE Com2900G11;
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dba.sp_ImportarCSV_PagosBanco
  @RutaArchivo      NVARCHAR(4000),
  @SeparadorCampos  NVARCHAR(10) = ',',
  @FilaInicial      INT = 2
AS
BEGIN
    SET NOCOUNT ON;

    -- Temp tables
    IF OBJECT_ID('tempdb..#PagosRaw') IS NOT NULL DROP TABLE #PagosRaw;
    CREATE TABLE #PagosRaw(
    [Id de pago] NVARCHAR(50) NULL,
    [fecha]      NVARCHAR(50) NULL,
    [CVU/CBU]    NVARCHAR(64) NULL,
    [ Valor ]    NVARCHAR(64) NULL
    );

    DECLARE @isLinux BIT = CASE WHEN @@version LIKE '%Linux%' THEN 1 ELSE 0 END;
    DECLARE @SQL NVARCHAR(MAX) =
        N'BULK INSERT #PagosRaw FROM '''+REPLACE(@RutaArchivo,'''','''''')+N''' WITH ('+
        N'FIELDTERMINATOR='''+@SeparadorCampos+N''','+
        N'ROWTERMINATOR=''0x0a'','+
        N'FIRSTROW='+CAST(@FilaInicial AS NVARCHAR(10))+N','+
        CASE WHEN @isLinux=1 THEN N'' ELSE N'CODEPAGE=''65001'',' END +
        N'TABLOCK);';
    EXEC (@SQL);

    -- normalizacion y tipificacion
    IF OBJECT_ID('tempdb..#PagosOK') IS NOT NULL DROP TABLE #PagosOK;
    SELECT
        TRY_CONVERT(INTEGER, LTRIM(RTRIM([Id de pago])))   AS id,
        TRY_CONVERT(DATE,  LTRIM(RTRIM([fecha])), 103)    AS fecha,  
        LTRIM(RTRIM([CVU/CBU]))                           AS cvu_cbu,
        NULL                                              AS id_uf,
        TRY_CONVERT(DECIMAL(12,2),
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE((TRIM([ Valor ])),'$',''),' ',''),'.',''),',','.'), CHAR(13), '')
        )                                                 AS importe
    INTO #PagosOK
    FROM #PagosRaw;

    -- Rechazadas por formato
    IF OBJECT_ID('tempdb..#PagosErr') IS NOT NULL DROP TABLE #PagosErr;
    SELECT * INTO #PagosErr
    FROM #PagosOK
    WHERE id IS NULL OR fecha IS NULL OR cvu_cbu IS NULL OR importe IS NULL;

    DELETE PO
    FROM #PagosOK PO
    WHERE PO.id IS NULL OR PO.fecha IS NULL OR PO.cvu_cbu IS NULL OR PO.importe IS NULL;

    UPDATE po SET
        po.id_uf = uf.id 
        FROM #PagosOK po 
        INNER JOIN dba.Persona p ON po.cvu_cbu = p.cvu_o_cbu 
        INNER JOIN dba.Unidad_funcional uf ON uf.dni_persona = p.dni;

    IF OBJECT_ID('tempdb..#MergeOut') IS NOT NULL DROP TABLE #MergeOut;
    CREATE TABLE #MergeOut(
        accion NVARCHAR(10),
        id INT,
        fecha DATE,
        id_uf INT,
        importe DECIMAL(12,2)
    );

    MERGE dba.Pago AS T
    USING (SELECT id, fecha, id_uf, importe FROM #PagosOK) AS S
      ON T.id = S.id
    WHEN MATCHED THEN UPDATE SET
      T.fecha = S.fecha,
      T.id_uf = S.id_uf,
      T.importe = S.importe
    WHEN NOT MATCHED THEN
      INSERT (id, fecha, id_uf, importe)
      VALUES (S.id, S.fecha, S.id_uf, S.importe)
    OUTPUT 
        $action AS accion,
        S.id,
        S.fecha,
        S.id_uf,
        S.importe
    INTO #MergeOut;

    SELECT id, fecha, cvu_cbu, importe, id_uf, 'Rechazado' as estado FROM #PagosErr;

    SELECT 
        SUM(CASE WHEN accion='INSERT' THEN 1 ELSE 0 END) AS insertados,
        SUM(CASE WHEN accion='UPDATE' THEN 1 ELSE 0 END) AS actualizados,
        (SELECT COUNT(*) FROM #PagosErr)                  AS rechazados
    FROM #MergeOut;

    SELECT * FROM #MergeOut;

  IF OBJECT_ID('tempdb..#PagosRaw') IS NOT NULL DROP TABLE #PagosRaw;
  IF OBJECT_ID('tempdb..#PagosOK') IS NOT NULL DROP TABLE #PagosOK;
  IF OBJECT_ID('tempdb..#PagosNoUF') IS NOT NULL DROP TABLE #PagosNoUF;
  IF OBJECT_ID('tempdb..#PagosOrdered') IS NOT NULL DROP TABLE #PagosOrdered;
END;
GO
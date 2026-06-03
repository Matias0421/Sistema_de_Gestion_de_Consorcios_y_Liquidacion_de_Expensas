/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del SP para la importación de las unidades funcionales que corresponden a cada consorcio que posee la administración
*/

USE Com2900G11;
GO

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dba.sp_ImportarTXTUnidadFuncional
    @RutaArchivo     VARCHAR(4000),
    @SeparadorCampos VARCHAR(10) = '\t',
    @FilaInicial     INT = 2
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        IF OBJECT_ID('tempdb..#TempUF') IS NOT NULL 
            DROP TABLE #TempUF;

        CREATE TABLE #TempUF (
            Nombre               VARCHAR(250),
            NroUnidadFuncional   VARCHAR(5),
            Piso                 VARCHAR(5),
            Departamento         VARCHAR(5),
            Coeficiente          VARCHAR(5),
            M2_Unidad_Funcional  VARCHAR(5),
            Baulera              VARCHAR(2),
            Cochera              VARCHAR(2),
            M2_Baulera           VARCHAR(5),
            M2_Cochera           VARCHAR(5)
        );

        DECLARE @SQL NVARCHAR(MAX);
        SET @SQL = N'
            BULK INSERT #TempUF
            FROM ''' + @RutaArchivo + N'''
            WITH (
                FIELDTERMINATOR = ''' + @SeparadorCampos + ''',
                ROWTERMINATOR   = ''\n'',
                FIRSTROW        = ' + CAST(@FilaInicial AS VARCHAR(10)) + '
            )
        ';

        PRINT(@SQL);
        EXEC(@SQL);

        IF OBJECT_ID('tempdb..#TempUFLimpias') IS NOT NULL 
            DROP TABLE #TempUFLimpias;

        SELECT DISTINCT
            (SELECT c.id FROM dba.Consorcio c WHERE c.nombre = temp.Nombre)              AS id_consorcio,
            TRY_CAST(TRIM(temp.NroUnidadFuncional) AS TINYINT)                          AS nro_uf,
            temp.Piso                                                                   AS piso,
            TRY_CAST(REPLACE(TRIM(temp.Coeficiente), ',', '.') AS DECIMAL(12,2))        AS coeficiente,
            temp.Departamento                                                           AS depto,
            TRY_CAST(TRIM(temp.M2_Unidad_Funcional) AS DECIMAL(12,2))                   AS superficie
        INTO #TempUFLimpias
        FROM #TempUF temp
        WHERE
            dba.CadenaNoVacia(temp.Nombre) = 1
            AND (SELECT c.id FROM dba.Consorcio c WHERE c.nombre = temp.Nombre) IS NOT NULL
            AND TRY_CAST(TRIM(temp.NroUnidadFuncional) AS TINYINT) > 0
            AND TRY_CAST(REPLACE(TRIM(temp.Coeficiente), ',', '.') AS DECIMAL(12,2)) > 0
            AND dba.CadenaNoVacia(temp.Piso) = 1
            AND dba.CadenaNoVacia(temp.Departamento) = 1
            AND TRY_CAST(TRIM(temp.M2_Unidad_Funcional) AS DECIMAL) > 0;
      
        IF OBJECT_ID('tempdb..#UFsInsertadas') IS NOT NULL 
            DROP TABLE #UFsInsertadas;

        CREATE TABLE #UFsInsertadas (
            id_uf INT
        );

        MERGE dba.Unidad_funcional AS destino
        USING #TempUFLimpias AS origen
        ON  destino.id_consorcio = origen.id_consorcio
        AND destino.piso         = origen.piso
        AND destino.depto        = origen.depto
        WHEN MATCHED THEN
            UPDATE SET
                destino.superficie  = origen.superficie,
                destino.nro_uf      = origen.nro_uf,
                destino.coeficiente = origen.coeficiente
        WHEN NOT MATCHED THEN
            INSERT (id_consorcio, nro_uf, piso, depto, superficie, coeficiente)
            VALUES (origen.id_consorcio, origen.nro_uf, origen.piso, origen.depto,
                    origen.superficie, origen.coeficiente)
        OUTPUT 
            CASE WHEN $action = 'INSERT' THEN inserted.id END
        INTO #UFsInsertadas (id_uf);

        SELECT 
            CASE WHEN ufi.id_uf IS NOT NULL THEN 'INSERT' ELSE 'UPDATE' END AS 'Accion',
            uf.id,
            ufl.id_consorcio, 
            ufl.nro_uf, 
            ufl.piso, 
            ufl.coeficiente, 
            ufl.depto, 
            ufl.superficie
        FROM #TempUFLimpias ufl
        INNER JOIN dba.Unidad_funcional uf ON uf.nro_uf = ufl.nro_uf AND uf.id_consorcio = ufl.id_consorcio
        LEFT JOIN #UFsInsertadas ufi ON uf.id = ufi.id_uf;

        --  cargar bauleras y cocheras en dba.Unidad_accesorio
        IF OBJECT_ID('tempdb..#TempAccesorios') IS NOT NULL
            DROP TABLE #TempAccesorios;

        CREATE TABLE #TempAccesorios (
            id_unidad_funcional      INT,
            id_tipo_unidad_accesorio INT,
            superficie               DECIMAL(12,2)
        );

        -- Bauleras tipo = 1
        INSERT INTO #TempAccesorios (id_unidad_funcional, id_tipo_unidad_accesorio, superficie)
        SELECT DISTINCT
            uf.id                                                   AS id_unidad_funcional,
            1                                                       AS id_tipo_unidad_accesorio,  
            TRY_CAST(TRIM(t.M2_Baulera) AS DECIMAL(12,2))          AS superficie
        FROM #TempUF t
        INNER JOIN dba.Consorcio c
            ON c.nombre = t.Nombre
        INNER JOIN dba.Unidad_funcional uf
            ON uf.id_consorcio = c.id
           AND uf.piso         = t.Piso
           AND uf.depto        = t.Departamento
        WHERE dba.CadenaNoVacia(t.Baulera) = 1
          AND UPPER(LTRIM(RTRIM(t.Baulera))) IN ('SI','S','1')
          AND TRY_CAST(TRIM(t.M2_Baulera) AS DECIMAL(12,2)) IS NOT NULL
          AND TRY_CAST(TRIM(t.M2_Baulera) AS DECIMAL(12,2)) > 0;

        -- Cocheras tipo = 0
        INSERT INTO #TempAccesorios (id_unidad_funcional, id_tipo_unidad_accesorio, superficie)
        SELECT DISTINCT
            uf.id                                                   AS id_unidad_funcional,
            0                                                       AS id_tipo_unidad_accesorio,  
            TRY_CAST(TRIM(t.M2_Cochera) AS DECIMAL(12,2))          AS superficie
        FROM #TempUF t
        INNER JOIN dba.Consorcio c
            ON c.nombre = t.Nombre
        INNER JOIN dba.Unidad_funcional uf
            ON uf.id_consorcio = c.id
           AND uf.piso         = t.Piso
           AND uf.depto        = t.Departamento
        WHERE dba.CadenaNoVacia(t.Cochera) = 1
          AND UPPER(LTRIM(RTRIM(t.Cochera))) IN ('SI','S','1')
          AND TRY_CAST(TRIM(t.M2_Cochera) AS DECIMAL(12,2)) IS NOT NULL
          AND TRY_CAST(TRIM(t.M2_Cochera) AS DECIMAL(12,2)) > 0;

        -- MERGE contra dba.Unidad_accesorio para evitar duplicados
        MERGE dba.Unidad_accesorio AS destino
        USING #TempAccesorios AS origen
            ON  destino.id_unidad_funcional      = origen.id_unidad_funcional
            AND destino.id_tipo_unidad_accesorio = origen.id_tipo_unidad_accesorio
        WHEN MATCHED THEN
            UPDATE SET destino.superficie = origen.superficie
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (superficie, id_unidad_funcional, id_tipo_unidad_accesorio)
            VALUES (origen.superficie, origen.id_unidad_funcional, origen.id_tipo_unidad_accesorio)
        OUTPUT $action, inserted.id, inserted.superficie, inserted.id_unidad_funcional, inserted.id_tipo_unidad_accesorio;

        DROP TABLE #TempAccesorios;


        DROP TABLE #TempUF;
        DROP TABLE #TempUFLimpias;
        DROP TABLE #UFsInsertadas;

    END TRY
    BEGIN CATCH
        DECLARE @MsjError  NVARCHAR(1000) = ERROR_MESSAGE();
        DECLARE @LineaError INT          = ERROR_LINE();

        RAISERROR('Error en linea %d: %s', 16, 1, @LineaError, @MsjError);
    END CATCH
END;
GO
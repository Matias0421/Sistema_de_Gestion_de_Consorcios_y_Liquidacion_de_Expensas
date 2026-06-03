/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del SP para la importación de gastos ordinarios que se registran por mes en los consorcios administrados.
*/

USE Com2900G11;
GO

USE Com2900G11;
GO

CREATE OR ALTER PROCEDURE dba.sp_ImportarServiciosJSON
	@RutaArchivo VARCHAR(4000),
	@Anio INT
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;
        
		DECLARE @JSON NVARCHAR(MAX);
		DECLARE @SQL NVARCHAR(MAX);
		SET @SQL = N'
			SELECT @JSONOUT = BulkColumn FROM OPENROWSET(
				BULK ''' + @RutaArchivo + ''', SINGLE_CLOB)
				AS datos
			';
		EXEC sp_executesql @SQL, N'@JSONOUT NVARCHAR(MAX) OUTPUT', @JSONOUT = @JSON OUTPUT;

		IF OBJECT_ID('tempdb..#TempServicio') IS NOT NULL DROP TABLE #TempServicio;
		CREATE TABLE #TempServicio (
			nombre VARCHAR(100),
			mes VARCHAR(50),
			bancarios VARCHAR(50),
			limpieza VARCHAR(50),
			administracion VARCHAR(50),
			seguros VARCHAR(50),
			gastos_generales VARCHAR(50),
			agua VARCHAR(50),
			luz VARCHAR(50),
			internet VARCHAR(50)
		);

		INSERT INTO #TempServicio
		SELECT * FROM OPENJSON(@JSON)
		WITH (
			nombre VARCHAR(100) '$."Nombre del consorcio"',
			mes VARCHAR(50) '$."Mes"',
			bancarios VARCHAR(50) '$."BANCARIOS"',
			limpieza VARCHAR(50) '$."LIMPIEZA"',
			administracion VARCHAR(50) '$."ADMINISTRACION"',
			seguros VARCHAR(50) '$."SEGUROS"',
			gastos_generales VARCHAR(50) '$."GASTOS GENERALES"',
			agua VARCHAR(50) '$."SERVICIOS PUBLICOS-Agua"',
			luz VARCHAR(50) '$."SERVICIOS PUBLICOS-Luz"',
			internet VARCHAR(50) '$."SERVICIOS PUBLICOS-Internet"'
		);

		ALTER TABLE #TempServicio ADD mes_num TINYINT, id_consorcio INT;

        UPDATE t
        SET
            t.nombre = dba.NormalizarNombre(t.nombre),
            t.mes = dba.NormalizarNombre(t.mes),

            t.bancarios = dba.FormatearDecimal(t.bancarios),
            t.limpieza = dba.FormatearDecimal(t.limpieza),
            t.administracion = dba.FormatearDecimal(t.administracion),
            t.seguros = dba.FormatearDecimal(t.seguros),
            t.gastos_generales = dba.FormatearDecimal(t.gastos_generales),
            t.agua = dba.FormatearDecimal(t.agua),
            t.luz = dba.FormatearDecimal(t.luz),
            t.internet = dba.FormatearDecimal(t.internet),
            t.mes_num = CASE LOWER(t.mes)
                WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
                WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
                WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
                WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
            END,
            t.id_consorcio = c.id
        FROM #TempServicio t
        LEFT JOIN dba.Consorcio c ON c.nombre = t.nombre;

        DECLARE @PrimerVto DATE, @SegundaVto DATE;
        SET @PrimerVto = DATEFROMPARTS(@Anio, 1, 10);
        SET @SegundaVto = DATEFROMPARTS(@Anio, 1, 25);
		
        DECLARE @ExpensasInsertadas TABLE (
            id INT PRIMARY KEY
        );

        SELECT 
            t.nombre,
            t.mes,
            CASE 
                WHEN t.id_consorcio IS NULL THEN 'Datos incompletos'
                WHEN t.mes_num IS NULL THEN 'Mes inválido'
                WHEN EXISTS (
                    SELECT 1 FROM dba.Expensa e
                    WHERE e.id_consorcio = t.id_consorcio
                      AND e.anio = @Anio
                      AND e.mes = t.mes_num
                ) THEN 'Expensa ya existente'
            END AS motivo_fallo
        FROM #TempServicio t
        WHERE t.id_consorcio IS NULL
           OR t.mes_num IS NULL
           OR EXISTS (
                SELECT 1 FROM dba.Expensa e
                WHERE e.id_consorcio = t.id_consorcio
                  AND e.anio = @Anio
                  AND e.mes = t.mes_num
            );

        INSERT INTO dba.Expensa (anio, mes, id_consorcio, primer_fecha_vto, segunda_fecha_vto)
        OUTPUT INSERTED.id INTO @ExpensasInsertadas(id)
        SELECT 
            @Anio,
            t.mes_num,
            t.id_consorcio,
            DATEFROMPARTS(@Anio, t.mes_num, 15),
            DATEFROMPARTS(@Anio, t.mes_num, 25)
        FROM #TempServicio t
        WHERE t.id_consorcio IS NOT NULL
          AND t.mes_num IS NOT NULL
          AND NOT EXISTS (
                SELECT 1 FROM dba.Expensa e
                WHERE e.id_consorcio = t.id_consorcio
                  AND e.anio = @Anio
                  AND e.mes = t.mes_num
            );

        INSERT INTO dba.Gasto (detalle, importe, cuota_actual, total_cuotas, id_tipo_gasto, id_expensa)
        OUTPUT 
            INSERTED.id_expensa,
            INSERTED.detalle,
            INSERTED.importe
        SELECT 
            g.detalle,
            g.importe,
            1, 1, 0,
            e.id
        FROM @ExpensasInsertadas ei
        JOIN dba.Expensa e ON e.id = ei.id
        JOIN #TempServicio t
              ON e.id_consorcio = t.id_consorcio
             AND e.anio = @Anio
             AND e.mes = t.mes_num
        CROSS APPLY (
            VALUES
                ('BANCARIOS', TRY_CAST(t.bancarios AS DECIMAL(12,2))),
                ('LIMPIEZA', TRY_CAST(t.limpieza AS DECIMAL(12,2))),
                ('ADMINISTRACION', TRY_CAST(t.administracion AS DECIMAL(12,2))),
                ('SEGUROS', TRY_CAST(t.seguros AS DECIMAL(12,2))),
                ('GASTOS GENERALES', TRY_CAST(t.gastos_generales AS DECIMAL(12,2))),
                ('AGUA', TRY_CAST(t.agua AS DECIMAL(12,2))),
                ('LUZ', TRY_CAST(t.luz AS DECIMAL(12,2))),
                ('INTERNET', TRY_CAST(t.internet AS DECIMAL(12,2)))
        ) AS g(detalle, importe)
        WHERE g.importe IS NOT NULL AND g.importe > 0;

       
       SELECT * FROM dba.Expensa e WHERE e.id IN (SELECT id FROM @ExpensasInsertadas);
	END TRY
	BEGIN CATCH
		DECLARE @MsjError NVARCHAR(1000) = ERROR_MESSAGE();
        DECLARE @LineaError INT = ERROR_LINE();

        RAISERROR('Error en linea %d: %s', 16, 1, @LineaError, @MsjError);
	END CATCH
END;
GO
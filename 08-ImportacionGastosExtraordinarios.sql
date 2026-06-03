/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del SP para la importación de gastos extraordinarios que se registran por mes en los consorcios administrados.
*/

USE Com2900G11;
GO

CREATE OR ALTER PROCEDURE dba.sp_ImportarExtraordinariasJSON
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
			cuota_actual VARCHAR(50),
			total_cuotas VARCHAR(50),
			importe VARCHAR(50),
			detalle VARCHAR(100)
		);

		INSERT INTO #TempServicio
		SELECT * FROM OPENJSON(@JSON)
		WITH (
			nombre VARCHAR(100) '$."Nombre del consorcio"',
			mes VARCHAR(50) '$."Mes"',
			cuota_actual VARCHAR(50) '$."Cuota actual"',
			total_cuotas VARCHAR(50) '$."Total cuotas"',
			importe VARCHAR(50) '$."Importe"',
			detalle VARCHAR(100) '$."Detalle"'
		);

		ALTER TABLE #TempServicio ADD mes_num TINYINT, id_consorcio INT;

		UPDATE t
		SET
			t.nombre = dba.NormalizarNombre(t.nombre),
			t.mes = dba.NormalizarNombre(t.mes),

			t.mes_num = CASE LOWER(t.mes)
                WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
                WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
                WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
                WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
            END,
			t.id_consorcio = c.id,
			t.importe = dba.FormatearDecimal(t.importe)
		FROM #TempServicio t
		LEFT JOIN dba.Consorcio c on c.nombre = t.nombre;
		
		SELECT * FROM #TempServicio;

		SELECT 
			t.nombre,
			t.mes,
			CASE
				WHEN t.id_consorcio IS NULL THEN 'Datos incompletos'
				WHEN t.mes_num IS NULL THEN 'Mes inválido'
				WHEN NOT EXISTS (
					SELECT 1 FROM dba.Expensa e
					WHERE e.id_consorcio = t.id_consorcio
						AND e.anio = @Anio
						AND e.mes = t.mes_num
				) THEN 'Expensa no cargada'
			END AS motivo_fallo
		FROM #TempServicio t
		WHERE t.id_consorcio IS NULL
			OR t.mes_num IS NULL 
			OR NOT EXISTS (
					SELECT 1 FROM dba.Expensa e
					WHERE e.id_consorcio = t.id_consorcio
						AND e.anio = @Anio
						AND e.mes = t.mes_num
			);

		MERGE dba.Gasto AS tgt
		USING (
			SELECT 
				t.detalle,
				TRY_CAST(t.importe AS DECIMAL(12,2)) AS importe,
				TRY_CAST(t.cuota_actual AS TINYINT) AS cuota_actual,
				TRY_CAST(t.total_cuotas AS TINYINT) AS total_cuotas,
				1 AS id_tipo_gasto,
				e.id AS id_expensa
			FROM dba.Expensa e 
			JOIN #TempServicio t 
				ON e.id_consorcio = t.id_consorcio 
				AND e.anio = @Anio 
				AND e.mes = t.mes_num
			WHERE TRY_CAST(t.importe AS DECIMAL(12,2)) IS NOT NULL 
			  AND TRY_CAST(t.importe AS DECIMAL(12,2)) > 0
		) AS src
		ON tgt.id_expensa = src.id_expensa
		   AND tgt.detalle = src.detalle

		WHEN MATCHED THEN
			UPDATE SET
				tgt.importe = src.importe,
				tgt.cuota_actual = src.cuota_actual,
				tgt.total_cuotas = src.total_cuotas,
				tgt.id_tipo_gasto = src.id_tipo_gasto

		WHEN NOT MATCHED THEN
			INSERT (detalle, importe, cuota_actual, total_cuotas, id_tipo_gasto, id_expensa)
			VALUES (src.detalle, src.importe, src.cuota_actual, src.total_cuotas, src.id_tipo_gasto, src.id_expensa)

		OUTPUT 
			$action AS accion,
			ISNULL(inserted.id_expensa, deleted.id_expensa) AS id_expensa,
			ISNULL(inserted.detalle, deleted.detalle) AS detalle,
			ISNULL(inserted.importe, deleted.importe) AS importe;

	END TRY
	BEGIN CATCH
		DECLARE @MsjError NVARCHAR(1000) = ERROR_MESSAGE();
		DECLARE @LineaError INT = ERROR_LINE();

		RAISERROR('Error en la linea %d: %s', 16, 1, @LineaError, @MsjError);
	END CATCH
END;
GO
/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del SP para la importación del archivo XLSX que posee la administración para llevar registro de los consorcios
*/

USE Com2900G11;
GO

CREATE OR ALTER PROCEDURE dba.sp_ImportarXLSXConsorcios
	@RutaArchivo VARCHAR(4000)
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		IF OBJECT_ID('tempdb..#TempConsorcios') IS NOT NULL DROP TABLE #TempConsorcios;

		CREATE TABLE #TempConsorcios(
			Consorcio VARCHAR(50),
			Nombre VARCHAR(50),
			Domicilio VARCHAR(50),
			Cant_unidades VARCHAR(50),
			M2_totales VARCHAR(50)
		);

		DECLARE @SQL NVARCHAR(MAX) = N'
			INSERT INTO #TempConsorcios (Consorcio, Nombre, Domicilio, Cant_unidades, M2_totales)
			SELECT Consorcio, [Nombre del consorcio], Domicilio, [Cant unidades funcionales], [m2 totales]
			FROM OPENROWSET(
				''Microsoft.ACE.OLEDB.12.0'',
				''Excel 12.0;Database=' + @RutaArchivo + ';HDR=YES'',
				''SELECT * FROM [Consorcios$]''
			);
		';
		EXEC(@SQL);

		IF OBJECT_ID('tempdb..#TempConsorciosLimpios') IS NOT NULL
			DROP TABLE #TempConsorciosLimpios;

		SELECT DISTINCT
			dba.NormalizarNombre(Nombre) as nombre,
			dba.NormalizarNombre(Domicilio) as domicilio,
			TRY_CAST(TRIM(M2_totales) AS DECIMAL) as superficie
		INTO #TempConsorciosLimpios
		FROM #tempConsorcios temp
		WHERE
			dba.CadenaNoVacia(temp.Nombre) = 1 AND
			dba.CadenaNoVacia(temp.Domicilio) = 1 AND
			dba.CadenaNoVacia(temp.M2_totales) = 1 AND
			TRY_CAST(TRIM(M2_totales) AS DECIMAL) > 0;

		MERGE dba.Consorcio AS destino
		USING #TempConsorciosLimpios AS origen
		ON destino.nombre = origen.nombre 
			AND destino.domicilio = origen.domicilio
		WHEN MATCHED THEN
			UPDATE SET
				destino.superficie_total = origen.superficie
		WHEN NOT MATCHED THEN
			INSERT (nombre, domicilio, superficie_total)
			VALUES (origen.nombre, origen.domicilio, origen.superficie)
		OUTPUT $action, inserted.id, inserted.nombre, inserted.domicilio, inserted.superficie_total;

		IF OBJECT_ID('tempdb..#TempConsorcios') IS NOT NULL 
			DROP TABLE #TempConsorcios;
		IF OBJECT_ID('tempdb..#TempConsorciosLimpios') IS NOT NULL
			DROP TABLE #TempConsorciosLimpios;

	END TRY
	BEGIN CATCH
		DECLARE @MsjError NVARCHAR(1000) = ERROR_MESSAGE();
        DECLARE @LineaError INT = ERROR_LINE();

        RAISERROR('Error en linea %d: %s', 16, 1, @LineaError, @MsjError);
	END CATCH
END;
GO

/* 
-- Habilitar configuración avanzada
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Habilitar consultas ad-hoc (OPENROWSET / OPENDATASOURCE)
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;

EXEC master.dbo.sp_MSset_oledb_prop
    N'Microsoft.ACE.OLEDB.12.0',
    N'AllowInProcess',
    1;
GO

EXEC master.dbo.sp_MSset_oledb_prop
    N'Microsoft.ACE.OLEDB.12.0',
    N'DynamicParameters',
    1;
GO
*/
/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del SP para la importación del archivo donde se asocia a cada inquilino/propietario con una UF perteneciente a los consorcios administrados
*/

USE Com2900G11;
GO

CREATE OR ALTER PROCEDURE dba.sp_ImportarCSVPersonaUF
	@RutaArchivo VARCHAR(4000),
	@SeparadorCampos VARCHAR(10) = '|',
	@FilaInicial INT = 2
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		IF OBJECT_ID('tempdb..#TempPersonaUF') IS NOT NULL DROP TABLE #TempPersonaUF;
		
		CREATE TABLE #TempPersonaUF (
			cvu_cbu VARCHAR(100),
			nombre_consorcio VARCHAR(100),
			nro_uf VARCHAR(10),
			piso VARCHAR(10),
			depto VARCHAR(10)
		);

		DECLARE @SQL NVARCHAR(MAX);
		SET @SQL = N'
			BULK INSERT #TempPersonaUF
			FROM ''' + @RutaArchivo + '''
			WITH (
				FIELDTERMINATOR = ''' + @SeparadorCampos + ''',
				ROWTERMINATOR = ''\n'',
				FIRSTROW = ' + CAST(@FilaInicial AS VARCHAR(10)) + '
			);
		';

		EXEC(@SQL);

		IF OBJECT_ID('tempdb..#TempPersonaUFLimpios') IS NOT NULL DROP TABLE #TempPersonaUFLimpios;

		SELECT DISTINCT
			cvu_cbu,
			nombre_consorcio,
			nro_uf,
			piso,
			depto
		INTO #TempPersonaUFLimpios
		FROM #TempPersonaUF
		WHERE dba.CadenaNoVacia(cvu_cbu) = 1 AND dba.CadenaNoVacia(nro_uf) = 1 AND dba.CadenaNoVacia(nombre_consorcio) = 1;

		UPDATE uf
		SET uf.dni_persona = p.dni
		OUTPUT inserted.id_consorcio, inserted.nro_uf, inserted.dni_persona
		FROM dba.Unidad_funcional uf
		INNER JOIN #TempPersonaUFLimpios tpu
			ON uf.id_consorcio = (SELECT c.id FROM dba.Consorcio c WHERE c.nombre = tpu.nombre_consorcio) AND uf.nro_uf = tpu.nro_uf
		INNER JOIN dba.Persona p
			ON p.cvu_o_cbu = tpu.cvu_cbu;

	END TRY
	BEGIN CATCH
        DECLARE @MsjError NVARCHAR(1000) = ERROR_MESSAGE();
        DECLARE @LineaError INT = ERROR_LINE();

        RAISERROR('Error en linea %d: %s', 16, 1, @LineaError, @MsjError);
	END CATCH
END;
GO


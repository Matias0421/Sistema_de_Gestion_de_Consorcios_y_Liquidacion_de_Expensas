/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del sp para la importación del registro de personas (inquilinos o propietarios) que presenta la administración.
*/

USE Com2900G11
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dba.sp_ImportarCSVPersonas
    @RutaArchivo NVARCHAR(4000),
    @SeparadorCampos NVARCHAR(10) = ';',
    @FilaInicial INT = 2
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        
        IF OBJECT_ID('tempdb..#TempPersonas') IS NOT NULL DROP TABLE #TempPersonas;
        CREATE TABLE #TempPersonas (
            Nombre NVARCHAR(250),
            Apellido NVARCHAR(250),
            DNI NVARCHAR(20),
            EmailPersonal NVARCHAR(250),
            Telefono NVARCHAR(50),
            CVU_CBU NVARCHAR(50),
            Inquilino NVARCHAR(10)
        );

        --SQL Dinamico para que permita que la ruta sea una variable. 
        DECLARE @SQL NVARCHAR(MAX);
        SET @SQL = N'
        BULK INSERT #TempPersonas
        FROM ''' + @RutaArchivo + N'''
        WITH (
            FIELDTERMINATOR = ''' + @SeparadorCampos + N''',
            ROWTERMINATOR = ''\n'',
            FIRSTROW = ' + CAST(@FilaInicial AS NVARCHAR(10)) + N',
            CODEPAGE = ''65001'',
            TABLOCK
        );';
        EXEC (@SQL);

        --Tabla para registrar errores 
        IF OBJECT_ID('tempdb..#ErroresPersonas') IS NOT NULL DROP TABLE #ErroresPersonas;
        CREATE TABLE #ErroresPersonas (
            TipoError NVARCHAR(100),
            DNI NVARCHAR(20),
            Nombre NVARCHAR(250),
            Apellido NVARCHAR(250),
            Email NVARCHAR(250),
            Telefono NVARCHAR(50),
            CVU_CBU NVARCHAR(50)
        );

        --Cargo el log de errores 
        -- VALIDACION DNI duplicado
        INSERT INTO #ErroresPersonas (TipoError, DNI, Nombre, Apellido, Email, Telefono, CVU_CBU)
        SELECT 'DNI duplicado', DNI, Nombre, Apellido, EmailPersonal, Telefono, CVU_CBU
        FROM #TempPersonas
        WHERE TRY_CAST(DNI AS INT) IS NOT NULL
        AND DNI IN (
            SELECT DNI
            FROM #TempPersonas
            WHERE TRY_CAST(DNI AS INT) IS NOT NULL
            GROUP BY DNI
            HAVING COUNT(*) > 1
        );

        -- VALIDACION - DNI vacio
        INSERT INTO #ErroresPersonas (TipoError, DNI, Nombre, Apellido, Email, Telefono, CVU_CBU)
        SELECT 'DNI nulo/vac�o', DNI, Nombre, Apellido, EmailPersonal, Telefono, CVU_CBU
        FROM #TempPersonas
        WHERE DNI IS NULL OR LTRIM(RTRIM(DNI)) = '';

        -- VALIDACION - DNI no numerico
        INSERT INTO #ErroresPersonas (TipoError, DNI, Nombre, Apellido, Email, Telefono, CVU_CBU)
        SELECT 'DNI no num�rico', DNI, Nombre, Apellido, EmailPersonal, Telefono, CVU_CBU
        FROM #TempPersonas
        WHERE TRY_CAST(DNI AS INT) IS NULL AND DNI IS NOT NULL AND LTRIM(RTRIM(DNI)) <> '';

        -- VALIDACION - mail invalido
        INSERT INTO #ErroresPersonas (TipoError, DNI, Nombre, Apellido, Email, Telefono, CVU_CBU)
        SELECT 'Email inv�lido', DNI, Nombre, Apellido, EmailPersonal, Telefono, CVU_CBU
        FROM #TempPersonas
        WHERE EmailPersonal NOT LIKE '%_@_%._%';

        -- vuelco los validos a una limpia.
        IF OBJECT_ID('tempdb..#TempPersonasLimpias') IS NOT NULL DROP TABLE #TempPersonasLimpias;
        SELECT DISTINCT
        TRY_CAST(DNI AS INT) AS dni,
        dba.NormalizarNombre(LTRIM(RTRIM(Nombre))) AS nombre,
        dba.NormalizarNombre(LTRIM(RTRIM(Apellido))) AS apellido,
        LOWER(REPLACE(LTRIM(RTRIM(EmailPersonal)), ' ', '')) AS email,
        LTRIM(RTRIM(Telefono)) AS nro_telefono,
        LEFT(LTRIM(RTRIM(CVU_CBU)), 22) AS cvu_o_cbu,
        CASE WHEN TRY_CAST(Inquilino AS INT) = 1 THEN 0 ELSE 1 END AS id_tipo_persona
        INTO #TempPersonasLimpias
        FROM #TempPersonas
        WHERE 
            TRY_CAST(DNI AS INT) IS NOT NULL
            AND LTRIM(RTRIM(DNI)) <> ''
            AND TRY_CAST(DNI AS INT) NOT IN (
            SELECT TRY_CAST(DNI AS INT)
            FROM #TempPersonas
            WHERE TRY_CAST(DNI AS INT) IS NOT NULL
            GROUP BY TRY_CAST(DNI AS INT)
            HAVING COUNT(*) > 1
        )
        AND EmailPersonal LIKE '%_@_%._%';

        IF OBJECT_ID('tempdb..#ResultadoMerge') IS NOT NULL DROP TABLE #ResultadoMerge;

        CREATE TABLE #ResultadoMerge (
            accion VARCHAR(10),
            dni INT,
            nombre VARCHAR(250),
            apellido VARCHAR(250),
            email VARCHAR(250),
            nro_telefono VARCHAR(250),
            cvu_o_cbu VARCHAR(250),
            id_tipo_persona VARCHAR(250)
        );

        -- vuelco los finales a la tabla original. 
        MERGE dba.Persona AS destino
        USING #TempPersonasLimpias AS origen
        ON destino.dni = origen.dni
        WHEN MATCHED THEN
            UPDATE SET
                destino.nombre = origen.nombre,
                destino.apellido = origen.apellido,
                destino.email = origen.email,
                destino.nro_telefono = origen.nro_telefono,
                destino.cvu_o_cbu = origen.cvu_o_cbu,
                destino.id_tipo_persona = origen.id_tipo_persona
        WHEN NOT MATCHED THEN
            INSERT (dni, nombre, apellido, email, nro_telefono, cvu_o_cbu, id_tipo_persona)
            VALUES (origen.dni, origen.nombre, origen.apellido, origen.email, origen.nro_telefono, origen.cvu_o_cbu, origen.id_tipo_persona)
        OUTPUT $action, inserted.dni, inserted.nombre, inserted.apellido, inserted.email, inserted.nro_telefono, inserted.cvu_o_cbu, inserted.id_tipo_persona
        INTO #ResultadoMerge (accion, dni, nombre, apellido, email, nro_telefono, cvu_o_cbu, id_tipo_persona);

        SELECT * FROM #ResultadoMerge;

        IF OBJECT_ID('tempdb..#TempPersonas') IS NOT NULL
            DROP TABLE #TempPersonas;

        IF OBJECT_ID('tempdb..#TempPersonasLimpias') IS NOT NULL
            DROP TABLE #TempPersonasLimpias;
    END TRY
    BEGIN CATCH
		DECLARE @MsjError NVARCHAR(1000) = ERROR_MESSAGE();
        DECLARE @LineaError INT = ERROR_LINE();

        RAISERROR('Error en linea %d: %s', 16, 1, @LineaError, @MsjError);
    END CATCH
END;
GO
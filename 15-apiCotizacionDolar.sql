/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Integración de la API del precio del dólar según una fecha de referencia. Posterior creación del SP que se utiliza para replicar el reporte 5,
        agregándole el valor de la morosidad resultante en USD
*/

USE Com2900G11;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('dba.DolarOficialHistorial', 'U') IS NULL
BEGIN
    CREATE TABLE dba.DolarOficialHistorial (
        id                 INT IDENTITY PRIMARY KEY,
        fecha_ejecucion    DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
        moneda             VARCHAR(10),
        casa               VARCHAR(50),
        nombre             VARCHAR(50),
        compra             DECIMAL(18,2),
        venta              DECIMAL(18,2),
        fecha_actualizacion DATETIME2
    );
END;
GO
CREATE OR ALTER PROCEDURE dba.sp_ActualizarDolarOficial
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @cmd   NVARCHAR(4000);
        DECLARE @json  NVARCHAR(MAX);

        SET @cmd = 'curl -s "https://dolarapi.com/v1/dolares/oficial"';

        IF OBJECT_ID('tempdb..#curl') IS NOT NULL DROP TABLE #curl;
        CREATE TABLE #curl (linea NVARCHAR(MAX));

        INSERT INTO #curl (linea)
        EXEC xp_cmdshell @cmd;

        SELECT @json = STRING_AGG(linea, '')
        FROM #curl
        WHERE linea IS NOT NULL;

        -- Parseamos el JSON y lo insertamos
        DECLARE @moneda VARCHAR(10),
                @casa   VARCHAR(50),
                @nombre VARCHAR(50),
                @compra DECIMAL(18,2),
                @venta  DECIMAL(18,2),
                @fechaAct DATETIME2;

        SELECT
            @moneda  = moneda,
            @casa    = casa,
            @nombre  = nombre,
            @compra  = compra,
            @venta   = venta,
            @fechaAct = fechaActualizacion
        FROM OPENJSON(@json)
        WITH (
            moneda            VARCHAR(10)   '$.moneda',
            casa              VARCHAR(50)   '$.casa',
            nombre            VARCHAR(50)   '$.nombre',
            compra            DECIMAL(18,2) '$.compra',
            venta             DECIMAL(18,2) '$.venta',
            fechaActualizacion DATETIME2    '$.fechaActualizacion'
        );

        INSERT INTO dba.DolarOficialHistorial
            (moneda, casa, nombre, compra, venta, fecha_actualizacion)
        VALUES
            (@moneda, @casa, @nombre, @compra, @venta, @fechaAct);

        -- Devolvemos el ultimo valor insertado
        SELECT TOP 1 *
        FROM dba.DolarOficialHistorial
        ORDER BY id DESC;
    END TRY
    BEGIN CATCH
        DECLARE @MsjError NVARCHAR(1000) = ERROR_MESSAGE();
        DECLARE @LineaError INT = ERROR_LINE();
        RAISERROR('Error en linea %d: %s', 16, 1, @LineaError, @MsjError);
    END CATCH
END;
GO
--Sp para convertir pesos a dolar (oficial)
CREATE OR ALTER FUNCTION dba.fn_ConvertirARS_A_USD
(
    @MontoARS DECIMAL(18,2),
    @Fecha    DATETIME2 = NULL
)
RETURNS DECIMAL(18,6)
AS
BEGIN
    DECLARE @venta DECIMAL(18,2);

    IF @Fecha IS NULL
    BEGIN
        SELECT TOP 1 @venta = venta
        FROM dba.DolarOficialHistorial
        ORDER BY fecha_actualizacion DESC, id DESC;
    END
    ELSE
    BEGIN
        SELECT TOP 1 @venta = venta
        FROM dba.DolarOficialHistorial
        WHERE fecha_actualizacion <= @Fecha
        ORDER BY fecha_actualizacion DESC, id DESC;
    END

    IF @MontoARS IS NULL OR @venta IS NULL OR @venta <= 0
        RETURN NULL;

    RETURN @MontoARS / @venta; 
END;
GO
--Version del reporte 5 pero con el valor en dolares 
CREATE OR ALTER PROCEDURE dba.sp_ReporteTopMorososUSD
    @Anio INT = NULL,
    @Mes INT = NULL,
    @IdConsorcio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dba.DolarOficialHistorial)
    BEGIN
        PRINT('No hay cotizaciones en dba.DolarOficialHistorial. Ejecute dba.sp_ActualizarDolarOficial primero.');
        RETURN;
    END;

    DECLARE @FechaRef DATETIME2 = SYSDATETIME();

    WITH ExpensasFiltradas AS (
        SELECT E.*
        FROM dba.Expensa E
        WHERE (@IdConsorcio IS NULL OR E.id_consorcio = @IdConsorcio)
          AND (@Anio IS NULL OR E.anio = @Anio)
          AND (@Mes IS NULL OR E.mes = @Mes)
    ),

    ExpensaConTotal AS (
        SELECT 
            E.id AS id_expensa,
            E.id_consorcio,
            E.anio,
            E.mes,
            E.primer_fecha_vto,
            E.segunda_fecha_vto,
            SUM(G.importe) AS total_expensa
        FROM ExpensasFiltradas E
        INNER JOIN dba.Gasto G ON G.id_expensa = E.id
        GROUP BY 
            E.id, E.id_consorcio, E.anio, E.mes, E.primer_fecha_vto, E.segunda_fecha_vto
    ),

    ExpensaPorUF AS (
        SELECT 
            UF.id AS id_uf,
            UF.dni_persona,
            UF.coeficiente,
            EX.*,
            (EX.total_expensa * UF.coeficiente / 100) AS monto_uf
        FROM ExpensaConTotal EX
        INNER JOIN dba.Unidad_funcional UF 
            ON UF.id_consorcio = EX.id_consorcio
    ),

    PagosPorUF AS (
        SELECT 
            P.id_uf,
            P.importe,
            P.fecha,
            YEAR(P.fecha) AS anio_pago,
            MONTH(P.fecha) AS mes_pago
        FROM dba.Pago P
    ),

    PagosFiltrados AS (
        SELECT 
            PP.id_uf,
            SUM(PP.importe) AS total_pagado,
            MIN(PP.fecha) AS primer_pago,
            MAX(PP.fecha) AS ultimo_pago
        FROM PagosPorUF PP
        INNER JOIN ExpensaPorUF EX 
            ON EX.id_uf = PP.id_uf 
           AND EX.anio = PP.anio_pago
           AND EX.mes = PP.mes_pago
        GROUP BY PP.id_uf
    ),

    Morosidad AS (
        SELECT
            EX.id_uf,
            EX.dni_persona,
            EX.id_consorcio,
            EX.anio,
            EX.mes,
            EX.monto_uf,
            ISNULL(PF.total_pagado, 0) AS total_pagado,

            CASE 
                WHEN PF.total_pagado IS NULL OR PF.total_pagado = 0
                     THEN EX.monto_uf * 0.05   -- no pago nada
                ELSE
                (
                    -- intereses por tramo
                    CASE WHEN PF.primer_pago > EX.primer_fecha_vto
                         AND PF.primer_pago <= EX.segunda_fecha_vto
                         THEN (EX.monto_uf - PF.total_pagado) * 0.02
                         ELSE 0 END
                    +
                    CASE WHEN PF.ultimo_pago > EX.segunda_fecha_vto
                         THEN (EX.monto_uf - PF.total_pagado) * 0.05
                         ELSE 0 END
                )
            END AS morosidad_calculada
        FROM ExpensaPorUF EX
        LEFT JOIN PagosFiltrados PF ON PF.id_uf = EX.id_uf
    )
    SELECT TOP(3)
        M.id_uf,
        M.dni_persona AS dni,
        P.nombre,
        P.apellido,
        P.email,
        P.nro_telefono,
        M.anio,
        M.mes,
        M.total_pagado,
        M.monto_uf,
        (M.monto_uf - M.total_pagado) AS pendiente_expensa,
        M.morosidad_calculada,
        (M.monto_uf - M.total_pagado + M.morosidad_calculada) AS total_pendiente,
        dba.fn_ConvertirARS_A_USD((M.monto_uf - M.total_pagado + M.morosidad_calculada), @FechaRef) AS total_pendiente_USD,
        @FechaRef AS fecha_ref
    INTO #TopMorosos
    FROM Morosidad M
    INNER JOIN dba.Persona P ON P.dni = M.dni_persona
    ORDER BY M.morosidad_calculada DESC;

    SELECT 
        id_uf,
        dni,
        nombre,
        apellido,
        email,
        nro_telefono,
        anio,
        mes,
        pendiente_expensa,
        morosidad_calculada,
        total_pendiente,
        total_pendiente_USD,
        fecha_ref
    FROM #TopMorosos;

    SELECT 
        id_uf AS "@UF",
        dni AS "@DNI",
        CONCAT(nombre, ' ', apellido) AS "@NombreCompleto",
        email AS "@Email",
        nro_telefono AS "@Telefono",
        pendiente_expensa AS "@PendienteExpensa",
        morosidad_calculada AS "@Morosidad",
        total_pendiente AS "@TotalPendiente",
        total_pendiente_usd AS "@TotalPendienteUSD",
        fecha_ref AS "@FechaReferencia",
        anio AS "@Anio",
        mes AS "@Mes"
    FROM #TopMorosos
    FOR XML PATH('Moroso'), ROOT('TopMorosos');

END
GO
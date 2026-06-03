/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación de los SP que se utilizarán como reportes pedidos en la entrega nro. 6
*/

USE Com2900G11;
GO
SET NOCOUNT ON;
GO

-- REPORTE 1
CREATE OR ALTER PROCEDURE dba.sp_ReporteFlujoCajaSemanal
    @FechaInicio DATE,
    @FechaFin DATE,
    @IdConsorcio INT = NULL,
    @TipoGasto INT = NULL  -- 0=Ordinario, 1=Extraordinario
AS
BEGIN
    SET NOCOUNT ON;

    WITH Semanas AS (
        SELECT 
            DATEPART(YEAR, fecha) AS Anio,
            DATEPART(WEEK, fecha) AS Semana,
            MIN(fecha) AS FechaInicioSemana,
            MAX(fecha) AS FechaFinSemana
        FROM dba.Pago p
        WHERE p.fecha BETWEEN @FechaInicio AND @FechaFin
        GROUP BY DATEPART(YEAR, fecha), DATEPART(WEEK, fecha)
    ),
    RecaudacionSemanal AS (
        SELECT 
            s.Anio,
            s.Semana,
            s.FechaInicioSemana,
            s.FechaFinSemana,
            COALESCE(SUM(CASE WHEN tg.id = 0 THEN p.importe ELSE 0 END), 0) AS RecaudacionOrdinaria,
            COALESCE(SUM(CASE WHEN tg.id = 1 THEN p.importe ELSE 0 END), 0) AS RecaudacionExtraordinaria,
            COUNT(p.id) AS CantidadPagos
        FROM Semanas s
        LEFT JOIN dba.Pago p ON p.fecha BETWEEN s.FechaInicioSemana AND s.FechaFinSemana
        LEFT JOIN dba.Unidad_funcional uf ON p.id_uf = uf.id
        LEFT JOIN dba.Expensa e ON uf.id_consorcio = e.id_consorcio 
            AND YEAR(p.fecha) = e.anio AND MONTH(p.fecha) = e.mes
        LEFT JOIN dba.Gasto g ON e.id = g.id_expensa
        LEFT JOIN dba.Tipo_gasto tg ON g.id_tipo_gasto = tg.id
        WHERE (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
          AND (@TipoGasto IS NULL OR tg.id = @TipoGasto)
        GROUP BY s.Anio, s.Semana, s.FechaInicioSemana, s.FechaFinSemana
    ),
    Estadisticas AS (
        SELECT 
            Anio,
            Semana,
            FechaInicioSemana,
            FechaFinSemana,
            RecaudacionOrdinaria,
            RecaudacionExtraordinaria,
            RecaudacionOrdinaria + RecaudacionExtraordinaria AS RecaudacionTotal,
            AVG(RecaudacionOrdinaria + RecaudacionExtraordinaria) OVER() AS PromedioPeriodo,
            SUM(RecaudacionOrdinaria + RecaudacionExtraordinaria) OVER(
                ORDER BY Anio, Semana 
                ROWS UNBOUNDED PRECEDING
            ) AS AcumuladoProgresivo
        FROM RecaudacionSemanal
    )
    SELECT 
        Anio,
        Semana,
        FechaInicioSemana,
        FechaFinSemana,
        RecaudacionOrdinaria,
        RecaudacionExtraordinaria,
        RecaudacionTotal,
        ROUND(PromedioPeriodo, 2) AS PromedioPeriodo,
        AcumuladoProgresivo
    FROM Estadisticas
    ORDER BY Anio, Semana;
END;
GO

-- REPORTE 2
CREATE OR ALTER PROCEDURE dba.sp_ReporteRecaudacionMensualDepartamento
    @Anio INT,
    @MesInicio INT = 1,
    @MesFin INT = 12,
    @IdConsorcio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Columns NVARCHAR(MAX) = '';

    IF OBJECT_ID('tempdb..#Meses') IS NOT NULL DROP TABLE #Meses;
    
    CREATE TABLE #Meses (
        MesNum INT,
        MesNombre NVARCHAR(20)
    );
    
    INSERT INTO #Meses (MesNum, MesNombre)
    VALUES 
        (1, 'Enero'), (2, 'Febrero'), (3, 'Marzo'), (4, 'Abril'), 
        (5, 'Mayo'), (6, 'Junio'), (7, 'Julio'), (8, 'Agosto'),
        (9, 'Septiembre'), (10, 'Octubre'), (11, 'Noviembre'), (12, 'Diciembre');

    SELECT @Columns += QUOTENAME(MesNombre) + ','
    FROM #Meses
    WHERE MesNum BETWEEN @MesInicio AND @MesFin;

    SET @Columns = LEFT(@Columns, LEN(@Columns) - 1);

    SET @SQL = N'
    WITH RecaudacionMensual AS (
        SELECT 
            uf.depto AS Departamento,
            m.MesNombre AS MesNombre,
            COALESCE(SUM(p.importe), 0) AS TotalRecaudado
        FROM #Meses m
        CROSS JOIN (SELECT DISTINCT depto FROM dba.Unidad_funcional WHERE (@IdConsorcioParam IS NULL OR id_consorcio = @IdConsorcioParam)) ufd
        LEFT JOIN dba.Unidad_funcional uf ON ufd.depto = uf.depto AND (@IdConsorcioParam IS NULL OR uf.id_consorcio = @IdConsorcioParam)
        LEFT JOIN dba.Pago p ON uf.id = p.id_uf AND YEAR(p.fecha) = @AnioParam AND MONTH(p.fecha) = m.MesNum
        WHERE m.MesNum BETWEEN @MesInicioParam AND @MesFinParam
        GROUP BY uf.depto, m.MesNum, m.MesNombre
    )
    SELECT Departamento, ' + @Columns + '
    FROM RecaudacionMensual
    PIVOT (
        SUM(TotalRecaudado)
        FOR MesNombre IN (' + @Columns + ')
    ) AS PivotTable
    ORDER BY Departamento;';

    EXEC sp_executesql @SQL, 
        N'@AnioParam INT, @MesInicioParam INT, @MesFinParam INT, @IdConsorcioParam INT',
        @AnioParam = @Anio, @MesInicioParam = @MesInicio, @MesFinParam = @MesFin, @IdConsorcioParam = @IdConsorcio;

    DROP TABLE #Meses;
END;
GO

-- REPORTE 3
CREATE OR ALTER PROCEDURE dba.sp_ReporteRecaudacionPorTipo
    @Anio INT,
    @IdConsorcio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --nombres de meses FORZADOS en español
    SELECT 
        TipoGasto,
        ISNULL([Enero], 0) AS Enero,
        ISNULL([Febrero], 0) AS Febrero,
        ISNULL([Marzo], 0) AS Marzo,
        ISNULL([Abril], 0) AS Abril,
        ISNULL([Mayo], 0) AS Mayo,
        ISNULL([Junio], 0) AS Junio,
        ISNULL([Julio], 0) AS Julio,
        ISNULL([Agosto], 0) AS Agosto,
        ISNULL([Septiembre], 0) AS Septiembre,
        ISNULL([Octubre], 0) AS Octubre,
        ISNULL([Noviembre], 0) AS Noviembre,
        ISNULL([Diciembre], 0) AS Diciembre
    FROM (
        SELECT 
            tg.tipo AS TipoGasto,
            CASE e.mes
                WHEN 1 THEN 'Enero'
                WHEN 2 THEN 'Febrero' 
                WHEN 3 THEN 'Marzo'
                WHEN 4 THEN 'Abril'
                WHEN 5 THEN 'Mayo'
                WHEN 6 THEN 'Junio'
                WHEN 7 THEN 'Julio'
                WHEN 8 THEN 'Agosto'
                WHEN 9 THEN 'Septiembre'
                WHEN 10 THEN 'Octubre'
                WHEN 11 THEN 'Noviembre'
                WHEN 12 THEN 'Diciembre'
            END AS MesNombre,
            SUM(p.importe) AS TotalRecaudado
        FROM dba.Pago p
        INNER JOIN dba.Unidad_funcional uf ON p.id_uf = uf.id
        INNER JOIN dba.Expensa e ON uf.id_consorcio = e.id_consorcio 
            AND YEAR(p.fecha) = e.anio 
            AND MONTH(p.fecha) = e.mes
        INNER JOIN dba.Gasto g ON e.id = g.id_expensa
        INNER JOIN dba.Tipo_gasto tg ON g.id_tipo_gasto = tg.id
        WHERE e.anio = @Anio
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
        GROUP BY tg.tipo, e.mes
    ) AS SourceTable
    PIVOT (
        SUM(TotalRecaudado)
        FOR MesNombre IN (
            [Enero], [Febrero], [Marzo], [Abril], [Mayo], [Junio],
            [Julio], [Agosto], [Septiembre], [Octubre], [Noviembre], [Diciembre]
        )
    ) AS PivotTable
    ORDER BY 
        CASE TipoGasto 
            WHEN 'Ordinario' THEN 1 
            WHEN 'Extraordinario' THEN 2 
            ELSE 3 
        END;
END;
GO

-- REPORTE 4
CREATE OR ALTER PROCEDURE dba.sp_ReporteTopMesesGastosIngresos
    @Anio INT,
    @IdConsorcio INT = NULL,
    @TipoOrden VARCHAR(10) = 'AMBOS' -- 'GASTOS', 'INGRESOS', 'AMBOS'
AS
BEGIN
    SET NOCOUNT ON;

	--mayores gastos
    IF @TipoOrden IN ('GASTOS', 'AMBOS')
    BEGIN
        SELECT TOP 5
            'MAYORES_GASTOS' AS Tipo,
            e.anio AS Anio,
            e.mes AS Mes,
            DATENAME(MONTH, DATEFROMPARTS(e.anio, e.mes, 1)) AS MesNombre,
            SUM(g.importe) AS TotalGastos,
            COUNT(g.id) AS CantidadGastos
        FROM dba.Expensa e
        INNER JOIN dba.Gasto g ON e.id = g.id_expensa
        WHERE e.anio = @Anio
          AND (@IdConsorcio IS NULL OR e.id_consorcio = @IdConsorcio)
        GROUP BY e.anio, e.mes
        ORDER BY TotalGastos DESC;
    END

	--mayores ingresos
    IF @TipoOrden IN ('INGRESOS', 'AMBOS')
    BEGIN
        SELECT TOP 5
            'MAYORES_INGRESOS' AS Tipo,
            e.anio AS Anio,
            e.mes AS Mes,
            DATENAME(MONTH, DATEFROMPARTS(e.anio, e.mes, 1)) AS MesNombre,
            SUM(p.importe) AS TotalIngresos,
            COUNT(p.id) AS CantidadPagos
        FROM dba.Expensa e
        INNER JOIN dba.Unidad_funcional uf ON e.id_consorcio = uf.id_consorcio
        INNER JOIN dba.Pago p ON uf.id = p.id_uf 
            AND YEAR(p.fecha) = e.anio AND MONTH(p.fecha) = e.mes
        WHERE e.anio = @Anio
          AND (@IdConsorcio IS NULL OR e.id_consorcio = @IdConsorcio)
        GROUP BY e.anio, e.mes
        ORDER BY TotalIngresos DESC;
    END
END;
GO

-- REPORTE 5
/* 
    Aclaración: este reporte calcula los top 3 morosos de acuerdo a la morosidad de un mes individualmente, no la acumulación de morosidad a lo largo de varios meses.
    En caso de que no se aclare un mes como parámetro, devolverá el top 3 de propietarios que mayor morosidad debieron al final de un mes en específico, por lo que puede, por ejemplo,
    mostrar que el usuario 1 debía $50.000 en junio, el usuario 2 debía $35.000 en mayo, etc.
*/
CREATE OR ALTER PROCEDURE dba.sp_ReporteTopMorosos
    @IdConsorcio INT = NULL,
    @Anio SMALLINT = NULL,
    @Mes TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

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
        (M.monto_uf - M.total_pagado + M.morosidad_calculada) AS total_pendiente
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
        total_pendiente
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
        anio AS "@Anio",
        mes AS "@Mes"
    FROM #TopMorosos
    FOR XML PATH('Moroso'), ROOT('TopMorosos');

END
GO

-- REPORTE 6
CREATE OR ALTER PROCEDURE dba.sp_ReporteIntervalosEntrePagos
    @Anio INT = NULL,
    @IdConsorcio INT = NULL,
    @DNIPropietario INT = NULL,
    @MostrarSoloConIntervalos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#PagosBase') IS NOT NULL DROP TABLE #PagosBase;
    
    SELECT 
        p.dni,
        p.nombre + ' ' + p.apellido AS Propietario,
        c.nombre AS Consorcio,
        c.id AS IdConsorcio,
        uf.id AS IdUF,
        uf.piso + ' ' + uf.depto AS Departamento,
        uf.nro_uf AS NroUF,
        pg.fecha AS FechaPago,
        pg.importe,
        e.anio,
        e.mes,
        e.primer_fecha_vto,
        LAG(pg.fecha) OVER (PARTITION BY uf.id ORDER BY pg.fecha) AS FechaPagoAnterior,
        DATEDIFF(DAY, LAG(pg.fecha) OVER (PARTITION BY uf.id ORDER BY pg.fecha), pg.fecha) AS DiasEntrePagos,
        DATEDIFF(DAY, e.primer_fecha_vto, pg.fecha) AS DiasDemoraVencimiento,
        ROW_NUMBER() OVER (PARTITION BY uf.id ORDER BY pg.fecha) AS OrdenPago,
        COUNT(pg.id) OVER (PARTITION BY uf.id) AS TotalPagosUF
    INTO #PagosBase
    FROM dba.Pago pg
    INNER JOIN dba.Unidad_funcional uf ON pg.id_uf = uf.id
    INNER JOIN dba.Persona p ON uf.dni_persona = p.dni
    INNER JOIN dba.Consorcio c ON uf.id_consorcio = c.id
    INNER JOIN dba.Expensa e ON uf.id_consorcio = e.id_consorcio 
        AND YEAR(pg.fecha) = e.anio AND MONTH(pg.fecha) = e.mes
    INNER JOIN dba.Gasto g ON e.id = g.id_expensa
    INNER JOIN dba.Tipo_gasto tg ON g.id_tipo_gasto = tg.id
    WHERE tg.id = 0  -- Solo expensas ordinarias
      AND (@Anio IS NULL OR e.anio = @Anio)
      AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
      AND (@DNIPropietario IS NULL OR p.dni = @DNIPropietario);

    IF OBJECT_ID('tempdb..#EstadisticasUF') IS NOT NULL DROP TABLE #EstadisticasUF;
    
    SELECT 
        IdUF,
        AVG(DiasEntrePagos) AS PromedioDiasEntrePagos,
        MAX(DiasEntrePagos) AS MaximoDiasEntrePagos,
        MIN(DiasEntrePagos) AS MinimoDiasEntrePagos,
        AVG(DiasDemoraVencimiento) AS PromedioDiasDemora
    INTO #EstadisticasUF
    FROM #PagosBase
    WHERE DiasEntrePagos IS NOT NULL
    GROUP BY IdUF;

    IF OBJECT_ID('tempdb..#ResultadoFinal') IS NOT NULL DROP TABLE #ResultadoFinal;
    
    SELECT 
        pb.dni AS DNI,
        pb.Propietario,
        pb.Consorcio,
        pb.Departamento,
        pb.NroUF,
        pb.anio AS Anio,
        pb.mes AS Mes,
        pb.primer_fecha_vto AS Vencimiento,
        pb.FechaPagoAnterior AS PagoAnterior,
        pb.FechaPago AS PagoActual,
        pb.DiasEntrePagos AS DiasEntrePagos,
        pb.DiasDemoraVencimiento AS DiasDemora,
        pb.OrdenPago AS OrdenPago,
        pb.TotalPagosUF AS TotalPagosUF,
        eu.PromedioDiasEntrePagos AS PromedioDiasEntrePagosUF,
        eu.PromedioDiasDemora AS PromedioDiasDemoraUF,
        pb.IdUF
    INTO #ResultadoFinal
    FROM #PagosBase pb
    LEFT JOIN #EstadisticasUF eu ON pb.IdUF = eu.IdUF
    WHERE (@MostrarSoloConIntervalos = 0 OR pb.DiasEntrePagos IS NOT NULL)
      AND (@Anio IS NULL OR pb.anio = @Anio);

    SELECT 
        DNI,
        Propietario,
        Consorcio,
        Departamento,
        NroUF,
        Anio,
        Mes,
        Vencimiento,
        PagoAnterior,
        PagoActual,
        DiasEntrePagos,
        DiasDemora,
        OrdenPago,
        TotalPagosUF,
        PromedioDiasEntrePagosUF,
        PromedioDiasDemoraUF
    FROM #ResultadoFinal
    ORDER BY Consorcio, NroUF, PagoActual;

    DECLARE @XMLResult XML;

    SET @XMLResult = (
        SELECT 
            rf.DNI AS "@DNI",
            rf.Propietario AS "@Nombre",
            rf.Consorcio AS "@Consorcio", 
            rf.Departamento AS "@Departamento",
            rf.NroUF AS "@NroUF",
            rf.TotalPagosUF AS "@TotalPagos",
            ISNULL(rf.PromedioDiasEntrePagosUF, 0) AS "@PromedioDiasEntrePagos",
            ISNULL(rf.PromedioDiasDemoraUF, 0) AS "@PromedioDiasDemora",
            (
                SELECT 
                    rf2.Anio AS "@Anio",
                    rf2.Mes AS "@Mes",
                    rf2.Vencimiento AS "@Vencimiento",
                    ISNULL(CONVERT(VARCHAR(10), rf2.PagoAnterior, 120), '') AS "@FechaPagoAnterior", 
                    CONVERT(VARCHAR(10), rf2.PagoActual, 120) AS "@FechaPagoActual",
                    ISNULL(rf2.DiasEntrePagos, 0) AS "@DiasEntrePagos",
                    ISNULL(rf2.DiasDemora, 0) AS "@DiasDemoraVencimiento",
                    rf2.OrdenPago AS "@OrdenPago"
                FROM #ResultadoFinal rf2
                WHERE rf2.IdUF = rf.IdUF
                ORDER BY rf2.PagoActual
                FOR XML PATH('Pago'), TYPE
            ) AS 'HistorialPagos'
        FROM (SELECT DISTINCT IdUF, DNI, Propietario, Consorcio, Departamento, 
                             NroUF, TotalPagosUF, PromedioDiasEntrePagosUF, PromedioDiasDemoraUF
              FROM #ResultadoFinal) rf
        ORDER BY rf.PromedioDiasEntrePagosUF DESC
        FOR XML PATH('AnalisisPagos'), ROOT('AnalisisIntervalosPagos')
    );

    SELECT @XMLResult AS ResultadoXML;

    IF @XMLResult IS NOT NULL
        PRINT 'XML generado exitosamente';
    ELSE
        PRINT 'Error: XML nulo';

    -- Limpiar tablas temporales
    DROP TABLE #PagosBase;
    DROP TABLE #EstadisticasUF;
    DROP TABLE #ResultadoFinal;
END;
GO


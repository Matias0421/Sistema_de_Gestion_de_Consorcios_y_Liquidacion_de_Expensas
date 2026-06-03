/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Facilitación de ejecución de los reportes para poder analizar sus resultados.
*/

USE Com2900G11;
GO
SET NOCOUNT ON;
GO

-- REPORTE 1: Flujo de caja semanal
EXEC dba.sp_ReporteFlujoCajaSemanal 
    @FechaInicio = '2025-04-01',
    @FechaFin = '2025-06-30',
    @IdConsorcio = 4, 
    @TipoGasto = 0;

-- REPORTE 2: Recaudacion mensual por depto
EXEC dba.sp_ReporteRecaudacionMensualDepartamento 
    @Anio = 2025,
    @MesInicio = 1,
    @MesFin = 12,
    @IdConsorcio = 4;

-- REPORTE 3: Recaudacion x tipo y periodo
EXEC dba.sp_ReporteRecaudacionPorTipo 
    @Anio = 2025,
    @IdConsorcio = 3;

-- REPORTE 4: Top 5 meses > gastos e ingresos
EXEC dba.sp_ReporteTopMesesGastosIngresos 
    @Anio = 2025,
    @IdConsorcio = 4,
    @TipoOrden = 'AMBOS';

-- REPORTE 5: Top 3 morosos del mes
EXEC dba.sp_ReporteTopMorosos
    @Anio = 2025,
    @Mes = 4,
    @IdConsorcio = 4; 

-- REPORTE 6
EXEC dba.sp_ReporteIntervalosEntrePagos 
    @Anio = 2025,
    @IdConsorcio = 4, 
    @DNIPropietario = NULL,
    @MostrarSoloConIntervalos = 1;

-- API Cotización dólar y reporte 5 con morosidad en USD
EXEC dba.sp_ActualizarDolarOficial;      
EXEC dba.sp_ReporteTopMorososUSD;   
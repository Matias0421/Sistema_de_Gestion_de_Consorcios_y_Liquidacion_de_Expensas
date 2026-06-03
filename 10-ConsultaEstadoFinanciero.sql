/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del SP para la consulta del estado financiero de una unidad funcional en un mes y año determinado. 
			En caso de que no se especifique un periodo, se tomará el periodo de la última expensa registrada a nombre del consorcio al que pertenece la UF.
*/

USE Com2900G11; 
GO

CREATE OR ALTER PROCEDURE dba.sp_ConsultarEstadoFinanciero @Anio INT = NULL, @Mes INT = NULL, @IdUF INT 
AS 
BEGIN 
	SET NOCOUNT ON; 
	IF NOT EXISTS (SELECT 1 FROM dba.Unidad_funcional uf WHERE uf.id = @IdUF) 
	BEGIN 
		PRINT('El valor ingresado para el parámetro @IdUF es NULL o no pertenece a una unidad funcional válida'); 
		RETURN; 
	END
	
	DECLARE @IdConsorcio INT;

	SELECT @IdConsorcio = id_consorcio FROM dba.Unidad_funcional WHERE id = @IdUF;

	IF @Mes IS NOT NULL AND (@Mes < 1 OR @Mes > 12)
	BEGIN
		PRINT('Ingrese un mes valido');
		RETURN;
	END;

	IF @Anio IS NULL
	BEGIN
		SELECT TOP 1
			@Anio = anio
		FROM dba.Expensa WHERE id_consorcio = @IdConsorcio
		ORDER BY anio DESC;
	END;

	IF @Mes IS NULL
	BEGIN
		SELECT TOP 1
			@Mes = mes
		FROM dba.Expensa WHERE id_consorcio = @IdConsorcio AND anio = @Anio
		ORDER BY mes DESC
	END;

	DECLARE @IdExpensa INT;

	SELECT @IdExpensa = id
	FROM dba.Expensa WHERE id_consorcio = @IdConsorcio
		AND anio = @Anio
		AND mes = @Mes;

	IF @IdExpensa IS NULL
	BEGIN
		PRINT('No existe expensa para ese consorcio en el año/mes indicado ('+CAST(@Mes AS VARCHAR(2))+'/'+CAST(@Anio AS VARCHAR(4))+')');
		RETURN;
	END;

	DECLARE @Coeficiente INT;
	SELECT @Coeficiente = coeficiente FROM dba.Unidad_funcional WHERE id = @IdUF;

	DECLARE @MesChar CHAR(2) = 	CASE WHEN (
		@Mes <= 9) THEN CONCAT('0', @Mes)
		ELSE (CAST(@Mes AS CHAR(2)))
	END;

	DECLARE @MesAnterior VARCHAR(2) = dba.FormatearMesAnterior(@MesChar);
	DECLARE @AnioAnterior VARCHAR(5) = CASE WHEN @MesAnterior <> '12' 
										THEN CAST(@Anio AS VARCHAR(4)) 
										ELSE TRY_CAST((@Anio - 1) AS VARCHAR(4)) 
										END;

	DECLARE @SaldoAnterior DECIMAL(12,2) =  dba.CalcularSaldo(@Coeficiente, @MesAnterior, @AnioAnterior, @IdConsorcio, NULL) + 
											dba.CalcularInteresPorMora(@Coeficiente, @MesAnterior, @AnioAnterior, @IdConsorcio, @IdUF) -
											dba.CalcularPagosRecibidos(@IdUf, @MesAnterior, @AnioAnterior);
	
	DECLARE @SaldoDeudor DECIMAL(12,2) = CASE WHEN @SaldoAnterior > 0 THEN @SaldoAnterior ELSE 0 END;

	DECLARE @SaldoAnteriorAFavor DECIMAL(12,2) = CASE WHEN @SaldoAnterior < 0 THEN ABS(@SaldoAnterior) ELSE 0 END;

	DECLARE @IngresosTotales DECIMAL(12,2) = dba.CalcularPagosRecibidos(@IdUf, @MesChar, CAST(@Anio AS VARCHAR(4)));

	DECLARE @PrimeroDelMes DATE = DATEFROMPARTS(@Anio, @Mes, 1);

	DECLARE @PrimerVto DATE;
	SELECT @PrimerVto = primer_fecha_vto FROM dba.Expensa WHERE id = @IdExpensa;

	DECLARE @IngresosEnTermino DECIMAL(12,2) = (
		SELECT COALESCE(SUM(importe), 0)
		FROM dba.Pago
		WHERE id_uf = @IdUf
			AND fecha BETWEEN @PrimeroDelMes AND @PrimerVto
	);

	DECLARE @Egresos DECIMAL(12,2) = dba.CalcularSaldo(@Coeficiente, @MesChar, CAST(@Anio AS VARCHAR(4)), @IdConsorcio, NULL);

    DECLARE @SAAplicadoADeuda DECIMAL(12,2) = CASE
                                                WHEN @SaldoAnteriorAFavor >= @SaldoDeudor
                                                    THEN @SaldoDeudor
                                                    ELSE @SaldoAnteriorAFavor
                                              END;

    DECLARE @SaldoDeudorRestante DECIMAL(12,2) = @SaldoDeudor - @SAAplicadoADeuda;

    DECLARE @SAAplicadoAEgresos DECIMAL(12,2) = CASE
                                                  WHEN (@SaldoAnteriorAFavor - @SAAplicadoADeuda) >= @Egresos
                                                     THEN @Egresos
                                                     ELSE (@SaldoAnteriorAFavor - @SAAplicadoADeuda)
                                                END;

    DECLARE @EgresosRestantes DECIMAL(12,2) = @Egresos - @SAAplicadoAEgresos;

	DECLARE @IngresoSaldoDeudor DECIMAL(12,2) = CASE
													WHEN @IngresosTotales >= @SaldoDeudorRestante
													THEN @SaldoDeudorRestante
													ELSE @IngresosTotales
												END;

    DECLARE @IngresosRestantesDespuesDeDeuda DECIMAL(12,2) =
            @IngresosTotales - @IngresoSaldoDeudor;

	DECLARE @IngresoAEgresos DECIMAL(12,2) = CASE
                                            WHEN @IngresosRestantesDespuesDeDeuda >= @EgresosRestantes
                                                THEN @EgresosRestantes
                                                ELSE @IngresosRestantesDespuesDeDeuda
                                            END;

    DECLARE @IngresosFinales DECIMAL(12,2) =
            @IngresosRestantesDespuesDeDeuda - @IngresoAEgresos;

    DECLARE @SaldoEnTermino DECIMAL(12,2) =
            CASE 
              WHEN @IngresosEnTermino <= (@IngresoSaldoDeudor + @IngresoAEgresos)
                THEN @IngresosEnTermino
                ELSE (@IngresoSaldoDeudor + @IngresoAEgresos)
            END;

    DECLARE @ExpensasAdelantadas DECIMAL(12,2) = @IngresosFinales;

	DECLARE @SaldoCierre DECIMAL(12,2) =
        @SaldoAnteriorAFavor   
        + @IngresosTotales      
        - @SAAplicadoADeuda
        - @SAAplicadoAEgresos
        - @IngresoSaldoDeudor 
        - @IngresoAEgresos;  
		
    SELECT 
		@Anio AS anio,
		@Mes AS mes,
        @SaldoDeudor AS saldo_deudor,
        @SaldoAnteriorAFavor AS saldo_anterior_a_favor,
        @Egresos AS egresos_mes,
		@IngresosTotales AS ingresos_mes_actual,
        @SaldoEnTermino AS ingresos_en_termino,
        @IngresoSaldoDeudor AS ingreso_expensas_adeudadas,
        @ExpensasAdelantadas AS ingreso_expensas_adelantadas,
        @SaldoCierre AS saldo_cierre;
END
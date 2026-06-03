/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación de todas las funciones auxiliares que se utilizarán para el desarrollo del sistema
*/

USE Com2900G11;
GO

CREATE OR ALTER FUNCTION dba.NormalizarNombre (@Texto NVARCHAR(200))
RETURNS NVARCHAR(200)
AS
BEGIN
    IF @Texto IS NULL RETURN NULL;
    
    DECLARE @Resultado NVARCHAR(200);
    SET @Texto = LOWER(LTRIM(RTRIM(@Texto)));
    
    WHILE CHARINDEX('  ', @Texto) > 0
        SET @Texto = REPLACE(@Texto, '  ', ' ');
    
    SET @Resultado = (
        SELECT STRING_AGG(
            UPPER(LEFT(value, 1)) + SUBSTRING(value, 2, LEN(value)),
            ' '
        ) 
        FROM STRING_SPLIT(@Texto, ' ')
        WHERE value <> ''
    );
    
    SET @Resultado = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        ISNULL(@Resultado, ''),
        ' De ', ' de '),
        ' Del ', ' del '),
        ' La ', ' la '),
        ' Las ', ' las '),
        ' Y ', ' y ');
    
    RETURN @Resultado;
END;
GO

CREATE OR ALTER FUNCTION dba.CadenaNoVacia (@Cadena VARCHAR(200))
RETURNS BIT
AS
BEGIN
    DECLARE @Resultado BIT;

    IF @Cadena IS NOT NULL AND LTRIM(RTRIM(@Cadena)) <> ''
        SET @Resultado = 1;
    ELSE
        SET @Resultado = 0;

    RETURN @Resultado;
END;
GO

CREATE OR ALTER FUNCTION dba.FormatearDecimal (@valor VARCHAR(50))
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @trab VARCHAR(50) = LTRIM(RTRIM(@valor));
    DECLARE @len INT = LEN(@trab);

    IF @trab IS NULL OR @trab = ''
        RETURN NULL;

    DECLARE @sepDecimal CHAR(1);
    DECLARE @posComa INT = CHARINDEX(',', @trab);
    DECLARE @posPunto INT = CHARINDEX('.', @trab);

    IF @posComa > 0 AND @posPunto > 0
        SET @sepDecimal =
            CASE WHEN @posComa > @posPunto THEN ',' ELSE '.' END;
    ELSE IF @posComa > 0
        SET @sepDecimal = ',';
    ELSE IF @posPunto > 0
        SET @sepDecimal = '.';
    ELSE
        RETURN @trab;

    DECLARE @parteEntera VARCHAR(50);
    DECLARE @parteDecimal VARCHAR(50);

    SET @parteEntera = LEFT(@trab, LEN(@trab) - 3);
    SET @parteDecimal = RIGHT(@trab, 2);

    SET @parteEntera = REPLACE(@parteEntera, '.', '');
    SET @parteEntera = REPLACE(@parteEntera, ',', '');
    SET @parteEntera = LTRIM(RTRIM(@parteEntera));

    RETURN @parteEntera + '.' + @parteDecimal;
END
GO

CREATE OR ALTER FUNCTION dba.CalcularSaldo(@Coeficiente DECIMAL(12,2), @Mes VARCHAR(2), @Anio VARCHAR(4), @IdConsorcio INTEGER, @IdTipoGasto INTEGER)
RETURNS DECIMAL(12,2)
AS
BEGIN
	DECLARE @SaldoAnterior DECIMAL(12,2) = 
		(SELECT SUM(g.importe) 
		FROM dba.Gasto g 
		WHERE 
			g.id_expensa = (SELECT e.id FROM dba.Expensa e WHERE id_consorcio = @IdConsorcio AND MES = TRY_CAST(@Mes AS TINYINT) AND anio = TRY_CAST(@Anio AS SMALLINT))
			AND (@IdTipoGasto IS NULL OR g.id_tipo_gasto = @IdTipoGasto))
		*@Coeficiente/100;
	IF @SaldoAnterior IS NOT NULL
	BEGIN
		RETURN @SaldoAnterior;
	END;
	RETURN 0;
END;
GO

CREATE OR ALTER FUNCTION dba.CalcularPagosRecibidos(@IdUf INTEGER, @Mes VARCHAR(02), @Anio VARCHAR(5))
RETURNS DECIMAL(12,2)
AS
BEGIN
	DECLARE @SumaPagos DECIMAL(12,2) = (SELECT SUM(pg.importe) FROM dba.Pago pg WHERE pg.id_uf = @IdUf AND pg.fecha BETWEEN @Anio+'-'+@Mes+'-01' AND @Anio+'-'+@Mes+'-30');
	IF @SumaPagos > 0
	BEGIN
		RETURN @SumaPagos;
	END;
	RETURN 0;
END;
GO

CREATE OR ALTER FUNCTION dba.CalcularInteresPorMora(@Coeficiente DECIMAL(12,2), @Mes VARCHAR(2), @Anio VARCHAR(5), @IdConsorcio INTEGER, @Id_UF INTEGER)
RETURNS DECIMAL(12,2)
AS
BEGIN
	DECLARE @Suma_expensa_anterior DECIMAL(12,2) = 
		(SELECT SUM(g.importe) 
		FROM dba.Gasto g 
		WHERE g.id_expensa = (SELECT e.id FROM dba.Expensa e WHERE id_consorcio = @IdConsorcio AND MES = TRY_CAST(@Mes AS TINYINT) AND anio = TRY_CAST(@Anio AS SMALLINT)))*@Coeficiente/100;
	IF @Suma_expensa_anterior IS NULL OR @Suma_expensa_anterior = 0
	BEGIN
		RETURN 0;
	END;

	DECLARE @interes_1er_fecha DECIMAL(12,2) = 
		(@suma_expensa_anterior - (SELECT SUM(pg.importe) FROM dba.Pago pg WHERE pg.id_uf = @Id_UF AND fecha BETWEEN @Anio+'-'+@Mes+'-01' AND @Anio+'-'+@Mes+'-14'))*0.02;

	DECLARE @interes_2da_fecha DECIMAL(12,2) = 
		(@suma_expensa_anterior - (SELECT SUM(pg.importe) FROM dba.Pago pg WHERE pg.id_uf = @Id_UF AND fecha BETWEEN @Anio+'-'+@Mes+'-01' AND @Anio+'-'+@Mes+'-24'))*0.05;

	DECLARE @restante DECIMAL(12,2) = 
		@Suma_expensa_anterior - (SELECT SUM(pg.importe) FROM dba.Pago pg WHERE pg.id_uf = @Id_UF AND fecha BETWEEN @Anio+'-'+@Mes+'-01' AND @Anio+'-'+@Mes+'-30');
	IF @interes_2da_fecha > 0
	BEGIN
		RETURN @restante + @interes_2da_fecha;
	END
	RETURN @restante + @interes_1er_fecha;
END;
GO

CREATE OR ALTER FUNCTION dba.FormatearMesAnterior(@Mes VARCHAR(2))
RETURNS VARCHAR(2)
AS
BEGIN
	DECLARE @MesInt        TINYINT;
		DECLARE @MesAnterior   VARCHAR(2);

		SET @MesInt = CONVERT(TINYINT, @Mes);
 
   
		SET @MesAnterior = RIGHT(
							  '0' + CAST(
									   CASE WHEN @MesInt = 1
											THEN 12
											ELSE @MesInt - 1
									   END
									   AS VARCHAR(2)
								   ),
							  2
						   );
		RETURN @MesAnterior;
END;
GO
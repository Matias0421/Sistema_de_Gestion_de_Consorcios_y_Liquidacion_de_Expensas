/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Creación del SP para la consulta de la expensa de un mes y año especificado para un cierto consorcio, 
			mostrando cuánto debe pagar cada unidad funcional perteneciente al mismo.
*/

USE Com2900G11;
GO

CREATE OR ALTER PROCEDURE dba.sp_GenerarExpensa
	@Mes VARCHAR(2),
	@Anio VARCHAR(5),
	@IdConsorcio VARCHAR(2)
AS
BEGIN
	SET NOCOUNT ON;
	IF TRY_CAST(@Mes AS SMALLINT) >= 13
	BEGIN
		PRINT('Numero de mes invalido');
		RETURN;
	END;
	SET @Mes = CASE WHEN (
		@Mes IN ('1','2','3','4','5','6','7','8','9')
		) THEN CONCAT('0', @Mes)
		ELSE (@Mes)
	END;
	DECLARE @MesAnterior VARCHAR(2) = dba.FormatearMesAnterior(@Mes);
	DECLARE @AnioAnterior VARCHAR(5) = CASE WHEN @MesAnterior <> '12' 
										THEN @Anio 
										ELSE TRY_CAST((TRY_CAST(@Anio AS SMALLINT) - 1) AS VARCHAR(5)) 
										END;
	DECLARE @SQL NVARCHAR(MAX) = N'
	WITH datos AS (
		SELECT DISTINCT
			u.coeficiente AS ''%'',
			u.nro_uf, 
			u.piso, 
			u.depto, 
			CONCAT(p.nombre, '' '', p.apellido) AS ''Propietario'',
			(dba.CalcularSaldo(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,NULL) 
			 + dba.CalcularInteresPorMora(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,u.id)) AS saldo_anterior,

			(dba.CalcularPagosRecibidos(u.id,'+@MesAnterior+','+@AnioAnterior+')) AS pagos_recibidos,

			CASE WHEN (dba.CalcularSaldo(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,NULL) 
				 + dba.CalcularInteresPorMora(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,u.id) 
				 - dba.CalcularPagosRecibidos(u.id,'+@MesAnterior+','+@AnioAnterior+')) > 0 THEN dba.CalcularSaldo(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,NULL) 
				 + dba.CalcularInteresPorMora(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,u.id) 
				 - dba.CalcularPagosRecibidos(u.id,'+@MesAnterior+','+@AnioAnterior+') ELSE 0 END AS saldo_pendiente,
			CASE WHEN (dba.CalcularSaldo(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,NULL) 
				 + dba.CalcularInteresPorMora(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,u.id) 
				 - dba.CalcularPagosRecibidos(u.id,'+@MesAnterior+','+@AnioAnterior+')) < 0 THEN ABS(dba.CalcularSaldo(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,NULL) 
				 + dba.CalcularInteresPorMora(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,u.id) 
				 - dba.CalcularPagosRecibidos(u.id,'+@MesAnterior+','+@AnioAnterior+')) ELSE 0 END AS saldo_a_favor,
			CASE 
				WHEN (
					dba.CalcularSaldo(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,NULL) 
					+ dba.CalcularInteresPorMora(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,u.id) 
					- dba.CalcularPagosRecibidos(u.id,'+@MesAnterior+','+@AnioAnterior+')
				) <= 0 THEN 0
				ELSE (
					dba.CalcularSaldo(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,NULL) 
					+ dba.CalcularInteresPorMora(u.coeficiente,'+@MesAnterior+','+@AnioAnterior+',c.id,u.id) 
					- dba.CalcularPagosRecibidos(u.id,'+@MesAnterior+','+@AnioAnterior+')
				) * 0.05
			END AS interes_por_mora,

			dba.CalcularSaldo(u.coeficiente,'+@Mes+','+@Anio+',c.id,0) AS expensas_ordinarias,
			dba.CalcularSaldo(
				(SELECT SUM(superficie) FROM dba.Unidad_accesorio WHERE id_unidad_funcional = u.id),
				'+@Mes+','+@Anio+', c.id, NULL
			) AS cocheras,
			dba.CalcularSaldo(u.coeficiente,'+@Mes+','+@Anio+',c.id,1) AS expensas_extraordinarias

		FROM dba.Unidad_funcional u
		INNER JOIN dba.Persona p ON p.dni = u.dni_persona
		INNER JOIN dba.Consorcio c ON c.id = u.id_consorcio
		INNER JOIN dba.Pago pg ON pg.id_uf = u.id
		WHERE c.id = ' + @IdConsorcio + '
	)

	SELECT *,
		   CAST(
				interes_por_mora 
				+ expensas_ordinarias 
				+ expensas_extraordinarias 
				+ cocheras
				AS DECIMAL(10,2)
		   ) AS total_a_pagar
	FROM datos
	ORDER BY nro_uf;
	';
	EXEC sp_executesql @SQL;
END;
GO
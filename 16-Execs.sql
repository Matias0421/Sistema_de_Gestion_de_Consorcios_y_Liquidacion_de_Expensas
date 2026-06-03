/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Facilitación de ejecución de los scripts necesarios para poblar el sistema de información mediante importación de archivos y para consultar
		partes claves del sistema (estado financiero, expensa de un cierto mes).
*/

USE Com2900G11;
GO

EXEC dba.sp_ImportarCSVPersonas @RutaArchivo = 'C:\Users\chris\Downloads\consorcios\Inquilino-propietarios-datos.csv';
GO

EXEC dba.sp_ImportarXLSXConsorcios @RutaArchivo = N'C:\users\chris\Downloads\consorcios\datos varios.xlsx';
GO

EXEC dba.sp_ImportarTXTUnidadFuncional @RutaArchivo = N'C:\Users\chris\Downloads\consorcios\UF por consorcio.txt';
GO

EXEC dba.sp_ImportarCSVPersonaUF @RutaArchivo = 'C:\users\chris\Downloads\consorcios\Inquilino-propietarios-UF.csv';
GO

EXEC dba.sp_ImportarServiciosJSON @RutaArchivo = 'C:\Users\chris\Downloads\consorcios\Servicios.Servicios.json', @Anio = 2025;
GO

-- Se debe ejecutar obligatoriamente la importación de los gastos ordinarios (sp_ImportarServiciosJSON) antes de importar los gastos extraordinarios, ya que el primer SP es el que genera una expensa a la que luego se asociarán todos los gastos de ese mes.
-- En caso de correr la importación de gastos extraordinarios primero, el registro no se cargará al sistema, ya que no encontrará una expensa a la cual pertenecería dicho gasto.
	
EXEC dba.sp_ImportarExtraordinariasJSON @RutaArchivo = N'C:\Users\chris\Downloads\consorcios\Extraordinarios.json', @Anio = 2025;
GO

EXEC dba.sp_ImportarCSV_PagosBanco 
  @RutaArchivo = N'C:\Users\chris\Downloads\consorcios\pagos_consorcios.csv',
  @SeparadorCampos = N',',
  @FilaInicial = 2;
GO

EXEC dba.sp_GenerarExpensa @Mes = '5', @Anio='2025', @IdConsorcio = '1';
GO

EXEC dba.sp_ConsultarEstadoFinanciero @IdUF = 1, @Mes = 6, @Anio = 2025;
GO

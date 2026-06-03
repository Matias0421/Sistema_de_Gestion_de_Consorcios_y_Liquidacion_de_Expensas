/*
Fecha de entrega: 25/11/2025
Número de comisión: 01-2900
Número de Grupo: 11
Nombre de la materia: Bases de Datos Aplicada
Integrantes: 
- Faulkner, Christian David (45744074). 
- Moreno, Julieta Carolina (44750145). 
- Deiriz, Matías Ezequiel (45421066)

CONSIGNA: Inserción tipos constantes de datos 
(Propietario/Inquilino como tipo de persona, Extraordinario/Ordinario como tipo de gasto, Cochera/Baulera como tipo de unidad accesorio)
*/

USE Com2900G11;
GO
SET NOCOUNT ON;

-- Tipo_persona

MERGE dba.Tipo_persona AS destino
USING (VALUES 
    (0, 'Inquilino'),
    (1, 'Propietario')
) AS origen (id, tipo)
ON destino.id = origen.id
WHEN NOT MATCHED THEN 
    INSERT (id, tipo) VALUES (origen.id, origen.tipo);
GO

CREATE OR ALTER TRIGGER dba.TR_Tipo_persona_Prevent_Modification
ON dba.Tipo_persona
INSTEAD OF DELETE, UPDATE
AS
BEGIN
    RAISERROR('No se permite modificar o eliminar registros de Tipo_persona.', 16, 1);
END;
GO


-- Tipo_gasto

MERGE dba.Tipo_gasto AS destino
USING (VALUES 
    (0, 'Ordinario'),
    (1, 'Extraordinario')
) AS origen (id, tipo)
ON destino.id = origen.id
WHEN NOT MATCHED THEN 
    INSERT (id, tipo) VALUES (origen.id, origen.tipo);
GO

CREATE OR ALTER TRIGGER dba.TR_Tipo_gasto_Prevent_Modification
ON dba.Tipo_gasto
INSTEAD OF DELETE, UPDATE
AS
BEGIN
    RAISERROR('No se permite modificar o eliminar registros de Tipo_gasto.', 16, 1);
END;
GO


-- Tipo_unidad_accesorio

MERGE dba.Tipo_unidad_accesorio AS destino
USING (VALUES 
    (0, 'Cochera'),
    (1, 'Baulera')
) AS origen (id, tipo)
ON destino.id = origen.id
WHEN NOT MATCHED THEN 
    INSERT (id, tipo) VALUES (origen.id, origen.tipo);
GO

CREATE OR ALTER TRIGGER dba.TR_Tipo_unidad_accesorio_Prevent_Modification
ON dba.Tipo_unidad_accesorio
INSTEAD OF DELETE, UPDATE
AS
BEGIN
    RAISERROR('No se permite modificar o eliminar registros de Tipo_unidad_accesorio.', 16, 1);
END;
GO

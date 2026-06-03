# 🏢 Sistema de Gestión de Consorcios y Liquidación de Expensas

![SQL Server](https://img.shields.io/badge/SQL%20Server%202022-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)
![Asignatura](https://img.shields.io/badge/Asignatura-Bases%20de%20Datos%20Aplicada-blue?style=for-the-badge)
![UNLaM](https://img.shields.io/badge/Universidad-UNLaM-green?style=for-the-badge)

Trabajo Práctico Integrador desarrollado para el **Departamento de Ingeniería e Investigaciones Tecnológicas** de la **Universidad Nacional de La Matanza (UNLaM)**. 

El proyecto abarca desde el análisis de viabilidad económica/técnica de motores de bases de datos hasta la implementación de una solución relacional robusta e integral que resuelve la persistencia, ETL, liquidación automatizada de expensas, enmascaramiento de datos y reportería avanzada para una administración de consorcios.

---

## 📄 Documentación Adicional
Consultá los informes metodológicos y de costos generados a lo largo del ciclo de vida del proyecto:
* [📄 Informe Final Consolidado (PDF)](Com2900_Grupo11.pdf)
* [📊 Diagrama de Entidad-Relación (DER)](./docs/DER_Grupo11.pdf)

---

## 🚀 Resumen de Entregas y Arquitectura

### 🛠️ Entrega 1 y 2: Análisis de Viabilidad y Estimación de Costos
Antes de codificar, se evaluaron dos arquitecturas para el cliente *Altos de Saint Just*:
1. **Apache Cassandra (NoSQL):** Evaluado bajo un modelo de alta disponibilidad (HA). Se concluyó que para un volumen proyectado de $\approx 1\text{ GB}$ en 2 años, el motor resultaba sobredimensionado, de alta complejidad operativa y requería un esquema de costos del personal técnico de **U$D 9.003/mes**.
2. **Azure SQL Database (PaaS):** Elegido como la solución óptima frente a competidores en la nube (AWS RDS y Cloud SQL). Al delegar la infraestructura, backups y alta disponibilidad a Microsoft, se logró optimizar el equipo técnico, reduciendo el TCO a un costo operativo (OPEX) base de **U$D 2.126/mes** en etapa de mantenimiento.

### 📐 Entrega 3 y 4: Modelo Relacional y Configuración de Entorno
* **Estándar de Diseño:** Se adoptó la nomenclatura `snake_case` con inicial mayúscula para tablas (`Tipo_persona`, `Gasto`) y minúsculas para campos. Los *Stored Procedures* siguen el formato `dba.sp_Accion` y los parámetros `CamelCase`.
* **Entorno:** Servidor **SQL Server 2022 Express Edition** (Limitación de 1 GB de RAM). 
* **Configuración del Motor:** Aislamiento estricto de discos (`D:\SQLData`, `E:\SQLLogs`, `F:\SQLBackups`) y habilitación de opciones avanzadas para la ingesta de archivos externos:
```sql
  EXEC sp_configure 'show advanced options', 1;
  EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
  -- Configuración de Proveedor OLE DB para lecturas XLSX/CSV en proceso
  EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'AllowInProcess', 1;
  EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'DynamicParameters', 1;
```

## 📥 Entrega 5: Pipeline Ingesta de Datos (ETL)
Migración de datos transaccionales mediante scripts robustos e idempotentes para los siguientes formatos:

**CSV: Datos de Personas, Asociación Persona-UF y Pagos.**

**XLSX: Registro de Consorcios.**

**TXT: Unidades Funcionales (UF).**

**JSON: Catálogo de Servicios y liquidación de Gastos Extraordinarios.**

## 📊 Entrega 6: Inteligencia de Negocio y Reportería Avanzada
Implementación de lógica analítica embebida en procedimientos almacenados:

*sp_ReporteFlujoCajaSemanal*: Análisis dinámico temporal de ingresos frente a egresos.

*sp_ReporteRecaudacionMensualDepartamento*: Matriz cruzada de cobros mensuales por departamento utilizando operadores PIVOT.

*sp_ReporteTopMorosos*: Identificación de deudores con conversión monetaria en tiempo real integrada a API externa.

*sp_ReporteIntervalosEntrePagos*: Análisis de comportamiento de pago de propietarios con salida nativa estructurada en XML.

## 🔒 Entrega 7: Seguridad, Privacidad y Respaldo
Protección de Datos Sensibles: Enmascaramiento y hashing de una vía (SHA2_256 con sal) para proteger campos críticos como DNI/CUIT, direcciones, emails, teléfonos, datos bancarios de débitos e importes de expensas.

*Estrategia RPO (Recovery Point Objective): Resguardo financiero automatizado parametrizado en 15 minutos:*

*Full Backup: Semanal (Domingos 03:00 h) - Retención 30 días.*

*Backup Diferencial: Diario (02:00 h) - Retención 7 días.*

*Transaction Log Backup: Cada 15 minutos - Retención 72 horas.*

*Copia Externa Remota: Diaria (04:00 h).*

## ⚙️ Requisitos de Instalación
**Clonar el repositorio.**

**Levantar los scripts numerados de manera secuencial (00_ al 15_).**

**Ajustar las rutas absolutas en el archivo de ejecución 16-Execs.sql hacia la carpeta local con los archivos fuentes (.csv, .json, .txt, .xlsx) para correr las pruebas de migración.**

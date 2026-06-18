-- ============================================================================
-- PROYECTO DATA WAREHOUSE: NETFLIX CATALOG ANALYSIS
-- SCRIPT 02: PROCESO DE CARGA (ETL) & CAPA SEMÁNTICA
-- Autor: Alejandro Nortes del Rio-Hortega
-- 
-- ÍNDICE DE SECCIONES:
--   1. AJUSTES PREVIOS E IMPORTACIÓN DE DATOS (Staging)
--   2. LIMPIEZA DE DATOS VACÍOS (Data Cleansing)
--   3. POBLADO DEL MODELO DIMENSIONAL (Carga de Dimensiones)
--      3.1. Dimensión Contenido
--      3.2. Dimensión Directores
--      3.3. Dimensión Países
--      3.4. Dimensión Categorías
--      3.5. Dimensión Fechas
--   4. POBLADO DE LA TABLA DE HECHOS (fact_catalogo)
--   5. DEPURACIÓN DE REGISTROS DUPLICADOS (Data Quality)
--   6. CAPA SEMÁNTICA (Creación de Vistas de Negocio)
-- ============================================================================

USE proyecto_netflix;

-- ============================================================================
-- 1. AJUSTES PREVIOS E IMPORTACIÓN DE DATOS (Staging)
-- ============================================================================

-- Habilitamos la carga local de archivos en el servidor MySQL
SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';

/* ----------------------------------------------------------------------------
   AUTOMATIZACIÓN DE LA CARGA DEL CSV MEDIANTE SCRIPT
   Nota: Asegúrate de cambiar la ruta por la ubicación real de tu archivo.
   ---------------------------------------------------------------------------- */
LOAD DATA LOCAL INFILE 'C:/Tu_Ruta_De_Usuario/data/netflix_titles.csv'
INTO TABLE netflix_raw
CHARACTER SET utf8mb4                         -- Soporta tildes y caracteres del catálogo global
FIELDS TERMINATED BY ','                      -- Separador por comas del CSV original
ENCLOSED BY '"'                               -- Protege textos con comas internas (descripciones)
LINES TERMINATED BY '\r\n'                    -- Salto de línea estándar en Windows
IGNORE 1 ROWS;                                -- Ignora la cabecera de las columnas

/* ----------------------------------------------------------------------------
   MANUAL DE INSTRUCCIONES PARA LA CARGA DEL CSV EN LA CAPA BRUTA (IDE) (FORMA MANUAL):
   ----------------------------------------------------------------------------
   1. En el panel izquierdo de DBeaver, haz clic derecho sobre la tabla 'netflix_raw'.
   2. Selecciona la opción 'Importar datos' (Import Data).
   3. Selecciona el formato 'CSV' en la ventana emergente y pulsa Siguiente.
   4. En la sección 'Source', haz clic en el botón 'Browse' y selecciona tu archivo 'netflix_titles.csv'.
   5. Haz clic en Siguiente.
   6. En los ajustes de importación, asegúrate de marcar con un tick verde las siguientes opciones:
      [✓] Truncate target table(s) before load (Evita datos duplicados en re-ejecuciones)
      [✓] Use multi-row value insert (Aumenta la velocidad de carga) -> Valor: 500
   7. Haz clic en Siguiente y finalmente en 'Proceder' (Procced/Completar).
   ----------------------------------------------------------------------------
*/


-- ACTIVAMOS TRANSACCIÓN PARA SEGURIDAD
START TRANSACTION;

-- ----------------------------------------------------------------------------
-- 2. LIMPIEZA PREVIA DE VALORES VACÍOS (Data Cleansing en Staging)
-- ----------------------------------------------------------------------------
SET SQL_SAFE_UPDATES = 0;

-- 1º Eliminamos los registros corruptos del CSV
DELETE FROM netflix_raw WHERE rating LIKE '%min%';

-- 2º Homogeneizamos los nulos del contenido que SÍ nos vamos a quedar
UPDATE netflix_raw SET rating = 'UR' WHERE rating IS NULL OR rating = ''; -- Los nulos pasan a 'UR'
UPDATE netflix_raw SET director = 'Unknown' WHERE director IS NULL OR director = '';  -- Los nulos pasan a 'Unknown'
UPDATE netflix_raw SET country = 'Unknown' WHERE country IS NULL OR country = '';  -- Los nulos pasan a 'Unknown'
SET SQL_SAFE_UPDATES = 1;


-- ============================================================================
-- 3. POBLADO DEL MODELO DIMENSIONAL (Carga de Dimensiones)
-- ============================================================================

-- 3.1. Carga de Dimensión Contenido (Mapeo directo 1 a 1)
INSERT INTO dim_contenido (show_id_original, tipo, title, rating, duration, description)
SELECT DISTINCT 
    show_id, 
    type, 
    title, 
    rating, 
    duration, 
    description
FROM netflix_raw;

-- 3.2. Carga de Dimensión Directores (Uso de IGNORE para evitar duplicados)
INSERT IGNORE INTO dim_directores (director_name)
SELECT DISTINCT 
	director
FROM netflix_raw;


-- 3.3. Carga de Dimensión Países (Limpieza de comas y espacios en los extremos)
INSERT IGNORE INTO dim_paises (country_name)
SELECT DISTINCT 
    TRIM(LEADING ' ' FROM TRIM(LEADING ',' FROM TRIM(country)))
FROM netflix_raw
WHERE country IS NOT NULL AND country != '';


-- 3.4. Carga de Dimensión Categorías
INSERT IGNORE INTO dim_categorias (categoria_name)
SELECT DISTINCT TRIM(listed_in)
FROM netflix_raw;


-- 3.5. Carga de Dimensión Fechas (Conversión de texto plano a formato DATE real)
INSERT IGNORE INTO dim_dates (fecha_real, anio_added, mes_added, mes_nombre, trimestre, dia_semana)
SELECT DISTINCT
    STR_TO_DATE(TRIM(date_added), '%M %d, %Y') AS f_real,
    YEAR(STR_TO_DATE(TRIM(date_added), '%M %d, %Y')) AS anio,
    MONTH(STR_TO_DATE(TRIM(date_added), '%M %d, %Y')) AS mes,
    MONTHNAME(STR_TO_DATE(TRIM(date_added), '%M %d, %Y')) AS mes_nom,
    QUARTER(STR_TO_DATE(TRIM(date_added), '%M %d, %Y')) AS trim,
    DAYNAME(STR_TO_DATE(TRIM(date_added), '%M %d, %Y')) AS d_sem
FROM netflix_raw
WHERE date_added IS NOT NULL 
  AND TRIM(date_added) != '' 
  AND STR_TO_DATE(TRIM(date_added), '%M %d, %Y') IS NOT NULL;

-- ============================================================================
-- 4. POBLADO DE LA TABLA DE HECHOS (fact_catalogo)
-- ============================================================================
-- Relacionamos la tabla intermedia con las dimensiones mediante claves foráneas (IDs)
INSERT INTO fact_catalogo (contenido_id, director_id, pais_id, categoria_id, date_id, release_year)
SELECT 
    c.contenido_id,
    d.director_id,
    p.pais_id,
    cat.categoria_id,
    dt.date_id,
    raw.release_year
FROM netflix_raw raw
-- Cruzamos con Contenido (es obligatorio, por eso es INNER JOIN)
INNER JOIN dim_contenido c ON raw.show_id = c.show_id_original
LEFT JOIN dim_directores d ON raw.director = d.director_name
LEFT JOIN dim_paises p ON raw.country = p.country_name
LEFT JOIN dim_categorias cat ON raw.listed_in = cat.categoria_name
LEFT JOIN dim_dates dt ON dt.fecha_real = (
    CASE -- Este case-when para mirar que en los que no haya nada devuelva null
        WHEN raw.date_added IS NULL OR TRIM(raw.date_added) = '' THEN NULL
        ELSE STR_TO_DATE(TRIM(raw.date_added), '%M %d, %Y')
    END
)
WHERE c.contenido_id IS NOT NULL; -- Filtro de seguridad: asegurarnos de no meter filas huérfanas

-- ============================================================================
-- 5. DEPURACIÓN DE REGISTROS DUPLICADOS (Data Quality)
-- EXPLICACIÓN: Eliminamos físicamente las filas duplicadas en la tabla de hechos, 
-- manteniendo únicamente el primer registro insertado (el menor ID).
-- ============================================================================
WITH control_duplicados AS (
    SELECT 
        f.fact_id,
        c.title,
        ROW_NUMBER() OVER (PARTITION BY c.title, f.director_id, f.release_year ORDER BY f.fact_id) AS numero_fila
    FROM fact_catalogo f
    INNER JOIN dim_contenido c ON f.contenido_id = c.contenido_id
)
SELECT * FROM control_duplicados WHERE numero_fila > 1;
-- Si devuelve 0 filas, el Data Warehouse goza de integridad total.
-- Si no borramos con lo siguiente

SET SQL_SAFE_UPDATES = 0;

DELETE FROM fact_catalogo
WHERE fact_id IN (
    SELECT fact_id FROM (
        SELECT 
            f.fact_id,
            ROW_NUMBER() OVER (
                PARTITION BY c.title, f.director_id, f.release_year 
                ORDER BY f.fact_id
            ) AS numero_fila
        FROM fact_catalogo f
        INNER JOIN dim_contenido c ON f.contenido_id = c.contenido_id
    ) AS tabla_temporal
    WHERE numero_fila > 1
);

SET SQL_SAFE_UPDATES = 1;


-- CONFIRMAMOS QUE TODA LA CARGA Y LIMPIEZA SE HA REALIZADO CORRECTAMENTE
COMMIT;

-- ============================================================================
-- 6. CAPA SEMÁNTICA (Creación de Vistas de Negocio)
-- ============================================================================
-- Requisito de arquitectura: Mínimo 2 vistas que faciliten el consumo de datos.

-- Vista 1: Vista global del catálogo traduciendo los IDs numéricos a texto legible
CREATE OR REPLACE VIEW v_catalogo_completo AS
SELECT 
    f.fact_id,
    c.title AS 'Título',
    c.tipo AS 'Tipo',
    d.director_name AS 'Director',
    p.country_name AS 'País',
    cat.categoria_name AS 'Género/Categoría',
    c.rating AS 'Clasificación',
    c.duration AS 'Duración',
    dt.fecha_real AS 'Fecha Incorporación'
FROM fact_catalogo f
INNER JOIN dim_contenido c ON f.contenido_id = c.contenido_id
LEFT JOIN dim_directores d ON f.director_id = d.director_id
LEFT JOIN dim_paises p ON f.pais_id = p.pais_id
LEFT JOIN dim_categorias cat ON f.categoria_id = cat.categoria_id
LEFT JOIN dim_dates dt ON f.date_id = dt.date_id;

-- Vista 2: Resumen ejecutivo del volumen de producción por país analizado
CREATE OR REPLACE VIEW v_resumen_paises AS
SELECT 
    p_limpio.country_name AS 'País',
    COUNT(f.fact_id) AS 'Total Títulos',
    SUM(CASE WHEN c.tipo = 'Movie' THEN 1 ELSE 0 END) AS 'Total Películas',
    SUM(CASE WHEN c.tipo = 'TV Show' THEN 1 ELSE 0 END) AS 'Total Series'
FROM fact_catalogo f
INNER JOIN dim_contenido c ON f.contenido_id = c.contenido_id
INNER JOIN dim_paises p_sucio ON f.pais_id = p_sucio.pais_id
-- Cruce mágico: Busca los países individuales dentro de las celdas con comas
INNER JOIN dim_paises p_limpio ON p_sucio.country_name LIKE CONCAT('%', p_limpio.country_name, '%')
-- Filtros de calidad: Fulminamos los nulos, el 'Unknown', los vacíos fantasmas y las filas con comas
WHERE p_limpio.country_name IS NOT NULL 
  AND p_limpio.country_name != 'Unknown' 
  AND TRIM(p_limpio.country_name) != ''
  AND p_limpio.country_name NOT LIKE '%,%'
GROUP BY p_limpio.country_name
ORDER BY COUNT(f.fact_id) DESC;

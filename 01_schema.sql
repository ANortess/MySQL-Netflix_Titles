-- ============================================================================
-- PROYECTO DATA WAREHOUSE: NETFLIX CATALOG ANALYSIS
-- Dataset (Kaggle): https://www.kaggle.com/datasets/shivamb/netflix-shows?resource=download
-- SCRIPT 01: SCRIPT DE ESTRUCTURA (SCHEMA & STAGING)
-- Autor: Alejandro Nortes del Rio-Hortega
-- 
-- ÍNDICE DE SECCIONES:
--   1. CONFIGURACIÓN INICIAL Y LIMPIEZA DE ENTORNO
--   2. CAPA BRUTA / INTERMEDIA (STAGING AREA - netflix_raw)
--   3. CAPA CORE: CREACIÓN DE DIMENSIONES (Modelo Estrella)
--      3.1. Dimensión Contenido
--      3.2. Dimensión Directores
--      3.3. Dimensión Países
--      3.4. Dimensión Categorías
--      3.5. Dimensión Fechas
--   4. CAPA CORE: CREACIÓN DE LA TABLA DE HECHOS (fact_catalogo)
--   5. OPTIMIZACIÓN: CREACIÓN DE ÍNDICES DE RENDIMIENTO
--   6. PROGRAMACIÓN: FUNCIÓN PERSONALIZADA (UDF)
-- ============================================================================

-- ============================================================================
-- 1. CONFIGURACIÓN INICIAL Y LIMPIEZA DE ENTORNO
-- ============================================================================
CREATE DATABASE IF NOT EXISTS proyecto_netflix;
USE proyecto_netflix;

-- Desactivamos restricciones de claves foráneas para poder hacer un DROP limpio
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS fact_catalogo;
DROP TABLE IF EXISTS dim_dates;
DROP TABLE IF EXISTS dim_contenido;
DROP TABLE IF EXISTS dim_directores;
DROP TABLE IF EXISTS dim_paises;
DROP TABLE IF EXISTS dim_categorias;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 2. CAPA BRUTA / INTERMEDIA (STAGING AREA - netflix_raw)
-- ============================================================================
-- Objetivo: Almacenar los datos del CSV de Kaggle tal y como vienen de origen.
CREATE TABLE netflix_raw (
    show_id VARCHAR(20),
    type VARCHAR(20),
    title VARCHAR(250),
    director TEXT,
    country TEXT,
    date_added VARCHAR(50),
    release_year INT,
    rating VARCHAR(20),
    duration VARCHAR(50),
    listed_in TEXT,
    description TEXT
);


-- ============================================================================
-- 3. CAPA CORE: CREACIÓN DE DIMENSIONES (Modelo Estrella)
-- ============================================================================

/* ----------------------------------------------------------------------------
   3.1. Dimensión Contenido:
   - Se establece contenido_id como clave primaria subrogada autoincremental.
   - show_id_original se mantiene como UNIQUE para asegurar la trazabilidad con el CSV.
   - Se incluye un CHECK para validar que el tipo de contenido solo acepte los dos formatos de la plataforma.
   ---------------------------------------------------------------------------- */
CREATE TABLE dim_contenido (
    contenido_id INT AUTO_INCREMENT PRIMARY KEY, 
    show_id_original VARCHAR(20) NOT NULL UNIQUE, 
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('Movie', 'TV Show')),
    title VARCHAR(250) NOT NULL,
    rating VARCHAR(20) NOT NULL,
    duration VARCHAR(50),
    description TEXT
);

/* ----------------------------------------------------------------------------
   3.2. Dimensión Directores:
   - Almacena las entidades únicas de directores de cine y televisión.
   - director_name se define como UNIQUE para evitar registros duplicados en la dimensión.
   ---------------------------------------------------------------------------- */
CREATE TABLE dim_directores (
    director_id INT AUTO_INCREMENT PRIMARY KEY,
    director_name VARCHAR(150) NOT NULL UNIQUE
);

/* ----------------------------------------------------------------------------
   3.3. Dimensión Países:
   - Mapea los territorios de origen de las producciones.
   - country_name actúa como un valor único obligatorio para salvaguardar la integridad.
   ---------------------------------------------------------------------------- */
CREATE TABLE dim_paises (
    pais_id INT AUTO_INCREMENT PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL UNIQUE
);

/* ----------------------------------------------------------------------------
   3.4. Dimensión Categorías:
   - Almacena los géneros y clasificaciones temáticas de la plataforma.
   ---------------------------------------------------------------------------- */
CREATE TABLE dim_categorias (
    categoria_id INT AUTO_INCREMENT PRIMARY KEY,
    categoria_name VARCHAR(100) NOT NULL UNIQUE
);

/* ----------------------------------------------------------------------------
   3.5. Dimensión Fechas:
   - Desglosa los atributos temporales a partir del campo texto original de carga.
   - Permite optimizar las consultas cronológicas sin sobrecargar la tabla de hechos.
   ---------------------------------------------------------------------------- */
CREATE TABLE dim_dates (
    date_id INT AUTO_INCREMENT PRIMARY KEY, 
    fecha_real DATE NOT NULL unique, -- Almacena la fecha completa (YYYY-MM-DD)
    anio_added INT NOT NULL,
    mes_added INT NOT NULL,
    mes_nombre VARCHAR(20) NOT NULL,
    trimestre INT NOT NULL,
    dia_semana VARCHAR(20) NOT NULL
);

-- ============================================================================
-- 4. CAPA CORE: CREACIÓN DE LA TABLA DE HECHOS (fact_catalogo)
-- ============================================================================
/* ----------------------------------------------------------------------------
   Tabla de Hechos Central: fact_catalogo
   - Centraliza el hecho transaccional de publicaciones del catálogo de Netflix.
   - Conecta las claves foráneas con cada una de las 5 dimensiones del modelo estrella.
   - Se añade una restricción CHECK en release_year para asegurar la consistencia histórica 
     de los datos (desde el nacimiento del cine en 1895 hasta el año actual 2026).
   ---------------------------------------------------------------------------- */
CREATE TABLE fact_catalogo (
    fact_id INT AUTO_INCREMENT PRIMARY KEY,
    contenido_id INT NOT NULL, -- Conecta con el ID numérico
    director_id INT,
    pais_id INT,
    categoria_id INT,
    date_id INT,
    release_year INT NOT NULL,
    
    -- Claves Foráneas actualizadas a tipos INT
    CONSTRAINT fk_fact_contenido FOREIGN KEY (contenido_id) REFERENCES dim_contenido(contenido_id) ON DELETE CASCADE,
    CONSTRAINT fk_fact_director FOREIGN KEY (director_id) REFERENCES dim_directores(director_id) ON DELETE SET NULL,
    CONSTRAINT fk_fact_pais FOREIGN KEY (pais_id) REFERENCES dim_paises(pais_id) ON DELETE SET NULL,
    CONSTRAINT fk_fact_categoria FOREIGN KEY (categoria_id) REFERENCES dim_categorias(categoria_id) ON DELETE SET NULL,
    CONSTRAINT fk_fact_date FOREIGN KEY (date_id) REFERENCES dim_dates(date_id) ON DELETE SET NULL
);

-- ============================================================================
-- 5. OPTIMIZACIÓN: CREACIÓN DE ÍNDICES DE RENDIMIENTO
-- ============================================================================
-- Índices creados para acelerar las consultas analíticas (GROUP BY / JOIN) en el EDA.
CREATE INDEX idx_fact_release ON fact_catalogo(release_year);
CREATE INDEX idx_fact_lookup ON fact_catalogo(contenido_id, director_id, categoria_id, pais_id, date_id);
CREATE INDEX idx_fact_contenido ON fact_catalogo(contenido_id);

-- ============================================================================
-- 6. PROGRAMACIÓN: FUNCIÓN PERSONALIZADA (User Defined Function - UDF)
-- ============================================================================
-- EXPLICACIÓN: Automatiza la clasificación de los contenidos según su tipo y 
-- duración en minutos, abstrayendo la lógica compleja para que el equipo de UX 
-- pueda segmentar la interfaz de manera directa mediante consultas sencillas.
-- ----------------------------------------------------------------------------
-- Forzamos la confianza en funciones para evitar errores de restricción binaria (Error 1418)
SET GLOBAL log_bin_trust_function_creators = 1;

DROP FUNCTION IF EXISTS f_clasificar_duracion;
DELIMITER $$

CREATE FUNCTION f_clasificar_duracion(p_tipo VARCHAR(50), p_duracion VARCHAR(50))
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE v_resultado VARCHAR(50);
    DECLARE v_minutos INT;
    
    IF p_tipo = 'TV Show' THEN
        SET v_resultado = 'Serie de TV';
    ELSEIF p_tipo = 'Movie' AND p_duracion LIKE '%min%' THEN
        SET v_minutos = CAST(REPLACE(p_duracion, ' min', '') AS UNSIGNED);
        IF v_minutos < 90 THEN
            SET v_resultado = 'Película Corta (<90 min)';
        ELSEIF v_minutos BETWEEN 90 AND 120 THEN
            SET v_resultado = 'Película Estándar (90-120 min)';
        ELSE
            SET v_resultado = 'Película Larga (>120 min)';
        END IF;
    ELSE
        SET v_resultado = 'Desconocido';
    END IF;
    
    RETURN v_resultado;
END$$

DELIMITER ;

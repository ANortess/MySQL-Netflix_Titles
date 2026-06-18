-- ============================================================================
-- PROYECTO DATA WAREHOUSE: NETFLIX CATALOG ANALYSIS
-- SCRIPT 03: CAPA DE EXPLOTACIÓN (EDA - CONSULTAS DE NEGOCIO AVANZADAS)
-- Autor: Alejandro Nortes del Rio-Hortega
-- ============================================================================

USE proyecto_netflix;

-- ============================================================================
-- REPASO PREVIO: USO DE LAS VISTAS DE NEGOCIO (CAPA SEMÁNTICA)
-- ============================================================================
SELECT * FROM v_catalogo_completo LIMIT 5;
SELECT * FROM v_resumen_paises LIMIT 5;


-- ============================================================================
-- CONSULTAS ANALÍTICAS (MÉTRICAS E INSIGHTS DE NEGOCIO)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CONSULTA 1: Distribución global de contenido (Películas vs Series)
-- INSIGHT: Permite conocer el enfoque de negocio actual de Netflix: ¿es una 
-- plataforma de cine o se orienta más a las series de televisión?
-- 
-- RESULTADO ANALIZADO:
--   • Movies (Películas): 6.131 títulos, lo que representa el 69.59% del catálogo.
--   • TV Shows (Series):  2.676 títulos, lo que representa el 30.41% del catálogo.
-- 
-- CONCLUSIÓN: El catálogo está fuertemente volcado hacia el cine (casi 7 de cada 
-- 10 títulos son películas).
-- ----------------------------------------------------------------------------
SELECT 
    tipo AS 'Tipo de Contenido', 
    COUNT(*) AS 'Total Títulos',
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_catalogo)), 2) AS 'Porcentaje %'
FROM dim_contenido
GROUP BY tipo;

-- ----------------------------------------------------------------------------
-- CONSULTA 2: Top 10 países con mayor volumen de producciones (Contando con LIKE)
-- INSIGHT: Detecta cuáles son los mercados clave para Netflix. Al usar LIKE,
-- si una película es de "United States, India", sumará +1 a United States y +1 a India.
-- 
-- RESULTADO ANALIZADO:
--   1. United States:   3.684 títulos
--   2. India:           1.046 títulos
--   3. United Kingdom:    805 títulos
--   4. Canada:            445 títulos
--   5. France:            391 títulos
-- 
-- CONCLUSIÓN: Estados Unidos lidera de forma aplastante el catálogo. Sin embargo, 
-- destaca el peso de mercados emergentes y estratégicos como la India (2º puesto) 
-- y el gran posicionamiento de España (Top 7) dentro del Top 10, consolidándose como 
-- el hub principal de producción en habla hispana.
-- ----------------------------------------------------------------------------
SELECT País, `Total Títulos` AS 'Total Producciones'
FROM v_resumen_paises
LIMIT 10;

-- ----------------------------------------------------------------------------
-- CONSULTA 3: Análisis de co-producciones internacionales en España
-- INSIGHT: Identifica el volumen de contenido donde España participa en solitario
-- o de manera conjunta con la industria de otros países.
-- 
-- RESULTADO ANALIZADO:
--   • Total Contenido con Sello Español: 232 títulos (100% del ecosistema local).
--   • Producción 100% Española:         145 títulos (~62.5% del volumen).
--   • Co-producción Internacional:        87 títulos (~37.5% del volumen).
-- 
-- CONCLUSIÓN: Aunque la mayoría del catálogo español se financia y produce en 
-- solitario (145 títulos), España muestra una altísima tasa de internacionalización: 
-- casi 4 de cada 10 proyectos con sello español se realizan en alianza con otros países.
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(f.fact_id) AS 'Total Contenido con Sello Español',
    SUM(CASE WHEN p.country_name = 'Spain' THEN 1 ELSE 0 END) AS 'Producción 100% Española',
    SUM(CASE WHEN p.country_name LIKE '%,%' THEN 1 ELSE 0 END) AS 'Co-producción Internacional'
FROM fact_catalogo f
INNER JOIN dim_paises p ON f.pais_id = p.pais_id
WHERE p.country_name LIKE '%Spain%';

-- ----------------------------------------------------------------------------
-- CONSULTA 4: Evolución cronológica del catálogo (Títulos añadidos por año)
-- INSIGHT: Muestra la agresividad de expansión que ha tenido Netflix a lo largo
-- de los años evaluando el ritmo de incorporación de nuevos contenidos.
-- 
-- RESULTADO ANALIZADO:
--   • 2008 - 2015: Fase Temprana (Catálogo reducido, de 1 a 82 títulos/año).
--   • 2016 - 2018: Fase de Expansión Masiva (Crecimiento exponencial, pasando de 427 a 1.647).
--   • 2019 - 2020: Pico Histórico (Madurez del catálogo con un récord de 2.015 títulos en 2019).
--   • 2021: Desaceleración Estratégica (Baja a 1.498 títulos, priorizando calidad sobre cantidad).
-- 
-- CONCLUSIÓN: Los datos reflejan perfectamente la estrategia de la compañía: una brutal 
-- carrera por inundar el mercado entre 2016 y 2020, estabilizándose a partir de 2021 debido 
-- a la fuerte competencia de otras plataformas de streaming.
-- ----------------------------------------------------------------------------
SELECT 
    dt.anio_added AS 'Año de Incorporación',
    COUNT(f.fact_id) AS 'Títulos Añadidos'
FROM fact_catalogo f
INNER JOIN dim_dates dt ON f.date_id = dt.date_id
GROUP BY dt.anio_added
ORDER BY dt.anio_added DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 5: Estacionalidad de los estrenos (Análisis por meses)
-- INSIGHT: Descubre si el equipo de marketing de Netflix concentra los lanzamientos
-- en épocas específicas del año (ej. campañas de invierno o verano).
-- 
-- RESULTADO ANALIZADO:
--   • Puesto #1 (Techo Estival): Julio lidera el año con 826 títulos añadidos.
--   • Puesto #2 (Campaña Navideña): Diciembre le sigue muy de cerca con 813 títulos.
--   • Bloque Sostenido (Otoño/Primavera): Meses como Septiembre (769), Abril (763) y Octubre (760) mantienen un ritmo alto.
--   • Puesto #12 (Valle Mínimo): Febrero es el mes con menos actividad, registrando solo 563 incorporaciones.
-- 
-- CONCLUSIÓN: La estrategia de lanzamientos está perfectamente alineada con los picos de 
-- ocio del consumidor. Netflix pone toda la carne en el asador en los dos periodos vacacionales 
-- clave del año: las vacaciones de verano (Julio) y los días festivos de invierno (Diciembre).
-- ----------------------------------------------------------------------------
SELECT 
    dt.mes_nombre AS 'Mes',
    COUNT(f.fact_id) AS 'Títulos Añadidos',
    RANK() OVER (ORDER BY COUNT(f.fact_id) DESC) AS 'Ranking de Popularidad'
FROM fact_catalogo f
INNER JOIN dim_dates dt ON f.date_id = dt.date_id
GROUP BY dt.mes_added, dt.mes_nombre
ORDER BY dt.mes_added ASC;

-- ----------------------------------------------------------------------------
-- CONSULTA 6: Los 10 directores más prolíficos de la plataforma (Desglosados con LIKE)
-- INSIGHT: Revela los cineastas con más obras. Al usar el cruce con LIKE,
-- si una película está dirigida por "Rajiv Chilaka, Gulzar", contará +1 para cada uno.
-- 
-- RESULTADO ANALIZADO:
--   1. Ram:                 76 obras (Concentración masiva / Coincidencias de nombre en cine asiático).
--   2. Rajiv Chilaka:       22 obras (Líder en contenido de animación infantil en mercados emergentes).
--   3. Jan Suter:           21 obras (Director clave en producciones y especiales de stand-up hispanohablantes).
--   4. Suhas Kadav:         16 obras |  5. Marcus Raboy: 16 obras
--   6. Jay Karas:           15 obras |  7. McG:          15 obras
--   8. Vijay:               14 obras |  9. LP:           13 obras
--   10. Cathy Garcia-Molina: 13 obras
-- 
-- CONCLUSIÓN: El volumen de directores refleja que el grueso del catálogo de Netflix no se apoya 
-- en los grandes directores de Hollywood (como Spielberg o Scorsese), sino en creadores de franquicias 
-- infantiles locales (como Chilaka o Kadav) y directores especializados en formatos de bajo coste y alta 
-- recurrencia, como los monólogos de comedia y especiales en vivo (Raboy, Karas).
-- ----------------------------------------------------------------------------
SELECT 
    d_limpio.director_name AS 'Director',
    COUNT(f.fact_id) AS 'Total Obras en Catálogo'
FROM fact_catalogo f
INNER JOIN dim_directores d ON f.director_id = d.director_id
INNER JOIN dim_directores d_limpio ON d.director_name LIKE CONCAT('%', d_limpio.director_name, '%')
WHERE d_limpio.director_name != 'Unknown' AND d_limpio.director_name NOT LIKE '%,%'
GROUP BY d_limpio.director_name
ORDER BY COUNT(f.fact_id) DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- CONSULTA 7: Top 15 categorías/géneros más frecuentes en Netflix (Desglosados con LIKE)
-- INSIGHT: Expone las preferencias temáticas reales de la plataforma. Al usar el desglose,
-- si un título está catalogado como "Dramas, Comedies", sumará +1 a Dramas y +1 a Comedies.
-- 
-- RESULTADO ANALIZADO:
--   • El Podio Comercial:  Movies (4.497), Dramas (3.188) y Comedies (2.253) lideran con fuerza.
--   • Enfoque Global:      International Movies (2.750) e International TV Shows (1.350) confirman la expansión fuera de EE.UU.
--   • Nichos Estratégicos: Action & Adventure (1.027) supera la barrera de los mil títulos, seguida de Documentaries (869).
--   • Formato Episódico:   TV Shows (1.754) y TV Dramas (762) aseguran horas de consumo recurrente.
-- 
-- CONCLUSIÓN: Netflix estructura su oferta basándose en tres pilares: largometrajes accesibles (Comedias/Acción), 
-- narrativas profundas de alta fidelización (Dramas/Series) y una fortísima inversión en contenido internacional 
-- para romper la dependencia del mercado norteamericano.
-- ----------------------------------------------------------------------------
SELECT 
    cat_limpia.categoria_name AS 'Género/Categoría',
    COUNT(f.fact_id) AS 'Cantidad de Títulos'
FROM fact_catalogo f
INNER JOIN dim_categorias cat ON f.categoria_id = cat.categoria_id
INNER JOIN dim_categorias cat_limpia ON cat.categoria_name LIKE CONCAT('%', cat_limpia.categoria_name, '%')
WHERE cat_limpia.categoria_name NOT LIKE '%,%'
GROUP BY cat_limpia.categoria_name
ORDER BY COUNT(f.fact_id) DESC
LIMIT 15;


-- ----------------------------------------------------------------------------
-- CONSULTA 8: Duración media de las películas a lo largo de los años
-- INSIGHT: ¿Ha cambiado la tendencia de los espectadores? Analiza si las películas 
-- que produce la industria cinematográfica se están volviendo más cortas o largas.
-- Nota: Filtramos el texto 'min' para convertir la columna 'duration' en número.
-- 
-- RESULTADO ANALIZADO POR ERAS:
--   • 1942 - 1947 [Era Primigenia]: Metrajes muy reducidos, con medias de 35 a 62 minutos (formatos de posguerra).
--   • 1960 - 1969 [Era de las Superproducciones]: Máximo histórico del catálogo. El cine se vuelve monumental, 
--     alcanzando un techo histórico en 1964 con 200.5 minutos de media (más de 3 horas por película).
--   • 1970 - 2005 [Era Comercial de Hollywood]: Estabilización general del metraje en la famosa franja 
--     estándar de las 2 horas (medias oscilando entre 110 y 125 minutos).
--   • 2006 - 2021 [Era Digital y Streaming]: Descenso drástico y continuado. El cine moderno se comprime 
--     año tras año, bajando de los 113 minutos en 2006 hasta el suelo reciente de 92.1 minutos en 2020.
-- 
-- CONCLUSIÓN: Existe una correlación directa entre el soporte/canal de distribución y la duración del filme. 
-- El cine vivió su época más larga en los cines de los años 60 (grandes epopeyas), pero la llegada de las 
-- plataformas de streaming y la lucha por capturar la atención del espectador en casa han provocado que las 
-- películas actuales sean casi una hora más cortas que las de hace 50 años.
-- ----------------------------------------------------------------------------
SELECT 
    f.release_year AS 'Año de Estreno',
    ROUND(AVG(CAST(REPLACE(c.duration, ' min', '') AS UNSIGNED)), 1) AS 'Duración Media (Minutos)'
FROM fact_catalogo f
INNER JOIN dim_contenido c ON f.contenido_id = c.contenido_id
WHERE c.tipo = 'Movie' AND c.duration LIKE '%min%'
GROUP BY f.release_year
ORDER BY f.release_year DESC;


-- ----------------------------------------------------------------------------
-- CONSULTA 9: Análisis de madurez del catálogo (Clasificaciones por edad)
-- INSIGHT: Segmenta el catálogo por tipo de público (infantil, adultos, etc.). 
-- Útil para evaluar si Netflix es una plataforma enfocada a familias o a adultos.
-- 
-- RESULTADO ANALIZADO POR AUDIENCIAS:
--   • Core Adulto (TV-MA, R, NC-17): 4.007 títulos acumulados. Representa el núcleo mayoritario 
--     del catálogo con series y cine de corte maduro (violencia, lenguaje, temas adultos).
--   • Core Juvenil/Familiar (TV-14, PG-13, TV-PG, PG): 3.800 títulos. Es el bloque intermedio 
--     que busca la masa comercial y el consumo en el hogar de adolescentes y público general.
--   • Core Infantil (TV-Y, TV-Y7, G, TV-G): 1.102 títulos. Segmento más reducido en volumen 
--     pero estratégicamente volcado en series (formatos episódicos de animación para fidelizar).
-- 
-- CONCLUSIÓN: El modelo de negocio de Netflix prioriza el contenido para adultos como motor de 
-- suscripción individual, pero mantiene un colchón gigante de contenido juvenil e infantil para 
-- justificar el pago de las cuentas familiares compartidas.
-- ----------------------------------------------------------------------------
SELECT 
    c.rating AS 'Clasificación de Edad',
    SUM(CASE WHEN c.tipo = 'Movie' THEN 1 ELSE 0 END) AS 'Películas',
    SUM(CASE WHEN c.tipo = 'TV Show' THEN 1 ELSE 0 END) AS 'Series',
    COUNT(*) AS 'Total acumulado'
FROM fact_catalogo f
INNER JOIN dim_contenido c ON f.contenido_id = c.contenido_id
GROUP BY c.rating
ORDER BY COUNT(*) DESC;


-- ----------------------------------------------------------------------------
-- CONSULTA 10: Desglose de formato en los 5 mercados estratégicos (Movies vs TV)
-- INSIGHT: Compara el peso de películas y series en los principales países productores
-- para entender si la estrategia de Netflix se adapta a la cultura local.
-- 
-- RESULTADO ANALIZADO POR MERCADOS:
--   • United States: Dominio absoluto y equilibrado (2.747 películas / 937 series).
--   • India: Hegemonía del largometraje. El mercado está copado por el formato película 
--     (962 frente a solo 84 series), reflejando la fuerte influencia de la industria de Bollywood.
--   • United Kingdom: Mercado maduro con una altísima tasa de producción de series (272), 
--     apoyado históricamente en fuertes alianzas con productoras británicas.
--   • Japan: El país atípico. Es el único de los grandes mercados donde el formato episódico 
--     (199 series) supera al cine (118 películas), impulsado directamente por el consumo de Anime.
--   • Spain: Consolidación hispana con 171 películas y 61 series, marcando un polo de creación clave.
-- 
-- CONCLUSIÓN: Netflix no impone un mismo formato globalmente. Los datos demuestran que adapta su 
-- oferta y su inversión a la tradición audiovisual de cada región (cine en India, series en Japón).
-- ----------------------------------------------------------------------------
SELECT 
    p_limpio.country_name AS 'País',
    SUM(CASE WHEN c.tipo = 'Movie' THEN 1 ELSE 0 END) AS 'Total Películas',
    SUM(CASE WHEN c.tipo = 'TV Show' THEN 1 ELSE 0 END) AS 'Total Series',
    COUNT(f.fact_id) AS 'Producción Total'
FROM fact_catalogo f
INNER JOIN dim_paises p_sucio ON f.pais_id = p_sucio.pais_id
INNER JOIN dim_contenido c ON f.contenido_id = c.contenido_id
-- Aplicamos la magia: buscamos los países limpios dentro del bloque con comas
INNER JOIN dim_paises p_limpio ON p_sucio.country_name LIKE CONCAT('%', p_limpio.country_name, '%')
WHERE p_limpio.country_name IN ('United States', 'India', 'United Kingdom', 'Japan', 'Spain')
GROUP BY p_limpio.country_name -- ¡Agrupamos por el limpio!
ORDER BY COUNT(f.fact_id) DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 11: Uso de nuestra Función Personalizada y CASE lógicos
-- REQUISITO: Ejecución de la FUNCTION creada y condicionales CASE
-- INSIGHT: Clasifica el catálogo aplicando lógica de negocio personalizada para 
-- diseñar una estrategia de optimización de infraestructura tecnológica (IT) y servidores.
-- 
-- RESULTADO ANALIZADO:
--   • Película Estándar (90-120 min): 3.146 títulos ➔ Prioridad Alta en Servidores.
--   • Serie de TV:                    2.675 títulos ➔ Prioridad Alta en Servidores.
--   • Película Corta (<90 min):       1.838 títulos ➔ Prioridad Media.
--   • Película Larga (>120 min):      1.142 títulos ➔ Prioridad Media.
-- 
-- CONCLUSIÓN: Esta consulta une el análisis de contenidos con la ingeniería de sistemas. 
-- El grueso de la plataforma se sostiene sobre películas estándar y series (más de 5.800 títulos). 
-- Al catalogarlos como 'Prioridad Alta', se define que estos contenidos deben estar pre-cargados 
-- en los nodos Edge (servidores locales) para evitar latencia y garantizar un streaming 4K instantáneo.
-- ----------------------------------------------------------------------------
SELECT 
    f_clasificar_duracion(c.tipo, c.duration) AS 'Segmento de Duración',
    COUNT(f.fact_id) AS 'Cantidad de Contenidos',
    CASE 
        WHEN COUNT(f.fact_id) > 2000 THEN 'Prioridad Alta en Servidores'
        WHEN COUNT(f.fact_id) BETWEEN 500 AND 2000 THEN 'Prioridad Media'
        ELSE 'Prioridad Baja'
    END AS 'Estrategia IT'
FROM fact_catalogo f
INNER JOIN dim_contenido c ON f.contenido_id = c.contenido_id
GROUP BY f_clasificar_duracion(c.tipo, c.duration)
ORDER BY COUNT(f.fact_id) DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 12: Análisis Cruzado Avanzado con CTEs Encadenadas
-- REQUISITO: CTEs (WITH) encadenadas utilizando más de una tabla temporal y subqueries
-- INSIGHT: Esta consulta cruza el TOP de mercados de Netflix con sus tres géneros 
-- predilectos, desvelando el perfil de consumo específico de cada región geográfica.
-- 
-- RESULTADO ANALIZADO POR REGIONES (TOP 3 GÉNEROS):
--   • INDIA: 
--     1. Movies (926) | 2. International Movies (864) | 3. Dramas (690).
--     Foco absoluto en el largometraje y las historias profundas o musicales tradicionales.
--   • UNITED KINGDOM: 
--     1. Movies (328) | 2. TV Shows (239) | 3. Dramas (233).
--     Mercado equilibrado que destaca por una fuerte cultura de series y ficción episódica.
--   • UNITED STATES: 
--     1. Movies (1.465) | 2. Dramas (1.066) | 3. Comedies (938).
--     El motor global de la plataforma, muy volcado en el cine y la comedia/sitcom americana.
--
-- CONCLUSIÓN: El uso de expresiones de tabla comunes (CTEs) encadenadas permite segmentar 
-- las preferencias sin mezclar los sesgos geográficos. Netflix aprovecha estos perfiles para 
-- decidir qué producir: sabe que invertir en una serie dramática funcionará en UK, pero en India 
-- debe priorizar los largometrajes de corte internacional.
-- ----------------------------------------------------------------------------
WITH cte_paises_top AS (
    SELECT p_limpio.country_name, COUNT(f.fact_id) AS volumen
    FROM fact_catalogo f
    INNER JOIN dim_paises p_sucio ON f.pais_id = p_sucio.pais_id
    INNER JOIN dim_paises p_limpio ON p_sucio.country_name LIKE CONCAT('%', p_limpio.country_name, '%')
    WHERE p_limpio.country_name IN ('United States', 'India', 'United Kingdom')
    GROUP BY p_limpio.country_name
),
cte_generos_por_pais AS (
    SELECT 
        p_limpio.country_name AS pais,
        cat_limpia.categoria_name AS genero,
        COUNT(f.fact_id) AS total_titulos
    FROM fact_catalogo f
    INNER JOIN dim_paises p_sucio ON f.pais_id = p_sucio.pais_id
    INNER JOIN dim_paises p_limpio ON p_sucio.country_name LIKE CONCAT('%', p_limpio.country_name, '%')
    INNER JOIN dim_categorias cat ON f.categoria_id = cat.categoria_id
    INNER JOIN dim_categorias cat_limpia ON cat.categoria_name LIKE CONCAT('%', cat_limpia.categoria_name, '%')
    WHERE p_limpio.country_name IN (SELECT country_name FROM cte_paises_top)
      AND cat_limpia.categoria_name NOT LIKE '%,%'
    GROUP BY p_limpio.country_name, cat_limpia.categoria_name
)
SELECT pais, genero, total_titulos
FROM (
    SELECT pais, genero, total_titulos,
           ROW_NUMBER() OVER (PARTITION BY pais ORDER BY total_titulos DESC) AS ranking_interno
    FROM cte_generos_por_pais
) consulta_final
WHERE ranking_interno <= 3;
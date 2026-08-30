-- ============================================================
-- 03 — SIMULAÇÃO DE IMPACTO FINANCEIRO
-- ============================================================
-- Pergunta de negócio: se os vendedores abaixo da média do
-- time chegassem à média, quanto de receita adicional isso
-- geraria?
--
-- Fórmula aplicada por vendedor:
--   (taxa_média − taxa_do_vendedor) × oportunidades_do_vendedor
--   × ticket_médio_do_time
--
-- Premissa: a meta de referência é a média histórica do
-- próprio time (não uma meta externa), documentada no README.
-- ============================================================


-- ------------------------------------------------------------
-- DETALHE POR VENDEDOR — gap de conversão e receita potencial
-- ------------------------------------------------------------
-- CTEs (WITH ... AS) quebram o cálculo em blocos legíveis, em
-- vez de aninhar subqueries confusas dentro de subqueries.
WITH taxa_time AS (
  SELECT 100.0 * SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) /
         SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END) AS taxa_media
  FROM pipeline
  WHERE deal_stage IN ('Won','Lost')
),
ticket_time AS (
  SELECT AVG(close_value) AS ticket_medio
  FROM pipeline
  WHERE deal_stage = 'Won'
),
vendedores AS (
  SELECT sales_agent,
         SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END) AS oportunidades_trabalhadas,
         100.0 * SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) /
         SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END) AS taxa_vendedor
  FROM pipeline
  GROUP BY sales_agent
)
SELECT
  v.sales_agent,
  ROUND(v.taxa_vendedor, 2) AS taxa_conversao_vendedor,
  ROUND(t.taxa_media, 2) AS taxa_media_time,
  v.oportunidades_trabalhadas,
  ROUND(tk.ticket_medio, 2) AS ticket_medio_time,
  ROUND((t.taxa_media - v.taxa_vendedor) / 100.0 * v.oportunidades_trabalhadas * tk.ticket_medio, 2) AS receita_potencial_adicional
FROM vendedores v
CROSS JOIN taxa_time t
CROSS JOIN ticket_time tk
WHERE v.taxa_vendedor < t.taxa_media
ORDER BY receita_potencial_adicional DESC;
-- CROSS JOIN é usado porque taxa_time e ticket_time têm sempre
-- uma única linha (um número só) — "cruzamos" esse número com
-- cada linha de vendedor, sem precisar de condição de JOIN.


-- ------------------------------------------------------------
-- TOTAL CONSOLIDADO — o número que vai no README/currículo
-- ------------------------------------------------------------
WITH taxa_time AS (
  SELECT 100.0 * SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) /
         SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END) AS taxa_media
  FROM pipeline
  WHERE deal_stage IN ('Won','Lost')
),
ticket_time AS (
  SELECT AVG(close_value) AS ticket_medio
  FROM pipeline
  WHERE deal_stage = 'Won'
),
vendedores AS (
  SELECT sales_agent,
         SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END) AS oportunidades_trabalhadas,
         100.0 * SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) /
         SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END) AS taxa_vendedor
  FROM pipeline
  GROUP BY sales_agent
)
SELECT
  ROUND(SUM((t.taxa_media - v.taxa_vendedor) / 100.0 * v.oportunidades_trabalhadas * tk.ticket_medio), 2) AS receita_total_potencial
FROM vendedores v
CROSS JOIN taxa_time t
CROSS JOIN ticket_time tk
WHERE v.taxa_vendedor < t.taxa_media;

-- Resultado validado nesta análise: R$ 200.173,88 em receita
-- potencial adicional (conferido também no Power BI via DAX).

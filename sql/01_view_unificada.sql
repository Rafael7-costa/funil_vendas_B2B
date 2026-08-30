-- ============================================================
-- 01 — MODELAGEM: VIEW UNIFICADA DO PIPELINE
-- ============================================================
-- Objetivo: unir a tabela de oportunidades (pipeline) com a
-- tabela de vendedores/times (times), trazendo região e gestor
-- para dentro de uma única visão — sem essa view, não seria
-- possível responder perguntas de negócio por região.
--
-- Tabelas de origem:
--   pipeline  -> sales_pipeline.csv
--   times     -> sales_teams.csv
-- ============================================================

CREATE VIEW vw_pipeline_completo AS
SELECT
  p.opportunity_id,
  p.sales_agent,
  t.manager,
  t.regional_office,
  p.product,
  p.account,
  p.deal_stage,
  p.engage_date,
  p.close_date,
  p.close_value,
  -- Ciclo de vendas: diferença em dias entre o primeiro contato
  -- e o fechamento. Fica NULL para oportunidades ainda em aberto
  -- (comportamento esperado, não é erro de dado).
  JULIANDAY(p.close_date) - JULIANDAY(p.engage_date) AS dias_ciclo
FROM pipeline p
LEFT JOIN times t ON p.sales_agent = t.sales_agent;
-- LEFT JOIN (não INNER) para garantir que nenhuma oportunidade
-- do pipeline seja perdida, mesmo que o vendedor não tenha
-- correspondência na tabela de times.


-- ============================================================
-- VALIDAÇÃO — rodar após criar a view
-- ============================================================
SELECT * FROM vw_pipeline_completo LIMIT 10;
-- Checar: regional_office e manager preenchidos (não nulos em
-- massa) e dias_ciclo com valores coerentes para linhas fechadas.

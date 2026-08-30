-- ============================================================
-- 02 — PERGUNTAS DE NEGÓCIO
-- ============================================================
-- Cada bloco responde diretamente a uma das 6 perguntas de
-- negócio definidas no README do projeto.
-- ============================================================


-- ------------------------------------------------------------
-- PERGUNTA 1 — Taxa de conversão geral (Won / total)
-- ------------------------------------------------------------
-- SUM(COUNT(*)) OVER () é uma window function: calcula o total
-- geral sem precisar de uma segunda query separada.
SELECT deal_stage, COUNT(*) AS qtd,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM pipeline
GROUP BY deal_stage;


-- ------------------------------------------------------------
-- PERGUNTA 2 — Ranking de vendedores (conversão + ticket médio)
-- ------------------------------------------------------------
-- CASE WHEN dentro de SUM/AVG permite contar/somar condicionalmente
-- sem precisar filtrar a tabela toda com WHERE.
SELECT sales_agent,
       COUNT(*) AS total_oportunidades,
       SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) AS ganhas,
       ROUND(100.0 * SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_conversao,
       ROUND(AVG(CASE WHEN deal_stage='Won' THEN close_value END), 2) AS ticket_medio
FROM pipeline
GROUP BY sales_agent
ORDER BY pct_conversao DESC;


-- ------------------------------------------------------------
-- PERGUNTA 3 — Receita e % de perda por produto
-- ------------------------------------------------------------
-- NULLIF evita erro de divisão por zero caso algum produto não
-- tenha nenhuma oportunidade Won/Lost ainda (só em aberto).
SELECT product,
       SUM(CASE WHEN deal_stage='Won' THEN close_value ELSE 0 END) AS receita_total,
       ROUND(100.0 * SUM(CASE WHEN deal_stage='Lost' THEN 1 ELSE 0 END) /
             NULLIF(SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END),0), 2) AS pct_perda
FROM pipeline
GROUP BY product
ORDER BY receita_total DESC;


-- ------------------------------------------------------------
-- PERGUNTA 4 — Ciclo médio de vendas por região
-- ------------------------------------------------------------
-- Usa a view unificada (vw_pipeline_completo), já que
-- regional_office só existe depois do JOIN com a tabela de times.
-- Filtra só Won: só faz sentido medir "tempo até fechar" em
-- negócios que de fato fecharam.
SELECT regional_office,
       ROUND(AVG(dias_ciclo), 1) AS dias_ciclo_medio
FROM vw_pipeline_completo
WHERE deal_stage = 'Won'
GROUP BY regional_office
ORDER BY dias_ciclo_medio;


-- ------------------------------------------------------------
-- PERGUNTA 5 — Sazonalidade: oportunidades ganhas por trimestre
-- ------------------------------------------------------------
-- SQLite não tem função nativa de trimestre — a fórmula
-- ((mês-1)/3)+1 converte "mês 1-12" em "trimestre 1-4"
-- (divisão inteira).
SELECT strftime('%Y', close_date) AS ano,
       ((CAST(strftime('%m', close_date) AS INTEGER) - 1) / 3) + 1 AS trimestre,
       COUNT(*) AS ganhas,
       SUM(close_value) AS receita
FROM pipeline
WHERE deal_stage = 'Won'
GROUP BY ano, trimestre
ORDER BY ano, trimestre;


-- ------------------------------------------------------------
-- PERGUNTA 6 — Vendedores abaixo da média (base para simulação)
-- ------------------------------------------------------------
-- Parte A: taxa média de conversão do time inteiro (referência)
SELECT ROUND(100.0 * SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) / COUNT(*), 2) AS taxa_media_time
FROM pipeline
WHERE deal_stage IN ('Won','Lost');

-- Parte B: vendedores com conversão abaixo dessa média
-- HAVING (não WHERE) porque o filtro é sobre uma coluna
-- agregada (pct_conversao), que só existe após o GROUP BY.
SELECT sales_agent,
       COUNT(*) AS total_oportunidades,
       ROUND(100.0 * SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) /
             SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END), 2) AS pct_conversao,
       (SELECT ROUND(AVG(close_value),2) FROM pipeline WHERE deal_stage='Won') AS ticket_medio_time
FROM pipeline
GROUP BY sales_agent
HAVING pct_conversao < (
    SELECT ROUND(100.0 * SUM(CASE WHEN deal_stage='Won' THEN 1 ELSE 0 END) /
                 SUM(CASE WHEN deal_stage IN ('Won','Lost') THEN 1 ELSE 0 END), 2)
    FROM pipeline
    WHERE deal_stage IN ('Won','Lost')
);

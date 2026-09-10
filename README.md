# Funil de Vendas B2B — Onde a Receita Está Vazando?

**Ferramentas:** SQL (SQLite/DBeaver) · Power BI · DAX
**Dataset:** CRM Sales Opportunities (Maven Tech) — [Kaggle](https://www.kaggle.com/datasets/innocentmfa/crm-sales-opportunities)
**Cargo-alvo:** Analista de Performance Comercial · Analista de Indicadores · Sales Ops Analyst

---

## 1. Problema de Negócio

Uma empresa de hardware vende para grandes contas via time comercial, mas não tem visibilidade clara de **onde o funil "vaza" oportunidades** nem de **quais vendedores e produtos performam melhor**. A liderança sabe o número final de receita fechada, mas não sabe quantificar quanto está deixando de faturar por desvios de performance individual — nem se esses desvios têm causa identificável (ciclo de venda, região, sazonalidade, produto) ou são aleatórios.

O objetivo deste projeto foi ir além do "quanto vendemos" e responder **"por que vendemos o que vendemos, e quanto vale corrigir os desvios encontrados"**.

---

## 2. Premissas

- `deal_stage` define a etapa da oportunidade (`Engaging`, `Prospecting`, `Won`, `Lost`).
- `close_value` só é considerado receita quando `deal_stage = Won`; negócios `Lost` ou em aberto não entram no cálculo de receita.
- Ciclo de vendas = `close_date − engage_date`, calculado apenas para oportunidades já decididas (Won ou Lost) — negócios em aberto não têm ciclo completo, então foram excluídos dessa métrica.
- A **meta de conversão de referência** usada na simulação financeira é a **média histórica do próprio time**, não uma meta externa — na ausência de uma meta oficial da empresa, essa é a premissa mais defensável e auditável.
- A simulação de receita potencial assume que o vendedor mantém o mesmo volume de oportunidades trabalhadas, elevando apenas sua taxa de conversão até a média do time — não considera aumento de esforço ou tempo adicional do vendedor.
- A base cobre 10 meses (março a dezembro), abrangendo 3 trimestres completos (Qtr2, Qtr3, Qtr4) e 1 incompleto (Qtr1) — período limitado para confirmar sazonalidade estrutural com múltiplos anos, mas suficiente para identificar um padrão recorrente dentro do próprio ano analisado.
- Valores nulos em `close_date`/`close_value` são esperados (oportunidades ainda em aberto) e foram tratados via lógica condicional nas queries/medidas, não removidos da base.

---

## 3. Perguntas de Negócio

1. Qual a taxa de conversão geral (Won / total de oportunidades)?
2. Quais vendedores têm a maior taxa de conversão e o maior ticket médio?
3. Qual produto tem maior receita total fechada e qual tem maior taxa de perda?
4. Qual o tempo médio de ciclo de vendas (dias) por vendedor e por região?
5. Há sazonalidade nas oportunidades ganhas por trimestre?
6. Se elevássemos a taxa de conversão dos vendedores abaixo da média para a média do time, quanto de receita adicional isso geraria?

**Perguntas adicionais investigadas** (além do escopo original, para diagnóstico de causa raiz):
7. Vendas com ciclo mais curto convertem mais que as de ciclo mais longo?
8. A conversão varia por região, isoladamente?
9. Existem pontos cegos de performance concentrados em combinações específicas de vendedor × produto?
10. Existe um padrão de comportamento dentro de cada trimestre (não só entre trimestres)?

---

## 4. Estratégia da Solução

O projeto foi estruturado em duas camadas técnicas complementares:

**SQL (SQLite via DBeaver)** — modelagem relacional das 4 tabelas do CRM (`pipeline`, `times`, `produtos`, `contas`) unificadas via `LEFT JOIN` numa view (`vw_pipeline_completo`), usada para validar toda a lógica de negócio antes de levar ao BI — incluindo o cálculo da simulação financeira via CTEs (`WITH`).

**Power BI (DAX)** — modelo com tabela de medidas dedicada (`_Medidas`), organizado em **4 páginas por propósito**, aplicando duas técnicas de análise:

- **Análise Descritiva** (Páginas 1, 2 e 3): retrato do estado atual do funil — KPIs, ranking de vendedores, performance por produto, sazonalidade.
- **Análise Diagnóstica** (Página 4): investigação de causa raiz por trás dos números descritivos — testando hipóteses sobre ciclo de venda, região e comportamento vendedor × produto.
- Com uma camada de **Análise Prescritiva pontual**: a medida de Receita Potencial Adicional não só diagnostica quem está abaixo da média, como quantifica o ganho de uma ação concreta (elevar o vendedor à média do time).

### Estrutura das páginas

| Página | Propósito | Perguntas respondidas |
|---|---|---|
| **1 — Visão Geral** | Leitura executiva rápida | 1, 5, 6 (resumo) e 10 |
| **2 — Performance Vendedor** | Ranking e detalhamento individual | 2, 4 e 6 (detalhe) |
| **3 — Performance Produto** | Receita e perda por produto | 3 |
| **4 — Análise de Causas** | Diagnóstico de causa raiz | 7, 8 e 9 |

---

## 5. Insights

**"Efeito de fim de trimestre" — o achado mais forte do projeto**
O primeiro mês de cada trimestre concentra a menor receita e o maior volume de negócios perdidos, enquanto o último mês do trimestre apresenta o pico de receita e a menor perda — padrão que se repetiu nos 3 trimestres completos da base. Em junho (fim do Qtr2), a receita fechada chegou a R$ 1,34 Mi com apenas 110 negócios perdidos; já em abril (início do mesmo trimestre), a receita foi de R$ 721 mil com 301 negócios perdidos — quase o triplo de perdas, com menos da metade da receita. Esse comportamento é consistente com o efeito de **"fechamento sob pressão de meta trimestral"**, comum em vendas B2B: negociações que estariam indefinidas tendem a ser fechadas — não descartadas como perdidas — no mês final do trimestre, enquanto o pipeline se reconstrói (e perde mais) logo no início do ciclo seguinte.

**Conversão e ciclo de venda — a crença popular não se confirma**
Diferente da suposição comum de que "quanto mais rápido o fechamento, maior a conversão", o comportamento observado **não é linear**: oportunidades com ciclo médio (16 a 45 dias) apresentam taxa de conversão mais alta do que as de ciclo rápido (até 15 dias) ou lento (45+ dias). O ticket médio mais elevado justamente no grupo de ciclo rápido descarta a hipótese de que esse padrão seja apenas efeito do tamanho do negócio — negociações rápidas não são simplesmente "as mais fáceis e baratas de fechar".

**Região não é fator determinante**
As três regionais analisadas (Central, East, West) apresentam taxas de conversão muito próximas entre si, com ciclo médio também similar (47 a 49 dias). Isso indica que diferenças de performance não são explicadas pela região em si — a causa está em outro nível (individual, temporal ou de produto).

**Nem todo produto de alta receita é eficiente**
O produto GTXPro lidera em receita fechada (R$ 3,51 Mi), mas o MG Advanced, mesmo com receita menor (R$ 2,22 Mi), apresenta a maior taxa de perda entre os principais produtos (40%) — sinal de que volume de receita e eficiência de conversão são leituras distintas e não podem ser avaliadas pelo mesmo indicador isoladamente.

**Os pontos cegos são individuais, não do time inteiro**
A matriz vendedor × produto mostra que as quedas de conversão mais acentuadas não formam um padrão coletivo (o que indicaria problema do produto ou do argumento de venda geral), mas aparecem concentradas em combinações específicas de vendedor com determinado produto — reforçando a necessidade de treinamento direcionado, célula por célula, em vez de uma capacitação genérica para todo o time.

---

## 6. Resultado / Impacto Financeiro

- **Receita fechada total:** R$ 10,01 Mi
- **Taxa de conversão geral:** 48,16%
- **Ciclo médio de vendas:** 47,99 dias
- **Receita potencial adicional identificada:** **R$ 200,17 Mil**

> "Se todos os vendedores abaixo da taxa de conversão média do time (63%) chegassem a esse mesmo patamar — mantendo o volume atual de oportunidades trabalhadas — a empresa teria capturado um adicional estimado de **R$ 200,17 mil em receita**, sem qualquer investimento em aquisição de novos leads. Esse valor está concentrado em um grupo específico de vendedores (destacados na Página 2 do dashboard), o que torna a ação de correção viável e direcionada, não um esforço genérico de treinamento para todo o time."

> "Adicionalmente, o padrão de 'efeito de fim de trimestre' identificado sugere uma segunda alavanca de ganho: antecipar o esforço de fechamento para o meio do trimestre — em vez de concentrá-lo apenas no mês final — tem potencial de reduzir o volume de negócios perdidos hoje concentrado no primeiro mês de cada ciclo seguinte."

### Estrutura completa do dashboard (4 páginas) disponível em:
[[Visualizar Dashboard](https://app.powerbi.com/view?r=eyJrIjoiOGQ2Y2U0NjYtNDVmYy00ZDE1LThiYmYtMGExNjQ5ZGNlMTUzIiwidCI6ImE0NTMyMzQyLWRjNjktNDhjMC1iODJhLTRhMWQ1ZDg2NGU2YiJ9)].

---

## 7. Próximos Passos

- Cruzar os dados de performance com custo de comissão/remuneração por vendedor, para calcular o ROI de um programa de coaching direcionado aos vendedores identificados abaixo da média.
- Investigar com mais profundidade a combinação vendedor × produto com maior gap de conversão (matriz da Página 4), validando com o time comercial se a causa é argumento de venda, precificação ou fit de produto.
- Validar o padrão de "efeito de fim de trimestre" com mais anos de histórico, para confirmar se é sazonalidade estrutural ou um comportamento pontual do período analisado.
- Automatizar a atualização do modelo (hoje via exportação CSV) com uma conexão direta ao banco, criando um scorecard mensal recorrente.
- Testar um modelo preditivo simples (regressão logística) de propensão a fechar negócio, usando as variáveis já mapeadas neste projeto (ciclo, vendedor, produto, região, mês do trimestre) como features — evolução natural da análise diagnóstica para a preditiva.

---

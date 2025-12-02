# 🧠 Projeto SIAD – Previsão de `matched_score`

### 0. Estrutura do Repositório
```bash
├── data/
│   └── resume_data.csv              # Dataset utilizado
├── r/
│   ├── 01_data_understanding.R      # Análise exploratória
│   ├── 02_data_preparation.R        # Preparação e limpeza
│   ├── 03_modeling.R                # Modelação baseline
│   ├── 03b_modeling_improved.R      # Modelação optimizada
│   ├── 04_evaluation.R              # Avaliação de resultados
│   ├── 05_others.R                  # Funções e modelo final
│   └── dependencies.R               # Dependencies
├── results/
│   ├── metrics.csv                  # Métricas de desempenho
│   ├── feature_importance.png       # Importância das variáveis
│   └── predictions_vs_actual.png    # Gráfico real vs previsto
├── modelo_final.rds                 # Modelo treinado
└── README.md                        # Descrição do projeto
```

## 📋 Descrição do Projeto
Este projeto foi desenvolvido no âmbito da unidade curricular **Sistemas Inteligentes de Apoio à Decisão (SIAD)**, sob orientação do **Prof. Sérgio Moro**.  
O objetivo é aplicar a metodologia **CRISP-DM** para desenvolver um modelo de **aprendizagem supervisionada** em **R**, capaz de **prever o valor da variável `matched_score`** com base nas restantes variáveis do dataset.

### Documentação
- 📖 `SUMARIO_MELHORIAS.md` - Visão geral das melhorias

---

## 🧩 Metodologia – CRISP-DM

O projeto segue as seis fases da metodologia **CRISP-DM (Cross Industry Standard Process for Data Mining)**:

 - Definição do problema: prever `matched_score` a partir de características do dataset.
 - Tipo de problema: **Regressão supervisionada**.
 - Benefício esperado: apoiar processos de decisão relacionados com a qualidade do “matching” entre entidades.
 - Variável dependente: `matched_score`.

---

 - Carregamento e exploração inicial dos dados (`read.csv`, `str`, `summary`, `skimr::skim`). [R & RELATÓRIO]
 - Identificação de variáveis numéricas e categóricas. [RELATÓRIO]
 - Análise da distribuição de `matched_score` (histogramas, boxplots). [R & RELATÓRIO]
 - Verificação de **valores omissos** e **outliers**. [R & RELATÓRIO]
 - Análise de correlações (`cor`, `corrplot`, `ggcorrplot`). [R & RELATÓRIO]

---

 - Tratamento de valores em falta (remoção ou imputação).
 - Codificação de variáveis categóricas (`factor`, `caret::dummyVars`).
 - Normalização / padronização de variáveis numéricas (`scale`).
 - Seleção e engenharia de atributos (feature engineering).
 - Divisão dos dados em **treino (80%)** e **teste (20%)**

### 4. Modeling
**Fase 1 - Baseline (03_modeling.R):**
Treino de modelos base:
- Regressão Linear (lm)
- Random Forest (randomForest)
- Gradient Boosting (xgboost)
- Regressão Regularizada (glmnet)

Utilização de validação cruzada com caret::trainControl().

**Fase 2 - Optimização (03b_modeling_improved.R):**
Melhorias implementadas:
- Hyperparameter tuning extensivo com grid search
- Novos modelos: SVM, GBM
- Ensemble methods: stacking e média ponderada
- Validação cruzada com 10 folds
- Feature importance analysis

Comparação dos modelos com base em métricas de regressão (RMSE, MAE, R²). [R & RELATÓRIO]

Justificação da escolha do modelo final. [RELATÓRIO]

### 5. Evaluation [R & RELATÓRIO]
Avaliação do modelo final com dados de teste:
- predictions <- predict(model_rf, newdata=test)
- caret::postResample(predictions, test$matched_score)

Visualização:
- Gráfico de valores reais vs. previstos.
- Análise de resíduos.

Comparação dos desempenhos dos modelos testados.

### 6. Others [R & RELATÓRIO]
Guardar o modelo final para utilização futura:
- saveRDS(modelo_final, "modelo_final.rds")
- O modelo é guardado automaticamente no script de modelação

Criar funções de previsão:

**1. Função básica de previsão (`prever_score`)**:
- Carrega modelo treinado (.rds)
- Aplica transformações Yeo-Johnson e padronização
- Retorna vetor de previsões
- Validações de entrada e tratamento de erros

**2. Função avançada com avaliação (`prever_e_avaliar`)**:
- Previsões + análise de desvios quando valores reais disponíveis
- Métricas: RMSE, MAE, MAPE, R², Correlação
- Estatísticas dos desvios (min, Q1, mediana, média, Q3, max, SD)
- Identificação dos Top 10 casos com maior desvio
- Gráficos automáticos: Previsto vs Real, Residuais, Q-Q plot, Histograma de resíduos
- Teste automático com primeiras 100 observações do conjunto de teste

Descrição de possíveis formas de integração do modelo num sistema real (API, dashboard, etc.).

### 7. Tecnologias e Pacotes Utilizados
Linguagem: R
Principais pacotes:
tidyverse
caret
randomForest
xgboost
glmnet
ggplot2
corrplot
skimr

---

## 📦 Guia de Utilização das Funções de Previsão

### 🎯 Funções Disponíveis

O ficheiro `r/05_others.R` contém duas funções para usar o modelo em produção:

#### **Função 1: `prever_score()`**

**Propósito:** Fazer previsões simples em novos dados.

**Inputs:**
```r
prever_score(
  novo_dado,                        # Dataframe com mesmos campos do treino (SEM matched_score)
  modelo_path = "modelo_final.rds"  # Caminho do modelo (opcional)
)
```

**Output:** Vetor numérico com previsões do `matched_score` (0 a 1).

**Exemplo:**
```r
# Carregar novos candidatos
novos_candidatos <- read.csv("novos_candidatos.csv")

# Fazer previsões
previsoes <- prever_score(novos_candidatos)

# Resultado: [1] 0.7890  0.4538  0.5400  0.8290  0.6278
#                 ↑       ↑       ↑       ↑       ↑
#              pessoa1 pessoa2 pessoa3 pessoa4 pessoa5
```

**Interpretação:**
- **0.8-1.0**: Excelente match
- **0.5-0.7**: Match razoável
- **0.0-0.4**: Fraco match

---

#### **Função 2: `prever_e_avaliar()`**

**Propósito:** Fazer previsões E avaliar a qualidade do modelo (quando valores reais disponíveis).

**Inputs:**
```r
prever_e_avaliar(
  novo_dado,                        # Dataframe SEM matched_score
  valores_reais = NULL,             # Vetor com valores reais (opcional)
  modelo_path = "modelo_final.rds",
  mostrar_grafico = TRUE            # Gerar gráficos?
)
```

**Output:** Lista com:
- `$previsoes` - Vetor de previsões
- `$metricas` - Dataframe com RMSE, MAE, MAPE, R², Correlação
- `$desvios` - Dataframe completo com erros (previsto - real)
- `$resumo_desvios` - Estatísticas dos erros (média, SD, quartis)

**Exemplo:**
```r
# Carregar dados de teste
test <- read.csv("data/test.csv")
valores_reais <- test$matched_score
test$matched_score <- NULL  # remover target

# Avaliar modelo
resultado <- prever_e_avaliar(test, valores_reais = valores_reais)

# Ver métricas
print(resultado$metricas)
#    Metrica   Valor
#       RMSE  0.1270  ← erro médio quadrático
#        MAE  0.0989  ← erro absoluto médio
#   MAPE (%) 18.0743 ← erro percentual
#         R²  0.4327  ← qualidade ajuste (0-1)
```

**Métricas Explicadas:**
- **RMSE (0.1270)**: Erro médio de ±0.127 pontos
- **MAE (0.0989)**: Erro absoluto médio ~10%
- **MAPE (18.07%)**: Erro percentual médio
- **R² (0.4327)**: Modelo explica 43.27% da variação
- **Correlação (0.6578)**: Correlação positiva moderada

**Resumo dos Resíduos (exemplo):**
```
Estatistica  Desvio_Real   Interpretação
─────────────────────────────────────────
Média        -0.0115       ✅ Sem viés sistemático
Desvio Padrão 0.1265       Maioria erros entre ±0.13
Mínimo       -0.4556       Pior subestimação
Máximo        0.5389       Pior sobrestimação
```

**Outputs Gráficos:**
- `results/previsao_vs_real.png` - Scatter plot (previsto vs real)
- `results/analise_residuos.png` - Histograma + Q-Q plot dos resíduos

---

### 🔄 Processamento Interno Automático

Ambas as funções aplicam automaticamente:

1. **Carregamento do modelo** salvo em `.rds`
2. **Transformação Yeo-Johnson** (corrige assimetria das variáveis)
3. **Padronização Z-score** (média=0, desvio padrão=1)
4. **Previsão** usando o modelo treinado
5. **(Apenas `prever_e_avaliar`)** Cálculo de erros e geração de relatórios

---

### 💡 Quando Usar Cada Função

| Situação | Função Recomendada |
|----------|-------------------|
| Prever scores de novos candidatos em produção | `prever_score()` |
| Avaliar qualidade do modelo com dados de teste | `prever_e_avaliar()` |
| Gerar relatório de performance | `prever_e_avaliar()` |
| Integrar em API/sistema que precisa apenas scores | `prever_score()` |

---

## 🚀 Melhorias Implementadas

### **Pipeline Optimizado**

Foram criados scripts adicionais para melhorar o desempenho do modelo:

#### **`r/02b_data_preparation_improved.R`**
**Melhorias na preparação de dados:**

- **Composite Features** (6 novas variáveis criadas ANTES da imputação):
  1. `skills_composite` - Média ponderada: (candidate×1 + job×1.5 + required×2) / 4.5
  2. `education_match_score` - Completude de degree/major/requirements (0-1)
  3. `responsibilities_composite` - Soma ponderada: (candidate×0.4 + job×0.6)
  4. `position_match_indicator` - Disponibilidade binária normalizada (0-1)
  5. `experience_composite` - Score de disponibilidade de dados (0-1)
  6. `profile_completeness` - Meta-feature: média de todas as anteriores

- **Estratégia:** Criar features compostas ANTES da imputação preserva relações entre variáveis
- **Output:** 41 colunas (40 preditoras + 1 target)
- **Ficheiros gerados:**
  - `data/train_improved.csv`
  - `data/test_improved.csv`
  - `data/yeo_johnson_transforms_improved.rds`
  - `data/scaling_parameters_improved.rds`

#### **`r/03b_modeling_improved.R`**
**Modelação com múltiplos algoritmos optimizados:**

- **Modelos implementados:**
  - XGBoost com grid extensivo (216 combinações)
  - Random Forest optimizado (4 valores de mtry)
  - Gradient Boosting Machine (8 combinações)
  - SVM Radial (4 combinações de sigma/C)
  - Ensemble (média simples dos 4 modelos)

- **Optimizações:**
  - Paralelização: `detectCores()-1` cores
  - Cross-validation: 10-fold com `allowParallel=TRUE`
  - Grid search completo para cada algoritmo

- **Resultado anterior:** XGBoost R²=0.4356 (+4.4% vs baseline 0.417)
- **Ficheiros gerados:**
  - `modelo_03b_improvement.rds`
  - `results/metrics_03b_improvement.csv`

#### **`r/03c_modeling_rf_tuned.R`**
**Random Forest com tuning extensivo:**

- **5 Fases de optimização:**
  1. **FASE 1:** Grid search de `mtry` (8 valores: 2, 5, 8, 12, 16, 20, 23, 27)
  2. **FASE 2:** Tuning de `ntree` (300/500/750/1000) e `nodesize` (3/5/10)
  3. **FASE 3:** Treino do modelo final com melhores hiperparâmetros
  4. **FASE 4:** Análise de importância de features
  5. **FASE 5:** Comparação com baseline

- **Optimizações:**
  - Paralelização com cluster PSOCK
  - Cross-validation: 5-fold (optimizado para velocidade)
  - Cleanup automático de clusters

- **Ficheiros gerados:**
  - `modelo_03c_improvement.rds`
  - `results/metrics_03c_improvement.csv`
  - `results/tuning_results_03c_improvement.csv`
  - `results/feature_importance_03c_improvement.csv`
  - `results/feature_importance_03c_improvement.png`

---

### **Comparação de Pipelines**

| Pipeline | Scripts | Nº Colunas | Features Especiais | Modelos | R² Esperado |
|----------|---------|------------|-------------------|---------|-------------|
| **Original** | 02 → 03 | 40 | Básicas | Linear, RF, XGBoost, GLMNet | 0.417 |
| **Improved Multi** | 02b → 03b | 41 | 6 compostas | XGBoost, RF, GBM, SVM, Ensemble | 0.436 |
| **Improved RF** | 02b → 03c | 41 | 6 compostas | RF tuning extensivo | A determinar |

---

### **Paralelização**

Todos os scripts de modelação optimizada (`03b`, `03c`) incluem:

```r
# Detectar núcleos disponíveis
num_cores <- parallel::detectCores() - 1
if(num_cores < 1) num_cores <- 1

# Criar cluster
cl <- parallel::makePSOCKcluster(num_cores)
doParallel::registerDoParallel(cl)

# Treinar com paralelização
trainControl(method = "cv", number = 5, allowParallel = TRUE)

# Cleanup
parallel::stopCluster(cl)
doParallel::registerDoSEQ()
```

**Benefício:** Redução significativa no tempo de treino (proporcional ao número de cores).

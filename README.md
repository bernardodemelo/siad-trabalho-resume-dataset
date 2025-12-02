# 🧠 Projeto SIAD – Previsão de `matched_score`

### 0. Estrutura do Repositório
```bash
├── data/
│   └── resume_data.csv              # Dataset utilizado
├── r/
│   ├── 01_data_understanding.R      # Análise exploratória
│   ├── 02_data_preparation.R        # Preparação e limpeza
│   ├── 02b_data_preparation_improved.R  # Preparação melhorada
│   ├── 03_modeling.R                # Modelação baseline
│   ├── 03b_modeling_improved.R      # Modelação multi-modelo
│   ├── 03c_modeling_rf_tuned.R      # Random Forest tuning
│   ├── 04_evaluation.R              # Avaliação de resultados
│   ├── 05_others.R                  # Funções e modelo final
│   └── dependencies.R               # Gestão de dependências
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


---

## 📚 Documentação Técnica dos Scripts

### **`dependencies.R`**
**Propósito:** Gestão centralizada de todos os pacotes R necessários.

**Funcionalidade:**
- Verifica e instala automaticamente pacotes em falta
- Lista completa de dependências do projeto

**Pacotes instalados:**
```r
# Core
- tidyverse      # Manipulação de dados
- caret          # Machine learning framework
- parallel       # Computação paralela (base)
- doParallel     # Backend paralelo para caret

# Modelação
- randomForest   # Random Forest
- xgboost        # Gradient Boosting
- glmnet         # Regressão regularizada
- gbm            # Gradient Boosting Machine
- kernlab        # SVM

# Pré-processamento
- bestNormalize  # Transformações (Yeo-Johnson)
- recipes        # Feature engineering
- rsample        # Amostragem e splits

# Visualização
- ggplot2        # Gráficos
- corrplot       # Matriz de correlação
- gridExtra      # Layout de gráficos
- vip            # Importância de variáveis

# Análise
- skimr          # Sumários estatísticos
- moments        # Assimetria e curtose
- pastecs        # Estatísticas descritivas

# Text mining
- text2vec       # Processamento de texto
- stringr        # Manipulação de strings
```

**Execução:**
```bash
Rscript r/dependencies.R
```

**Output:** Mensagens de instalação/verificação de pacotes.

---

### **`01_data_understanding.R`**
**Propósito:** Análise exploratória de dados (EDA).

**Dependências:**
- `dependencies.R`
- Dataset: `data/resume_data.csv`

**Funcionalidades:**
1. Carregamento e inspeção inicial (`str()`, `summary()`, `skim()`)
2. Análise de valores omissos (padrões e percentagens)
3. Distribuição da variável target (`matched_score`)
4. Análise de correlações entre variáveis numéricas
5. Identificação de outliers (boxplots, IQR)
6. Análise de variáveis categóricas (frequências, cardinalidade)

**Outputs gerados:**
- Gráficos exploratórios (consola)
- Matrizes de correlação
- Estatísticas descritivas

**Execução:**
```bash
Rscript r/01_data_understanding.R
```

---

### **`02_data_preparation.R`** (Pipeline Original)
**Propósito:** Preparação baseline dos dados para modelação.

**Dependências:**
- `dependencies.R`
- Input: `data/resume_data.csv` (9544 linhas × 35 colunas)

**Pipeline de transformação:**
```
1. Feature Engineering Básica
   ├─ skills_count (contagem de skills)
   ├─ career_word_count (palavras em descrição)
   ├─ responsibilities_word_count
   ├─ text_length_total
   └─ age_min, age_max (extração de idades)

2. Limpeza
   ├─ Remover colunas >50% missing
   └─ Imputação (mediana/moda)

3. Encoding
   ├─ Label encoding (34 variáveis categóricas)
   └─ Redução de cardinalidade (top-50 + "Other")

4. Transformações
   ├─ Yeo-Johnson (22 variáveis com |skew| > 1)
   └─ Z-score standardization (39 preditoras)

5. Split
   └─ 80% treino (7636) / 20% teste (1908)
```

**Outputs:**
- `data/train.csv` (7636 × 40)
- `data/test.csv` (1908 × 40)
- `data/resume_data_final_standardized.csv`
- `data/resume_data_final_standardized.rds`
- `data/yeo_johnson_transforms.rds`
- `data/scaling_parameters.rds`
- `outputs/padronizacao_comparacao.png`

**Dimensões finais:** 40 colunas (39 preditoras + 1 target)

**Execução:**
```bash
Rscript r/02_data_preparation.R
```

**Tempo de execução:** ~5-10 segundos

---

### **`02b_data_preparation_improved.R`** (Pipeline Melhorado)
**Propósito:** Preparação avançada com composite features.

**Dependências:**
- `dependencies.R`
- Input: `data/resume_data.csv`

**Diferenças vs 02:**

**🆕 Composite Features (criadas ANTES da imputação):**
```r
1. skills_composite
   Formula: (candidate×1 + job×1.5 + required×2) / 4.5
   Objetivo: Capturar match de competências com pesos

2. education_match_score  
   Formula: (degree_avail + major_avail + requirements_avail) / 3
   Objetivo: Completude educacional (0-1)

3. responsibilities_composite
   Formula: candidate×0.4 + job×0.6
   Objetivo: Alinhamento de responsabilidades

4. position_match_indicator
   Formula: mean(candidate_avail, job_avail)
   Objetivo: Disponibilidade binária normalizada

5. experience_composite
   Formula: (years_avail + months_avail) / 2
   Objetivo: Score de experiência

6. profile_completeness
   Formula: média das 5 features acima
   Objetivo: Meta-feature de completude geral
```

**Pipeline:**
```
1. Composite Features (ANTES imputação) ← DIFERENÇA CHAVE
2. Feature Engineering Básica
3. Limpeza e Imputação
4. Encoding
5. Transformações (Yeo-Johnson + Z-score)
6. Split 80/20
```

**Outputs:**
- `data/train_improved.csv` (7636 × 41)
- `data/test_improved.csv` (1908 × 41)
- `data/resume_data_improved_standardized.csv`
- `data/yeo_johnson_transforms_improved.rds`
- `data/scaling_parameters_improved.rds`

**Dimensões finais:** 41 colunas (40 preditoras + 1 target)

**Execução:**
```bash
Rscript r/02b_data_preparation_improved.R
```

---

### **`03_modeling.R`** (Baseline)
**Propósito:** Treino de modelos baseline com configuração padrão.

**Dependências:**
- `dependencies.R`
- Inputs: `data/train.csv`, `data/test.csv`

**Modelos treinados:**
```r
1. Regressão Linear (lm)
   - Método: mínimos quadrados ordinários
   - Parâmetros: intercept=TRUE

2. Random Forest (rf)
   - Parâmetros: mtry={2, 16, 30}
   - ntree: 500 (padrão)

3. XGBoost (xgbTree)
   - Grid: nrounds={50,100}, max_depth={3,6}, eta={0.1,0.3}
   - 12 combinações

4. GLMNet (Elastic Net)
   - Grid: alpha={0,0.5,1}, lambda=seq(0.001,0.1,0.01)
```

**Configuração CV:**
- Método: 5-fold cross-validation
- Métrica: RMSE
- Sem paralelização

**Outputs:**
- `modelo_final.rds` (melhor modelo)
- `results/metrics.csv`
- Gráficos de performance (consola)

**Resultado esperado:** XGBoost R²=0.417

**Execução:**
```bash
Rscript r/03_modeling.R
```

**Tempo:** ~5-15 minutos (depende do hardware)

---

### **`03b_modeling_improved.R`** (Multi-modelo Optimizado)
**Propósito:** Treino de múltiplos modelos com hyperparameter tuning extensivo.

**Dependências:**
- `dependencies.R`
- `parallel`, `doParallel`
- Inputs: `data/train_improved.csv`, `data/test_improved.csv`

**Modelos treinados:**

```r
1. XGBoost (xgbTree) - Grid extensivo
   Parâmetros:
   - nrounds: {50, 100, 150}
   - max_depth: {3, 6, 9}
   - eta: {0.01, 0.05, 0.1, 0.3}
   - gamma: {0, 0.1}
   - colsample_bytree: {0.6, 0.8, 1.0}
   - min_child_weight: {1, 3}
   - subsample: {0.8, 1.0}
   Total: 216 combinações

2. Random Forest (rf)
   - mtry: {5, 10, 15, 20}
   - ntree: 500

3. Gradient Boosting Machine (gbm)
   - n.trees: {100, 150}
   - interaction.depth: {3, 5}
   - shrinkage: {0.05, 0.1}
   - n.minobsinnode: {10}
   Total: 8 combinações

4. SVM Radial (svmRadial)
   - sigma: {0.01, 0.05}
   - C: {0.5, 1}
   Total: 4 combinações

5. Ensemble (média simples dos 4 modelos)
```

**Configuração CV:**
- Método: 10-fold cross-validation
- Paralelização: `detectCores()-1` cores
- allowParallel: TRUE

**Outputs:**
- `modelo_03b_improvement.rds` (melhor modelo)
- `results/metrics_03b_improvement.csv`

**Resultado anterior:** XGBoost R²=0.4356 (+4.4% vs baseline)

**Execução:**
```bash
Rscript r/03b_modeling_improved.R
```

**Tempo:** ~30-60 minutos com paralelização (7+ cores recomendado)

---

### **`03c_modeling_rf_tuned.R`** (Random Forest Especializado)
**Propósito:** Tuning extensivo focado exclusivamente em Random Forest.

**Dependências:**
- `dependencies.R`
- `parallel`, `doParallel`
- Inputs: `data/train_improved.csv`, `data/test_improved.csv`

**5 Fases de optimização:**

```r
FASE 1: Grid Search de mtry
├─ Valores: {2, 5, 8, 12, 16, 20, 23, 27}
├─ CV: 5-fold
└─ Seleciona melhor mtry

FASE 2: Tuning de ntree e nodesize
├─ ntree: {300, 500, 750, 1000}
├─ nodesize: {3, 5, 10}
├─ Usa melhor mtry da Fase 1
└─ Total: 12 combinações

FASE 3: Modelo Final
├─ Treina com melhores hiperparâmetros
└─ Validação no conjunto de teste

FASE 4: Feature Importance
├─ Calcula importância de variáveis
├─ Gera ranking
└─ Visualização (gráfico + CSV)

FASE 5: Comparação com Baseline
├─ Carrega metrics.csv do baseline
├─ Compara R², RMSE, MAE
└─ Calcula melhoria percentual
```

**Configuração CV:**
- Método: 5-fold (optimizado para velocidade)
- Paralelização: cluster PSOCK
- Cleanup automático de recursos

**Outputs:**
- `modelo_03c_improvement.rds`
- `results/metrics_03c_improvement.csv`
- `results/tuning_results_03c_improvement.csv`
- `results/feature_importance_03c_improvement.csv`
- `results/feature_importance_03c_improvement.png`

**Execução:**
```bash
Rscript r/03c_modeling_rf_tuned.R
```

**Tempo:** ~20-40 minutos com paralelização

---

### **`04_evaluation.R`**
**Propósito:** Avaliação detalhada do modelo final.

**Dependências:**
- `dependencies.R`
- Inputs: `modelo_final.rds`, `data/test.csv`

**Análises realizadas:**
1. Previsões no conjunto de teste
2. Cálculo de métricas (RMSE, MAE, R², Correlação)
3. Análise de resíduos (distribuição, normalidade)
4. Gráficos:
   - Previsto vs Real (scatter plot)
   - Resíduos vs Previsto
   - Histograma de resíduos
   - Q-Q plot
5. Identificação de outliers/casos extremos

**Outputs:**
- `results/predictions_vs_actual.png`
- `results/residuals_analysis.png`
- Relatório de métricas (consola)

**Execução:**
```bash
Rscript r/04_evaluation.R
```

---

### **`05_others.R`** (Funções de Produção)
**Propósito:** Funções reutilizáveis para deploy do modelo.

**Dependências:**
- `dependencies.R`
- `modelo_final.rds`
- `data/yeo_johnson_transforms.rds`
- `data/scaling_parameters.rds`

**Funções disponíveis:**

#### `prever_score(novo_dado, modelo_path)`
**Input:**
- `novo_dado`: Dataframe sem `matched_score` (mesma estrutura do treino)
- `modelo_path`: Caminho do modelo (default: "modelo_final.rds")

**Output:**
- Vetor numérico com previsões (0-1)

**Processamento interno:**
1. Carrega modelo
2. Aplica Yeo-Johnson transforms
3. Aplica Z-score standardization
4. Gera previsões

#### `prever_e_avaliar(novo_dado, valores_reais, modelo_path, mostrar_grafico)`
**Inputs:**
- `novo_dado`: Dataframe sem target
- `valores_reais`: Vetor com valores reais (opcional)
- `modelo_path`: Caminho do modelo
- `mostrar_grafico`: Boolean (default: TRUE)

**Outputs:**
- Lista com:
  - `$previsoes`: Vetor de previsões
  - `$metricas`: RMSE, MAE, MAPE, R², Correlação
  - `$desvios`: Dataframe completo (Real, Previsto, Desvio)
  - `$resumo_desvios`: Min, Q1, Mediana, Média, Q3, Max, SD

**Gráficos gerados:**
- `results/previsao_vs_real.png`
- `results/analise_residuos.png` (histograma + Q-Q plot)

**Teste automático:**
- Executa automaticamente com 100 primeiras observações de `data/test.csv`
- Valida funcionamento das funções

**Execução:**
```bash
# Via script
Rscript r/05_others.R

# Via consola R
source("r/05_others.R")
previsoes <- prever_score(novos_dados)
```

---

## 🔄 Fluxo de Execução Completo

### **Pipeline Original (Baseline):**
```bash
1. Rscript r/dependencies.R          # Instalar pacotes
2. Rscript r/01_data_understanding.R # EDA
3. Rscript r/02_data_preparation.R   # Preparar dados (40 cols)
4. Rscript r/03_modeling.R           # Treinar modelos (R²=0.417)
5. Rscript r/04_evaluation.R         # Avaliar
6. Rscript r/05_others.R             # Testar funções
```

### **Pipeline Melhorado (Optimizado):**
```bash
1. Rscript r/dependencies.R                  # Instalar pacotes
2. Rscript r/01_data_understanding.R         # EDA
3. Rscript r/02b_data_preparation_improved.R # Preparar (41 cols + composites)
4. Rscript r/03b_modeling_improved.R         # Multi-modelo (R²=0.436)
   OU
   Rscript r/03c_modeling_rf_tuned.R         # RF tuning extensivo
5. Rscript r/04_evaluation.R                 # Avaliar
6. Rscript r/05_others.R                     # Deploy
```

---

## ⚙️ Requisitos de Sistema

**R Version:** 4.5+ (testado em 4.5.0)

**RAM recomendada:**
- Baseline (03): 4GB
- Improved (03b/03c): 8GB+ (devido a grids extensivos)

**CPU:**
- Single-core: Funcional mas lento
- Multi-core (4+): Recomendado para 03b/03c
- Detecta automaticamente: `parallel::detectCores()-1`

**Tempo estimado (pipeline completo):**
- Baseline: ~20-30 minutos
- Improved: ~1-2 horas (com paralelização)

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

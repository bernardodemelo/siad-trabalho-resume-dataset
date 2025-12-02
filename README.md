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

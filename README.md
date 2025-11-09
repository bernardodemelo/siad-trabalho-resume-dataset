# 🧠 Projeto SIAD – Previsão de `matched_score`

## 📋 Descrição do Projeto
Este projeto foi desenvolvido no âmbito da unidade curricular **Sistemas Inteligentes de Apoio à Decisão (SIAD)**, sob orientação do **Prof. Sérgio Moro**.  
O objetivo é aplicar a metodologia **CRISP-DM** para desenvolver um modelo de **aprendizagem supervisionada** em **R**, capaz de **prever o valor da variável `matched_score`** com base nas restantes variáveis do dataset.

---

## 🧩 Metodologia – CRISP-DM

O projeto segue as seis fases da metodologia **CRISP-DM (Cross Industry Standard Process for Data Mining)**:

~~### 1. Business Understanding~~
~~- Definição do problema: prever `matched_score` a partir de características do dataset.~~
~~- Tipo de problema: **Regressão supervisionada**.~~
~~- Benefício esperado: apoiar processos de decisão relacionados com a qualidade do “matching” entre entidades.~~
~~- Variável dependente: `matched_score`.~~

---

### 2. Data Understanding
- Carregamento e exploração inicial dos dados (`read.csv`, `str`, `summary`, `skimr::skim`).
- Identificação de variáveis numéricas e categóricas.
- Análise da distribuição de `matched_score` (histogramas, boxplots).
- Verificação de **valores omissos** e **outliers**.
- Análise de correlações (`cor`, `corrplot`, `ggcorrplot`).

---

### 3. Data Preparation
- Tratamento de valores em falta (remoção ou imputação).
- Codificação de variáveis categóricas (`factor`, `caret::dummyVars`).
- Normalização / padronização de variáveis numéricas (`scale`).
- Seleção e engenharia de atributos (feature engineering).
- Divisão dos dados em **treino (80%)** e **teste (20%)**:
  ```r
  set.seed(123)
  index <- caret::createDataPartition(data$matched_score, p=0.8, list=FALSE)
  train <- data[index, ]
  test  <- data[-index, ]

### 3. Data Preparation
- Tratamento de valores em falta (remoção ou imputação).
- Codificação de variáveis categóricas (`factor`, `caret::dummyVars`).
- Normalização / padronização de variáveis numéricas (`scale`).
- Seleção e engenharia de atributos (feature engineering).
- Divisão dos dados em **treino (80%)** e **teste (20%)**:
  ```r
  set.seed(123)
  index <- caret::createDataPartition(data$matched_score, p=0.8, list=FALSE)
  train <- data[index, ]
  test  <- data[-index, ]

### 4. Modeling
Treino de vários modelos supervisionados:
- Regressão Linear (lm)
- Random Forest (randomForest)
- Gradient Boosting (xgboost)
- Regressão Regularizada (glmnet)

Utilização de validação cruzada com caret::trainControl().

Comparação dos modelos com base em métricas de regressão (RMSE, MAE, R²).

Justificação da escolha do modelo final.

### 5. Evaluation
Avaliação do modelo final com dados de teste:
- predictions <- predict(model_rf, newdata=test)
- caret::postResample(predictions, test$matched_score)

Visualização:
- Gráfico de valores reais vs. previstos.
- Análise de resíduos.

Comparação dos desempenhos dos modelos testados.

### 6. Deployment
Guardar o modelo final para utilização futura:
- saveRDS(model_rf, "modelo_final.rds")

Criar uma função de previsão:
- prever_score <- function(novo_dado) {
  modelo <- readRDS("modelo_final.rds")
  predict(modelo, newdata = novo_dado)
}

Descrição de possíveis formas de integração do modelo num sistema real (API, dashboard, etc.).

### 7. Estrutura do Repositório
├── data/
│   └── resume_data.csv              # Dataset utilizado
├── R/
│   ├── 01_data_understanding.R      # Análise exploratória
│   ├── 02_data_preparation.R        # Preparação e limpeza
│   ├── 03_modeling.R                # Modelação
│   ├── 04_evaluation.R              # Avaliação de resultados
│   └── 05_deployment.R              # Funções e modelo final
├── results/
│   ├── metrics.csv                  # Métricas de desempenho
│   ├── feature_importance.png       # Importância das variáveis
│   └── predictions_vs_actual.png    # Gráfico real vs previsto
├── modelo_final.rds                 # Modelo treinado
└── README.md                        # Descrição do projeto

### 8. Tecnologias e Pacotes Utilizados
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

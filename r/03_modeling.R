########################################################
# === 3. Modeling: Treino de modelos supervisionados ===
########################################################


# Carregar dependências e definir seed
source("r/dependencies.R")

# Carregar dados de treino e teste (já padronizados)
cat("========================================================\n")
cat("         INÍCIO DO TREINO DE MODELOS                    \n")
cat("========================================================\n\n")

cat("[DEBUG] A carregar dados de treino...\n")
start_time <- Sys.time()
train <- read.csv("data/train.csv")
cat("[DEBUG] Dados de treino carregados em", round(as.numeric(Sys.time() - start_time), 2), "segundos\n")

cat("[DEBUG] A carregar dados de teste...\n")
start_time <- Sys.time()
test  <- read.csv("data/test.csv")
cat("[DEBUG] Dados de teste carregados em", round(as.numeric(Sys.time() - start_time), 2), "segundos\n\n")

# Garantir que matched_score é numérico
target <- "matched_score"
cat("[DEBUG] A converter variável target para numérico...\n")
train[[target]] <- as.numeric(train[[target]])
test[[target]]  <- as.numeric(test[[target]])

cat("[DEBUG] Dimensões do treino:", dim(train), "(linhas x colunas)\n")
cat("[DEBUG] Dimensões do teste:", dim(test), "(linhas x colunas)\n")
cat("[DEBUG] Número de variáveis preditoras:", ncol(train) - 1, "\n")
cat("[DEBUG] Variável target:", target, "\n")
cat("[DEBUG] Valores únicos em matched_score (treino):", length(unique(train[[target]])), "\n")
cat("[DEBUG] Range de matched_score (treino): [", min(train[[target]], na.rm=TRUE), ",", max(train[[target]], na.rm=TRUE), "]\n\n")

# NOTA: Os dados já vêm padronizados do script 02_data_preparation.R
# Apenas removemos variáveis com variância zero (zero variance)
# Criar diretório results/ se não existir
cat("[DEBUG] A verificar/criar diretório results/...\n")
if(!dir.exists("results")) {
  dir.create("results")
  cat("[DEBUG] Diretório results/ criado\n")
} else {
  cat("[DEBUG] Diretório results/ já existe\n")
}

# Remover variáveis com variância zero (zero variance)
cat("[DEBUG] A identificar variáveis com variância zero...\n")
start_time <- Sys.time()
zv_cols <- nearZeroVar(train, saveMetrics = FALSE)
cat("[DEBUG] Identificação concluída em", round(as.numeric(Sys.time() - start_time), 2), "segundos\n")

if(length(zv_cols) > 0) {
  cat("[DEBUG] Removendo", length(zv_cols), "variáveis com variância zero\n")
  train <- train[, -zv_cols]
  test <- test[, -zv_cols]
  cat("[DEBUG] Variáveis restantes:", ncol(train) - 1, "preditoras + 1 target\n")
} else {
  cat("[DEBUG] Nenhuma variável com variância zero encontrada\n")
}

# Usar dados diretamente (já padronizados)
cat("[DEBUG] A preparar dados finais para modelação...\n")
train_baked <- train
test_baked <- test
cat("[DEBUG] Dados preparados. Dimensões finais - Treino:", dim(train_baked), "| Teste:", dim(test_baked), "\n\n")

cat("=== Treino de Modelos ===\n")
cat("Configuração: Validação Cruzada com 5 folds\n\n")

# Model 1: Regressão Linear (lm)
cat("--------------------------------------------------------\n")
cat("1. TREINANDO: Regressão Linear (lm)\n")
cat("--------------------------------------------------------\n")
cat("[DEBUG] Início:", format(Sys.time(), "%H:%M:%S"), "\n")
start_time <- Sys.time()

lm_model <- train(matched_score ~ ., data = train_baked, method = "lm",
                  trControl = trainControl(method = "cv", number = 5, verboseIter = TRUE))

elapsed_time <- as.numeric(Sys.time() - start_time)
cat("[DEBUG] Treino concluído em", round(elapsed_time, 2), "segundos (", round(elapsed_time/60, 2), "minutos)\n")

cat("[DEBUG] A gerar previsões no conjunto de teste...\n")
lm_pred <- predict(lm_model, newdata = test_baked)
cat("[DEBUG] Previsões geradas:", length(lm_pred), "valores\n")
cat("   ✓ Regressão Linear concluída\n\n")

# Model 2: Random Forest
cat("--------------------------------------------------------\n")
cat("2. TREINANDO: Random Forest (rf)\n")
cat("--------------------------------------------------------\n")
cat("[DEBUG] Início:", format(Sys.time(), "%H:%M:%S"), "\n")
cat("[DEBUG] NOTA: Random Forest pode demorar bastante tempo...\n")
start_time <- Sys.time()

rf_model <- train(matched_score ~ ., data = train_baked, method = "rf",
                  trControl = trainControl(method = "cv", number = 5, verboseIter = TRUE),
                  importance = TRUE)

elapsed_time <- as.numeric(Sys.time() - start_time)
cat("[DEBUG] Treino concluído em", round(elapsed_time, 2), "segundos (", round(elapsed_time/60, 2), "minutos)\n")

cat("[DEBUG] A gerar previsões no conjunto de teste...\n")
rf_pred <- predict(rf_model, newdata = test_baked)
cat("[DEBUG] Previsões geradas:", length(rf_pred), "valores\n")
cat("   ✓ Random Forest concluído\n\n")

# Model 3: Gradient Boosting (xgboost)
cat("--------------------------------------------------------\n")
cat("3. TREINANDO: XGBoost (xgbTree)\n")
cat("--------------------------------------------------------\n")
cat("[DEBUG] Início:", format(Sys.time(), "%H:%M:%S"), "\n")
cat("[DEBUG] NOTA: XGBoost pode demorar bastante tempo...\n")
start_time <- Sys.time()

xgb_model <- train(matched_score ~ ., data = train_baked, method = "xgbTree",
                   trControl = trainControl(method = "cv", number = 5, verboseIter = TRUE))

elapsed_time <- as.numeric(Sys.time() - start_time)
cat("[DEBUG] Treino concluído em", round(elapsed_time, 2), "segundos (", round(elapsed_time/60, 2), "minutos)\n")

cat("[DEBUG] A gerar previsões no conjunto de teste...\n")
xgb_pred <- predict(xgb_model, newdata = test_baked)
cat("[DEBUG] Previsões geradas:", length(xgb_pred), "valores\n")
cat("   ✓ XGBoost concluído\n\n")

# Model 4: Regressão Regularizada (glmnet)
cat("--------------------------------------------------------\n")
cat("4. TREINANDO: GLMNet (Regressão Regularizada)\n")
cat("--------------------------------------------------------\n")
cat("[DEBUG] Início:", format(Sys.time(), "%H:%M:%S"), "\n")
start_time <- Sys.time()

glmnet_model <- train(matched_score ~ ., data = train_baked, method = "glmnet",
                      trControl = trainControl(method = "cv", number = 5, verboseIter = TRUE))

elapsed_time <- as.numeric(Sys.time() - start_time)
cat("[DEBUG] Treino concluído em", round(elapsed_time, 2), "segundos (", round(elapsed_time/60, 2), "minutos)\n")

cat("[DEBUG] A gerar previsões no conjunto de teste...\n")
glmnet_pred <- predict(glmnet_model, newdata = test_baked)
cat("[DEBUG] Previsões geradas:", length(glmnet_pred), "valores\n")
cat("   ✓ GLMNet concluído\n\n")

# Avaliação dos modelos
cat("========================================================\n")
cat("         AVALIAÇÃO DOS MODELOS                          \n")
cat("========================================================\n")
cat("[DEBUG] A calcular métricas para todos os modelos...\n")

results <- data.frame(
  model = c("Linear", "RandomForest", "XGBoost", "GLMNet"),
  RMSE = c(
    RMSE(lm_pred, test_baked$matched_score),
    RMSE(rf_pred, test_baked$matched_score),
    RMSE(xgb_pred, test_baked$matched_score),
    RMSE(glmnet_pred, test_baked$matched_score)
  ),
  MAE = c(
    MAE(lm_pred, test_baked$matched_score),
    MAE(rf_pred, test_baked$matched_score),
    MAE(xgb_pred, test_baked$matched_score),
    MAE(glmnet_pred, test_baked$matched_score)
  ),
  R2 = c(
    R2(lm_pred, test_baked$matched_score),
    R2(rf_pred, test_baked$matched_score),
    R2(xgb_pred, test_baked$matched_score),
    R2(glmnet_pred, test_baked$matched_score)
  )
)

cat("[DEBUG] Métricas calculadas\n")
cat("\nResultados:\n")
print(results)
cat("\n")

# Guardar métricas
cat("[DEBUG] A guardar métricas em results/metrics.csv...\n")
write.csv(results, "results/metrics.csv", row.names = FALSE)
cat("[DEBUG] Métricas guardadas\n")

# Guardar importância das variáveis do melhor modelo (exemplo: Random Forest)
cat("[DEBUG] A gerar gráfico de importância de variáveis (Random Forest)...\n")
png("results/feature_importance.png", width=800, height=600)
vip(rf_model)
dev.off()
cat("[DEBUG] Gráfico guardado: results/feature_importance.png\n")

# Identificar melhor modelo (menor RMSE)
cat("[DEBUG] A identificar melhor modelo (menor RMSE)...\n")
best_idx <- which.min(results$RMSE)
best_model_name <- results$model[best_idx]
best_model <- list(lm = lm_model, rf = rf_model, xgb = xgb_model, glmnet = glmnet_model)[[best_idx]]

cat("\n========================================================\n")
cat("              MELHOR MODELO                              \n")
cat("========================================================\n")
cat("Modelo:", best_model_name, "\n")
cat("RMSE:", round(results$RMSE[best_idx], 4), "\n")
cat("MAE:", round(results$MAE[best_idx], 4), "\n")
cat("R²:", round(results$R2[best_idx], 4), "\n")
cat("========================================================\n\n")

# Guardar modelo final
cat("[DEBUG] A guardar modelo final em modelo_final.rds...\n")
saveRDS(best_model, "modelo_final.rds")
cat("[DEBUG] Modelo final guardado\n\n")

cat("========================================================\n")
cat("         TREINO DE MODELOS CONCLUÍDO                    \n")
cat("========================================================\n")
cat("Ficheiros gerados:\n")
cat("  - results/metrics.csv\n")
cat("  - results/feature_importance.png\n")
cat("  - modelo_final.rds\n")
cat("========================================================\n")

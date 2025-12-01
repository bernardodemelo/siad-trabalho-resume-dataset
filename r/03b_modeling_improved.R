########################################################
# === 3B. Modeling MELHORADO: Iteração 2 ===
########################################################

source("r/dependencies.R")

cat("========================================================\n")
cat("    ITERAÇÃO 2 - MELHORAR R² DE 0.417                  \n")
cat("========================================================\n\n")

train <- read.csv("data/train.csv")
test  <- read.csv("data/test.csv")

target <- "matched_score"
train[[target]] <- as.numeric(train[[target]])
test[[target]]  <- as.numeric(test[[target]])

if(!dir.exists("results")) dir.create("results")

zv_cols <- nearZeroVar(train, saveMetrics = FALSE)
if(length(zv_cols) > 0) {
  train <- train[, -zv_cols]
  test <- test[, -zv_cols]
}

train_baked <- train
test_baked <- test

cat("Estratégia: Tuning + Novos modelos + Ensemble\n\n")

ctrl_tuned <- trainControl(
  method = "cv",
  number = 10,
  verboseIter = FALSE,
  savePredictions = "final"
)

# --------------------------------------------------------
# 1. XGBoost Tuned
# --------------------------------------------------------
cat("1. XGBoost tuned...\n")
start_time <- Sys.time()

xgb_grid <- expand.grid(
  nrounds = c(150, 250, 350),
  max_depth = c(6, 8, 10),
  eta = c(0.05, 0.1, 0.15),
  gamma = c(0, 0.1),
  colsample_bytree = c(0.7, 0.9),
  min_child_weight = c(1, 3),
  subsample = c(0.8, 1.0)
)

xgb_tuned <- train(
  matched_score ~ ., 
  data = train_baked, 
  method = "xgbTree",
  trControl = ctrl_tuned,
  tuneGrid = xgb_grid,
  verbose = FALSE
)

cat("   Tempo:", round(as.numeric(Sys.time() - start_time)/60, 2), "min |")
cat(" Melhor R² CV:", round(max(xgb_tuned$results$Rsquared), 4), "\n")
xgb_pred_tuned <- predict(xgb_tuned, newdata = test_baked)

# --------------------------------------------------------
# 2. Random Forest Tuned
# --------------------------------------------------------
cat("2. Random Forest tuned...\n")
start_time <- Sys.time()

rf_tuned <- train(
  matched_score ~ ., 
  data = train_baked, 
  method = "rf",
  trControl = ctrl_tuned,
  tuneGrid = data.frame(mtry = c(10, 20, 30, 40)),
  importance = TRUE,
  ntree = 500
)

cat("   Tempo:", round(as.numeric(Sys.time() - start_time)/60, 2), "min |")
cat(" Melhor R² CV:", round(max(rf_tuned$results$Rsquared), 4), "\n")
rf_pred_tuned <- predict(rf_tuned, newdata = test_baked)

# --------------------------------------------------------
# 3. GBM
# --------------------------------------------------------
cat("3. GBM...\n")
start_time <- Sys.time()

gbm_grid <- expand.grid(
  n.trees = c(150, 250),
  interaction.depth = c(5, 7),
  shrinkage = c(0.05, 0.1),
  n.minobsinnode = c(10)
)

gbm_model <- train(
  matched_score ~ ., 
  data = train_baked, 
  method = "gbm",
  trControl = ctrl_tuned,
  tuneGrid = gbm_grid,
  verbose = FALSE
)

cat("   Tempo:", round(as.numeric(Sys.time() - start_time)/60, 2), "min |")
cat(" Melhor R² CV:", round(max(gbm_model$results$Rsquared), 4), "\n")
gbm_pred <- predict(gbm_model, newdata = test_baked)

# --------------------------------------------------------
# 4. SVM Radial
# --------------------------------------------------------
cat("4. SVM Radial...\n")
start_time <- Sys.time()

svm_grid <- expand.grid(
  sigma = c(0.01, 0.05),
  C = c(1, 10)
)

svm_model <- train(
  matched_score ~ ., 
  data = train_baked, 
  method = "svmRadial",
  trControl = ctrl_tuned,
  tuneGrid = svm_grid
)

cat("   Tempo:", round(as.numeric(Sys.time() - start_time)/60, 2), "min |")
cat(" Melhor R² CV:", round(max(svm_model$results$Rsquared), 4), "\n")
svm_pred <- predict(svm_model, newdata = test_baked)

# ============================================================
# ENSEMBLE
# ============================================================
cat("\n=== Ensemble ===\n")

# Ensemble simples (média)
ensemble_mean_pred <- (xgb_pred_tuned + rf_pred_tuned + gbm_pred + svm_pred) / 4

# ============================================================
# Avaliação
# ============================================================
cat("\n=== Resultados ===\n\n")

results_improved <- data.frame(
  model = c(
    "XGBoost_Tuned", 
    "RandomForest_Tuned",
    "GBM",
    "SVM",
    "Ensemble_Mean"
  ),
  RMSE = c(
    RMSE(xgb_pred_tuned, test_baked$matched_score),
    RMSE(rf_pred_tuned, test_baked$matched_score),
    RMSE(gbm_pred, test_baked$matched_score),
    RMSE(svm_pred, test_baked$matched_score),
    RMSE(ensemble_mean_pred, test_baked$matched_score)
  ),
  MAE = c(
    MAE(xgb_pred_tuned, test_baked$matched_score),
    MAE(rf_pred_tuned, test_baked$matched_score),
    MAE(gbm_pred, test_baked$matched_score),
    MAE(svm_pred, test_baked$matched_score),
    MAE(ensemble_mean_pred, test_baked$matched_score)
  ),
  R2 = c(
    R2(xgb_pred_tuned, test_baked$matched_score),
    R2(rf_pred_tuned, test_baked$matched_score),
    R2(gbm_pred, test_baked$matched_score),
    R2(svm_pred, test_baked$matched_score),
    R2(ensemble_mean_pred, test_baked$matched_score)
  )
)

results_improved <- results_improved[order(-results_improved$R2), ]

cat("========================================================\n")
cat("         RESULTADOS MELHORADOS                          \n")
cat("========================================================\n\n")
print(results_improved, row.names = FALSE)

# Comparar com baseline
cat("\n=== Comparação com Baseline ===\n")
results_baseline <- read.csv("results/metrics.csv")
best_baseline_r2 <- max(results_baseline$R2)
best_improved_r2 <- max(results_improved$R2)
improvement <- (best_improved_r2 - best_baseline_r2) / best_baseline_r2 * 100

cat("Melhor R² baseline:", round(best_baseline_r2, 4), "\n")
cat("Melhor R² improved:", round(best_improved_r2, 4), "\n")
cat("Melhoria:", round(improvement, 2), "%\n\n")

# Guardar resultados
write.csv(results_improved, "results/metrics_03b_improvement.csv", row.names = FALSE)
cat("[INFO] Métricas guardadas: results/metrics_03b_improvement.csv\n")

# Guardar melhor modelo
best_idx <- which.max(results_improved$R2)
best_model_name <- results_improved$model[best_idx]

if(best_model_name == "XGBoost_Tuned") {
  best_model <- xgb_tuned
} else if(best_model_name == "RandomForest_Tuned") {
  best_model <- rf_tuned
} else if(best_model_name == "GBM") {
  best_model <- gbm_model
} else if(best_model_name == "SVM") {
  best_model <- svm_model
} else {
  best_model <- list(
    xgb = xgb_tuned,
    rf = rf_tuned,
    gbm = gbm_model,
    svm = svm_model
  )
}

saveRDS(best_model, "modelo_03b_improvement.rds")
cat("[INFO] Modelo guardado: modelo_03b_improvement.rds\n\n")

cat("========================================================\n")
cat("              MELHOR MODELO                             \n")
cat("========================================================\n")
cat("Modelo:", best_model_name, "\n")
cat("RMSE:", round(results_improved$RMSE[best_idx], 4), "\n")
cat("MAE:", round(results_improved$MAE[best_idx], 4), "\n")
cat("R²:", round(results_improved$R2[best_idx], 4), "\n")
cat("========================================================\n")

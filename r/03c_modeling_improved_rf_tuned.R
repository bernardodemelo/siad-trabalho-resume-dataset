########################################################
# === 3C. Random Forest com Hyperparameter Tuning ===
########################################################
# ESTRATÉGIA: Tuning focado em Random Forest com grid extensivo
# para maximizar performance e extrair feature importance

source("r/dependencies.R")

cat("========================================================\n")
cat("   RANDOM FOREST - HYPERPARAMETER TUNING EXTENSIVO      \n")
cat("========================================================\n\n")

# Carregar dados melhorados (se existirem) ou normais
if(file.exists("data/train_improved.csv")) {
  cat("[INFO] Usando dados MELHORADOS (com features compostas)\n\n")
  train <- read.csv("data/train_improved.csv")
  test  <- read.csv("data/test_improved.csv")
} else {
  cat("[INFO] Usando dados normais\n\n")
  train <- read.csv("data/train.csv")
  test  <- read.csv("data/test.csv")
}

target <- "matched_score"
train[[target]] <- as.numeric(train[[target]])
test[[target]]  <- as.numeric(test[[target]])

if(!dir.exists("results")) dir.create("results")

# Remover zero variance
zv_cols <- nearZeroVar(train, saveMetrics = FALSE)
if(length(zv_cols) > 0) {
  train <- train[, -zv_cols]
  test <- test[, -zv_cols]
  cat("[INFO]", length(zv_cols), "colunas zero-variance removidas\n")
}

cat("[INFO] Dimensões: Treino =", nrow(train), "x", ncol(train), 
    "| Teste =", nrow(test), "x", ncol(test), "\n\n")

# ============================================================
# ATIVAR PARALELIZAÇÃO
# ============================================================
cores <- detectCores() - 1
if(cores < 1) cores <- 1  # Garantir pelo menos 1 core

cl <- makePSOCKcluster(cores)
registerDoParallel(cl)
cat(">>> Utilizando", cores, "núcleos do processador em paralelo.\n\n")

# ============================================================
# CONFIGURAÇÃO DO TUNING
# ============================================================

# Cross-validation com 10 folds
ctrl <- trainControl(
  method = "cv",
  number = 10,
  verboseIter = FALSE,
  savePredictions = "final",
  allowParallel = TRUE  # Usar paralelização se disponível
)

cat("=== Estratégia de Tuning ===\n")
cat("Método: 10-fold Cross-Validation\n")
cat("Parâmetros a tunar:\n")
cat("  - mtry: número de variáveis em cada split\n")
cat("  - ntree: número de árvores (fixado em sequências)\n")
cat("  - nodesize: tamanho mínimo dos nós terminais\n")
cat("  - maxnodes: número máximo de nós terminais\n\n")

# ============================================================
# FASE 1: Grid Search em mtry (básico mas importante)
# ============================================================
cat("========================================================\n")
cat("FASE 1: Grid Search em mtry                            \n")
cat("========================================================\n\n")

n_features <- ncol(train) - 1  # Excluir target

# Grid de mtry: testar desde sqrt(p) até p/2
mtry_values <- unique(floor(c(
  sqrt(n_features),           # Valor padrão para classificação
  n_features / 3,             # Valor padrão para regressão
  n_features / 4,
  n_features / 5,
  n_features / 2,
  2, 5, 10, 15, 20, 30, 40, 50
)))
mtry_values <- mtry_values[mtry_values > 0 & mtry_values <= n_features]
mtry_values <- sort(mtry_values)

cat("Grid mtry:", paste(mtry_values, collapse = ", "), "\n")
cat("Total de combinações:", length(mtry_values), "\n\n")

start_time <- Sys.time()

rf_mtry <- train(
  matched_score ~ ., 
  data = train, 
  method = "rf",
  trControl = ctrl,
  tuneGrid = data.frame(mtry = mtry_values),
  ntree = 500,  # Fixar árvores nesta fase
  importance = TRUE
)

elapsed <- as.numeric(Sys.time() - start_time)
cat("Tempo FASE 1:", round(elapsed/60, 2), "min\n")
cat("Melhor mtry:", rf_mtry$bestTune$mtry, "\n")
cat("Melhor R² CV:", round(max(rf_mtry$results$Rsquared), 4), "\n\n")

# ============================================================
# FASE 2: Tuning fino com melhor mtry + ntree otimizado
# ============================================================
cat("========================================================\n")
cat("FASE 2: Tuning fino - ntree + nodesize                 \n")
cat("========================================================\n\n")

best_mtry <- rf_mtry$bestTune$mtry

cat("Testando diferentes combinações de ntree e nodesize...\n")
cat("mtry fixado em:", best_mtry, "\n\n")

# Testar diferentes ntree manualmente (caret não suporta tuning de ntree diretamente)
ntree_values <- c(300, 500, 750, 1000)
nodesize_values <- c(3, 5, 10)

results_fine <- data.frame()

for(nt in ntree_values) {
  for(ns in nodesize_values) {
    cat("  Testando: ntree =", nt, ", nodesize =", ns, "... ")
    
    start_sub <- Sys.time()
    
    rf_test <- train(
      matched_score ~ ., 
      data = train, 
      method = "rf",
      trControl = ctrl,
      tuneGrid = data.frame(mtry = best_mtry),
      ntree = nt,
      nodesize = ns,
      importance = TRUE
    )
    
    elapsed_sub <- as.numeric(Sys.time() - start_sub)
    r2_cv <- max(rf_test$results$Rsquared)
    
    cat("R² =", round(r2_cv, 4), "(", round(elapsed_sub/60, 2), "min)\n")
    
    # Testar em test set
    pred_test <- predict(rf_test, newdata = test)
    r2_test <- R2(pred_test, test$matched_score)
    rmse_test <- RMSE(pred_test, test$matched_score)
    mae_test <- MAE(pred_test, test$matched_score)
    
    results_fine <- rbind(results_fine, data.frame(
      mtry = best_mtry,
      ntree = nt,
      nodesize = ns,
      R2_CV = r2_cv,
      R2_Test = r2_test,
      RMSE_Test = rmse_test,
      MAE_Test = mae_test,
      Time_min = elapsed_sub / 60
    ))
  }
}

cat("\n")
results_fine <- results_fine[order(-results_fine$R2_Test), ]

cat("========================================================\n")
cat("          RESULTADOS DO TUNING FINO                     \n")
cat("========================================================\n\n")
print(results_fine, row.names = FALSE)

# ============================================================
# FASE 3: Treinar modelo final com melhores parâmetros
# ============================================================
cat("\n========================================================\n")
cat("FASE 3: Modelo Final                                    \n")
cat("========================================================\n\n")

best_config <- results_fine[1, ]
cat("Melhores parâmetros:\n")
cat("  - mtry:", best_config$mtry, "\n")
cat("  - ntree:", best_config$ntree, "\n")
cat("  - nodesize:", best_config$nodesize, "\n\n")

cat("Treinando modelo final...\n")
start_final <- Sys.time()

rf_final <- train(
  matched_score ~ ., 
  data = train, 
  method = "rf",
  trControl = ctrl,
  tuneGrid = data.frame(mtry = best_config$mtry),
  ntree = best_config$ntree,
  nodesize = best_config$nodesize,
  importance = TRUE
)

elapsed_final <- as.numeric(Sys.time() - start_final)
cat("Tempo:", round(elapsed_final/60, 2), "min\n\n")

# Predições finais
pred_final <- predict(rf_final, newdata = test)

# Métricas finais
metrics_final <- data.frame(
  model = "RandomForest_Tuned",
  mtry = best_config$mtry,
  ntree = best_config$ntree,
  nodesize = best_config$nodesize,
  RMSE = RMSE(pred_final, test$matched_score),
  MAE = MAE(pred_final, test$matched_score),
  R2 = R2(pred_final, test$matched_score)
)

cat("========================================================\n")
cat("              RESULTADO FINAL                           \n")
cat("========================================================\n\n")
print(metrics_final, row.names = FALSE)

# ============================================================
# FASE 4: Feature Importance Analysis
# ============================================================
cat("\n========================================================\n")
cat("FASE 4: Feature Importance                             \n")
cat("========================================================\n\n")

# Extrair importância das variáveis
importance_scores <- randomForest::importance(rf_final$finalModel)

# Ordenar por %IncMSE (ou IncNodePurity para regressão)
if("%IncMSE" %in% colnames(importance_scores)) {
  importance_df <- data.frame(
    Feature = rownames(importance_scores),
    Importance = importance_scores[, "%IncMSE"]
  )
} else {
  importance_df <- data.frame(
    Feature = rownames(importance_scores),
    Importance = importance_scores[, "IncNodePurity"]
  )
}

importance_df <- importance_df[order(-importance_df$Importance), ]

cat("Top 20 Features mais importantes:\n\n")
print(head(importance_df, 20), row.names = FALSE)

# Guardar feature importance
write.csv(importance_df, "results/feature_importance_03c_improvement.csv", row.names = FALSE)
cat("\n[INFO] Feature importance guardada: results/feature_importance_03c_improvement.csv\n")

# Gráfico de feature importance (Top 20)
if(!dir.exists("results")) dir.create("results")

png("results/feature_importance_03c_improvement.png", width = 1200, height = 800, res = 100)
par(mar = c(5, 10, 4, 2))
top_20 <- head(importance_df, 20)
barplot(
  rev(top_20$Importance), 
  names.arg = rev(top_20$Feature),
  horiz = TRUE,
  las = 1,
  col = "steelblue",
  main = "Top 20 Features - Random Forest Tuned",
  xlab = "Importância"
)
dev.off()
cat("[INFO] Gráfico guardado: results/feature_importance_03c_improvement.png\n\n")

# ============================================================
# FASE 5: Comparação com baseline
# ============================================================
if(file.exists("results/metrics.csv")) {
  cat("========================================================\n")
  cat("COMPARAÇÃO COM BASELINE                                \n")
  cat("========================================================\n\n")
  
  baseline <- read.csv("results/metrics.csv")
  rf_baseline <- baseline[baseline$model == "RandomForest", ]
  
  if(nrow(rf_baseline) > 0) {
    cat("Random Forest Baseline:\n")
    cat("  R²:", round(rf_baseline$R2, 4), "\n")
    cat("  RMSE:", round(rf_baseline$RMSE, 4), "\n")
    cat("  MAE:", round(rf_baseline$MAE, 4), "\n\n")
    
    cat("Random Forest Tuned:\n")
    cat("  R²:", round(metrics_final$R2, 4), "\n")
    cat("  RMSE:", round(metrics_final$RMSE, 4), "\n")
    cat("  MAE:", round(metrics_final$MAE, 4), "\n\n")
    
    improvement_r2 <- (metrics_final$R2 - rf_baseline$R2) / rf_baseline$R2 * 100
    improvement_rmse <- (rf_baseline$RMSE - metrics_final$RMSE) / rf_baseline$RMSE * 100
    
    cat("Melhoria:\n")
    cat("  R²:", round(improvement_r2, 2), "%\n")
    cat("  RMSE:", round(improvement_rmse, 2), "%\n\n")
  }
}

# ============================================================
# GUARDAR MODELO E RESULTADOS
# ============================================================
cat("========================================================\n")
cat("GUARDANDO RESULTADOS                                    \n")
cat("========================================================\n\n")

saveRDS(rf_final, "modelo_03c_improvement.rds")
cat("[INFO] Modelo guardado: modelo_03c_improvement.rds\n")

write.csv(metrics_final, "results/metrics_03c_improvement.csv", row.names = FALSE)
cat("[INFO] Métricas guardadas: results/metrics_03c_improvement.csv\n")

write.csv(results_fine, "results/tuning_results_03c_improvement.csv", row.names = FALSE)
cat("[INFO] Resultados de tuning: results/tuning_results_03c_improvement.csv\n")

# ============================================================
# DESATIVAR PARALELIZAÇÃO
# ============================================================
stopCluster(cl)
registerDoSEQ()
cat("\n[INFO] Cluster paralelo encerrado.\n")

cat("\n========================================================\n")
cat("              TUNING CONCLUÍDO                          \n")
cat("========================================================\n")
cat("Tempo total:", round((elapsed + elapsed_final)/60, 2), "min\n")
cat("Melhor configuração: mtry =", best_config$mtry, 
    ", ntree =", best_config$ntree, 
    ", nodesize =", best_config$nodesize, "\n")
cat("R² final:", round(metrics_final$R2, 4), "\n")
cat("========================================================\n")

########################################################
# === 3. Modeling: Treino de modelos supervisionados ===
########################################################


# Carregar dependências e definir seed
source("R/dependencies.R")

# Carregar dados de treino e teste
train <- read.csv("data/train.csv")
test  <- read.csv("data/test.csv")

# Garantir que matched_score é numérico
target <- "matched_score"
train[[target]] <- as.numeric(train[[target]])
test[[target]]  <- as.numeric(test[[target]])

# Preprocessing recipe: dummies e normalização (caso necessário)
rec <- recipe(matched_score ~ ., data = train) %>%
  step_zv(all_predictors()) %>%
  step_normalize(all_numeric_predictors())
prep_rec <- prep(rec)
train_baked <- bake(prep_rec, new_data = NULL)
test_baked  <- bake(prep_rec, new_data = test)

# Model 1: Regressão Linear (lm)
lm_model <- train(matched_score ~ ., data = train_baked, method = "lm",
                  trControl = trainControl(method = "cv", number = 5))
lm_pred <- predict(lm_model, newdata = test_baked)

# Model 2: Random Forest
rf_model <- train(matched_score ~ ., data = train_baked, method = "rf",
                  trControl = trainControl(method = "cv", number = 5),
                  importance = TRUE)
rf_pred <- predict(rf_model, newdata = test_baked)

# Model 3: Gradient Boosting (xgboost)
xgb_model <- train(matched_score ~ ., data = train_baked, method = "xgbTree",
                   trControl = trainControl(method = "cv", number = 5))
xgb_pred <- predict(xgb_model, newdata = test_baked)

# Model 4: Regressão Regularizada (glmnet)
glmnet_model <- train(matched_score ~ ., data = train_baked, method = "glmnet",
                      trControl = trainControl(method = "cv", number = 5))
glmnet_pred <- predict(glmnet_model, newdata = test_baked)

# Avaliação dos modelos
results <- tibble(
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
print(results)

# Guardar métricas
write.csv(results, "results/metrics.csv", row.names = FALSE)

# Guardar importância das variáveis do melhor modelo (exemplo: Random Forest)
png("results/feature_importance.png", width=800, height=600)
vip(rf_model)
dev.off()

# Guardar modelo final (exemplo: o melhor por RMSE)
best_model <- list(lm = lm_model, rf = rf_model, xgb = xgb_model, glmnet = glmnet_model)[[which.min(results$RMSE)]]
saveRDS(best_model, "modelo_final.rds")

cat("Modelos treinados e avaliados. Resultados guardados em 'results/'.\n")

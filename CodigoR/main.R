########################################################################
# crispdm_resume_project.R
# Pipeline CRISP-DM para prever matched_score
# Executar no RStudio. Comentários explicam cada fase.
########################################################################

# --- Pacotes necessários ---
# Packages
packages <- c(
  "tidyverse", "caret", "randomForest", "xgboost", 
  "text2vec", "glmnet", "recipes", "rsample", "skimr", "vip"
)

# 2. Install the packages
install.packages(packages)

library(tidyverse)
library(caret)
library(randomForest)
library(xgboost)
library(text2vec)
library(glmnet)
library(recipes)
library(rsample)
library(skimr)
library(vip)

# Definir seed data para reproducibilidade do script.
set.seed(123)

# --- 1. Business understanding (documentar) ---
# (Escrever no relatório: objetivo, métricas, stakeholders)

# --- 2. Data understanding ---
df_raw <- resume_data

# Dimensão do Dataset. 
cat("Dimensão:", dim(df_raw), "\n")

# Sumário expandido com a função skim (já oferece os tipos de variáveis)
skim(df_raw)

# percentagem NA por coluna
na_percentage <- sapply(df_raw, function(x) mean(is.na(x)))*100
na_percentage_sorted <- sort(na_percentage, decreasing = TRUE)
cat("% NAs / Column (Sorted):\n")
print(na_percentage_sorted)

# confirmar a variável dependente ??? 
table(is.na(df_raw$matched_score))
df_raw$matched_score <- as.numeric(df_raw$matched_score)

# explorar distribuição do matched_score
hist(df_raw$matched_score, breaks = 30, main = "Distribuição matched_score", xlab = "matched_score")

# --- 3. Data preparation & Feature engineering ---

df <- df_raw %>% 
  # remover duplicados
  distinct() %>%
  # exemplo de tratamento simples: substituir strings vazias por NA
  mutate_all(~na_if(., ""))

# EXEMPLO de features textuais: skills (separadas por \n)
# Criar número de skills
if("skills" %in% names(df)){
  df <- df %>%
    mutate(n_skills = ifelse(is.na(skills), 0, str_count(skills, "\\n") + 1),
           skills_clean = ifelse(is.na(skills), "", skills))
} else {
  df$n_skills <- 0
  df$skills_clean <- ""
}

# Criar feature career_objective length
if("career_objective" %in% names(df)){
  df <- df %>%
    mutate(career_len = ifelse(is.na(career_objective), 0, nchar(career_objective)),
           career_obj_clean = ifelse(is.na(career_objective), "", career_objective))
} else {
  df$career_len <- 0
  df$career_obj_clean <- ""
}

# Exemplo de transformar passing_years para média (se for lista) - adaptar conforme dados
if("passing_years" %in% names(df)){
  # se for string com anos separados, tomar o mais recente
  df <- df %>%
    mutate(passing_years_clean = passing_years)
}

# Remover colunas com > 90% NA (opcional)
cols_remove <- names(na_pct[na_pct > 90])
df <- df %>% select(-one_of(cols_remove))

# Tratar restantes NAs: estratégia simples - imputar median/presente
num_cols <- df %>% select(where(is.numeric)) %>% names()
cat("Numeric cols:", num_cols, "\n")

# Imputar medianas para numéricas
for (nc in num_cols){
  df[[nc]][is.na(df[[nc]])] <- median(df[[nc]], na.rm = TRUE)
}

# Para categóricas, imputar "Unknown"
cat_cols <- df %>% select(where(~!is.numeric(.))) %>% names()
for (cc in cat_cols){
  df[[cc]][is.na(df[[cc]])] <- "Unknown"
}

# --- TEXT FEATURES using TF-IDF (text2vec) ---
# Vamos usar skills_clean e responsibilities (se existir) como fontes textuais
text_cols <- c()
if("skills_clean" %in% names(df)) text_cols <- c(text_cols, "skills_clean")
if("responsibilities" %in% names(df)) {
  df$responsibilities_clean <- ifelse(is.na(df$responsibilities), "", df$responsibilities)
  text_cols <- c(text_cols, "responsibilities_clean")
}
# Concatenate textual fields if multiple
if(length(text_cols) > 0){
  df$doc_text <- df %>% select(all_of(text_cols)) %>% apply(1, paste, collapse = " ")
} else {
  df$doc_text <- ""
}

# Build TF-IDF matrix (limit vocab to top 2000)
it <- itoken(df$doc_text, progressbar = FALSE, tokenizer = word_tokenizer)
v <- create_vocabulary(it, ngram = c(1L,1L)) %>% prune_vocabulary(term_count_min = 5, doc_proportion_max = 0.5)
v <- v %>% top_n(2000, wt = term_count)
vectorizer <- vocab_vectorizer(v)
dtm <- create_dtm(it, vectorizer)
tfidf_transformer <- TfIdf$new()
dtm_tfidf <- tfidf_transformer$fit_transform(dtm)

# Convert sparse dtm to data frame with limited columns (top 200 features via SVD or select top terms)
# For simplicity, use truncated SVD to reduce dimensionality (k = 50)
library(irlba)
svd_k <- 50
svd_res <- irlba::irlba(dtm_tfidf, nv = svd_k, maxit = 1000)
svd_df <- as.data.frame(svd_res$u %*% diag(svd_res$d))

# Name SVD features
colnames(svd_df) <- paste0("text_svd_", 1:ncol(svd_df))
df <- bind_cols(df, svd_df)

# --- Prepare final modeling dataset ---
# Remove large text columns to avoid duplication
drop_text_cols <- c("skills", "skills_clean", "career_objective", "career_obj_clean", "doc_text", "responsibilities", "responsibilities_clean")
df_model <- df %>% select(-one_of(intersect(names(df), drop_text_cols)))

# Ensure matched_score present and numeric
df_model$matched_score <- as.numeric(df_model$matched_score)

# Split train/test
set.seed(123)
split <- initial_split(df_model, prop = 0.8, strata = "matched_score")
train_data <- training(split)
test_data  <- testing(split)

# --- 4. Modeling ---
# Baseline: Linear model (with caret)
# Preprocessing recipe: convert character to factors (or dummy), center/scale numerics (except target)
rec <- recipe(matched_score ~ ., data = train_data) %>%
  update_role(matches("id|ID|address|company_url"), new_role = "drop") %>% # example
  step_string2factor(all_nominal_predictors()) %>%
  step_dummy(all_nominal_predictors(), one_hot = TRUE) %>%
  step_zv(all_predictors()) %>%   # remove zero variance
  step_normalize(all_numeric_predictors())

prep_rec <- prep(rec)
train_baked <- bake(prep_rec, new_data = NULL)
test_baked  <- bake(prep_rec, new_data = test_data)

# Model 1: Linear (glmnet ridge)
x_train <- as.matrix(train_baked %>% select(-matched_score))
y_train <- train_baked$matched_score
x_test <- as.matrix(test_baked %>% select(-matched_score))
y_test <- test_baked$matched_score

cvglm <- cv.glmnet(x_train, y_train, alpha = 0, nfolds = 5)
best_lambda <- cvglm$lambda.min
cat("Best lambda (ridge):", best_lambda, "\n")
pred_glm <- predict(cvglm, s = best_lambda, newx = x_test)
rmse_glm <- sqrt(mean((pred_glm - y_test)^2))
mae_glm <- mean(abs(pred_glm - y_test))
r2_glm <- cor(as.numeric(pred_glm), y_test)^2
cat("GLMnet (Ridge) RMSE:", rmse_glm, "MAE:", mae_glm, "R2:", r2_glm, "\n")

# Model 2: Random Forest
# Convert to data.frame (caret friendly)
rf_train <- train_baked
rf_test  <- test_baked

# reducing columns for RF if too many dims (optional): sample columns
if(ncol(rf_train) > 200){
  rf_train <- rf_train %>% select(matched_score, sample(names(.)[names(.) != "matched_score"], 200))
  rf_test  <- rf_test %>% select(matched_score, intersect(names(rf_train), names(rf_test)))
}

rf_model <- randomForest(matched_score ~ ., data = rf_train, ntree = 200, importance = TRUE)
rf_pred <- predict(rf_model, newdata = rf_test)
rmse_rf <- sqrt(mean((rf_pred - rf_test$matched_score)^2))
mae_rf <- mean(abs(rf_pred - rf_test$matched_score))
r2_rf <- cor(rf_pred, rf_test$matched_score)^2
cat("RF RMSE:", rmse_rf, "MAE:", mae_rf, "R2:", r2_rf, "\n")

# Feature importance
imp <- importance(rf_model)
vip::vip(rf_model)

# Model 3: XGBoost (simple)
dtrain <- xgb.DMatrix(data = x_train, label = y_train)
dtest  <- xgb.DMatrix(data = x_test, label = y_test)
params <- list(objective = "reg:squarederror", eval_metric = "rmse", max_depth = 6, eta = 0.1)
xgb_model <- xgb.train(params = params, data = dtrain, nrounds = 200, watchlist = list(train = dtrain), verbose = 0)
xgb_pred <- predict(xgb_model, dtest)
rmse_xgb <- sqrt(mean((xgb_pred - y_test)^2))
mae_xgb <- mean(abs(xgb_pred - y_test))
r2_xgb <- cor(xgb_pred, y_test)^2
cat("XGBoost RMSE:", rmse_xgb, "MAE:", mae_xgb, "R2:", r2_xgb, "\n")

# Save the best model (example: if xgboost best)
# xgb.save(xgb_model, "xgb_model.model")

# --- 5. Evaluation analysis ---
results <- tibble(
  model = c("RidgeGLM", "RandomForest", "XGBoost"),
  RMSE = c(rmse_glm, rmse_rf, rmse_xgb),
  MAE = c(mae_glm, mae_rf, mae_xgb),
  R2 = c(r2_glm, r2_rf, r2_xgb)
)
print(results)

# Residual analysis for best model
best_pred <- xgb_pred
resid <- y_test - best_pred
hist(resid, main = "Resíduos (melhor modelo)", xlab = "y - yhat", breaks = 30)

# --- 6. Deployment notes (salvar artefatos) ---
# Salvar recipe e modelo
saveRDS(prep_rec, "recipe_preproc.rds")
saveRDS(xgb_model, "xgb_model.rds") # prefer xgboost as example
# Para servir: criar endpoint que aplica recipe -> transforma -> xgb.predict

cat("FIM do script. Ver relatório para documentação das escolhas.\n")

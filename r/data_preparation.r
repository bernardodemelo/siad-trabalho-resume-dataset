########################################################
# === 2. Data Preparation: Tratamento de valores em falta ===
########################################################

# Carregar o dataset
df <- read.csv("data/resume_data.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)

# Função para calcular a moda
tab_mode <- function(x) {
  ux <- na.omit(unique(x))
  ux[which.max(tabulate(match(x, ux)))]
}

# Criar features úteis para modelação
# 1. Contagem de skills
df$skills_count <- sapply(df$skills, function(x){
  if(is.na(x)) return(0)
  x <- gsub("\\[|\\]|'|\"", "", x)
  length(unlist(strsplit(x, ",")))
})
# 2. Número de palavras em career objective
df$career_word_count <- sapply(df$career_objective, function(x){
  if(is.na(x)) return(0)
  length(unlist(strsplit(x, "\\s+")))
})
# 3. Número de palavras em responsabilidades
df$responsibilities_word_count <- sapply(df$responsibilities.1, function(x){
  if(is.na(x)) return(0)
  length(unlist(strsplit(x, "\\s+")))
})
# 4. Tamanho do CV em caracteres
df$text_length_total <- apply(df, 1, function(row){
  sum(nchar(paste(row, collapse=" ")), na.rm = TRUE)
})
# 5. Extrair idades de age_requirement
df$age_min <- as.numeric(str_extract(df$age_requirement, "\\d{2}"))
df$age_max <- as.numeric(str_extract(df$age_requirement, "(?<=to )\\d{2}"))

# 1. Remover colunas com mais de 50% de valores em falta
na_perc <- sapply(df, function(x) mean(is.na(x) | x == "N/A" | x == "None"))
df <- df[, na_perc <= 0.5]

# 2. Imputar valores em falta
for(col in names(df)) {
  if (is.numeric(df[[col]])) {
    # Imputação pela mediana
    med <- median(df[[col]], na.rm = TRUE)
    df[[col]][is.na(df[[col]])] <- med
  } else {
    # Imputação pela moda
    moda <- tab_mode(df[[col]])
    df[[col]][is.na(df[[col]]) | df[[col]] == "N/A" | df[[col]] == "None"] <- moda
  }
}

# Verificar se ainda existem valores em falta
total_na <- sum(is.na(df))
cat("Valores NA restantes após tratamento:", total_na, "\n")

# Converter colunas de texto para factor
cat_cols <- names(df)[sapply(df, function(x) is.character(x))]
df[cat_cols] <- lapply(df[cat_cols], factor)

# Remoção de outliers nas variáveis numéricas
remove_outliers <- function(x) {
  q1 <- quantile(x, 0.25, na.rm = TRUE)
  q3 <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  x[x < (q1 - 1.5 * iqr) | x > (q3 + 1.5 * iqr)] <- NA
  return(x)
}
num_cols <- names(df)[sapply(df, is.numeric)]
df[num_cols] <- lapply(df[num_cols], remove_outliers)

# Codificação de variáveis categóricas
cat_cols <- names(df)[sapply(df, function(x) is.character(x) | is.factor(x))]
# Converter para factor
for(col in cat_cols) {
  df[[col]] <- as.factor(df[[col]])
}

# Codificação one-hot/dummy para todas as categóricas (exceto a variável dependente)
dummies <- dummyVars(~ ., data = df, fullRank = TRUE)
df_encoded <- as.data.frame(predict(dummies, newdata = df))

# Normalização / padronização de variáveis numéricas
num_cols <- names(df_encoded)[sapply(df_encoded, is.numeric)]
df_encoded[num_cols] <- lapply(df_encoded[num_cols], scale)

# Definir percentagem de valores NA finais
na_total <- mean(is.na(df_encoded)) * 100
cat("Percentagem total de valores NA no dataset final:", round(na_total, 2), "%\n")

# Guardar o dataset final normalizado e codificado antes da divisão
write.csv(df_encoded, "data/resume_data_final.csv", row.names = FALSE)

# Divisão dos dados em treino (80%) e teste (20%)
index <- caret::createDataPartition(df_encoded$matched_score, p=0.8, list=FALSE)
train <- df_encoded[index, ]
test  <- df_encoded[-index, ]


# parte ainda em teste --> Miguel

# ============================================================
# === Padronização e Correção de Skewness ===
# ============================================================
# Primeiro verificamos skewness e aplicamos Yeo-Johnson se necessário
# Comentário: Yeo-Johnson é seguro para zeros e negativos, melhora normalidade
library(bestNormalize)
library(e1071)

num_cols <- names(df_encoded)[sapply(df_encoded, is.numeric)]

for (col in num_cols) {
  skew_val <- skewness(df_encoded[[col]], na.rm = TRUE)
  if (abs(skew_val) > 1) {
    
    norm_obj <- yeojohnson(df_encoded[[col]])
    df_encoded[[col]] <- predict(norm_obj)
  }
}

# Padronização final (Z-score)
# Comentário: Garantimos média = 0 e desvio padrão = 1 para todas as variáveis numéricas
df_encoded[num_cols] <- scale(df_encoded[num_cols])

# ============================================================
# === Guardar dataset final ===
# ============================================================
write.csv(df_encoded, "data/resume_data_final.csv", row.names = FALSE)

# ============================================================
# === Divisão dos dados em treino (80%) e teste (20%) ===
# ============================================================
set.seed(123)
index <- caret::createDataPartition(df_encoded$matched_score, p = 0.8, list = FALSE)
train <- df_encoded[index, ]
test  <- df_encoded[-index, ]

write.csv(train, "data/train.csv", row.names = FALSE)
write.csv(test, "data/test.csv", row.names = FALSE)

cat("Data preparation finalizada com:\n")
cat("- Codificação categórica (dummy)\n")
cat("- Correção de skewness (Yeo-Johnson)\n")
cat("- Padronização (Z-score)\n")
cat("- Novas features adicionadas\n")
cat("- Split treino/teste concluído!\n")
cat("data preparation finalizada com padronização, correção de skewness e novas features!\n")
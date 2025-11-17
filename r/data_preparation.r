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

# Instalação automática do pacote 'caret' caso não esteja instalado
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!require(caret)) {
  install.packages("caret", dependencies = TRUE)
}
library(caret)

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

# Guardar o dataset final normalizado e codificado antes da divisão
write.csv(df_encoded, "data/resume_data_final.csv", row.names = FALSE)

# Divisão dos dados em treino (80%) e teste (20%)
set.seed(123)
index <- caret::createDataPartition(df_encoded$matched_score, p=0.8, list=FALSE)
train <- df_encoded[index, ]
test  <- df_encoded[-index, ]

write.csv(train, "data/train.csv", row.names = FALSE)
write.csv(test, "data/test.csv", row.names = FALSE)

cat("Data preparation finalizada!\n")
cat("Codificação de variáveis categóricas concluída!\n")
cat("Normalização de variáveis numéricas concluída!\n")
cat("Divisão treino/teste concluída!\n")
cat("Data preparation finalizada!\n")

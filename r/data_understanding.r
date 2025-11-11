########################################################
# === 1. Preparação do ambiente e pacotes necessários ===
########################################################

# Lista dos pacotes que o script necessita
required_packages <- c("skimr", "stringr", "corrplot", "dplyr")

# Função que verifica se cada pacote está instalado;
# se não estiver, faz a instalação e carrega automaticamente.
for(pkg in required_packages){
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}
# --- 2. Data understanding ---
df_raw <- resume_data
# meti isto para mim porque me tava a dar erro a executar o df_raw
#df_raw <- read.csv("C:/Users/migue/Documents/resume_data.csv",
 #                  header = TRUE, sep = ",", stringsAsFactors = FALSE)
df <- df_raw #copia do dataset
# Dimensão do Dataset. 
cat("Dimensão:", dim(df_raw), "\n")

# Sumário expandido com a função skim (já oferece os tipos de variáveis)
skim(df_raw)

# percentagem NA por coluna
na_percentage <- sapply(df_raw, function(x) mean(is.na(x)))*100
na_percentage_sorted <- sort(na_percentage, decreasing = TRUE)
cat("% NAs / Column (Sorted):\n")
print(na_percentage_sorted)

# confirmar a variável dependente 
table(is.na(df_raw$matched_score))

# explorar distribuição do matched_score - Histograma
hist(df_raw$matched_score, breaks = 30, main = "Distribuição matched_score", xlab = "matched_score")

# descrição de outliers a partir do boxplot 
boxplot(df_raw$matched_score, main="Boxplot matched_score", ylab="matched_score")

# deteção de outliers a partir do critério de IQR (Intervalo Interquartil)
boxplot.stats(df_raw$matched_score)$out


########################################################
# === 3. Variável Dependente matched_score ===
########################################################

df$matched_score <- as.numeric(df$matched_score)

# numero em falta na var dependente
cat("NAs em matched_score:", sum(is.na(df$matched_score)), "\n")

# Histograma
hist(df$matched_score, breaks = 30,
     main = "Distribuição matched_score",
     col = "skyblue", xlab = "matched_score")

# Boxplot
boxplot(df$matched_score, main = "Boxplot matched_score",
        col = "orange", ylab = "matched_score")

# Outliers via IQR (interquartile range)
outliers <- boxplot.stats(df$matched_score)$out
cat("Outliers detectados:", length(outliers), "\n")

# objetivo: compreender o comportamento e possiveis problemas no matched_score
########################################################
# === 4. Procurar colunas que possam conter datas ===
########################################################

# Esta função procura padrões de datas (anos tipo 19xx ou 20xx) em colunas de texto.
# Ajuda a identificar variáveis temporais que podem ser convertidas para formato de data.
possible_dates <- sapply(df, function(x) {
  if(!is.character(x)) return(FALSE)
  any(grepl("\\b(19|20)\\d{2}\\b", x))
})

cat("Colunas que parecem conter datas:\n")
print(names(df)[possible_dates])


########################################################
# === 5. Criar Features Numéricas Úteis ===
########################################################

### 5.1 Contagem de skills (coluna vem como string tipo lista)
#limpar caracteres especiais
df$skills_count <- sapply(df$skills, function(x){
  if(is.na(x)) return(0)
  x <- gsub("\\[|\\]|'|\"", "", x)
  length(unlist(strsplit(x, ",")))
})

### 5.2 Número de palavras em career objective
df$career_word_count <- sapply(df$career_objective, function(x){
  if(is.na(x)) return(0)
  length(unlist(strsplit(x, "\\s+")))
})

### 5.3 Número de palavras em responsabilidades
df$responsibilities_word_count <- sapply(df$responsibilities.1, function(x){
  if(is.na(x)) return(0)
  length(unlist(strsplit(x, "\\s+")))
})


### 5.4 tamanho do CV em caracteres (útil)
df$text_length_total <- apply(df, 1, function(row){
  sum(nchar(paste(row, collapse=" ")), na.rm = TRUE)
})

# gerar novas variaveis quantitativas para representar melhor as 
# informações textuais

########################################################
# === 6. Extrair idades de age_requirement ===
########################################################

df$age_min <- as.numeric(str_extract(df$age_requirement, "\\d{2}"))
df$age_max <- as.numeric(str_extract(df$age_requirement, "(?<=to )\\d{2}"))


########################################################
# === 7. Converter colunas textuais para fatores ===
########################################################
# Identificamos colunas do tipo 'character' e transformamos em 'factor'
# para que possam ser usadas em análises categóricas e modelação estatística.
cols_texto <- names(df)[sapply(df, is.character)]
df[cols_texto] <- lapply(df[cols_texto], factor)


########################################################
# === 8. Histogramas e Boxplots Extras ===
########################################################

numeric_cols <- names(df)[sapply(df, is.numeric)]

# Histograma para TODAS as numéricas
pdf("histogramas_numericos.pdf", width = 10, height = 8)
par(mfrow=c(3,3))
for(col in numeric_cols){
  hist(df[[col]], main=paste("Hist:", col),
       xlab=col, col="blue")
}
dev.off()


# Boxplots de TODAS as numéricas
pdf("boxplots.pdf",width=10,height=8)
par(mfrow=c(3,3))
for(col in numeric_cols){
  boxplot(df[[col]], main=paste("Boxplot:", col),
          col="lightblue")
}


########################################################
# === 9. Matriz de Correlação ===
########################################################

#identificar relações lineares entre variáveis,
# úteis para modelação e seleção de features.
num_df <- df[numeric_cols]

corrplot(cor(num_df, use="pairwise.complete.obs"),
         method="color", tl.cex=0.6)


########################################################
# 10. Remoção opcional de outliers (IQR)
########################################################
# : limpar valores extremos que podem 
# distorcer as análises ou o treino de modelos.
remove_outliers <- function(x) {
  q1 <- quantile(x, 0.25, na.rm = TRUE)
  q3 <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  x[x < (q1 - 1.5 * iqr) | x > (q3 + 1.5 * iqr)] <- NA
  return(x)
}

df_no_outliers <- df
df_no_outliers[numeric_cols] <- lapply(df_no_outliers[numeric_cols], remove_outliers)


########################################################
# 11. Dataset final pronto para modelação
########################################################

df_final <- df_no_outliers %>% 
  select(matched_score, everything())

cat("Dataset final preparado! Dimensão:", dim(df_final), "\n")


# Comparar dimensão antes e depois do pré-processamento
cat("Dimensão original (df_raw):", dim(df_raw), "\n")
cat("Dimensão final (df_final):", dim(df_final), "\n")

# Explicação:
# As dimensões indicam o número de linhas (observações) e colunas (variáveis).
# O número de linhas deve ser o mesmo, pois não foram eliminadas observações.
# O número de colunas deve ser MAIOR, porque criámos novas variáveis (features)
# como skills_count, career_word_count, text_length_total, etc.

# Verificar se há diferenças no número de linhas
if (nrow(df_raw) == nrow(df_final)) {
  cat("O número de observações (linhas) manteve-se igual.\n")
} else {
  cat("O número de observações alterou-se!\n")
}

na_total <- mean(is.na(df_final)) * 100
cat("Percentagem total de valores NA no dataset final:", round(na_total, 2), "%\n")
########################################################
# === 1. Preparação do ambiente e pacotes necessários ===
########################################################

df_raw <-  read.csv("data/resume_data.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)

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

df_raw$matched_score <- as.numeric(df$matched_score)

# numero em falta na var dependente
cat("NAs em matched_score:", sum(is.na(df_raw$matched_score)), "\n")

# Histograma
hist(df_raw$matched_score, breaks = 30,
     main = "Distribuição matched_score",
     col = "skyblue", xlab = "matched_score")

# Boxplot
boxplot(df_raw$matched_score, main = "Boxplot matched_score",
        col = "orange", ylab = "matched_score")

# Outliers via IQR (interquartile range)
outliers <- boxplot.stats(df_raw$matched_score)$out
cat("Outliers detectados:", length(outliers), "\n")
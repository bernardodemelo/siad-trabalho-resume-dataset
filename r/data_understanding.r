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

# confirmar a variável dependente 
table(is.na(df_raw$matched_score))

# explorar distribuição do matched_score - Histograma
hist(df_raw$matched_score, breaks = 30, main = "Distribuição matched_score", xlab = "matched_score")

# descrição de outliers a partir do boxplot 
boxplot(df_raw$matched_score, main="Boxplot matched_score", ylab="matched_score")

# deteção de outliers a partir do critério de IQR (Intervalo Interquartil)
boxplot.stats(df_raw$matched_score)$out
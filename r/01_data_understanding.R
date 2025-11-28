##################################################
# === 1. Recolha e decrição de dados inicial === #
##################################################

# Carregar dependências e definir seed
source("r/dependencies.R")

# Encontrar o diretorio
getwd()

df_raw <-  read.csv("data/resume_data.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)

# Dimensão do Dataset. 
cat("Dimensão:", dim(df_raw), "\n")

# Sumário expandido com a função skim (já oferece os tipos de variáveis)
skim(df_raw)

# Visão geral da estrutura dos dados
glimpse(df)


#################################
# === 2. Análise exploratória === #
#################################

### Entradas vazias ###

# Calcular % de NA ou Vazio
missing_simple <- df_raw %>%
  summarise(across(everything(), ~ mean(is.na(.) | as.character(.) == "") * 100)) %>%
  pivot_longer(cols = everything(), names_to = "Variavel", values_to = "Pct_Vazios") %>%
  arrange(desc(Pct_Vazios))

# Mostrar o resultado formatado
print(as.data.frame(missing_simple))

# Gráfico de barras % Dados em falta por variável
ggplot(filter(missing_simple, Pct_Vazios > 0), 
       aes(x = reorder(Variavel, Pct_Vazios), y = Pct_Vazios)) +
  geom_bar(stat = "identity", fill = "tomato") +
  coord_flip() + # Barra horizontal para ler melhor os nomes
  labs(title = "% de dados vazios por Variável",
       x = "Variável",
       y = "Percentagem (%)") +
  theme_minimal()

### Entradas com dados vazios ###

# Contar quantas vezes aparecem strings que representam nulos mas não são NA reais
count_hidden_na <- function(column, pattern) {
  sum(str_count(as.character(column), pattern), na.rm = TRUE)
}

# Verificar "N/A"
na_text_counts <- sapply(df_raw, count_hidden_na, pattern = "N/A")
print(head(sort(na_text_counts, decreasing = TRUE), 5))

# Verificar "None"
none_text_counts <- sapply(df_raw, count_hidden_na, pattern = "None")
print(head(sort(none_text_counts, decreasing = TRUE), 5))


### estatística e distribuições ###

## X.job_position_name ##

# Tabela de Frequências
job_counts <- df_raw %>%
  count(X.job_position_name, sort = TRUE)

print("Número de Cargos Únicos:")
print(nrow(job_counts))

print("Cargos existentes:")
print(head(job_counts, nrow(job_counts)))


## matched_score ##

# confirmar a variável dependente 
table(is.na(df_raw$matched_score))

# Analisar matched_score
summary(df$matched_score)
stat.desc(df$matched_score)

# distribuição do Matched Score - Histograma
ggplot(df_raw, aes(x = matched_score)) +
  geom_histogram(binwidth = 0.05, fill = "tomato", color = "black") +
  labs(title = "Distribuição do Matched Score",
       x = "Score",
       y = "Frequência") +
  theme_minimal()

# descrição de outliers a partir do boxplot 
boxplot(df_raw$matched_score, main="Boxplot matched_score", ylab="matched_score", col = "tomato")

# deteção de outliers a partir do critério de IQR (Intervalo Interquartil)
outliers <- boxplot.stats(df_raw$matched_score)$out
cat("Outliers detectados:", length(outliers), "\n")
########################################################
# === 2. Data Preparation: Tratamento de valores em falta ===
########################################################
# Carregar dependências e definir seed
source("r/dependencies.R")

# Encontrar o diretorio
getwd()
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
if("responsibilities.1" %in% names(df)){
  df$responsibilities_word_count <- sapply(df$responsibilities.1, function(x){
    if(is.na(x)) return(0)
    length(unlist(strsplit(x, "\\s+")))
  })
} else {
  df$responsibilities_word_count <- 0
}
# 4. Tamanho do CV em caracteres
df$text_length_total <- apply(df, 1, function(row){
  nchar(paste(row, collapse=" "))
})
# 5. Extrair idades de age_requirement
df$age_min <- as.numeric(str_extract(df$age_requirement, "\\d{2}"))
df$age_max <- as.numeric(str_extract(df$age_requirement, "(?<=to )\\d{2}"))

# 1. Remover colunas com mais de 50% de valores em falta
na_perc <- sapply(df, function(x) mean(is.na(x) | x == "N/A" | x == "None"))
df <- df[, na_perc <= 0.5]

# 2. valores em falta
# === 2. Imputar valores em falta ===
for(col in names(df)) {
  if (is.numeric(df[[col]])) {
    # Imputação pela median
    med <- median(df[[col]], na.rm = TRUE)
    df[[col]][is.na(df[[col]])] <- med
  } else {
    # pela moda
    # Converte para character caso seja factor
    temp_col <- as.character(df[[col]])
    moda <- tab_mode(temp_col)
    temp_col[is.na(temp_col) | temp_col == "N/A" | temp_col == "None"] <- moda
    df[[col]] <- temp_col
  }
}

# === Verificar se ainda existem valores em falta ===
total_na <- sum(is.na(df))
cat("Valores NA restantes após tratamento:", total_na, "\n")

# === Converter colunas de texto para factor ===
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
# Seleciona colunas numéricas 
num_cols <- names(df)[sapply(df, is.numeric)]
target <- "matched_score" # coluna alvo

# Exclui matched_score da remoção de outliers
num_cols_no_target <- setdiff(num_cols, target)

df[num_cols_no_target] <- lapply(df[num_cols_no_target], remove_outliers)

# Codificação de variáveis categóricas
cat_cols <- names(df)[sapply(df, function(x) is.character(x) | is.factor(x))]
# Converter para factor
for(col in cat_cols) {
  df[[col]] <- as.factor(df[[col]])
}

# Codificação one-hot/dummy para todas as categóricas (exceto a variável dependente)
predictors <- setdiff(names(df), target)
dummies <- dummyVars(~ ., data = df[predictors], fullRank = TRUE)
df_encoded <- as.data.frame(predict(dummies, newdata = df[predictors]))

# Adiciona a coluna target de volta
df_encoded[[target]] <- df[[target]]

# ============================================================================
# Changes #1: Removi A normalização PREMATURA QUE ESTAVA AQUI
# Problema: Estavamos a normalizar TODAS as colunas (incluindo target)
# e depois tentavamos normalizar de novo na secção de padronização
# Solução: removi esta parte # df_encoded[num_cols_encoded] <- as.data.frame(lapply(df_encoded[num_cols_encoded], scale))

# ============================================================================

# ============================================================================
# Changes #2: ADICIONAR IMPUTAÇÃO DOS NAs CRIADOS PELOS OUTLIERS
# Problema: A remoção de outliers cria NAs que não são tratados
# Solução: mediana antes de continuar
# ============================================================================
for(col in names(df_encoded)) {
  if (is.numeric(df_encoded[[col]])) {
    if(any(is.na(df_encoded[[col]]))) {
      med <- median(df_encoded[[col]], na.rm = TRUE)
      df_encoded[[col]][is.na(df_encoded[[col]])] <- med
      cat("Imputados", sum(is.na(df_encoded[[col]])), "NAs em", col, "\n")
    }
  }
}

# Definir percentagem de valores NA finais
na_total <- mean(is.na(df_encoded)) * 100
cat("Percentagem total de valores NA no dataset final:", round(na_total, 2), "%\n")

# ============================================================================
# Changes #3: GUARDAR DADOS *ANTES* DA PADRONIZAÇÃO
# Problema: Guardar os dados já normalizados como "final"
# Solução: Guardar aqui como "before_standardization" para comparação
# ============================================================================
write.csv(df_encoded, "data/resume_data_before_standardization.csv", row.names = FALSE)
cat("Dados ANTES da padronização guardados em: data/resume_data_before_standardization.csv\n")

# NOTA: A divisão treino/teste será feita DEPOIS da padronização
# para garantir que ambos os conjuntos usam os mesmos parâmetros de padronização


########################################################
# === PADRONIZAÇÃO E CORREÇÃO DE SKEWNESS === # 
########################################################
cat("\n")

# Instalar e carregar pacotes necessários
install_and_load("bestNormalize")
install_and_load("moments")
install_and_load("ggplot2")
install_and_load("gridExtra")

# === ETAPA 1: IDENTIFICAÇÃO E DIAGNÓSTICO INICIAL ===
cat("=== ETAPA 1: Diagnóstico Inicial ===\n")

# ============================================================================
# Changes #4: CRIAR CÓPIA DOS DADOS PARA TRABALHAR
# Problema: Modificar df_encoded diretamente pode causar confusão
# Solução: Criar df_standardized como cópia para trabalhar
# ============================================================================
df_standardized <- df_encoded

# Selecionar colunas numéricas excluindo a variável target
num_cols <- setdiff(names(df_standardized)[sapply(df_standardized, is.numeric)], target)

cat("Total de variáveis numéricas (preditoras):", length(num_cols), "\n")
cat("Variável target excluída da padronização:", target, "\n\n")

# Estatísticas descritivas antes da padronização
stats_before <- data.frame(
  Variable = num_cols,
  Mean = sapply(df_standardized[num_cols], mean, na.rm = TRUE),
  SD = sapply(df_standardized[num_cols], sd, na.rm = TRUE),
  Min = sapply(df_standardized[num_cols], min, na.rm = TRUE),
  Max = sapply(df_standardized[num_cols], max, na.rm = TRUE),
  Skewness = sapply(df_standardized[num_cols], function(x) skewness(x, na.rm = TRUE)),
  Kurtosis = sapply(df_standardized[num_cols], function(x) kurtosis(x, na.rm = TRUE))
)
rownames(stats_before) <- NULL

cat("Estatísticas Descritivas antes (primeiras 10 variáveis):\n")
print(head(stats_before, 10))
cat("\n")

# Identificar variáveis com alta assimetria
highly_skewed <- stats_before$Variable[abs(stats_before$Skewness) > 1]
cat("Variáveis com |skewness| > 1:", length(highly_skewed), "de", length(num_cols), "\n")
if(length(highly_skewed) > 0) {
  cat("Exemplos:", paste(head(highly_skewed, 5), collapse = ", "), "\n")
}
cat("\n")

# === ETAPA 2: CORREÇÃO DE SKEWNESS (YEO-JOHNSON) ===
cat("=== ETAPA 2: Correção de Assimetria (Yeo-Johnson Transformation) ===\n")
cat("Critério: Aplicar transformação quando |skewness| > 1\n\n")

# Inicializar lista para armazenar objetos de normalização
norm_objs <- list()
skewed_cols <- c()

# Dataframe para armazenar comparação de skewness
skewness_comparison <- data.frame(
  Variable = character(),
  Skewness_Before = numeric(),
  Skewness_After = numeric(),
  Improvement = numeric(),
  stringsAsFactors = FALSE
)

# Loop para verificar skewness e aplicar Yeo-Johnson se necessário
for(col in num_cols){
  # Verificar se a coluna tem variância (não é constante)
  if(sd(df_standardized[[col]], na.rm = TRUE) == 0){
    cat(sprintf("%-30s | Variância zero - ignorada\n", col))
    next
  }
  skew_before <- skewness(df_standardized[[col]], na.rm = TRUE)
  
  if(is.na(skew_before) || !is.finite(skew_before)){
    cat(sprintf(" %-30s | Skewness inválido - ignorada\n", col))
    next
  }
  
  if(abs(skew_before) > 1){
    # Aplicar transformação Yeo-Johnson
    norm_obj <- yeojohnson(df_standardized[[col]])
    df_standardized[[col]] <- predict(norm_obj)
    
    # Armazenar objeto e nome da coluna
    norm_objs[[col]] <- norm_obj
    skewed_cols <- c(skewed_cols, col)
    
    # Calcular novo skewness
    skew_after <- skewness(df_standardized[[col]], na.rm = TRUE)
    improvement <- abs(skew_before) - abs(skew_after)
    
    # Adicionar à tabela de comparação
    skewness_comparison <- rbind(skewness_comparison, data.frame(
      Variable = col,
      Skewness_Before = skew_before,
      Skewness_After = skew_after,
      Improvement = improvement
    ))
    
    cat(sprintf(" %-30s | Antes: %7.3f → Depois: %7.3f (Δ = %.3f)\n", 
                col, skew_before, skew_after, improvement))
  }
}

cat("Resumo da Correção de Skewness:")
cat("- Variáveis transformadas:", length(skewed_cols), "\n")
cat("- Variáveis não transformadas:", length(num_cols) - length(skewed_cols), "\n")
if(nrow(skewness_comparison) > 0) {
  cat("- Melhoria média em |skewness|:", 
      round(mean(skewness_comparison$Improvement), 3), "\n")
}
cat("\n")

# Guardar objetos de normalização para aplicar no conjunto de teste
saveRDS(norm_objs, "data/yeo_johnson_transforms.rds")
cat("Objetos de transformação guardados: 'data/yeo_johnson_transforms.rds'\n\n")

# === ETAPA 3: PADRONIZAÇÃO Z-SCORE ===
cat("=== ETAPA 3: Padronização Z-Score ===\n")
cat("Fórmula: z = (x - μ) / σ\n")
cat("Objetivo: Média = 0, Desvio Padrão = 1\n\n")

# Calcular e guardar parâmetros de escalonamento (ANTES de padronizar)
scaling_params <- data.frame(
  Variable = num_cols,
  Mean = sapply(df_standardized[num_cols], mean, na.rm = TRUE),
  SD = sapply(df_standardized[num_cols], sd, na.rm = TRUE)
)

cat("Parâmetros calculados (primeiras 5 variáveis):\n")
print(head(scaling_params, 5))
cat("\n")

# ============================================================================
# MUDANÇA #5: APLICAR PADRONIZAÇÃO CORRETAMENTE
# Problema: scale() pode não funcionar bem com data.frames diretamente
# Solução: Aplicar scale() e converter de volta para data.frame
# ============================================================================
df_standardized[num_cols] <- as.data.frame(scale(df_standardized[num_cols]))

cat(" Padronização Z-score aplicada a", length(num_cols), "variáveis\n\n")

# Guardar parâmetros para aplicar no conjunto de teste
saveRDS(scaling_params, "data/scaling_parameters.rds")
cat("Parâmetros de escalonamento guardados: 'data/scaling_parameters.rds'\n\n")

# === ETAPA 4: DIAGNÓSTICO PÓS-PADRONIZAÇÃO ===
cat("=== ETAPA 4: Diagnóstico Pós-Padronização ===\n")

# Estatísticas descritivas DEPOIS da padronização
stats_after <- data.frame(
  Variable = num_cols,
  Mean = sapply(df_standardized[num_cols], mean, na.rm = TRUE),
  SD = sapply(df_standardized[num_cols], sd, na.rm = TRUE),
  Min = sapply(df_standardized[num_cols], min, na.rm = TRUE),
  Max = sapply(df_standardized[num_cols], max, na.rm = TRUE),
  Skewness = sapply(df_standardized[num_cols], function(x) skewness(x, na.rm = TRUE)),
  Kurtosis = sapply(df_standardized[num_cols], function(x) kurtosis(x, na.rm = TRUE))
)
rownames(stats_after) <- NULL

cat("Estatísticas Pós-Padronização DEPOIS (primeiras 10 variáveis):\n")
print(head(stats_after, 10))
cat("\n")

# Verificação de qualidade da padronização
mean_check <- all(abs(stats_after$Mean) < 1e-10)
sd_check <- all(abs(stats_after$SD - 1) < 1e-10)

cat("Verificação de Qualidade:\n")
cat("Todas as médias ≈ 0:", mean_check, "\n")
cat("Todos os desvios padrão = 1:", sd_check, "\n")
cat("Range típico de valores padronizados: [", 
    round(min(stats_after$Min), 2), ",", 
    round(max(stats_after$Max), 2), "]\n")
cat("Média geral de |skewness|:", 
    round(mean(abs(stats_after$Skewness)), 3), "\n\n")

# ============================================================================
# MUDANÇA #6: ADICIONAR COMPARAÇÃO LADO A LADO
#
# ============================================================================
cat("=== COMPARAÇÃO ANTES vs DEPOIS (primeiras 5 variáveis) ===\n")
comparison_table <- data.frame(
  Variable = head(num_cols, 5),
  Mean_Before = head(stats_before$Mean, 5),
  Mean_After = head(stats_after$Mean, 5),
  SD_Before = head(stats_before$SD, 5),
  SD_After = head(stats_after$SD, 5)
)
print(comparison_table)
cat("\n")

# === ETAPA 5: VISUALIZAÇÕES COMPARATIVAS ===
cat("=== ETAPA 5: Geração de Visualizações ===\n")

# Criar diretório de outputs se não existir
if(!dir.exists("outputs")) dir.create("outputs")

# Selecionar primeiras 6 variáveis para visualização
vars_to_plot <- head(num_cols, 6)

# Criar lista de plots
plots_list <- list()

# ============================================================================
# Changes #7: USAR DADOS CORRETOS PARA VISUALIZAÇÃO
# Problema: Estava a tentar recarregar dados de arquivo errado
# Solução: Usar df_encoded (antes) e df_standardized (depois)
# ============================================================================
for(i in seq_along(vars_to_plot)){
  var <- vars_to_plot[i]
  
  # Dados ANTES (do df_encoded original)
  df_plot_before <- data.frame(
    value = df_encoded[[var]],
    stage = "Antes"
  )
  
  # Dados DEPOIS (do df_standardized)
  df_plot_after <- data.frame(
    value = df_standardized[[var]],
    stage = "Depois"
  )
  
  df_plot <- rbind(df_plot_before, df_plot_after)
  
  p <- ggplot(df_plot, aes(x = value, fill = stage)) +
    geom_histogram(bins = 30, alpha = 0.6, position = "identity") +
    facet_wrap(~stage, scales = "free") +
    labs(title = var, x = "Valor", y = "Frequência") +
    scale_fill_manual(values = c("Antes" = "#E74C3C", "Depois" = "#3498DB")) +
    theme_minimal() +
    theme(
      legend.position = "none",
      plot.title = element_text(size = 10, face = "bold")
    )
  
  plots_list[[i]] <- p
}

# Guardar visualizações
png("outputs/padronizacao_comparacao.png", width = 1400, height = 900, res = 120)
grid.arrange(grobs = plots_list, ncol = 2, 
             top = "Comparação: Antes vs Depois da Padronização")
dev.off()

cat("Visualizações guardadas: 'outputs/padronizacao_comparacao.png'\n\n")

# === ETAPA 6: GUARDAR DATASET FINAL ===
cat("=== ETAPA 6: Guardar Dataset Final Padronizado ===\n")

# Guardar em formato compacto (RDS)
saveRDS(df_standardized, "data/resume_data_final_standardized.rds")
cat("Dataset guardado (RDS): 'data/resume_data_final_standardized.rds'\n")

# Guardar em formato legível (CSV)
write.csv(df_standardized, "data/resume_data_final_standardized.csv", row.names = FALSE)
cat("Dataset guardado (CSV): 'data/resume_data_final_standardized.csv'\n\n")

# === ETAPA 6.5: DIVISÃO TREINO/TESTE E GUARDAR ===
cat("=== ETAPA 6.5: Divisão em Treino (80%) e Teste (20%) ===\n")

# Garantir que matched_score é numérico
df_standardized[[target]] <- as.numeric(df_standardized[[target]])

# Verificações antes da divisão
cat("1) NAs em matched_score: ", sum(is.na(df_standardized[[target]])), "\n")
cat("2) NaNs em matched_score:", sum(is.nan(df_standardized[[target]])), "\n")
cat("3) Coluna matched_score existe?: ", target %in% names(df_standardized), "\n")

# Divisão dos dados em treino (80%) e teste (20%)
index <- caret::createDataPartition(df_standardized[[target]], p=0.8, list=FALSE)
train <- df_standardized[index, ]
test  <- df_standardized[-index, ]

cat("Dimensões do conjunto de treino:", dim(train), "\n")
cat("Dimensões do conjunto de teste:", dim(test), "\n\n")

# Guardar conjuntos de treino e teste padronizados
write.csv(train, "data/train.csv", row.names = FALSE)
write.csv(test, "data/test.csv", row.names = FALSE)
cat("Conjunto de TREINO guardado: 'data/train.csv'\n")
cat("Conjunto de TESTE guardado: 'data/test.csv'\n\n")

# === ETAPA 7: RELATÓRIO FINAL ===
cat("========================================================\n")
cat("              RELATÓRIO DE PADRONIZAÇÃO                \n")
cat("========================================================\n")
cat("Observações totais:", nrow(df_standardized), "\n")
cat("Variáveis totais:", ncol(df_standardized), "\n")
cat("Variáveis preditoras padronizadas:", length(num_cols), "\n")
cat("Variáveis com correção de skewness:", length(skewed_cols), "\n")
cat("Variável target (não padronizada):", target, "\n")
cat("\n")
cat("Arquivos gerados:\n")
cat("  1. data/resume_data_before_standardization.csv (ANTES)\n")
cat("  2. data/yeo_johnson_transforms.rds\n")
cat("  3. data/scaling_parameters.rds\n")
cat("  4. data/resume_data_final_standardized.rds (DEPOIS)\n")
cat("  5. data/resume_data_final_standardized.csv (DEPOIS)\n")
cat("  6. data/train.csv (CONJUNTO DE TREINO PADRONIZADO)\n")
cat("  7. data/test.csv (CONJUNTO DE TESTE PADRONIZADO)\n")
cat("  8. outputs/padronizacao_comparacao.png\n")
cat("\n")
cat("Status:PADRONIZAÇÃO CONCLUÍDA COM SUCESSO!\n")
cat("========================================================\n\n")

# === EXEMPLO: Como aplicar no conjunto de TESTE ===
cat("=== INSTRUÇÕES: Aplicar Padronização no Conjunto de Teste ===\n")
cat("
# Carregar parâmetros salvos
norm_objs <- readRDS('data/yeo_johnson_transforms.rds')
scaling_params <- readRDS('data/scaling_parameters.rds')

# Aplicar transformações Yeo-Johnson (se aplicável)
for(col in names(norm_objs)){
  if(col %in% names(test)){
    test[[col]] <- predict(norm_objs[[col]], test[[col]])
  }
}

# Aplicar padronização Z-score usando parâmetros do TREINO
for(i in 1:nrow(scaling_params)){
  var <- scaling_params$Variable[i]
  if(var %in% names(test)){
    test[[var]] <- (test[[var]] - scaling_params$Mean[i]) / scaling_params$SD[i]
  }
}
\n")
cat("========================================================\n")

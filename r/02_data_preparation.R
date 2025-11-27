########################################################
# === 2. Data Preparation: Tratamento de valores em falta ===
########################################################
# Carregar dependências e definir seed

# Encontrar o diretorio
getwd()
source("r/dependencies.R")

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

cat("\n=== CODIFICAÇÃO DE VARIÁVEIS CATEGÓRICAS ===\n")

# Identificar variáveis categóricas (excluindo o target)
cat_cols <- names(df)[sapply(df, function(x) is.character(x) | is.factor(x))]
cat_cols <- setdiff(cat_cols, target)  # Remover matched_score da lista

cat("Total de variáveis categóricas:", length(cat_cols), "\n\n")

# PASSO 1: Analisar cardinalidade (quantos níveis únicos cada variável tem)
cat("Análise de Cardinalidade:\n")
cat("-------------------------\n")
high_cardinality_vars <- c()

for(col in cat_cols) {
  unique_vals <- length(unique(df[[col]]))
  cat(sprintf("  %-30s : %5d níveis únicos\n", col, unique_vals))
  
  # REDUÇÃO DE CARDINALIDADE (importante para variáveis com muitos níveis)
  # Se uma variável tem >50 categorias únicas, agrupa as menos frequentes
  if(unique_vals > 50) {
    high_cardinality_vars <- c(high_cardinality_vars, col)
    
    # Encontrar as 50 categorias mais frequentes
    freq_table <- table(df[[col]])
    top_levels <- names(sort(freq_table, decreasing = TRUE)[1:50])
    
    # Substituir as restantes por "Other"
    df[[col]] <- ifelse(df[[col]] %in% top_levels, as.character(df[[col]]), "Other")
    df[[col]] <- as.factor(df[[col]])
    
    cat(sprintf("    → REDUZIDO para 51 níveis (top 50 + 'Other')\n"))
  }
}

if(length(high_cardinality_vars) > 0) {
  cat("\n⚠️ Variáveis com alta cardinalidade reduzidas:\n")
  cat(paste("  -", high_cardinality_vars, collapse = "\n"), "\n")
}

cat("\n")

# PASSO 2: Aplicar LABEL ENCODING
cat("Aplicando Label Encoding...\n")
cat("---------------------------\n")

# Criar cópia do dataframe
df_encoded <- df

# Converter cada variável categórica para números inteiros
# Exemplo: ["A", "B", "A", "C"] vira [1, 2, 1, 3]
for(col in cat_cols) {
  df_encoded[[col]] <- as.integer(as.factor(df_encoded[[col]]))
  cat(sprintf("  ✓ %s convertida para inteiros\n", col))
}

cat("\n")
cat("Dimensões após Label Encoding:", nrow(df_encoded), "linhas x", ncol(df_encoded), "colunas\n")
cat("Tamanho em memória:", format(object.size(df_encoded), units = "MB"), "\n")

# Comparação com One-Hot (para referência)
cat("\n📊 Comparação Label vs One-Hot:\n")
cat("  Label Encoding:  ", ncol(df_encoded), "colunas\n")
cat("  One-Hot (estimado): ~", ncol(df_encoded) - length(cat_cols) + sum(sapply(df[cat_cols], function(x) length(unique(x)))), "colunas\n")
cat("\n")

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
# Changes #5: APLICAR PADRONIZAÇÃO CORRETAMENTE
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
# Changes #6: ADICIONAR COMPARAÇÃO LADO A LADO
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

########################################################
# === Aplicar Padronização em Novos Dados de Teste ===
########################################################
# Este script aplica as mesmas transformações do treino
# em novos dados (ex: dados futuros, validação externa)

cat("========================================================\n")
cat("    APLICAÇÃO DE PADRONIZAÇÃO EM DADOS DE TESTE        \n")
cat("========================================================\n\n")

# === PASSO 1: CARREGAR PARÂMETROS SALVOS DO TREINO ===
cat("=== PASSO 1: Carregando Parâmetros do Treino ===\n")

# Carregar objetos de transformação Yeo-Johnson
norm_objs <- readRDS('data/yeo_johnson_transforms.rds')
cat("Transformações Yeo-Johnson carregadas:", length(norm_objs), "variáveis\n")

# Carregar parâmetros de escalonamento (média e desvio padrão)
scaling_params <- readRDS('data/scaling_parameters.rds')
cat("Parâmetros de escalonamento carregados:", nrow(scaling_params), "variáveis\n")

cat("\nPrimeiros 5 parâmetros de escalonamento:\n")
print(head(scaling_params, 5))
cat("\n")

# === PASSO 2: CARREGAR DADOS DE TESTE ===
cat("=== PASSO 2: Carregando Dados de Teste ===\n")

# Opção A: Carregar o conjunto de teste já dividido
test <- read.csv("data/test.csv", stringsAsFactors = FALSE)
cat("Dados de teste carregados:", nrow(test), "linhas x", ncol(test), "colunas\n")

# Opção B: Se tiver novos dados para processar (descomente se necessário)
# test <- read.csv("data/novos_dados.csv", stringsAsFactors = FALSE)
# NOTA: Os novos dados devem ter as MESMAS colunas que os dados de treino!

cat("\n")

# === PASSO 3: VERIFICAÇÕES INICIAIS ===
cat("=== PASSO 3: Verificações de Integridade ===\n")

# Verificar se as colunas necessárias existem
missing_yj_cols <- setdiff(names(norm_objs), names(test))
missing_scale_cols <- setdiff(scaling_params$Variable, names(test))

if(length(missing_yj_cols) > 0) {
  cat("Colunas Yeo-Johnson ausentes no teste:\n")
  print(missing_yj_cols)
}

if(length(missing_scale_cols) > 0) {
  cat("Colunas de escalonamento ausentes no teste:\n")
  print(missing_scale_cols)
}

# Verificar NAs antes do processamento
na_count_before <- sum(is.na(test))
cat("NAs nos dados de teste ANTES do processamento:", na_count_before, "\n\n")

# === PASSO 4: APLICAR TRANSFORMAÇÕES YEO-JOHNSON ===
cat("=== PASSO 4: Aplicando Transformações Yeo-Johnson ===\n")
cat("(Apenas para variáveis que foram transformadas no treino)\n\n")

yj_applied <- 0
for(col in names(norm_objs)){
  if(col %in% names(test)){
    # Verificar se a coluna tem dados válidos
    if(all(is.na(test[[col]]))) {
      cat(sprintf("%-30s | Todos os valores são NA - ignorada\n", col))
      next
    }
    
    # Aplicar a transformação Yeo-Johnson usando o objeto do treino
    test[[col]] <- predict(norm_objs[[col]], test[[col]])
    yj_applied <- yj_applied + 1
    cat(sprintf("%-30s | Transformação aplicada\n", col))
  } else {
    cat(sprintf("%-30s | Coluna não encontrada no teste\n", col))
  }
}

cat("\nResumo Yeo-Johnson:\n")
cat("  - Variáveis transformadas:", yj_applied, "de", length(norm_objs), "\n\n")

# === PASSO 5: APLICAR PADRONIZAÇÃO Z-SCORE ===
cat("=== PASSO 5: Aplicando Padronização Z-Score ===\n")
cat("Usando média e desvio padrão do conjunto de TREINO\n\n")

scaled_applied <- 0
for(i in 1:nrow(scaling_params)){
  var <- scaling_params$Variable[i]
  
  if(var %in% names(test)){
    # Verificar se a coluna tem dados válidos
    if(all(is.na(test[[var]]))) {
      cat(sprintf("%-30s | Todos os valores são NA - ignorada\n", var))
      next
    }
    
    # Aplicar padronização: z = (x - μ) / σ
    mean_train <- scaling_params$Mean[i]
    sd_train <- scaling_params$SD[i]
    
    # Proteção contra divisão por zero
    if(sd_train == 0 || is.na(sd_train)) {
      cat(sprintf("%-30s | SD=0 no treino - ignorada\n", var))
      next
    }
    
    test[[var]] <- (test[[var]] - mean_train) / sd_train
    scaled_applied <- scaled_applied + 1
    cat(sprintf("%-30s | μ=%.3f, σ=%.3f\n", var, mean_train, sd_train))
  } else {
    cat(sprintf("%-30s | Coluna não encontrada no teste\n", var))
  }
}

cat("\nResumo Padronização:\n")
cat("  - Variáveis padronizadas:", scaled_applied, "de", nrow(scaling_params), "\n\n")

# === PASSO 6: DIAGNÓSTICO PÓS-PADRONIZAÇÃO ===
cat("=== PASSO 6: Diagnóstico dos Dados Padronizados ===\n")

# Selecionar apenas as variáveis numéricas padronizadas
num_cols_test <- intersect(scaling_params$Variable, names(test))

if(length(num_cols_test) > 0) {
  stats_test <- data.frame(
    Variable = num_cols_test,
    Mean = sapply(test[num_cols_test], mean, na.rm = TRUE),
    SD = sapply(test[num_cols_test], sd, na.rm = TRUE),
    Min = sapply(test[num_cols_test], min, na.rm = TRUE),
    Max = sapply(test[num_cols_test], max, na.rm = TRUE),
    NAs = sapply(test[num_cols_test], function(x) sum(is.na(x)))
  )
  rownames(stats_test) <- NULL
  
  cat("Estatísticas dos dados de teste padronizados (primeiras 10 variáveis):\n")
  print(head(stats_test, 10))
  cat("\n")
  
  # Verificação de qualidade
  cat("Verificação de Qualidade:\n")
  mean_range <- range(stats_test$Mean[is.finite(stats_test$Mean)])
  sd_range <- range(stats_test$SD[is.finite(stats_test$SD)])
  
  cat("  - Range de médias: [", round(mean_range[1], 3), ",", round(mean_range[2], 3), "]\n")
  cat("  - Range de SDs: [", round(sd_range[1], 3), ",", round(sd_range[2], 3), "]\n")
  cat("  - Total de NAs:", sum(stats_test$NAs), "\n")
  
  # Alerta se as estatísticas estão muito diferentes do esperado
  if(abs(median(stats_test$Mean, na.rm = TRUE)) > 0.5) {
    cat("\n ATENÇÃO: Média mediana do teste está longe de 0!\n")
    cat("   Isto pode indicar que os dados de teste são muito diferentes do treino.\n")
  }
  if(abs(median(stats_test$SD, na.rm = TRUE) - 1) > 0.5) {
    cat("\n ATENÇÃO: SD mediano do teste está longe de 1!\n")
    cat("   Isto pode indicar que os dados de teste são muito diferentes do treino.\n")
  }
} else {
  cat(" Nenhuma variável numérica encontrada para diagnóstico.\n")
}


# === PASSO 7: TRATAMENTO DE NAs REMANESCENTES ===
cat("=== PASSO 7: Verificação Final de NAs ===\n")

na_count_after <- sum(is.na(test))
cat("NAs nos dados de teste DEPOIS do processamento:", na_count_after, "\n")

if(na_count_after > 0) {
  cat("\n Ainda existem", na_count_after, "valores NA!\n")
  cat("Colunas com NAs:\n")
  
  na_summary <- sapply(test, function(x) sum(is.na(x)))
  na_cols <- names(na_summary[na_summary > 0])
  
  for(col in na_cols) {
    cat(sprintf("  - %-30s : %d NAs\n", col, na_summary[col]))
  }
  
  cat("\nRecomendação: Considere imputar estes valores antes da predição.\n")
}

cat("\n")

# === PASSO 8: GUARDAR DADOS PROCESSADOS ===
cat("=== PASSO 8: Guardar Dados de Teste Padronizados ===\n")

# Guardar em RDS (mais eficiente)
saveRDS(test, "data/test_padronizado.rds")
cat(" Dados guardados (RDS): 'data/test_padronizado.rds'\n")

# Guardar em CSV (para inspeção manual)
write.csv(test, "data/test_padronizado.csv", row.names = FALSE)
cat("Dados guardados (CSV): 'data/test_padronizado.csv'\n")

cat("Tamanho final:", format(object.size(test), units = "MB"), "\n\n")

# === RELATÓRIO FINAL ===
cat("========================================================\n")
cat("              RELATÓRIO DE PROCESSAMENTO                \n")
cat("========================================================\n")
cat("Dados de teste processados:", nrow(test), "linhas x", ncol(test), "colunas\n")
cat("Transformações Yeo-Johnson aplicadas:", yj_applied, "variáveis\n")
cat("Padronizações Z-score aplicadas:", scaled_applied, "variáveis\n")
cat("NAs finais:", na_count_after, "\n")
cat("\n")
cat("Status: PROCESSAMENTO CONCLUÍDO!\n")
cat("Os dados estão prontos para predição.\n")
cat("========================================================\n\n")

# === EXEMPLO DE USO PARA PREDIÇÃO ===
cat("=== EXEMPLO: Como Usar os Dados Padronizados ===\n")
cat("
# Carregar dados padronizados
test_padronizado <- readRDS('data/test_padronizado.rds')

# Carregar modelo treinado (exemplo)
# modelo <- readRDS('models/modelo_random_forest.rds')

# Fazer predições
# predicoes <- predict(modelo, newdata = test_padronizado)

# Avaliar resultados
# if('matched_score' %in% names(test_padronizado)) {
#   rmse <- sqrt(mean((predicoes - test_padronizado$matched_score)^2))
#   cat('RMSE:', rmse, '\\n')
# }
\n")
cat("========================================================\n")


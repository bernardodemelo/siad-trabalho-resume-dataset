########################################################
# === 2B. Data Preparation MELHORADO: Features Compostas ===
########################################################
# ESTRATÉGIA: Criar features compostas entre variáveis relacionadas
# para preservar MÁXIMO de informação antes de tratar valores vazios

source("r/dependencies.R")

cat("========================================================\n")
cat("  DATA PREPARATION MELHORADO - Features Compostas      \n")
cat("========================================================\n\n")

# Carregar dataset original
df <- read.csv("data/resume_data.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)

cat("Dimensões iniciais:", nrow(df), "linhas x", ncol(df), "colunas\n\n")

# ============================================================
# FASE 1: CRIAR FEATURES COMPOSTAS (ANTES DE IMPUTAR)
# ============================================================
cat("=== FASE 1: Criando Features Compostas ===\n\n")

# 1. Skills Composite Score
# Combina skills + related_skills_in_job + skills_required
cat("1. Skills Composite Score...\n")
df$skills_composite <- 0

# Contar skills do candidato
df$skills_count_candidate <- sapply(df$skills, function(x){
  if(is.na(x) || x == "" || x == "N/A") return(0)
  x <- gsub("\\[|\\]|'|\"", "", x)
  length(unlist(strsplit(x, ",")))
})

# Contar related skills in job (se existir coluna)
if("related_skills_in_job" %in% names(df)) {
  df$skills_count_job <- sapply(df$related_skills_in_job, function(x){
    if(is.na(x) || x == "" || x == "N/A") return(0)
    x <- gsub("\\[|\\]|'|\"", "", x)
    length(unlist(strsplit(x, ",")))
  })
} else {
  df$skills_count_job <- 0
}

# Contar skills required (se existir coluna)
if("skills_required" %in% names(df)) {
  df$skills_count_required <- sapply(df$skills_required, function(x){
    if(is.na(x) || x == "" || x == "N/A") return(0)
    x <- gsub("\\[|\\]|'|\"", "", x)
    length(unlist(strsplit(x, ",")))
  })
} else {
  df$skills_count_required <- 0
}

# Score composto: média ponderada
# Peso maior para skills_required (mais importante)
df$skills_composite <- (df$skills_count_candidate * 1 + 
                        df$skills_count_job * 1.5 + 
                        df$skills_count_required * 2) / 4.5

cat("   ✓ Skills composite: candidate (", mean(df$skills_count_candidate), ") + job (", 
    mean(df$skills_count_job), ") + required (", mean(df$skills_count_required), ")\n")

# 2. Education Match Score
# Combina degree_names + major_field_of_studies + educational_requirements
cat("\n2. Education Match Score...\n")

df$education_completeness <- 0
if("degree_names" %in% names(df)) {
  df$education_completeness <- df$education_completeness + 
    ifelse(!is.na(df$degree_names) & df$degree_names != "" & df$degree_names != "N/A", 1, 0)
}
if("major_field_of_studies" %in% names(df)) {
  df$education_completeness <- df$education_completeness + 
    ifelse(!is.na(df$major_field_of_studies) & df$major_field_of_studies != "" & df$major_field_of_studies != "N/A", 1, 0)
}
if("educational_requirements" %in% names(df)) {
  df$education_completeness <- df$education_completeness + 
    ifelse(!is.na(df$educational_requirements) & df$educational_requirements != "" & df$educational_requirements != "N/A", 1, 0)
}

# Normalizar para 0-1
df$education_match_score <- df$education_completeness / 3

cat("   ✓ Education match: média de completude =", round(mean(df$education_match_score), 3), "\n")

# 3. Responsibilities Match
# Combina responsibilities com responsibilities.1
cat("\n3. Responsibilities Composite...\n")

if("responsibilities" %in% names(df)) {
  df$resp_word_count_candidate <- sapply(df$responsibilities, function(x){
    if(is.na(x) || x == "" || x == "N/A") return(0)
    length(unlist(strsplit(as.character(x), "\\s+")))
  })
} else {
  df$resp_word_count_candidate <- 0
}

if("responsibilities.1" %in% names(df)){
  df$resp_word_count_job <- sapply(df$responsibilities.1, function(x){
    if(is.na(x) || x == "" || x == "N/A") return(0)
    length(unlist(strsplit(as.character(x), "\\s+")))
  })
} else {
  df$resp_word_count_job <- 0
}

# Score composto: soma ponderada
df$responsibilities_composite <- df$resp_word_count_candidate * 0.4 + 
                                 df$resp_word_count_job * 0.6

cat("   ✓ Responsibilities: candidate (", mean(df$resp_word_count_candidate), 
    " palavras) + job (", mean(df$resp_word_count_job), " palavras)\n")

# 4. Position Match Indicator
# Combina positions com X.job_position_name
cat("\n4. Position Match Indicator...\n")

df$position_filled <- 0
if("positions" %in% names(df)) {
  df$position_filled <- df$position_filled + 
    ifelse(!is.na(df$positions) & df$positions != "" & df$positions != "N/A", 1, 0)
}
if("X.job_position_name" %in% names(df)) {
  df$position_filled <- df$position_filled + 
    ifelse(!is.na(df$X.job_position_name) & df$X.job_position_name != "" & df$X.job_position_name != "N/A", 1, 0)
}

# Normalizar
df$position_match_indicator <- df$position_filled / 2

cat("   ✓ Position indicator: média =", round(mean(df$position_match_indicator), 3), "\n")

# 5. Experience Score Composite
# Combina start_dates + end_dates + experiencete_requirements
cat("\n5. Experience Score Composite...\n")

df$experience_data_available <- 0
if("start_dates" %in% names(df)) {
  df$experience_data_available <- df$experience_data_available + 
    ifelse(!is.na(df$start_dates) & df$start_dates != "" & df$start_dates != "N/A", 1, 0)
}
if("end_dates" %in% names(df)) {
  df$experience_data_available <- df$experience_data_available + 
    ifelse(!is.na(df$end_dates) & df$end_dates != "" & df$end_dates != "N/A", 1, 0)
}
if("experiencete_requirements" %in% names(df)) {
  df$experience_data_available <- df$experience_data_available + 
    ifelse(!is.na(df$experiencete_requirements) & df$experiencete_requirements != "" & df$experiencete_requirements != "N/A", 1, 0)
}

# Normalizar
df$experience_composite <- df$experience_data_available / 3

cat("   ✓ Experience composite: média =", round(mean(df$experience_composite), 3), "\n")

# 6. Profile Completeness Score (META-FEATURE)
cat("\n6. Profile Completeness Score...\n")

# Conta quantos campos importantes estão preenchidos
df$profile_completeness <- rowMeans(data.frame(
  df$skills_composite > 0,
  df$education_match_score > 0,
  df$responsibilities_composite > 0,
  df$position_match_indicator > 0,
  df$experience_composite > 0
))

cat("   ✓ Profile completeness: média =", round(mean(df$profile_completeness), 3), "\n")

cat("\n[INFO] 6 features compostas criadas com sucesso!\n\n")

# ============================================================
# FASE 2: AGORA SIM, TRATAR VALORES EM FALTA
# ============================================================
cat("=== FASE 2: Tratamento de Valores em Falta ===\n\n")

# Função para calcular moda
tab_mode <- function(x) {
  ux <- na.omit(unique(x))
  if(length(ux) == 0) return(NA)
  ux[which.max(tabulate(match(x, ux)))]
}

# 1. Remover colunas com >50% missing
na_perc <- sapply(df, function(x) mean(is.na(x) | x == "N/A" | x == "None" | x == ""))
cols_to_remove <- names(df)[na_perc > 0.5]

if(length(cols_to_remove) > 0) {
  cat("Removendo", length(cols_to_remove), "colunas com >50% missing:\n")
  cat(paste("  -", cols_to_remove, collapse = "\n"), "\n\n")
  df <- df[, na_perc <= 0.5]
}

# 2. Imputar valores restantes
cat("Imputando valores em falta...\n")
for(col in names(df)) {
  if(is.numeric(df[[col]])) {
    # Mediana para numéricas
    if(any(is.na(df[[col]]))) {
      med <- median(df[[col]], na.rm = TRUE)
      n_missing <- sum(is.na(df[[col]]))
      df[[col]][is.na(df[[col]])] <- med
      cat("  ✓", col, ":", n_missing, "valores imputados com mediana\n")
    }
  } else {
    # Moda para categóricas
    temp_col <- as.character(df[[col]])
    missing_mask <- is.na(temp_col) | temp_col == "N/A" | temp_col == "None" | temp_col == ""
    if(any(missing_mask)) {
      moda <- tab_mode(temp_col[!missing_mask])
      n_missing <- sum(missing_mask)
      temp_col[missing_mask] <- moda
      df[[col]] <- temp_col
      cat("  ✓", col, ":", n_missing, "valores imputados com moda\n")
    }
  }
}

# ============================================================
# FASE 3: FEATURE ENGINEERING ADICIONAL
# ============================================================
cat("\n=== FASE 3: Feature Engineering ===\n\n")

# 1. Contagem de palavras em career objective
if("career_objective" %in% names(df)) {
  df$career_word_count <- sapply(df$career_objective, function(x){
    if(is.na(x) || x == "") return(0)
    length(unlist(strsplit(as.character(x), "\\s+")))
  })
} else {
  df$career_word_count <- 0
}

# 2. Tamanho total do perfil
df$text_length_total <- apply(df, 1, function(row){
  nchar(paste(row, collapse=" "))
})

# 3. Extrair idade min/max de age_requirement (se existir)
if("age_requirement" %in% names(df)) {
  df$age_min <- as.numeric(str_extract(df$age_requirement, "\\d{2}"))
  df$age_max <- as.numeric(str_extract(df$age_requirement, "(?<=to )\\d{2}"))
  df$age_range <- df$age_max - df$age_min
  # Imputar NAs criados
  df$age_min[is.na(df$age_min)] <- median(df$age_min, na.rm = TRUE)
  df$age_max[is.na(df$age_max)] <- median(df$age_max, na.rm = TRUE)
  df$age_range[is.na(df$age_range)] <- median(df$age_range, na.rm = TRUE)
}

cat("✓ Features de contagem criadas\n")
cat("✓ Features de idade extraídas\n\n")

# ============================================================
# FASE 4: ENCODING E TRATAMENTO DE OUTLIERS
# ============================================================
cat("=== FASE 4: Encoding e Outliers ===\n\n")

# Converter categóricas para factor
cat_cols <- names(df)[sapply(df, function(x) is.character(x))]
target <- "matched_score"
cat_cols <- setdiff(cat_cols, target)

df[cat_cols] <- lapply(df[cat_cols], factor)

# Reduzir cardinalidade alta (>50 níveis)
for(col in cat_cols) {
  unique_vals <- length(unique(df[[col]]))
  if(unique_vals > 50) {
    freq_table <- table(df[[col]])
    top_levels <- names(sort(freq_table, decreasing = TRUE)[1:50])
    df[[col]] <- ifelse(df[[col]] %in% top_levels, as.character(df[[col]]), "Other")
    df[[col]] <- as.factor(df[[col]])
    cat("  ✓", col, "reduzido de", unique_vals, "para 51 níveis\n")
  }
}

# Label encoding
df_encoded <- df
for(col in cat_cols) {
  df_encoded[[col]] <- as.integer(as.factor(df_encoded[[col]]))
}

cat("\n✓ Label encoding aplicado\n")

# Remover outliers (exceto target)
remove_outliers <- function(x) {
  q1 <- quantile(x, 0.25, na.rm = TRUE)
  q3 <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  x[x < (q1 - 1.5 * iqr) | x > (q3 + 1.5 * iqr)] <- NA
  return(x)
}

num_cols <- names(df_encoded)[sapply(df_encoded, is.numeric)]
num_cols_no_target <- setdiff(num_cols, target)

df_encoded[num_cols_no_target] <- lapply(df_encoded[num_cols_no_target], remove_outliers)

# Reimputar NAs criados por outliers
for(col in num_cols_no_target) {
  if(any(is.na(df_encoded[[col]]))) {
    med <- median(df_encoded[[col]], na.rm = TRUE)
    df_encoded[[col]][is.na(df_encoded[[col]])] <- med
  }
}

cat("✓ Outliers removidos e reimputados\n\n")

# ============================================================
# FASE 5: PADRONIZAÇÃO COM YEO-JOHNSON
# ============================================================
cat("=== FASE 5: Padronização ===\n\n")

# Aplicar Yeo-Johnson para correção de skewness
num_cols_for_transform <- setdiff(num_cols, target)

yj_list <- list()
for(col in num_cols_for_transform) {
  if(sd(df_encoded[[col]], na.rm = TRUE) > 0) {
    yj_obj <- bestNormalize::yeojohnson(df_encoded[[col]])
    df_encoded[[col]] <- yj_obj$x.t
    yj_list[[col]] <- yj_obj
  }
}

saveRDS(yj_list, "data/yeo_johnson_transforms_improved.rds")
cat("✓ Transformações Yeo-Johnson aplicadas e guardadas\n")

# Padronização (scale)
scaling_params <- list()
for(col in num_cols_no_target) {
  mean_val <- mean(df_encoded[[col]], na.rm = TRUE)
  sd_val <- sd(df_encoded[[col]], na.rm = TRUE)
  
  if(sd_val > 0) {
    df_encoded[[col]] <- (df_encoded[[col]] - mean_val) / sd_val
    scaling_params[[col]] <- list(mean = mean_val, sd = sd_val)
  }
}

saveRDS(scaling_params, "data/scaling_parameters_improved.rds")
cat("✓ Padronização aplicada e parâmetros guardados\n\n")

# ============================================================
# FASE 6: DIVISÃO TREINO/TESTE E GUARDAR
# ============================================================
cat("=== FASE 6: Divisão e Salvamento ===\n\n")

set.seed(42)
train_idx <- createDataPartition(df_encoded[[target]], p = 0.8, list = FALSE)

train <- df_encoded[train_idx, ]
test <- df_encoded[-train_idx, ]

# Guardar ficheiros
write.csv(df_encoded, "data/resume_data_final_standardized_improved.csv", row.names = FALSE)
write.csv(train, "data/train_improved.csv", row.names = FALSE)
write.csv(test, "data/test_improved.csv", row.names = FALSE)

saveRDS(df_encoded, "data/resume_data_final_standardized_improved.rds")

cat("========================================================\n")
cat("                  RESUMO FINAL                          \n")
cat("========================================================\n")
cat("Dataset final:\n")
cat("  - Linhas:", nrow(df_encoded), "\n")
cat("  - Colunas:", ncol(df_encoded), "\n")
cat("  - Features compostas criadas: 6\n")
cat("  - Treino:", nrow(train), "| Teste:", nrow(test), "\n")
cat("\nFicheiros guardados:\n")
cat("  ✓ data/resume_data_final_standardized_improved.csv\n")
cat("  ✓ data/train_improved.csv\n")
cat("  ✓ data/test_improved.csv\n")
cat("  ✓ data/yeo_johnson_transforms_improved.rds\n")
cat("  ✓ data/scaling_parameters_improved.rds\n")
cat("========================================================\n")

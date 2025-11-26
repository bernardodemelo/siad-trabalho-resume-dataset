########################################################
# === 5. Deployment: Função de Previsão e Integração ===
########################################################

# Carregar dependências
source("r/dependencies.R")

cat("========================================================\n")
cat("              DEPLOYMENT - MODELO FINAL                 \n")
cat("========================================================\n\n")

# ============================================================================
# FUNÇÃO DE PREVISÃO
# ============================================================================
# Esta função permite fazer previsões para novos dados
# IMPORTANTE: Os novos dados devem ter as mesmas variáveis que o dataset original
# e devem passar pelo mesmo processo de preparação (padronização, etc.)
# ============================================================================

prever_score <- function(novo_dado, caminho_modelo = "modelo_final.rds") {
  #'
  #' Função para prever matched_score para novos dados
  #'
  #' @param novo_dado data.frame ou data.table com as mesmas variáveis do dataset original
  #' @param caminho_modelo caminho para o ficheiro do modelo treinado (default: "modelo_final.rds")
  #' @return vetor com as previsões de matched_score
  #'
  #' @examples
  #' # Carregar um novo registo
  #' novo_registo <- read.csv("novo_dado.csv")
  #' # Fazer previsão
  #' previsao <- prever_score(novo_registo)
  #'
  
  # Carregar modelo
  if(!file.exists(caminho_modelo)) {
    stop(paste("Ficheiro do modelo não encontrado:", caminho_modelo))
  }
  
  modelo <- readRDS(caminho_modelo)
  cat("Modelo carregado:", caminho_modelo, "\n")
  
  # Verificar se os dados precisam de preparação
  # NOTA: Em produção, os novos dados devem passar pelo mesmo processo
  # de preparação usado no treino (padronização, transformações, etc.)
  
  # Fazer previsão
  previsoes <- predict(modelo, newdata = novo_dado)
  
  cat("Previsões geradas:", length(previsoes), "valores\n")
  
  return(previsoes)
}

# ============================================================================
# FUNÇÃO DE PREVISÃO COM PREPARAÇÃO COMPLETA
# ============================================================================
# Esta função aplica todo o pipeline de preparação antes de fazer a previsão
# ============================================================================

prever_score_completo <- function(novo_dado_raw, 
                                   caminho_modelo = "modelo_final.rds",
                                   caminho_transforms = "data/yeo_johnson_transforms.rds",
                                   caminho_scaling = "data/scaling_parameters.rds") {
  #'
  #' Função completa que prepara os dados e faz previsão
  #' Aplica as mesmas transformações usadas no treino
  #'
  #' @param novo_dado_raw data.frame com dados brutos (sem preparação)
  #' @param caminho_modelo caminho para o modelo
  #' @param caminho_transforms caminho para transformações Yeo-Johnson
  #' @param caminho_scaling caminho para parâmetros de padronização
  #' @return vetor com previsões
  #'
  
  cat("=== Preparação de Dados para Previsão ===\n")
  
  # 1. Carregar transformações e parâmetros
  if(file.exists(caminho_transforms)) {
    norm_objs <- readRDS(caminho_transforms)
    cat("Transformações Yeo-Johnson carregadas\n")
  } else {
    norm_objs <- NULL
    cat("Aviso: Transformações Yeo-Johnson não encontradas\n")
  }
  
  if(file.exists(caminho_scaling)) {
    scaling_params <- readRDS(caminho_scaling)
    cat("Parâmetros de padronização carregados\n")
  } else {
    stop("Parâmetros de padronização não encontrados!")
  }
  
  # 2. Preparar dados (aplicar mesmas transformações do treino)
  novo_dado <- novo_dado_raw
  
  # Aplicar transformações Yeo-Johnson (se existirem)
  if(!is.null(norm_objs)) {
    for(col in names(norm_objs)) {
      if(col %in% names(novo_dado)) {
        novo_dado[[col]] <- predict(norm_objs[[col]], novo_dado[[col]])
      }
    }
  }
  
  # Aplicar padronização Z-score usando parâmetros do treino
  for(i in 1:nrow(scaling_params)) {
    var <- scaling_params$Variable[i]
    if(var %in% names(novo_dado)) {
      novo_dado[[var]] <- (novo_dado[[var]] - scaling_params$Mean[i]) / scaling_params$SD[i]
    }
  }
  
  cat("Dados preparados\n\n")
  
  # 3. Fazer previsão
  previsoes <- prever_score(novo_dado, caminho_modelo)
  
  return(previsoes)
}

# ============================================================================
# TESTE DA FUNÇÃO DE PREVISÃO
# ============================================================================

cat("=== Teste da Função de Previsão ===\n")

# Carregar alguns dados de teste para demonstrar
if(file.exists("data/test.csv")) {
  test_sample <- read.csv("data/test.csv")
  
  # Pegar apenas algumas linhas para teste
  if(nrow(test_sample) > 0) {
    test_sample_small <- test_sample[1:min(5, nrow(test_sample)), ]
    
    # Remover a coluna target para simular novos dados
    if("matched_score" %in% names(test_sample_small)) {
      test_sample_small$matched_score <- NULL
    }
    
    cat("A testar previsão com", nrow(test_sample_small), "registos de exemplo...\n")
    
    # Fazer previsão (assumindo que os dados já estão preparados)
    tryCatch({
      previsoes_teste <- prever_score(test_sample_small)
      cat("Previsões de teste geradas com sucesso!\n")
      cat("Valores previstos (primeiros 5):", paste(round(head(previsoes_teste, 5), 2), collapse = ", "), "\n\n")
    }, error = function(e) {
      cat("Erro ao testar previsão:", e$message, "\n")
      cat("(Isto é normal se os dados precisarem de preparação adicional)\n\n")
    })
  }
} else {
  cat("Ficheiro de teste não encontrado. Função criada mas não testada.\n\n")
}

# ============================================================================
# DOCUMENTAÇÃO DE INTEGRAÇÃO
# ============================================================================

cat("========================================================\n")
cat("         FORMAS DE INTEGRAÇÃO DO MODELO                 \n")
cat("========================================================\n\n")

cat("1. INTEGRAÇÃO EM R SCRIPT\n")
cat("   - Usar a função prever_score() ou prever_score_completo()\n")
cat("   - Carregar novos dados e aplicar a função\n\n")

cat("2. API REST (usando plumber)\n")
cat("   # Criar ficheiro api.R:\n")
cat("   #* @post /predict\n")
cat("   #* @param data:data.frame\n")
cat("   function(data) {\n")
cat("     source('R/05_deployment.R')\n")
cat("     prever_score_completo(data)\n")
cat("   }\n")
cat("   # Executar: plumber::plumb('api.R')$run(port=8000)\n\n")

cat("3. SHINY APP (Dashboard Interativo)\n")
cat("   - Criar interface Shiny para upload de dados\n")
cat("   - Usar a função de previsão no servidor\n")
cat("   - Mostrar resultados em gráficos e tabelas\n\n")

cat("4. BATCH PROCESSING\n")
cat("   - Processar ficheiros CSV em lote\n")
cat("   - Guardar previsões em ficheiro de saída\n\n")

cat("5. INTEGRAÇÃO COM BANCOS DE DADOS\n")
cat("   - Conectar a base de dados (PostgreSQL, MySQL, etc.)\n")
cat("   - Ler novos registos periodicamente\n")
cat("   - Fazer previsões e guardar resultados\n\n")

cat("========================================================\n")
cat("              DEPLOYMENT CONCLUÍDO                      \n")
cat("========================================================\n\n")

cat("Ficheiros importantes:\n")
cat("  - modelo_final.rds: Modelo treinado\n")
cat("  - data/yeo_johnson_transforms.rds: Transformações aplicadas\n")
cat("  - data/scaling_parameters.rds: Parâmetros de padronização\n")
cat("  - R/05_deployment.R: Funções de previsão\n\n")

cat("Para usar o modelo:\n")
cat("  source('R/05_deployment.R')\n")
cat("  previsoes <- prever_score(novos_dados)\n\n")


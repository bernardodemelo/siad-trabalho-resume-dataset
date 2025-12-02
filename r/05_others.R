########################################################
# === 6. Others: Modelo final e função de previsão ===
########################################################

# Carregar dependências
source("r/dependencies.R")

cat("========================================================\n")
cat("         MODELO FINAL E FUNÇÃO DE PREVISÃO              \n")
cat("========================================================\n\n")

# -----------------------------------------------------
# 1. Guardar o modelo final
# -----------------------------------------------------
# NOTA: O modelo já foi guardado no script 03_modeling.R
# Este código serve como referência para guardar qualquer modelo

# Exemplo de como guardar um modelo manualmente:
# saveRDS(modelo_final, file = "modelo_final.rds")

cat("[INFO] O modelo final já foi guardado em 'modelo_final.rds'\n")
cat("[INFO] Este ficheiro foi gerado pelo script 03_modeling.R\n\n")

# -----------------------------------------------------
# 2. Função de previsão para novos dados
# -----------------------------------------------------

#' Prever matched_score para novos dados
#' 
#' Esta função carrega o modelo treinado e faz previsões para novos dados.
#' Os dados devem ter a mesma estrutura (variáveis) do dataset de treino.
#' 
#' @param novo_dado Data frame com os novos dados para previsão
#' @param modelo_path Caminho para o ficheiro .rds do modelo (padrão: "modelo_final.rds")
#' @return Vetor numérico com as previsões do matched_score
#' @examples
#' # Exemplo de uso:
#' # novos_dados <- read.csv("novos_dados.csv")
#' # previsoes <- prever_score(novos_dados)
prever_score <- function(novo_dado, modelo_path = "modelo_final.rds") {
  
  # Validações básicas
  if(!file.exists(modelo_path)) {
    stop("Erro: O ficheiro do modelo não foi encontrado em: ", modelo_path)
  }
  
  if(!is.data.frame(novo_dado)) {
    stop("Erro: novo_dado deve ser um data frame")
  }
  
  # Carregar o modelo
  cat("[INFO] A carregar modelo de:", modelo_path, "\n")
  modelo <- readRDS(modelo_path)
  
  # Carregar parâmetros de padronização
  if(file.exists("data/scaling_parameters.rds")) {
    cat("[INFO] A carregar parâmetros de padronização...\n")
    scaling_params <- readRDS("data/scaling_parameters.rds")
    
    # Aplicar transformações Yeo-Johnson
    if(file.exists("data/yeo_johnson_transforms.rds")) {
      yj_transforms <- readRDS("data/yeo_johnson_transforms.rds")
      cat("[INFO] A aplicar transformações Yeo-Johnson...\n")
      
      # Aplicar cada transformação usando a função yeojohnson do bestNormalize
      for(var_name in names(yj_transforms)) {
        if(var_name %in% names(novo_dado)) {
          transform_obj <- yj_transforms[[var_name]]
          lambda <- transform_obj$lambda
          
          # Aplicar transformação Yeo-Johnson manualmente
          x <- novo_dado[[var_name]]
          if(lambda != 0) {
            x_pos <- ifelse(x >= 0, ((x + 1)^lambda - 1) / lambda, NA)
            x_neg <- ifelse(x < 0, -((-x + 1)^(2 - lambda) - 1) / (2 - lambda), NA)
            novo_dado[[var_name]] <- ifelse(x >= 0, x_pos, x_neg)
          } else {
            novo_dado[[var_name]] <- ifelse(x >= 0, log(x + 1), -log(-x + 1))
          }
        }
      }
    }
    
    # Padronizar variáveis numéricas
    cat("[INFO] A padronizar variáveis...\n")
    for(var in names(scaling_params)) {
      if(var %in% names(novo_dado)) {
        novo_dado[[var]] <- (novo_dado[[var]] - scaling_params[[var]]$mean) / 
                            scaling_params[[var]]$sd
      }
    }
  } else {
    warning("Parâmetros de padronização não encontrados. As previsões podem ser imprecisas.")
  }
  
  # Fazer previsões
  cat("[INFO] A gerar previsões...\n")
  previsoes <- predict(modelo, newdata = novo_dado)
  
  cat("[INFO]", length(previsoes), "previsões geradas com sucesso\n")
  
  return(previsoes)
}

# -----------------------------------------------------
# 3. Função de previsão com avaliação de desvios
# -----------------------------------------------------

#' Prever matched_score e avaliar desvios em relação aos valores reais
#' 
#' Esta função faz previsões e calcula métricas de erro quando os valores
#' reais estão disponíveis, permitindo avaliar a qualidade das previsões.
#' 
#' @param novo_dado Data frame com os novos dados para previsão
#' @param valores_reais Vetor numérico com os valores reais de matched_score (opcional)
#' @param modelo_path Caminho para o ficheiro .rds do modelo (padrão: "modelo_final.rds")
#' @param mostrar_grafico Lógico indicando se deve gerar gráficos de análise (padrão: TRUE)
#' @return Lista contendo previsões, métricas e análise de desvios
#' @examples
#' # Com valores reais para avaliação:
#' # resultado <- prever_e_avaliar(novos_dados, valores_reais = test$matched_score)
#' # print(resultado$metricas)
prever_e_avaliar <- function(novo_dado, valores_reais = NULL, 
                              modelo_path = "modelo_final.rds",
                              mostrar_grafico = TRUE) {
  
  # Fazer previsões usando a função base
  cat("\n========================================================\n")
  cat("         PREVISÃO COM AVALIAÇÃO DE DESVIOS              \n")
  cat("========================================================\n\n")
  
  previsoes <- prever_score(novo_dado, modelo_path)
  
  resultado <- list(
    previsoes = previsoes,
    metricas = NULL,
    desvios = NULL,
    resumo_desvios = NULL
  )
  
  # Se valores reais foram fornecidos, calcular métricas e desvios
  if(!is.null(valores_reais)) {
    
    if(length(valores_reais) != length(previsoes)) {
      stop("Erro: O número de valores reais (", length(valores_reais), 
           ") não corresponde ao número de previsões (", length(previsoes), ")")
    }
    
    cat("\n=== Análise de Desvios ===\n")
    
    # Calcular desvios (erros)
    desvios <- previsoes - valores_reais
    desvios_abs <- abs(desvios)
    desvios_perc <- (desvios / valores_reais) * 100
    
    # Calcular métricas de erro
    metricas <- data.frame(
      Metrica = c("RMSE", "MAE", "MAPE (%)", "R²", "Correlação"),
      Valor = c(
        sqrt(mean(desvios^2)),
        mean(desvios_abs),
        mean(abs(desvios_perc), na.rm = TRUE),
        cor(previsoes, valores_reais)^2,
        cor(previsoes, valores_reais)
      )
    )
    metricas$Valor <- round(metricas$Valor, 4)
    
    cat("\nMétricas de Desempenho:\n")
    print(metricas, row.names = FALSE)
    
    # Estatísticas dos desvios
    resumo_desvios <- data.frame(
      Estatistica = c("Mínimo", "Q1", "Mediana", "Média", "Q3", "Máximo", "Desvio Padrão"),
      Desvio_Absoluto = round(c(
        min(desvios_abs),
        quantile(desvios_abs, 0.25),
        median(desvios_abs),
        mean(desvios_abs),
        quantile(desvios_abs, 0.75),
        max(desvios_abs),
        sd(desvios_abs)
      ), 4),
      Desvio_Real = round(c(
        min(desvios),
        quantile(desvios, 0.25),
        median(desvios),
        mean(desvios),
        quantile(desvios, 0.75),
        max(desvios),
        sd(desvios)
      ), 4)
    )
    
    cat("\nResumo dos Desvios:\n")
    print(resumo_desvios, row.names = FALSE)
    
    # Identificar casos com maior desvio
    n_piores <- min(10, length(desvios))
    idx_piores <- order(desvios_abs, decreasing = TRUE)[1:n_piores]
    
    cat("\nTop", n_piores, "casos com maior desvio absoluto:\n")
    casos_piores <- data.frame(
      Indice = idx_piores,
      Real = round(valores_reais[idx_piores], 4),
      Previsto = round(previsoes[idx_piores], 4),
      Desvio = round(desvios[idx_piores], 4),
      Desvio_Abs = round(desvios_abs[idx_piores], 4),
      Desvio_Perc = round(desvios_perc[idx_piores], 2)
    )
    print(casos_piores, row.names = FALSE)
    
    # Gerar gráficos se solicitado
    if(mostrar_grafico) {
      cat("\n[INFO] A gerar gráficos de análise...\n")
      
      # Criar diretório para gráficos se não existir
      if(!dir.exists("results")) {
        dir.create("results")
      }
      
      # Gráfico 1: Valores Reais vs Previstos
      png("results/previsao_vs_real.png", width = 800, height = 600)
      par(mfrow = c(2, 2), mar = c(4, 4, 3, 2))
      
      # Scatter plot
      plot(valores_reais, previsoes, 
           main = "Valores Reais vs Previstos",
           xlab = "Valores Reais", ylab = "Valores Previstos",
           pch = 16, col = rgb(0, 0, 1, 0.5))
      abline(0, 1, col = "red", lwd = 2, lty = 2)
      grid()
      
      # Distribuição dos desvios
      hist(desvios, breaks = 30, col = "lightblue", border = "white",
           main = "Distribuição dos Desvios",
           xlab = "Desvio (Previsto - Real)", ylab = "Frequência")
      abline(v = 0, col = "red", lwd = 2, lty = 2)
      abline(v = mean(desvios), col = "blue", lwd = 2)
      legend("topright", legend = c("Zero", "Média"), 
             col = c("red", "blue"), lty = c(2, 1), lwd = 2)
      
      # Boxplot dos desvios absolutos
      boxplot(desvios_abs, horizontal = TRUE, col = "lightgreen",
              main = "Boxplot dos Desvios Absolutos",
              xlab = "Desvio Absoluto")
      
      # Desvios ao longo das observações
      plot(seq_along(desvios), desvios, type = "h", col = "darkblue",
           main = "Desvios por Observação",
           xlab = "Índice da Observação", ylab = "Desvio")
      abline(h = 0, col = "red", lwd = 2, lty = 2)
      abline(h = c(mean(desvios) - sd(desvios), mean(desvios) + sd(desvios)), 
             col = "orange", lty = 2)
      
      dev.off()
      cat("[INFO] Gráfico guardado: results/previsao_vs_real.png\n")
      
      # Gráfico 2: Análise de Resíduos
      png("results/analise_residuos.png", width = 800, height = 600)
      par(mfrow = c(2, 2), mar = c(4, 4, 3, 2))
      
      # Q-Q plot
      qqnorm(desvios, main = "Q-Q Plot dos Desvios", pch = 16, col = rgb(0, 0, 1, 0.5))
      qqline(desvios, col = "red", lwd = 2)
      
      # Desvios vs Valores Previstos
      plot(previsoes, desvios, 
           main = "Desvios vs Valores Previstos",
           xlab = "Valores Previstos", ylab = "Desvios",
           pch = 16, col = rgb(0, 0, 1, 0.5))
      abline(h = 0, col = "red", lwd = 2, lty = 2)
      grid()
      
      # Desvios vs Valores Reais
      plot(valores_reais, desvios, 
           main = "Desvios vs Valores Reais",
           xlab = "Valores Reais", ylab = "Desvios",
           pch = 16, col = rgb(0, 0, 1, 0.5))
      abline(h = 0, col = "red", lwd = 2, lty = 2)
      grid()
      
      # Scale-Location plot
      plot(previsoes, sqrt(abs(desvios)), 
           main = "Scale-Location Plot",
           xlab = "Valores Previstos", ylab = "√|Desvios|",
           pch = 16, col = rgb(0, 0, 1, 0.5))
      abline(h = mean(sqrt(abs(desvios))), col = "red", lwd = 2, lty = 2)
      grid()
      
      dev.off()
      cat("[INFO] Gráfico guardado: results/analise_residuos.png\n")
    }
    
    # Adicionar resultados à lista de retorno
    resultado$metricas <- metricas
    resultado$desvios <- data.frame(
      Real = valores_reais,
      Previsto = previsoes,
      Desvio = desvios,
      Desvio_Abs = desvios_abs,
      Desvio_Perc = desvios_perc
    )
    resultado$resumo_desvios <- resumo_desvios
    
  } else {
    cat("\n[INFO] Valores reais não fornecidos. Apenas previsões disponíveis.\n")
  }
  
  cat("\n========================================================\n")
  
  return(invisible(resultado))
}

# -----------------------------------------------------
# 4. Exemplo de uso das funções
# -----------------------------------------------------

cat("\n=== Exemplo de Uso ===\n\n")
cat("Função 1: Previsão simples\n")
cat("---------------------------\n")
cat("# 1. Carregar novos dados\n")
cat("novos_dados <- read.csv('caminho/para/novos_dados.csv')\n\n")
cat("# 2. Fazer previsões\n")
cat("previsoes <- prever_score(novos_dados)\n\n")
cat("# 3. Ver resultados\n")
cat("print(previsoes)\n\n")

cat("Função 2: Previsão com avaliação de desvios\n")
cat("--------------------------------------------\n")
cat("# 1. Carregar dados com valores reais conhecidos\n")
cat("dados_teste <- read.csv('data/test.csv')\n")
cat("valores_reais <- dados_teste$matched_score\n")
cat("dados_teste$matched_score <- NULL  # remover para simular novos dados\n\n")
cat("# 2. Fazer previsões e avaliar desvios\n")
cat("resultado <- prever_e_avaliar(dados_teste, valores_reais = valores_reais)\n\n")
cat("# 3. Ver métricas\n")
cat("print(resultado$metricas)\n\n")
cat("# 4. Ver resumo dos desvios\n")
cat("print(resultado$resumo_desvios)\n\n")
cat("# 5. Análise detalhada dos desvios\n")
cat("View(resultado$desvios)  # todos os desvios\n\n")

# Exemplo prático com dados de teste (se existirem)
if(file.exists("data/test.csv")) {
  cat("\n=== Teste das Funções com Dados de Teste ===\n\n")
  test_data <- read.csv("data/test.csv")
  
  # Usar uma amostra para demonstração
  n_sample <- min(100, nrow(test_data))
  cat("[INFO] A usar", n_sample, "observações do conjunto de teste\n\n")
  
  if(n_sample > 0) {
    test_sample <- test_data[seq_len(n_sample), ]
    
    # Remover a coluna matched_score se existir (para simular dados novos)
    if("matched_score" %in% names(test_sample)) {
      valores_reais <- test_sample$matched_score
      test_sample_sem_target <- test_sample
      test_sample_sem_target$matched_score <- NULL
      
      # Teste 1: Previsão simples
      cat("--- Teste 1: Função prever_score() ---\n")
      previsoes_simples <- prever_score(test_sample_sem_target)
      cat("\nPrimeiras 5 previsões:", round(head(previsoes_simples, 5), 4), "\n\n")
      
      # Teste 2: Previsão com avaliação de desvios
      cat("\n--- Teste 2: Função prever_e_avaliar() ---\n")
      resultado_completo <- prever_e_avaliar(
        test_sample_sem_target, 
        valores_reais = valores_reais,
        mostrar_grafico = TRUE
      )
      
      cat("\n[INFO] Teste completo realizado com sucesso!\n")
      cat("[INFO] Ficheiros gerados:\n")
      cat("  - results/previsao_vs_real.png\n")
      cat("  - results/analise_residuos.png\n")
    }
  }
}

# -----------------------------------------------------
# 5. Integração em Sistemas Reais
# -----------------------------------------------------

cat("\n========================================================\n")
cat("         INTEGRAÇÃO EM SISTEMAS REAIS                   \n")
cat("========================================================\n\n")

cat("O modelo pode ser integrado em sistemas reais através de:\n\n")

cat("1. API REST (com Plumber):\n")
cat("   - Criar endpoints para receber dados e retornar previsões\n")
cat("   - Exemplo: POST /predict com JSON dos dados\n")
cat("   - Referência: https://www.rplumber.io/\n\n")

cat("2. Shiny Dashboard:\n")
cat("   - Interface web interativa para fazer previsões\n")
cat("   - Upload de ficheiros CSV ou entrada manual de dados\n")
cat("   - Visualização de resultados e desvios em tempo real\n")
cat("   - Referência: https://shiny.rstudio.com/\n\n")

cat("3. Script Batch:\n")
cat("   - Processar grandes volumes de dados periodicamente\n")
cat("   - Agendar com cron (Linux/Mac) ou Task Scheduler (Windows)\n")
cat("   - Exemplo: Rscript predict_batch.R input.csv output.csv\n\n")

cat("4. Integração Python:\n")
cat("   - Usar o pacote 'rpy2' para chamar funções R do Python\n")
cat("   - Útil para integrar com aplicações Django/Flask\n\n")

cat("5. Docker Container:\n")
cat("   - Empacotar modelo e dependências num container\n")
cat("   - Facilita deployment e escalabilidade\n")
cat("   - Base image: rocker/r-base ou rocker/tidyverse\n\n")

cat("========================================================\n")
cat("         FICHEIRO 05_OTHERS.R CONCLUÍDO                 \n")
cat("========================================================\n")
cat("Ficheiro do modelo: modelo_final.rds\n")
cat("Funções disponíveis:\n")
cat("  - prever_score(novo_dado)\n")
cat("  - prever_e_avaliar(novo_dado, valores_reais)\n")
cat("========================================================\n")

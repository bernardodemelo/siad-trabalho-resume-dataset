########################################################
# === 4. Evaluation: Avaliação do modelo final ===
########################################################

# Carregar pacotes necessários
source("r/dependencies.R")

# Criar diretório results/ se não existir
if(!dir.exists("results")) dir.create("results")

# Carregar modelo final e dados de teste
cat("A carregar modelo final e dados de teste...\n")
modelo_final <- readRDS("modelo_final.rds")
test <- read.csv("data/test.csv")

# Garantir que matched_score é numérico
test$matched_score <- as.numeric(test$matched_score)

cat("Dimensões do conjunto de teste:", dim(test), "\n\n")

# Prever valores no conjunto de teste
cat("A gerar previsões...\n")
predictions <- predict(modelo_final, newdata = test)
cat("Previsões geradas:", length(predictions), "valores\n\n")

# Avaliação com caret::postResample
cat("=== Métricas de Avaliação ===\n")
metrics <- postResample(pred = predictions, obs = test$matched_score)
print(metrics)
cat("\n")

# Gráfico de valores reais vs previstos
cat("A gerar gráfico: Valores Reais vs. Previstos...\n")
df_plot <- data.frame(Real = test$matched_score, Previsto = predictions)
p <- ggplot(df_plot, aes(x = Real, y = Previsto)) +
  geom_point(alpha = 0.5, color = "steelblue") +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed", linewidth = 1) +
  labs(title = "Valores Reais vs. Previstos", 
       x = "Valor Real (matched_score)", 
       y = "Valor Previsto") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))
ggsave("results/predictions_vs_actual.png", plot = p, width = 8, height = 6, dpi = 300)
cat("Gráfico guardado: 'results/predictions_vs_actual.png'\n")

# Análise de resíduos
cat("A gerar gráfico: Distribuição dos Resíduos...\n")
residuos <- test$matched_score - predictions
p2 <- ggplot(data.frame(residuos), aes(x = residuos)) +
  geom_histogram(bins = 30, fill = "skyblue", color = "black", alpha = 0.7) +
  geom_vline(xintercept = 0, color = "red", linetype = "dashed", linewidth = 1) +
  labs(title = "Distribuição dos Resíduos", 
       x = "Resíduo (Real - Previsto)", 
       y = "Frequência") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))
ggsave("results/residuals_hist.png", plot = p2, width = 8, height = 6, dpi = 300)
cat("Gráfico guardado: 'results/residuals_hist.png'\n\n")

# Estatísticas dos resíduos
cat("=== Estatísticas dos Resíduos ===\n")
cat("Média dos resíduos:", round(mean(residuos), 4), "\n")
cat("Desvio padrão dos resíduos:", round(sd(residuos), 4), "\n")
cat("Resíduos mínimos:", round(min(residuos), 4), "\n")
cat("Resíduos máximos:", round(max(residuos), 4), "\n\n")

cat("Avaliação concluída. Resultados e gráficos guardados em 'results/'.\n")

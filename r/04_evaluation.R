########################################################
# === 4. Evaluation: Avaliação do modelo final ===
########################################################

# Carregar pacotes necessários
source("R/dependencies.R")

# Carregar modelo final e dados de teste
modelo_final <- readRDS("modelo_final.rds")
test <- read.csv("data/test.csv")

# Prever valores no conjunto de teste
predictions <- predict(modelo_final, newdata = test)

# Avaliação com caret::postResample
metrics <- postResample(pred = predictions, obs = test$matched_score)
print(metrics)

# Gráfico de valores reais vs previstos
library(ggplot2)
df_plot <- data.frame(Real = test$matched_score, Previsto = predictions)
p <- ggplot(df_plot, aes(x = Real, y = Previsto)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  labs(title = "Valores Reais vs. Previstos", x = "Real", y = "Previsto") +
  theme_minimal()
ggsave("results/predictions_vs_actual.png", plot = p)

# Análise de resíduos
residuos <- test$matched_score - predictions
ggplot(data.frame(residuos), aes(x = residuos)) +
  geom_histogram(bins = 30, fill = "skyblue", color = "black") +
  labs(title = "Distribuição dos Resíduos", x = "Resíduo", y = "Frequência") +
  theme_minimal()

dev.print(png, filename = "results/residuals_hist.png")
dev.off()

cat("Avaliação concluída. Resultados e gráficos guardados em 'results/'.\n")

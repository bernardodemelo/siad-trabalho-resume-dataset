# --- Pacotes necessários ---

# Função auxiliar para instalar e carregar pacotes
install_and_load <- function(package) {
  if (!require(package, character.only = TRUE, quietly = TRUE)) {
    install.packages(package, repos = "https://cloud.r-project.org", quiet = TRUE)
    library(package, character.only = TRUE)
  }
}

# Pacotes
packages <- c(
  "tidyverse", "caret", "randomForest", "xgboost", 
  "text2vec", "glmnet", "recipes", "rsample", "skimr", "vip", "caret", 
  "skimr", "stringr", "corrplot", "dplyr", "bestNormalize", "moments", 
  "gridExtra", "ggplot2"
)

# 2. Instalação de Pacotes
install.packages(packages, repos = "https://cloud.r-project.org")

library(tidyverse)
library(caret)
library(randomForest)
library(xgboost)
library(text2vec)
library(glmnet)
library(recipes)
library(rsample)
library(skimr)
library(vip)
library(caret)
library(stringr)
library(skimr)
library(corrplot)
library(dplyr)

# Definir seed data para reproducibilidade do script.
set.seed(123)

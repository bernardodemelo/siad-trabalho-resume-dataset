# --- Pacotes necessários ---

# Pacotres
packages <- c(
  "tidyverse", "caret", "randomForest", "xgboost", 
  "text2vec", "glmnet", "recipes", "rsample", "skimr", "vip", "caret", 
  "skimr", "stringr", "corrplot", "dplyr"
)

# 2. Instalação de Pacotes
install.packages(packages)

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

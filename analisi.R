# analisi.R
if (!require("pdftools", quietly = TRUE)) install.packages("pdftools", repos = "http://cran.us.r-project.org")
if (!require("tidytext", quietly = TRUE)) install.packages("tidytext", repos = "http://cran.us.r-project.org")
if (!require("dplyr", quietly = TRUE)) install.packages("dplyr", repos = "http://cran.us.r-project.org")
if (!require("stringr", quietly = TRUE)) install.packages("stringr", repos = "http://cran.us.r-project.org")

library(pdftools)
library(dplyr)
library(tidytext)
library(stringr)

cat("Llegint el PDF...\n")
text_pdf <- pdf_text("sessio1.pdf")
cat(sprintf("S'han llegit %d pàgines.\n", length(text_pdf)))

# Mostrar un petit fragment de la primera pàgina per veure l'idioma i el format
cat("\n--- Fragment de la pàgina 1 ---\n")
cat(substr(text_pdf[1], 1, 800))
cat("\n-------------------------------\n")

# Convertir a data frame
df_text <- data.frame(
  text = text_pdf,
  pagina = 1:length(text_pdf),
  stringsAsFactors = FALSE
)

# Tokenització i neteja bàsica
df_paraules <- df_text %>%
  unnest_tokens(paraula, text) %>%
  filter(!str_detect(paraula, "^[0-9]+$")) # Treure números

cat("\nCercant termes específics...\n")
termes_clau <- c("nación", "catalunya", "españa", "nació", "espanya", "cataluña", "vox")

ocurrencies <- df_paraules %>%
  filter(paraula %in% termes_clau) %>%
  count(paraula, sort = TRUE)

print(ocurrencies)

cat("\nParaules més freqüents (inclou paraules buides per ara):\n")
top_paraules <- df_paraules %>%
  count(paraula, sort = TRUE) %>%
  head(15)
print(top_paraules)

cat("\nAnàlisi bàsica acabada.\n")

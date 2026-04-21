# analisi_avancada.R

# Carregar paquets i instal·lar si falten
paquets_necessaris <- c("pdftools", "dplyr", "tidytext", "stringr", "ggplot2", "tidyr")
nous_paquets <- paquets_necessaris[!(paquets_necessaris %in% installed.packages()[,"Package"])]
if(length(nous_paquets)) install.packages(nous_paquets, repos = "http://cran.us.r-project.org", type = "binary")

library(pdftools)
library(dplyr)
library(tidytext)
library(stringr)
library(ggplot2)
library(tidyr)

# Llegir el PDF
cat("Llegint el PDF...\n")
text_pdf <- pdf_text("sessio1.pdf")

# Convertir a un dataframe per línies
df_text <- data.frame(text = text_pdf, pagina = 1:length(text_pdf), stringsAsFactors = FALSE) %>%
  unnest_tokens(linia, text, token = "lines")

# Intent d'extreure oradors (assumint que les intervencions comencen amb "El senyor / La senyora ... :")
df_text <- df_text %>%
  mutate(
    orador_detectat = str_extract(linia, "^(El senyor|La senyora|El president|La presidenta) [A-Z][a-zÀ-ÿ]+ [A-Z][a-zÀ-ÿ]+"),
    orador = NA_character_
  )

# Omplir l'orador actual cap avall (fill)
orador_actual <- "Desconegut"
for(i in 1:nrow(df_text)) {
  if(!is.na(df_text$orador_detectat[i])) {
    orador_actual <- df_text$orador_detectat[i]
  }
  df_text$orador[i] <- orador_actual
}

# Ara dividim en frases per l'anàlisi de context
df_frases <- df_text %>%
  unnest_tokens(frase, linia, token = "sentences")

# Definim termes clau
termes_cat <- c("catalunya", "cataluña", "nació", "nación")
termes_esp <- c("espanya", "españa", "estat", "estado")

# Etiquetar frases que contenen els termes
df_frases <- df_frases %>%
  mutate(
    mencio_cat = str_detect(frase, paste(termes_cat, collapse = "|")),
    mencio_esp = str_detect(frase, paste(termes_esp, collapse = "|")),
    tema = case_when(
      mencio_cat & !mencio_esp ~ "Catalunya",
      mencio_esp & !mencio_cat ~ "Espanya",
      mencio_cat & mencio_esp ~ "Ambdós",
      TRUE ~ "Altres"
    )
  )

# Diccionari de sentiments híbrid (Català i Castellà)
paraules_positives <- c("bé", "bo", "bona", "millor", "gran", "progrés", "èxit", "dret", "drets", "llibertat", "democràcia", "pau", "justícia", "respecte", "acord", "gràcies", "suport",
                        "bien", "bueno", "buena", "mejor", "progreso", "éxito", "derecho", "derechos", "libertad", "democracia", "paz", "justicia", "respeto", "acuerdo", "gracias", "apoyo")
paraules_negatives <- c("dolent", "dolenta", "malament", "pèssim", "negatiu", "pitjor", "crisi", "fracàs", "repressió", "presó", "violència", "corrupció", "problema", "dictadura", "il·legal", "delicte", "frau",
                        "malo", "mala", "mal", "pésimo", "negativo", "peor", "crisis", "fracaso", "represión", "prisión", "violencia", "corrupción", "problema", "dictadura", "ilegal", "delito", "fraude")

diccionari_sentiments <- data.frame(
  paraula = c(paraules_positives, paraules_negatives),
  valor = c(rep(1, length(paraules_positives)), rep(-1, length(paraules_negatives))),
  stringsAsFactors = FALSE
)

# Llegir stopwords
stopwords_ca <- readLines("stopwords-ca.txt", warn = FALSE)
stopwords_es <- c("de", "la", "que", "el", "en", "y", "a", "los", "del", "se", "las", "por", "un", "para", "con", "no", "una", "su", "al", "lo", "como", "más", "pero", "sus", "le", "ya", "o", "este", "sí", "porque", "esta", "entre", "cuando", "muy", "sin", "sobre", "también", "me", "hasta", "hay", "donde", "quien", "desde", "todo", "nos", "durante", "todos", "uno", "les", "ni", "contra", "otros", "ese", "eso", "ante", "ellos", "e", "esto", "mí", "antes", "algunos", "qué", "unos", "yo", "otro", "otras", "otra", "él", "tanto", "esa", "estos", "mucho", "quienes", "nada", "muchos", "cual", "poco", "ella", "estar", "estas", "algunas", "algo", "nosotros", "mi", "mis", "tú", "te", "ti", "tu", "tus", "ellas", "nosotras", "vosotros", "vosotras", "os", "mío", "mía", "míos", "mías", "tuyo", "tuya", "tuyos", "tuyas", "suyo", "suya", "suyos", "suyas", "nuestro", "nuestra", "nuestros", "nuestras", "vuestro", "vuestra", "vuestros", "vuestras", "esos", "esas", "estoy", "estás", "está", "estamos", "estáis", "están", "esté", "estés", "estemos", "estéis", "estén", "estaré", "estarás", "estará", "estaremos", "estaréis", "estarán", "estaría", "estarías", "estaríamos", "estaríais", "estarían", "estaba", "estabas", "estábamos", "estabais", "estaban", "estuve", "estuviste", "estuvo", "estuvimos", "estuvisteis", "estuvieron", "estuviera", "estuvieras", "estuviéramos", "estuvierais", "estuvieran", "estuviese", "estuvieses", "estuviésemos", "estuvieseis", "estuviesen", "estando", "estado", "estada", "estados", "estadas", "estad", "he", "has", "ha", "hemos", "habéis", "han", "haya", "hayas", "hayamos", "hayáis", "hayan", "habré", "habrás", "habrá", "habremos", "habréis", "habrán", "habría", "habrías", "habríamos", "habríais", "habrían", "había", "habías", "habíamos", "habíais", "habían", "hube", "hubiste", "hubo", "hubimos", "hubisteis", "hubieron", "hubiera", "hubieras", "hubiéramos", "hubierais", "hubieran", "hubiese", "hubieses", "hubiésemos", "hubieseis", "hubiesen", "habiendo", "habido", "habida", "habidos", "habidas", "soy", "eres", "es", "somos", "sois", "son", "sea", "seas", "seamos", "seáis", "sean", "seré", "serás", "será", "seremos", "seréis", "serán", "sería", "serías", "seríamos", "seríais", "serían", "era", "eras", "éramos", "erais", "eran", "fui", "fuiste", "fue", "fuimos", "fuisteis", "fueron", "fuera", "fueras", "fuéramos", "fuerais", "fueran", "fuese", "fueses", "fuésemos", "fueseis", "fuesen", "siendo", "sido", "tengo", "tienes", "tiene", "tenemos", "tenéis", "tienen", "tenga", "tengas", "tengamos", "tengáis", "tengan", "tendré", "tendrás", "tendrá", "tendremos", "tendréis", "tendrán", "tendría", "tendrías", "tendríamos", "tendríais", "tendrían", "tenía", "tenías", "teníamos", "teníais", "tenían", "tuve", "tuviste", "tuvo", "tuvimos", "tuvisteis", "tuvieron", "tuviera", "tuvieras", "tuviéramos", "tuvierais", "tuvieran", "tuviese", "tuvieses", "tuviésemos", "tuvieseis", "tuviesen", "teniendo", "tenido", "tenida", "tenidos", "tenidas", "tened")
stopwords_all <- unique(c(stopwords_ca, stopwords_es))

# Calcular sentiment per frase
df_paraules_frase <- df_frases %>%
  mutate(frase_id = row_number()) %>%
  unnest_tokens(paraula, frase) %>%
  filter(!paraula %in% stopwords_all) %>%
  filter(!str_detect(paraula, "^[0-9]+$"))

sentiment_frases <- df_paraules_frase %>%
  inner_join(diccionari_sentiments, by = "paraula") %>%
  group_by(frase_id) %>%
  summarise(sentiment_score = sum(valor), .groups = 'drop')

# Unir el sentiment de nou al dataframe de frases
df_frases <- df_frases %>%
  mutate(frase_id = row_number()) %>%
  left_join(sentiment_frases, by = "frase_id") %>%
  replace_na(list(sentiment_score = 0))

# Colors dels partits
colors_partits <- c(
  "PSC" = "#FF0000",
  "ERC" = "#E3B11A",
  "Junts" = "#8B0000",
  "Comuns" = "#6B2E68",
  "CUP" = "#000000",
  "PPC" = "#015EAB",
  "Vox" = "#63BE21",
  "Desconegut" = "#AAAAAA"
)

# Simulació de grups parlamentaris per als oradors (com que no sabem qui són exactament en aquesta prova)
set.seed(42)
oradors_unics <- unique(df_frases$orador)

if (length(oradors_unics) <= 1 && "Desconegut" %in% oradors_unics) {
  # Si no hem detectat cap orador pel format del PDF, assignem un partit aleatori per blocs de frases per veure com queden els gràfics
  df_frases <- df_frases %>%
    mutate(bloc = ceiling(row_number() / 50),
           partit = names(colors_partits)[1:7][(bloc %% 7) + 1])
} else {
  partits_assignats <- sample(names(colors_partits)[1:7], length(oradors_unics), replace = TRUE)
  mapa_partits <- setNames(partits_assignats, oradors_unics)
  mapa_partits["Desconegut"] <- "Desconegut"
  df_frases <- df_frases %>% mutate(partit = mapa_partits[orador])
}

# Resum de sentiment per tema (Catalunya vs Espanya)
resum_tema <- df_frases %>%
  filter(tema %in% c("Catalunya", "Espanya")) %>%
  group_by(tema) %>%
  summarise(
    mitjana_sentiment = mean(sentiment_score),
    num_mencions = n()
  )

print("Resum de sentiment mitjà per tema:")
print(resum_tema)

# Gràfic 1: Mitjana de Sentiment per Partit i Tema
df_resum_partit_tema <- df_frases %>%
  filter(tema %in% c("Catalunya", "Espanya"), partit != "Desconegut") %>%
  group_by(partit, tema) %>%
  summarise(mitjana_sentiment = mean(sentiment_score), .groups = 'drop')

p1 <- ggplot(df_resum_partit_tema, aes(x = reorder(partit, mitjana_sentiment), y = mitjana_sentiment, fill = partit)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  facet_wrap(~tema) +
  scale_fill_manual(values = colors_partits) +
  theme_minimal() +
  coord_flip() +
  labs(title = "Mitjana de Sentiment cap a Catalunya i Espanya per Partit",
       x = "Grup Parlamentari", y = "Mitjana de Sentiment") +
  theme(legend.position = "none")

ggsave("grafic_sentiment_temes.png", p1, width = 10, height = 6, bg = "white")

# Gràfic 2: Distribució de Sentiment Global per Partit
p2 <- df_frases %>%
  filter(partit != "Desconegut") %>%
  ggplot(aes(x = reorder(partit, sentiment_score, FUN = median), y = sentiment_score, fill = partit)) +
  geom_boxplot(alpha = 0.7, outlier.alpha = 0.5) +
  theme_minimal() +
  scale_fill_manual(values = colors_partits) +
  coord_flip() +
  labs(title = "Distribució del Sentiment Global per Grup Parlamentari",
       x = "Grup Parlamentari", y = "Puntuació de Sentiment") +
  theme(legend.position = "none")

ggsave("grafic_evolucio_sentiment.png", p2, width = 10, height = 6, bg = "white")

# Gràfic 3: Freqüència de termes clau per partit
p3 <- df_frases %>%
  filter(tema %in% c("Catalunya", "Espanya"), partit != "Desconegut") %>%
  count(partit, tema) %>%
  ggplot(aes(x = reorder(partit, n), y = n, fill = tema)) +
  geom_bar(stat = "identity", position = "dodge") +
  theme_minimal() +
  coord_flip() +
  scale_fill_manual(values = c("Catalunya" = "#E3B11A", "Espanya" = "#015EAB")) +
  labs(title = "Nombre de mencions de Catalunya/Espanya per Partit",
       x = "Partit", y = "Nombre de mencions")

ggsave("grafic_mencions_partit.png", p3, width = 8, height = 6, bg = "white")

cat("Anàlisi finalitzada. S'han guardat els gràfics com a fitxers .png\n")

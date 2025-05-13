# -----------------------------------------------------------------------------
# ProtCompare - Protein Sequence Similarity Comparator (Shiny App)
# Developer: Lourdes Martínez Martínez
# Contact:   loumtezmtez@gmail.com
# GitHub:    https://github.com/LouMtz2/ProtCompare
# License:   MIT License © 2025 Lourdes Martínez Martínez
# Version:   1.0 (May 2025)
# -----------------------------------------------------------------------------

library(shiny)
library(readxl)
library(DT)
library(Biostrings)
library(pwalign)
library(bslib)

ui <- fluidPage(
  theme = bs_theme(version = 5, bootswatch = "minty"),
  
  titlePanel(
    div("ProtCompare", style = "background-color: #58855C; color: white; padding: 10px; border-radius: 5px;")
  ),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload Excel file (.xlsx)", accept = ".xlsx"),
      
      textAreaInput("query_seq", "Paste your protein sequence:", 
                    value = "", rows = 5, placeholder = "MTSLNLLTDIPGIRVGH..."),
      
      numericInput("n_random", "Random samples for p-value:", value = 100, min = 10, step = 10),
      
      actionButton("run", "Compare Sequences", class = "btn-success"),
      br(),
      
      downloadButton("downloadData", "Download Results (CSV)", class = "btn-success"),
      br(), br(),
      
      helpText(HTML("<span style='font-size: smaller; padding: 4px 6px; border-radius: 4px; text-align: justify; display: block;'>
        Excel file must contain a column with protein sequences. Acceptable column names include: 
        <b>translation</b>, <b>aa_sequence</b>, <b>prot_seq</b>.
      </span>")),
      
      hr()
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Results", DTOutput("result_table")),
        tabPanel("About",
                 br(),
                 HTML(
                   "<h4 style='background-color: #58855C; color: white; padding: 10px; border-radius: 5px;'>ProtCompare</h4>
             <div style='text-align: justify;'>
             <p>This Shiny app compares a user-provided protein sequence to sequences from an uploaded Excel file using local alignment (BLOSUM62).</p>
             <p>For each sequence, it calculates:</p>
             <ul>
               <li>Identity (%)</li>
               <li>Coverage (%) of the query</li>
               <li>Combined Score (Identity × Coverage)</li>
               <li>Alignment Score</li>
               <li>Empirical P-Value from a user-defined number of random alignments</li>
             </ul>
             <p style='font-size: smaller;'>Column names accepted: <b>translation</b>, <b>aa_sequence</b>, <b>prot_seq</b></p>
             <p style='font-size: 75%;'>This app does not use a reference database or compute statistical E-values like BLAST. Instead, it estimates p-values empirically by comparing the actual alignment score to a number of alignments with random sequences. If the p-value is shown as 0, it means that none of the random alignments scored as well as the true match — i.e., the real p-value is lower than 1 divided by the number of random samples (1/N).</p>
             <hr>
             <b>Developer:</b> Lourdes Martínez Martínez<br>
             <b>Email:</b> <a href='mailto:loumtezmtez@gmail.com'>loumtezmtez@gmail.com</a><br>
             <b>Version:</b> 1.0<br>
             <b>Created:</b> May 2025<br>
             <b>License:</b> MIT License (© 2025 Lourdes Martínez Martínez)<br>
             <b>Source:</b> <a href='https://github.com/LouMtz2/ProtCompare' target='_blank'>GitHub Repository</a>
             </div>"
                 ),
                 style = "padding: 15px;"
        )
      )
    )
  ),
  
  tags$footer(
    style = "margin-top: 30px; padding: 10px; font-size: 90%; color: gray; text-align: center;",
    HTML("© 2025 Lourdes Martínez Martínez – <a href='mailto:loumtezmtez@gmail.com'>loumtezmtez@gmail.com</a> – MIT License")
  )
)

server <- function(input, output) {
  results <- reactiveVal(NULL)
  used_colname <- reactiveVal(NULL)
  
  observeEvent(input$run, {
    req(input$file)
    req(nzchar(input$query_seq))
    
    # Try to read the file safely
    df <- tryCatch({
      read_excel(input$file$datapath)
    }, error = function(e) {
      showModal(modalDialog("❌ Unable to read the Excel file. Please upload a valid .xlsx file.", easyClose = TRUE))
      return(NULL)
    })
    if (is.null(df)) return()
    
    # Find column with protein sequences
    accepted_names <- c("translation", "aa_sequence", "prot_seq")
    col_match <- grep(paste(accepted_names, collapse = "|"), names(df), ignore.case = TRUE, value = TRUE)
    
    if (length(col_match) == 0) {
      showModal(modalDialog("❌ No suitable column found. Your file must contain a column named: translation, aa_sequence, or prot_seq.", easyClose = TRUE))
      return()
    }
    
    seq_col <- col_match[1]
    used_colname(seq_col)
    
    query_string <- toupper(gsub("[^ARNDCQEGHILKMFPSTWYVBZX*]", "", input$query_seq))
    if (nchar(query_string) == 0) {
      showModal(modalDialog("❌ Invalid query sequence. No amino acids detected.", easyClose = TRUE))
      return()
    }
    query <- AAString(query_string)
    
    similarity_results <- list()
    
    withProgress(message = "🔍 Comparing sequences...", value = 0, {
      n <- nrow(df)
      for (i in seq_len(n)) {
        incProgress(1 / n, detail = paste("Sequence", i, "of", n))
        
        target_seq <- df[[seq_col]][[i]]
        if (is.na(target_seq) || nchar(target_seq) == 0) next
        
        target_string <- toupper(gsub("[^ARNDCQEGHILKMFPSTWYVBZX*]", "", target_seq))
        if (nchar(target_string) == 0) next
        
        target <- AAString(target_string)
        
        alignment <- tryCatch({
          pwalign::pairwiseAlignment(
            query, target,
            substitutionMatrix = "BLOSUM62",
            gapOpening = -12,
            gapExtension = -0.5,
            type = "local"
          )
        }, error = function(e) NULL)
        
        if (is.null(alignment)) next
        
        percent_id <- pwalign::pid(alignment)
        aligned_len <- nchar(as.character(alignedPattern(alignment)))
        coverage <- aligned_len / nchar(query) * 100
        combined_score <- percent_id * (coverage / 100)
        alignment_score <- score(alignment)
        
        rand_scores <- tryCatch({
          replicate(input$n_random, {
            rand_seq <- AAString(paste0(sample(c("A","R","N","D","C","Q","E","G","H","I",
                                                 "L","K","M","F","P","S","T","W","Y","V"),
                                               nchar(target), replace = TRUE), collapse = ""))
            rand_align <- pwalign::pairwiseAlignment(
              query, rand_seq,
              substitutionMatrix = "BLOSUM62",
              gapOpening = -12,
              gapExtension = -0.5,
              type = "local"
            )
            score(rand_align)
          })
        }, error = function(e) rep(NA, input$n_random))
        
        if (any(is.na(rand_scores))) next
        
        empirical_p <- mean(rand_scores >= alignment_score)
        empirical_display <- ifelse(empirical_p < 1 / input$n_random,
                                    paste0("< ", signif(1 / input$n_random, 2)),
                                    signif(empirical_p, 3))
        
        similarity_results[[length(similarity_results) + 1]] <- data.frame(
          Index = i,
          "Identity (%)" = round(percent_id, 2),
          "Coverage (%)" = round(coverage, 2),
          "Combined Score" = round(combined_score, 2),
          "Alignment Score" = round(alignment_score, 2),
          "Empirical P-Value" = empirical_display,
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      }
    })
    
    # Handle empty result
    if (length(similarity_results) == 0) {
      showModal(modalDialog("⚠️ No valid alignments were produced. Please check your input sequences.", easyClose = TRUE))
      return()
    }
    
    similarity_df <- do.call(rbind, similarity_results)
    
    result_df <- df[similarity_df$Index, , drop = FALSE]
    result_df <- cbind(similarity_df[, -1], result_df)
    result_df <- result_df[order(-result_df$`Combined Score`), ]
    
    results(result_df)
    
    output$result_table <- renderDT({
      req(results())
      datatable(results(), options = list(pageLength = 10), rownames = FALSE)
    })
  })
  
  output$used_column <- renderText({
    req(used_colname())
    paste("✅ Using sequence column:", used_colname())
  })
  
  output$downloadData <- downloadHandler(
    filename = function() {
      paste0("similarity_results_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(results(), file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)



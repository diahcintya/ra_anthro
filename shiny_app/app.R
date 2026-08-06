# Child Anthropometry Dashboard -------------------------------------------------
#
# Country dropdown + clickable Leaflet map, both driving the same selected
# country, showing harmonized under-5 anthropometric outcomes aggregated
# from this project's pipeline (see country_summary.csv / prepare_data.R).
#
# Run: shiny::runApp("shiny_app")

library(shiny)
library(leaflet)
library(bslib)
library(dplyr)
library(readr)
library(tibble)

country_summary <- read_csv("country_summary.csv", show_col_types = FALSE)

fmt_pct <- function(x) if (is.na(x)) "n/a" else paste0(formatC(x, digits = 1, format = "f"), "%")
fmt_z <- function(x) if (is.na(x)) "n/a" else formatC(x, digits = 2, format = "f")

ui <- page_sidebar(
  title = "Child Anthropometry Across 14 Countries",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  sidebar = sidebar(
    width = 280,
    selectInput(
      "country_select", "Select a country",
      choices = setNames(country_summary$country_code, country_summary$country_name),
      selected = country_summary$country_code[1]
    ),
    hr(),
    p(
      class = "text-muted small",
      "Harmonized under-5 anthropometric outcomes, aggregated to the",
      "country level. Click a map marker or use the dropdown to explore."
    )
  ),
  card(
    full_screen = TRUE,
    card_header("Country map"),
    leafletOutput("map", height = 380)
  ),
  layout_column_wrap(
    width = 1 / 4,
    value_box("Children observed", textOutput("n_children"), theme = "primary"),
    value_box("Stunted", textOutput("stunted_pct"), theme = "danger"),
    value_box("Wasted", textOutput("wasted_pct"), theme = "warning"),
    value_box("Underweight", textOutput("underweight_pct"), theme = "info")
  ),
  card(
    card_header("Mean z-scores"),
    tableOutput("zscore_table")
  )
)

server <- function(input, output, session) {
  selected <- reactiveVal(country_summary$country_code[1])

  observeEvent(input$country_select, {
    req(input$country_select)
    if (input$country_select != selected()) selected(input$country_select)
  })

  observeEvent(input$map_marker_click, {
    cc <- input$map_marker_click$id
    req(cc)
    if (cc != selected()) {
      selected(cc)
      updateSelectInput(session, "country_select", selected = cc)
    }
  })

  current <- reactive({
    country_summary %>% filter(country_code == selected())
  })

  output$map <- renderLeaflet({
    leaflet(country_summary) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircleMarkers(
        lng = ~lon, lat = ~lat, layerId = ~country_code,
        radius = 10, color = "#2C3E50", fillColor = "#18BC9C",
        fillOpacity = 0.8, stroke = TRUE, weight = 2,
        label = ~country_name
      )
  })

  observeEvent(selected(), {
    cs <- current()
    leafletProxy("map") %>%
      setView(lng = cs$lon, lat = cs$lat, zoom = 5) %>%
      clearGroup("highlight") %>%
      addCircleMarkers(
        data = cs, lng = ~lon, lat = ~lat,
        group = "highlight", radius = 14, color = "#E74C3C",
        fillOpacity = 0, weight = 3
      )
  })

  output$n_children <- renderText(format(current()$n_children, big.mark = ","))
  output$stunted_pct <- renderText(fmt_pct(current()$stunted_pct))
  output$wasted_pct <- renderText(fmt_pct(current()$wasted_pct))
  output$underweight_pct <- renderText(fmt_pct(current()$underweight_pct))

  output$zscore_table <- renderTable({
    tibble(
      Country = current()$country_name,
      `Mean HAZ` = fmt_z(current()$mean_haz),
      `Mean WAZ` = fmt_z(current()$mean_waz),
      `Mean WHZ` = fmt_z(current()$mean_whz),
      `Overweight %` = fmt_pct(current()$overweight_pct)
    )
  })
}

shinyApp(ui, server)

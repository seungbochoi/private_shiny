## Server side ..!

# This is the brain of the UI. 
# Deals with the actual calculations and data manipulation. 
shinyServer(function(input,output, session){
  options(warn=0)
  
  globaldata <- reactiveValues(
    # input tables
    alpha1 = 0,  beta1 = 0, calculating_status = FALSE
  )
  
  # below will show the percentage of the bench mark and return prices of stock
  output$plot1 <- renderPlotly({
    prices = window(prices, start = input$dateRange[1], end = input$dateRange[2])
    vect1 = rebase(as.numeric(prices[,input$ticker]),100)
    vect2 = rebase(as.numeric(prices$Bench),100)
    
    # below line will draw the two different (benchmark and return)of stocks graph in the same plot
    plot_ly( x = time(prices), y = vect1, type = 'scatter', mode = 'lines', name = 'Company') %>% 
      add_trace(y  = vect2, name = 'Benchmark',mode = 'lines')
  })
  
  # below will calculate the sliding window based method standard deviation to plot
  output$Chart2 = renderPlotly({
    st_dev_df = window(st_dev_df, start = input$dateRange[1], end = input$dateRange[2])
    plot_ly( x = time(st_dev_df), y = as.numeric(st_dev_df[,input$ticker]), type = 'scatter', mode = 'lines', name = 'plot')
  })
  
  # below line will put the data together to draw the porfolio regression graph
  output$plot3 = renderPlotly({
    vector1 = window(monthly_returns[,input$ticker], start = input$dateRange[1], end = input$dateRange[2])
    vector2 = window(monthly_returns$Bench, start = input$dateRange[1], end = input$dateRange[2])
    df3 = cbind(vector1,vector2)
    save(df3, file = 'df3.Rdata')
    colnames(df3)[1] = 'Portfolio'
    df3 = as.data.frame(df3)
    
    regr = lm(Portfolio ~ Bench, data = df3 )
    regr = summary(regr)
    globaldata$alpha1 = regr[["coefficients"]][1]
    globaldata$beta1 = regr[["coefficients"]][2]
    
    plot_ly(df3,  x = ~Portfolio, y = ~Bench)
    
  })
  
  # for selected tickers, this wil plot the return graph of stocks
  # for all the input tickers, it will be a selected input from the all choices,
  # or the string typed input which user want to put it into
  output$plot5 = renderPlotly({
    if(input$ticker3=="")
    {
      ticker_select = input$ticker2
    }else
    {
      ticker_select = input$ticker3
    }
    databm = getyahooprice(input$defaultbenchmark,input$dateRange2[1],input$dateRange2[2])
    data5 = getyahooprice(ticker_select,input$dateRange2[1],input$dateRange2[2])
    ## Data of a benchmark index can be different from a regular company
    ## Thus we alight the 2 dataframes
    databm = databm[time(data5),]
    
    databm = as.data.frame(databm)
    data5 = as.data.frame(data5)
    print(dim(databm))
    print(dim(data5))
    
    vect1 = rebase(as.numeric(data5[,1]),100)
    vect2 = rebase(as.numeric(databm[,1]),100)
    
    print(length(vect1))
    print(length(vect2))
    
    plot_ly(x = as.Date(row.names(data5)), y = vect1,  type = 'scatter', mode = 'lines', name = paste('Prices of:',ticker_select) )  %>%
      add_trace(y  = vect2, name = input$defaultbenchmark,mode = 'lines')
  })
  
  
  output$upsidedownside = renderPlotly({
    if(input$ticker3=="")
    {
      ticker_select = input$ticker2
    }else
    {
      ticker_select = input$ticker3
    }
    databm = getyahooprice(input$defaultbenchmark,input$dateRange2[1],input$dateRange2[2])
    stock = getyahooprice(ticker_select,input$dateRange2[1],input$dateRange2[2])
    ## Data of a benchmark index can be different from a regular company
    ## Thus we alight the 2 dataframes
    databm = databm[time(stock),]
    
    
    # here we compute the upside(price>0) and downside(price<0) cumulatively calculate
    df_output = compute_upside_downside(stock,databm)
    time = time(df_output)
    df_output = as.data.frame(df_output)
    print(colnames(df_output))
    # print(row.names(df_output))
    plot_ly(x = time, y = df_output[,1],  type = 'scatter', mode = 'lines', name = colnames(df_output)[1] ) %>% 
      add_trace(y  = df_output[,2], name =  colnames(df_output)[2],mode = 'lines') %>% 
      add_trace(y  = df_output[,3], name =  colnames(df_output)[3],mode = 'lines') %>% 
      add_trace(y  = df_output[,4], name =  colnames(df_output)[4],mode = 'lines') 
  })
  
  # below will get the single stock data and will plot it
  # will calculate the standard deviation based on moving window
  output$plot6 = renderPlotly({
    if(input$ticker3=="")
    {
      ticker_select = input$ticker2
    }else
    {
      ticker_select = input$ticker3
    }
    
    # this will get the data from yahoo finance, (can be lively active)
    data5 = getyahooprice(ticker_select,input$dateRange2[1],input$dateRange2[2])
    print(colnames(data5))
    
    returns5 = Return.calculate(data5, method = 'log')
    stdev5 = stdevwind(returns5)
    stdev5 = as.data.frame(stdev5)
    print(stdev5)
    
    # will draw the anualized volatility return graph calculated
    plot_ly(x = as.Date(row.names(stdev5)), y = stdev5[,1],  type = 'scatter', mode = 'lines', name = paste('Rolling volatility of:',ticker_select) )
  })
  
  # this will get the single price of tickek designated by users and will perform each action below
  # rolling sliding window based regression performance, draw the plot, give the scores result
  output$chart10 = renderPlot({
    
    if(input$ticker3=="")
    {
      ticker_select = input$ticker2
    }else
    {
      ticker_select = input$ticker3
    }
    
    a = getyahooprice(ticker_select,input$dateRange2[1],input$dateRange2[2])
    
    # get the calculated result which contains the upper,lower,and fitted(middle) of result
    rolled_input = execute_roll_linear(a,input$windrange)
    
    # this will draw the plot of the result based on the prediction and will show superior result 
    # will show how linear regression(regular) is not working well compared to this
    draw_comparison_result_plot(a, rolled_input)
    
    # this will shows the result score based on each metric on table bottom right
    output$Table2 = DT::renderDataTable({
      df2 = matrix(data = NA,nrow=2,ncol = 2)
      colnames(df2) = c('Score Metric',"Value")
      df2[1,1] = 'RMSE'
      df2[2,1] = 'MAE'
      df2[1,2] = round(get_rmse(rolled_input$fit, a),3)
      df2[2,2] = round(get_mae(rolled_input$fit, a),3)
      df2 = as.data.frame(df2)
      
      DT::datatable(df2,
                    options = list(autoWidth = TRUE, searching = FALSE, dom = 't'
                                   
                    )
      )
      
    })
    
    
  })
  
  observeEvent(input$do, { 
    # here will draw the pca result for the plotting
    output$plotPCA = renderPlot({
      
      if(input$areainput2!="")
      {
        list_stocks = input$areainput2
        list_stocks = unlist(strsplit(list_stocks, ","))
        print(list_stocks)
        dataPCA = get_multiple_stock(list_stocks, input$dateRange3[1],input$dateRange3[2])
        draw_pca_var_plot(dataPCA)
        
      }
    })
    
    # this will draw the variance plot from the pca calculated
    output$plotVAR = renderPlot({
      
      if(input$areainput2!="")
      {
        list_stocks = input$areainput2
        list_stocks = unlist(strsplit(list_stocks, ","))
        print(list_stocks)
        dataPCA = get_multiple_stock(list_stocks, input$dateRange3[1],input$dateRange3[2])
        draw_var_explanation(dataPCA)
      }
    })
    
    # this will convert the result from pca calculation as data frame and then put the result table to shiny
    output$dfImportance = DT::renderDataTable({
      list_stocks = input$areainput2
      list_stocks = unlist(strsplit(list_stocks, ","))
      print(list_stocks)
      dataPCA = get_multiple_stock(list_stocks, input$dateRange3[1],input$dateRange3[2])
      give_summary = as.data.frame(pca_importance(give_summary(dataPCA)))
      
      colz = c()
      ## we loop through the number of tickers in the dataframe and create a vector with PCA & number, for the amount of tickers included
      for(i in 1:length(colnames(give_summary)))
      {
        colz = c(colz,paste("PCA",i))
      }
      colnames(give_summary) = colz
      give_summary = round(give_summary,2)
      DT::datatable(give_summary
      )
    })
  })
  
  # below will draw the cluster result calculated to put on shiney app by getting stacked stocks
  observeEvent(input$do2, { 
    
    output$plotCluster = renderPlot({
      
      if(input$areainput2!="")
      {
        list_stocks = input$areainput2
        list_stocks = unlist(strsplit(list_stocks, ","))
        print(list_stocks)
        dataCluster = get_multiple_stock(list_stocks, input$dateRange3[1],input$dateRange3[2])
        draw_cluster_analysis(dataCluster, input$num_center2,  input$numstart)
        
      }
    })
    
    # this will get the user chosen stocks(stacked) and will put out the dendogram result
    output$plotDend = renderPlot({
      
      if(input$areainput2!="")
      {
        list_stocks = input$areainput2
        list_stocks = unlist(strsplit(list_stocks, ","))
        print(list_stocks)
        dataDend = get_multiple_stock(list_stocks, input$dateRange3[1],input$dateRange3[2])
        give_cluster_dendogram(dataDend)
      }
    })
  })
  
  # this dynamically handling in accordance with the input parameter user choose. We need this since there should be the maximum
  output$num_center <- renderUI({
    
    sliderInput('num_center2', label = 'Number of Centers(dynamically adjusting to your ticker inputs)', min = 0, value = 1, step = 1,
                max = length(unlist(strsplit(input$areainput2, ","))))  
  })
  
  # below will give the window frame input selection based on the selected period
  output$windowframe = renderText ({
    paste("Period: from ",input$dateRange[1]," to ",input$dateRange[2], sep='')
  })
  
  # below will return all necessary format(rebased for percentage)
  # it will print out the result on shiney app
  # it contains the annulized return ,bench mark, alpha and beta calculated based on linear regression
  output$Table1 = DT::renderDataTable({
    
    returns_bench = window(returns$Bench, start = input$dateRange[1], end = input$dateRange[2])
    ret_benchmark = paste(round(Return.annualized(returns_bench, scale = 252, geometric = TRUE), 4) *100, "%", sep='')
    
    returns_ticker = window(returns[,input$ticker], start = input$dateRange[1], end = input$dateRange[2])
    ret_ticker =   paste(round(Return.annualized(returns_ticker, scale = 252, geometric = TRUE), 4) *100, "%", sep='')
    
    df_results = rbind(ret_benchmark,ret_ticker)
    rownames(df_results) = c('Benchmark', input$ticker)
    print(df_results)
    colnames(df_results) = c('Annualized Return')
    df_results = cbind(df_results, c("",round(globaldata$alpha1,4)),c("",round(globaldata$beta1,4)))
    colnames(df_results)[2] = 'Alpha vs Benchmark'
    colnames(df_results)[3] = 'Beta vs Benchmark'
    
    DT::datatable(df_results,
                  options = list(autoWidth = FALSE, searching = FALSE, dom = 't'
                  )
    )
  })
  
  ## OUTPUT CHART FOR THE TECHNICAL ANALYSIS IN TAB4
  
  output$plot_tech = renderPlot({
    
    if(input$ticker_tech!='')
    {
      # ticker_name = 'MSFT'
      single_stock = getSymbols(input$ticker_tech, src='yahoo',from= input$dateRange_tech[1],to  = input$dateRange_tech[2], auto.assign = FALSE)
      
      draw_stock_analysis(single_stock,input$ticker_tech, input$stdev, input$bbn1,input$bbn2,input$bbn3,paste('last',input$months,'months'))
    }
    
  })
  
  # dataframe = observe({
  #   
  #   get_multiple_stock(nasdaq$Symbol, input$dateRange_bt[1], input$dateRange_bt[2])  
  # } )
  
  ## observe event = do something on event
  ## here event is the button calc
  observeEvent(input$calc, { 
    
    withProgress(message = 'In progress', 
                 value = 0, {
                   
                   incProgress(0.1, detail = 'Prices Download')
                   
                   
                   ## downloal all price series for 100 nasdaq companies
                   dataframe = get_multiple_stock(nasdaq$Symbol, input$dateRange_bt[1], input$dateRange_bt[2])    
                   
                   ## frequency is the frequency at which you review your portfolio
                   ## suppose every 3 months you want to select the best 20 companies according to their momentum
                   ## and invest your money in it. after 3 months, you sell all, and buy the 20 which are NOW the best according to their momentum
                   freq = input$reviewf
                   
                   ## usually 10 to 30 companies to be invested in
                   num_companies = input$number_comp
                   dayz = time(dataframe)
                   
                   days_end = find_eom(dayz)
                   print(days_end)
                   
                   dates_review = select_freq(days_end, freq)
                   print('-----')
                   print(dates_review)
                   dates_review_q = select_freq(days_end, 3)
                   
                   incProgress(0.5, detail = 'Calculations')
                   
                   if(input$strategy=='momentum3m'){
                     sel_cr = momentum_3m(dataframe,dates_review,freq)
                   }
                   
                   if(input$strategy=='faber3m'){
                     sel_cr = faber_3m(dataframe,dates_review,freq)
                   }
                   
                   portfolio = determine_portfolio(sel_cr, num_companies)
                   
                   save(portfolio, file = 'portfolio.Rdata')
                   
                   calc = calculate_historical_track( dataframe, portfolio, input$weight)
                   
                   
                   portfolio = cbind(as.character(time(portfolio)),portfolio)
                   
                   incProgress(0.8, detail = 'Output')
                   
                   output$portfolio = DT::renderDataTable({
                     DT::datatable(portfolio)
                   })
                   
                   # print(calc[,1])
                   # print(calc[,3])
                   print(calc[1,1])
                   print(calc[nrow(calc),1])
                   
                   time_calc = as.Date(as.character(calc[,1]),origin = "1900-01-01")
                   
                   nd = getyahooprice('SPY',calc[1,1], calc[nrow(calc),1])
                   
                   nd = rebase(nd[,1],100)
                   nd = rbind(nd,nd[nrow(nd),])
                   print(dim(nd))
                   print(nd)
                   output$portfolio_t = renderPlotly({
                     
                     # print(row.names(df_output))
                     plot_ly(x = calc[,1], y =  as.numeric(calc[,3]), name ='Composite Portfolio', type = 'scatter', mode = 'lines' )%>% 
                       add_trace(y  = as.numeric(nd[,1]), name =  'S&P 500',mode = 'lines') 
                   })
                   
                 })
    
    
  })
  
  
})

Gather.Views.Meals.ReportChartsView = Backbone.View.extend

  initialize: (options) ->
    @elStr = options.el
    @data = options.data
    @cmty = if options.multiCommunity then "#{options.cmty} " else ''

    @addServingsByMonth(1)
    @addCostByMonth(2)
    @addMealsByMonth(3)
    @addServingsByWeekday(4)
    if options.multiCommunity
      @addCommunityRep(5)
    else
      @addCostByWeekday(5)
    @addMealTypes(6)

  addServingsByMonth: (num) ->
    data = [{key: 'Avg. Servings', values: @data.servings_by_month[0]}]
    chart = @lineChart().forceY([0,40])
    @setMonthXAxis(chart, data)
    chart.yAxis.axisLabel('Avg. Servings per Meal').tickFormat(d3.format(',.1f'))
    @addChart(num, chart, data, "Avg. Servings per #{@cmty}Meal by Month")

  addCostByMonth: (num) ->
    data = [{key: 'Avg. Cost', values: @data.cost_by_month[0]}]
    chart = @lineChart().forceY([0,8])
    @setMonthXAxis(chart, data)
    chart.yAxis.axisLabel('Avg. Full Meal Price').tickFormat(d3.format('$.2f'))
    @addChart(num, chart, data, "Avg. Full #{@cmty}Meal Price by Month")

  addMealsByMonth: (num) ->
    data = [{key: 'Meals', values: @data.meals_by_month[0]}]
    chart = @lineChart().forceY([0,30])
    @setMonthXAxis(chart, data)
    chart.yAxis.axisLabel('Number of Meals').tickFormat(d3.format(',f'))
    @addChart(num, chart, data, "Number of #{@cmty}Meals by Month")

  addServingsByWeekday: (num) ->
    data = [{values: @data.servings_by_weekday[0]}]
    chart = @barChart().forceY([0,40])
    chart.xAxis.axisLabel('Weekday').tickFormat (d) => @tickFormat(data, d)
    chart.yAxis.axisLabel('Avg. Servings per Meal').tickValues([10,20,30,40]).tickFormat(d3.format(',.1f'))
    @addChart(num, chart, data, "Avg. Servings per #{@cmty}Meal by Weekday")

  addCostByWeekday: (num) ->
    data = [{values: @data.cost_by_weekday[0]}]
    chart = @barChart().forceY([0,8])
    chart.xAxis.axisLabel('Weekday').tickFormat (d) => @tickFormat(data, d)
    chart.yAxis.axisLabel('Avg. Full Meal Price').tickValues([2,4,6,8]).tickFormat(d3.format('$,.2f'))
    @addChart(num, chart, data, "Avg. Full #{@cmty}Meal Price by Weekday")

  addCommunityRep: (num) ->
    data = @data.community_rep
    console.log(data)
    chart = @pieChart()
    @addChart(num, chart, data, "Avg. Community Representation at #{@cmty}Meals")

  addMealTypes: (num) ->
    data = @data.meal_types
    chart = @pieChart()
    console.log(data)
    @addChart(num, chart, data, "Avg. Meal Types at #{@cmty}Meals")

  addChart: (num, chart, data, title) ->
    $('<h4>').text(title).prependTo(@$("#chart#{num}"))
    chart.showLegend(false).duration(300)
    d3.select("#chart#{num} svg").datum(data).call(chart)
    nv.utils.windowResize -> chart.update() # Update the chart when window resizes.
    nv.addGraph(chart)

  lineChart: ->
    nv.models.lineChart()
      .margin({top: 10, right: 10, bottom: 60, left: 60})
      .options(useInteractiveGuideline: true)

  barChart: ->
    nv.models.discreteBarChart()
      .margin({top: 10, right: 10, bottom: 60, left: 60})

  pieChart: ->
    nv.models.pieChart()
      .margin({top: 10, right: 0, bottom: 10, left: 0})
      .showTooltipPercent(true)
      .labelsOutside(true)
      .x((d) -> d.key)
      .y((d) -> d.y)
      .valueFormat(d3.format(',.1f'))

  setMonthXAxis: (chart, data) ->
    chart.xAxis
      .axisLabel('Month')
      .tickFormat((d) => @tickFormat(data, d))
      .tickValues([0,3,6,9])

  tickFormat: (data, d) ->
    if d >= 0 && d < data[0].values.length
      data[0].values[d].l  # l = Label
    else
      ''

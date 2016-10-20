Mess.Views.Meals.ReportChartsView = Backbone.View.extend

  initialize: (options) ->
    @elStr = options.el
    @data = options.data
    @cmty = if options.multiCommunity then "#{options.cmty} " else ''

    @addDinersByMonth(1)
    @addCostByMonth(2)
    @addMealsByMonth(3)
    @addDinersByWeekday(4)
    @addCommunityRep(5)
    @addDinerTypes(6)

  addDinersByMonth: (num) ->
    data = [{key: 'Avg. Diners', values: @data.diners_by_month[0]}]
    chart = @lineChart().forceY([0,40])
    @setMonthXAxis(chart, data)
    chart.yAxis.axisLabel('Avg. Diners per Meal').tickFormat(d3.format(',.1f'))
    @addChart(num, chart, data, "Avg. Diners per #{@cmty}Meal by Month")

  addCostByMonth: (num) ->
    data = [{key: 'Avg. Cost', values: @data.cost_by_month[0]}]
    chart = @lineChart().forceY([0,10])
    @setMonthXAxis(chart, data)
    chart.yAxis.axisLabel('Avg. Adult Cost per Meal').tickFormat(d3.format('$.2f'))
    @addChart(num, chart, data, "Avg. Adult Cost per #{@cmty}Meal by Month")

  addMealsByMonth: (num) ->
    data = [{key: 'Meals', values: @data.meals_by_month[0]}]
    chart = @lineChart().forceY([0,30])
    @setMonthXAxis(chart, data)
    chart.yAxis.axisLabel('Number of Meals').tickFormat(d3.format(',f'))
    @addChart(num, chart, data, "Number of #{@cmty}Meals by Month")

  addDinersByWeekday: (num) ->
    data = [{values: @data.diners_cost_by_weekday[0]}]
    chart = @barChart().forceY([0,40])
    chart.xAxis.axisLabel('Weekday').tickFormat (d) -> data[0].values[d].l
    chart.yAxis.axisLabel('Avg. Diners per Meal').tickValues([10,20,30,40]).tickFormat(d3.format(',.1f'))
    @addChart(num, chart, data, "Avg. Diners per #{@cmty}Meal by Weekday")

  addCommunityRep: (num) ->
    data = @data.community_rep
    chart = @pieChart()
    @addChart(num, chart, data, "Avg. Community Representation at #{@cmty}Meals")

  addDinerTypes: (num) ->
    data = @data.diner_types
    chart = @pieChart()
    @addChart(num, chart, data, "Avg. Diner Types at #{@cmty}Meals")

  addChart: (num, chart, data, title) ->
    $('<h5>').text(title).prependTo(@$("#chart#{num}"))
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
      .margin({top: 0, right: 0, bottom: 0, left: 0})
      .showTooltipPercent(true)
      .x((d) -> d.key)
      .y((d) -> d.y)
      .valueFormat(d3.format(',.1f'))

  setMonthXAxis: (chart, data) ->
    chart.xAxis
      .axisLabel('Month')
      .tickFormat((d) -> data[0].values[d].l) # l = Label
      .tickValues([0,3,6,9])

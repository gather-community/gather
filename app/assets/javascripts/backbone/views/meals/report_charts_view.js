Gather.Views.Meals.ReportChartsView = Backbone.View.extend({
  initialize(options) {
    this.elStr = options.el;
    this.data = options.data;
    this.cmty = options.multiCommunity ? `${options.cmty} ` : "";

    this.addServingsByMonth(1);
    this.addCostByMonth(2);
    this.addMealsByMonth(3);
    this.addServingsByWeekday(4);
    if (options.multiCommunity) {
      this.addCommunityRep(5);
    } else {
      this.addCostByWeekday(5);
    }
    this.addMealTypes(6);
  },

  addServingsByMonth(num) {
    const data = [{key: "Avg. Servings", values: this.data.servings_by_month[0]}];
    const chart = this.lineChart().forceY([0, 40]);
    this.setMonthXAxis(chart, data);
    chart.yAxis.axisLabel("Avg. Servings per Meal").tickFormat(d3.format(",.1f"));
    this.addChart(num, chart, data, `Avg. Servings per ${this.cmty}Meal by Month`);
  },

  addCostByMonth(num) {
    const data = [{key: "Avg. Cost", values: this.data.cost_by_month[0]}];
    const chart = this.lineChart().forceY([0, 8]);
    this.setMonthXAxis(chart, data);
    chart.yAxis.axisLabel("Avg. Full Meal Price").tickFormat(d3.format("$.2f"));
    this.addChart(num, chart, data, `Avg. Full ${this.cmty}Meal Price by Month`);
  },

  addMealsByMonth(num) {
    const data = [{key: "Meals", values: this.data.meals_by_month[0]}];
    const chart = this.lineChart().forceY([0, 30]);
    this.setMonthXAxis(chart, data);
    chart.yAxis.axisLabel("Number of Meals").tickFormat(d3.format(",f"));
    this.addChart(num, chart, data, `Number of ${this.cmty}Meals by Month`);
  },

  addServingsByWeekday(num) {
    const data = [{values: this.data.servings_by_weekday[0]}];
    const chart = this.barChart().forceY([0, 40]);
    chart.xAxis.axisLabel("Weekday").tickFormat(d => this.tickFormat(data, d));
    chart.yAxis.axisLabel("Avg. Servings per Meal").tickValues([10, 20, 30, 40]).tickFormat(d3.format(",.1f"));
    this.addChart(num, chart, data, `Avg. Servings per ${this.cmty}Meal by Weekday`);
  },

  addCostByWeekday(num) {
    const data = [{values: this.data.cost_by_weekday[0]}];
    const chart = this.barChart().forceY([0, 8]);
    chart.xAxis.axisLabel("Weekday").tickFormat(d => this.tickFormat(data, d));
    chart.yAxis.axisLabel("Avg. Full Meal Price").tickValues([2, 4, 6, 8]).tickFormat(d3.format("$,.2f"));
    this.addChart(num, chart, data, `Avg. Full ${this.cmty}Meal Price by Weekday`);
  },

  addCommunityRep(num) {
    const data = this.data.community_rep;
    console.log(data);
    const chart = this.pieChart();
    this.addChart(num, chart, data, `Avg. Community Representation at ${this.cmty}Meals`);
  },

  addMealTypes(num) {
    const data = this.data.meal_types;
    const chart = this.pieChart();
    console.log(data);
    this.addChart(num, chart, data, `Avg. Meal Types at ${this.cmty}Meals`);
  },

  addChart(num, chart, data, title) {
    $("<h4>").text(title).prependTo(this.$(`#chart${num}`));
    chart.showLegend(false).duration(300);
    d3.select(`#chart${num} svg`).datum(data).call(chart);
    nv.utils.windowResize(() => chart.update()); // Update the chart when window resizes.
    nv.addGraph(chart);
  },

  lineChart() {
    return nv.models.lineChart()
      .margin({top: 10, right: 10, bottom: 60, left: 60})
      .options({useInteractiveGuideline: true});
  },

  barChart() {
    return nv.models.discreteBarChart()
      .margin({top: 10, right: 10, bottom: 60, left: 60});
  },

  pieChart() {
    return nv.models.pieChart()
      .margin({top: 10, right: 0, bottom: 10, left: 0})
      .showTooltipPercent(true)
      .labelsOutside(true)
      .x(d => d.key)
      .y(d => d.y)
      .valueFormat(d3.format(",.1f"));
  },

  setMonthXAxis(chart, data) {
    return chart.xAxis
      .axisLabel("Month")
      .tickFormat(d => this.tickFormat(data, d))
      .tickValues([0, 3, 6, 9]);
  },

  tickFormat(data, d) {
    if ((d >= 0) && (d < data[0].values.length)) {
      return data[0].values[d].l; // L = Label
    } else {
      return "";
    }
  }
});

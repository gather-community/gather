Gather.Views.Meals.ReportChartsView = Backbone.View.extend({
  initialize(options) {
    this.elStr = options.el;
    this.data = options.data;
    this.cmty = options.multiCommunity ? options.cmty : null;

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
    const data = [{key: I18n.t("meals.report_charts.avg_servings"), values: this.data.servings_by_month[0]}];
    const chart = this.lineChart().forceY([0, 40]);
    this.setMonthXAxis(chart, data);
    chart.yAxis.axisLabel(I18n.t("meals.report_charts.avg_servings_per_meal")).tickFormat(d3.format(",.1f"));
    this.addChart(num, chart, data, this.title("servings_by_month"));
  },

  addCostByMonth(num) {
    const data = [{key: I18n.t("meals.report_charts.avg_cost"), values: this.data.cost_by_month[0]}];
    const chart = this.lineChart().forceY([0, 8]);
    this.setMonthXAxis(chart, data);
    chart.yAxis.axisLabel(I18n.t("meals.report_charts.avg_full_meal_price")).tickFormat(d3.format("$.2f"));
    this.addChart(num, chart, data, this.title("cost_by_month"));
  },

  addMealsByMonth(num) {
    const data = [{key: I18n.t("meals.report_charts.meals"), values: this.data.meals_by_month[0]}];
    const chart = this.lineChart().forceY([0, 30]);
    this.setMonthXAxis(chart, data);
    chart.yAxis.axisLabel(I18n.t("meals.report_charts.number_of_meals")).tickFormat(d3.format(",f"));
    this.addChart(num, chart, data, this.title("meals_by_month"));
  },

  addServingsByWeekday(num) {
    const data = [{values: this.data.servings_by_weekday[0]}];
    const chart = this.barChart().forceY([0, 40]);
    chart.xAxis.axisLabel(I18n.t("meals.report_charts.weekday")).tickFormat(d => this.tickFormat(data, d));
    chart.yAxis.axisLabel(I18n.t("meals.report_charts.avg_servings_per_meal"))
      .tickValues([10, 20, 30, 40]).tickFormat(d3.format(",.1f"));
    this.addChart(num, chart, data, this.title("servings_by_weekday"));
  },

  addCostByWeekday(num) {
    const data = [{values: this.data.cost_by_weekday[0]}];
    const chart = this.barChart().forceY([0, 8]);
    chart.xAxis.axisLabel(I18n.t("meals.report_charts.weekday")).tickFormat(d => this.tickFormat(data, d));
    chart.yAxis.axisLabel(I18n.t("meals.report_charts.avg_full_meal_price"))
      .tickValues([2, 4, 6, 8]).tickFormat(d3.format("$,.2f"));
    this.addChart(num, chart, data, this.title("cost_by_weekday"));
  },

  addCommunityRep(num) {
    const data = this.data.community_rep;
    console.log(data);
    const chart = this.pieChart();
    this.addChart(num, chart, data, this.title("community_rep"));
  },

  addMealTypes(num) {
    const data = this.data.meal_types;
    const chart = this.pieChart();
    console.log(data);
    this.addChart(num, chart, data, this.title("meal_types"));
  },

  // Chart titles name the community when the cluster has more than one.
  title(key) {
    if (this.cmty) {
      return I18n.t(`meals.report_charts.titles.${key}_community`, {community: this.cmty});
    }
    return I18n.t(`meals.report_charts.titles.${key}`);
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
      .axisLabel(I18n.t("meals.report_charts.month"))
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

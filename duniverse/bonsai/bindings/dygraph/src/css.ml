let install_css () =
  Inline_css.Private.append
    {|
/**
 * Default styles for the dygraphs charting library.
 */

.dygraph-legend {
  position: absolute;
  font-size: 14px;
  z-index: 10;
  width: 250px;  /* labelsDivWidth */
  /*
  dygraphs determines these based on the presence of chart labels.
  It might make more sense to create a wrapper div around the chart proper.
  top: 0px;
  right: 2px;
  */
  background: white;
  line-height: normal;
  text-align: left;
  overflow: hidden;
}

/* styles for a solid line in the legend */
.dygraph-legend-line {
  display: inline-block;
  position: relative;
  bottom: .5ex;
  padding-left: 1em;
  height: 1px;
  border-bottom-width: 2px;
  border-bottom-style: solid;
  /* border-bottom-color is set based on the series color */
}

/* styles for a dashed line in the legend, e.g. when strokePattern is set */
.dygraph-legend-dash {
  display: inline-block;
  position: relative;
  bottom: .5ex;
  height: 1px;
  border-bottom-width: 2px;
  border-bottom-style: solid;
  /* border-bottom-color is set based on the series color */
  /* margin-right is set based on the stroke pattern */
  /* padding-left is set based on the stroke pattern */
}

.dygraph-roller {
  position: absolute;
  z-index: 10;
}

/* This class is shared by all annotations, including those with icons */
.dygraph-annotation {
  position: absolute;
  z-index: 10;
  overflow: hidden;
}

/* This class only applies to annotations without icons */
/* Old class name: .dygraphDefaultAnnotation */
.dygraph-default-annotation {
  border: 1px solid black;
  background-color: white;
  text-align: center;
}

.dygraph-axis-label {
  /* position: absolute; */
  /* font-size: 14px; */
  z-index: 10;
  line-height: normal;
  overflow: hidden;
  color: black;  /* replaces old axisLabelColor option */
}

.dygraph-axis-label-x {
}

.dygraph-axis-label-y {
}

.dygraph-axis-label-y2 {
}

.dygraph-title {
  font-weight: bold;
  z-index: 10;
  text-align: center;
  /* font-size: based on titleHeight option */
}

.dygraph-xlabel {
  text-align: center;
  /* font-size: based on xLabelHeight option */
}

/* For y-axis label */
.dygraph-label-rotate-left {
  text-align: center;
  /* See http://caniuse.com/#feat=transforms2d */
  transform: rotate(90deg);
  -webkit-transform: rotate(90deg);
  -moz-transform: rotate(90deg);
  -o-transform: rotate(90deg);
  -ms-transform: rotate(90deg);
}

/* For y2-axis label */
.dygraph-label-rotate-right {
  text-align: center;
  /* See http://caniuse.com/#feat=transforms2d */
  transform: rotate(-90deg);
  -webkit-transform: rotate(-90deg);
  -moz-transform: rotate(-90deg);
  -o-transform: rotate(-90deg);
  -ms-transform: rotate(-90deg);
}
|}
;;

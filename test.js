var lastTime=0.0
var data=null

function getData(){
    var xmlhttp = new XMLHttpRequest()
    xmlhttp.onreadystatechange=function()
    {
	if (xmlhttp.readyState==4 && xmlhttp.status==200)
	{
	    document.getElementById("data").innerHTML=xmlhttp.responseText
	    data=JSON.parse(xmlhttp.responseText)
	    //!@todo sort data on client
	    for(var k in data){
		if(data.hasOwnProperty(k)){
		    l = data[k].length
		    if(l > 1){
			lastTime = Math.max(data[k][l-2][0], lastTime)
		    }
		}
	    }
	}
    }
    xmlhttp.open("GET","/cgi-bin/test?t=".concat(lastTime),true)
    xmlhttp.send()
}

function drawChart() {
    var data = google.visualization.arrayToDataTable([
	['Year', 'Sales', 'Expenses'],
	['2013',  1000,      400],
	['2014',  1170,      460],
	['2015',  660,       1120],
	['2016',  1030,      540]
    ]);

    var options = {
	title: 'Company Performance',
	hAxis: {title: 'Year',  titleTextStyle: {color: '#333'}},
	vAxis: {minValue: 0}
    };

    var chart = new google.visualization.AreaChart(document.getElementById('myChart'));
    chart.draw(data, options);
}

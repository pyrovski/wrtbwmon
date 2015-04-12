var lastTime = new Date(0)
var data=null

function compareEntries(a, b){
    return (a[0] >= b[0] ? (a[0] == b[0] ? 0 : 1) : -1)
}

if (!Array.prototype.last){
    Array.prototype.last = function(){
	return this[this.length - 1]
    }
}

function getData(){
    var xmlhttp = new XMLHttpRequest()
    xmlhttp.onreadystatechange=function()
    {
    	if (xmlhttp.readyState==4 && xmlhttp.status==200){
    	    document.getElementById("data").innerHTML=xmlhttp.responseText
    	    data=JSON.parse(xmlhttp.responseText)
	    for(var k in data){
	    	if(data.hasOwnProperty(k)){
	    	    l = data[k].length
	    	    if(l > 1){
	    		data[k] = data[k].slice(0,l-1).sort(compareEntries)
	    		for(var i = 0; i < data[k].length; i++)
	    		    data[k][i][0] = new Date(data[k][i][0] * 1000)
	    		lastTime = new Date(Math.max(data[k].last()[0], lastTime))
	    	    } else
	    		data[k] = [[]]
	    	}
	    }
	    if(data["192.168.1.139"].length > 1){
		var chart = new google.visualization.AreaChart(document.getElementById('myChart'));
		dt = [["time","in","out"]].concat(data["192.168.1.139"]).slice(0,data["192.168.1.139"].length)
		console.debug(dt)
		dt = google.visualization.arrayToDataTable(dt)
		
		chart.draw(dt)
	    }
    	}
    }
    xmlhttp.open("GET","/cgi-bin/test?t=".concat(lastTime.getTime()/1000),true)
    xmlhttp.send()
}

function drawChart() {
    var data2 = google.visualization.arrayToDataTable([
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
    chart.draw(data2, options);
}

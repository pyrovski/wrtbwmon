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

function parseData(textData, data){
    newData = JSON.parse(textData)
    var compacted = {}
    for(var key in newData){
	if(newData.hasOwnProperty(key)){
	    var keySplit = key.split(':')
	    var host = keySplit[0]
	    l = newData[key].length
	    if(l > 1){
		newData[key] = newData[key].slice(0,l-1)
	    	for(var i = 0; i < newData[key].length; i++)
	    	    newData[key][i][0] = new Date(newData[key][i][0] * 1000)
	    } else
	    	newData[key] = [[]]
	    if(host in compacted)
		compacted[host] = compacted[host].concat(newData[key])
	    else
		compacted[host] = newData[key]
	}
    }
    if(data == null)
	data = {}
	
    newData = data
    for(var host in newData)
	if(newData.hasOwnProperty(host)){
	    if(host in compacted){
		newData[host] =
		    newData[host].concat(compacted[host]).sort(compareEntries)
		lastTime =
		    new Date(Math.max(compacted[host].last()[0], lastTime))
		delete compacted[host]
	    }
	}
    for(var host in compacted)
	if(host != undefined && compacted.hasOwnProperty(host))
	    newData[host] = compacted[host].sort(compareEntries)
    return newData
}

function getData(){
    var xmlhttp = new XMLHttpRequest()
    xmlhttp.onreadystatechange=function()
    {
    	if (xmlhttp.readyState==4 && xmlhttp.status==200){
    	    data = parseData(xmlhttp.responseText, data)
    	    //document.getElementById("data").innerHTML=JSON.stringify(data)
	    if("192.168.1.139" in data && data["192.168.1.139"].length > 1){
		var chart = new google.visualization.AreaChart(document.getElementById('myChart'));
		//!@todo format data into bytes/s instead of bytes, plot rectangles instead of trapezoids
		dt = [["time","in","out"]].concat(data["192.168.1.139"]).slice(0,data["192.168.1.139"].length)
		dt = google.visualization.arrayToDataTable(dt)
		
		chart.draw(dt)
	    } else {
		document.getElementById('myChart').innerHTML="no data for 192.168.1.139"
	    }
    	}
    }
    xmlhttp.open("GET",
		 "/cgi-bin/test?t=".concat(lastTime.getTime()/1000),
		 true)
    xmlhttp.send()
}

var lastTime = new Date(0)
var data=null

function copy(obj){
    return JSON.parse(JSON.stringify(obj))
}

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
	    }
	    if(l > 1){
		if(host in compacted)
		    compacted[host] = compacted[host].concat(newData[key])
		else
		    compacted[host] = newData[key]
	    }
	}
    }
    if(data == null)
	data = {}
	
    newData = data
    for(var host in newData)
	if(newData.hasOwnProperty(host)){
	    if(host in compacted){
		newData[host] =
		    newData[host].concat(compacted[host].sort(compareEntries))
		delete compacted[host]
	    }
	}
    for(var host in compacted)
	if(host != undefined && compacted.hasOwnProperty(host))
	    newData[host] = compacted[host].sort(compareEntries)
    for(var host in newData)
	if(newData.hasOwnProperty(host) && newData[host].length > 0){
	    lastTime =
		new Date(Math.max(newData[host].last()[0], lastTime))
	    // remove duplicate timestamps (mostly zeros?)
	    newData[host] = newData[host].filter(function(v,i,a){
		return i == 0 || a[i-1][0].getTime() != a[i][0].getTime()
	    })
	}
    return newData
}

function getData(){
    var xmlhttp = new XMLHttpRequest()
    xmlhttp.onreadystatechange=function()
    {
    	if (xmlhttp.readyState==4 && xmlhttp.status==200){
	    oldLastTime = lastTime
	    data = parseData(xmlhttp.responseText, data)
	    if(oldLastTime.getTime() == 0){
		oldLastTime = Infinity
		for(var host in data)
		    if(data.hasOwnProperty(host))
			oldLastTime = new Date(Math.min(data[host][0][0], oldLastTime))
	    }
	    document.getElementById("data").innerHTML="got " + (lastTime - oldLastTime)/1000 + " s of data"

	    if("192.168.1.139" in data && data["192.168.1.139"].length > 1){
		var chart = new google.visualization.AreaChart(document.getElementById('myChart'));
		//!@todo format data into bytes/s instead of bytes, plot rectangles instead of trapezoids
		hostData = data["192.168.1.139"]
		bars = []
		for(i = 1; i < hostData.length; i++){
		    endBar = copy(hostData[i])
		    endBar[0] = new Date(endBar[0])
		    startTime = new Date(hostData[i-1][0])
		    tDiff = (endBar[0] - startTime)/1000
		    endBar[1]/=tDiff
		    endBar[2]/=tDiff
		    startBar = copy(endBar)
		    startBar[0] = startTime
		    bars.push(startBar)
		    bars.push(endBar)
		}
		dt = [["time","in","out"]].concat(bars)
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

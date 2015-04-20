var lastTime = new Date(0)
var data = null
var selectedHost = null
var auto = false
var interval = null

function pause(obj){
    if(arguments.length > 0){
	switch(obj.innerHTML){
	    //!@todo fix
	case "Pause":
	    obj.innerHTML = "Resume"
    	    window.clearInterval(interval)
	    auto = false
	    break;
	case "Resume":
	    obj.innerHTML = "Pause"
	    window.setInterval(getData, 2000)
	    auto = true
	    break;
	}
    } else {
	if(interval != null)
    	    window.clearInterval(interval)
	auto = false
    }
}

function toBars(hostData){
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
    return bars
}

function copy(obj){
    return JSON.parse(JSON.stringify(obj))
}

function compareEntries(a, b){
    if(a[0] > b[0])
	return 1
    if(a[0] < b[0])
	return -1
    if(a[1] && !b[1] || a[2] && !b[2])
	return 1
    if(!a[1] && b[1] || !a[2] && b[2])
	return -1
    // times are equal, but traffic data may not be
    return 0
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
		return i == a.length-1 || a[i+1][0].getTime() != a[i][0].getTime()
	    })
	}
    return newData
}

function drawChart(host){
    selectedHost = host
    if(host in data && data[host].length > 1){
	var chart = new google.visualization.AreaChart(document.getElementById('myChart'));
	bars = toBars(data[host])
	dt = [["time","in","out"]].concat(bars)
	dt = google.visualization.arrayToDataTable(dt)

	var options = {explorer:{}} // hAxis:{logScale:true}
	chart.draw(dt, options)
    } else {
	document.getElementById('myChart').innerHTML="no data for " + host
    }
    if(!auto){
	interval = window.setInterval(getData, 2000)
	auto=true
    }
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
			oldLastTime = new Date(Math.min(data[host][0][0],
							oldLastTime))
	    }
	    if(selectedHost != null)
		drawChart(selectedHost)
	    hosts=[]
	    for(var host in data)
		if(data.hasOwnProperty(host))
		    hosts.push(host)
	    hostsString = ""
	    for(i = 0; i < hosts.length; i++){
		hostsString += "<option value=\"" + hosts[i] + "\""
		if(selectedHost == hosts[i])
		    hostsString += " selected"
		hostsString += ">" + hosts[i] + "</option>"
	    }
	    //!@todo avoid unselecting previous selection when new data is loaded
	    // redraw chart for the selected host when loading new data
	    activeElement = document.activeElement
	    var selectActive = activeElement.id == "select"
	    document.getElementById("hosts").innerHTML =
		"<select onchange=\"drawChart(this.value)\" " +
		" id=\"select\">"+ 
		hostsString+
		"</select>"
	    if(selectActive)
		document.getElementById("select").focus()
	    document.getElementById("data").innerHTML=
		"got " + (lastTime - oldLastTime)/1000 + " s of data"
    	}
    }
    xmlhttp.open("GET",
		 "/cgi-bin/test?t=".concat(lastTime.getTime()/1000),
		 true)
    xmlhttp.send()
}

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

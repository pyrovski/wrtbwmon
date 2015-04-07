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
var data2 = {
    labels: ["January", "February", "March", "April", "May", "June", "July"],
    datasets: [
	{
	    label: "My First dataset",
	    fillColor: "rgba(220,220,220,0.2)",
	    strokeColor: "rgba(220,220,220,1)",
	    pointColor: "rgba(220,220,220,1)",
	    pointStrokeColor: "#fff",
	    pointHighlightFill: "#fff",
	    pointHighlightStroke: "rgba(220,220,220,1)",
	    data: [65, 59, 80, 81, 56, 55, 40]
	},
	{
	    label: "My Second dataset",
	    fillColor: "rgba(151,187,205,0.2)",
	    strokeColor: "rgba(151,187,205,1)",
	    pointColor: "rgba(151,187,205,1)",
	    pointStrokeColor: "#fff",
	    pointHighlightFill: "#fff",
	    pointHighlightStroke: "rgba(151,187,205,1)",
	    data: [28, 48, 40, 19, 86, 27, 90]
	}
    ]
};

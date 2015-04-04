function getData(){
    var xmlhttp = new XMLHttpRequest()
    xmlhttp.onreadystatechange=function()
    {
	if (xmlhttp.readyState==4 && xmlhttp.status==200)
	{
	    document.getElementById("data").innerHTML=xmlhttp.responseText;
	}
    }
    xmlhttp.open("GET","/cgi-bin/test",true)
    xmlhttp.send()
}

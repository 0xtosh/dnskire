
if (document.getElementById('formAjax') && document.getElementById('fileAjax')) {
   var myForm = document.getElementById('formAjax');
   var myFile = document.getElementById('fileAjax');
   var updatestatus = document.getElementById('updatestatus'); 

   myForm.onsubmit = function(event) {
   event.preventDefault();
    
   updatestatus.innerHTML = '<br><br><br>&nbsp;&nbsp;&nbsp;Processing...<br><div class=\"loader\"><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span></div>';

    var protocol = "udptcp"; // we default to udp+tcp
    if (document.getElementsByName('protocol')[1].checked) {  // if udp selected use that, if not we default to udp+tcp
       protocol = "udp";
    }
    else {
       protocol = "udptcp";
    }
    var files = myFile.files;
    var file = files[0];
    let domain = document.getElementById('domain').value;
    let subdomain = document.getElementById('subdomain').value;

    if (!file || !domain || !subdomain) {
       updatestatus.innerHTML = '<span class=\"is-error fadeOut\">' + "Missing<br>input!" + '</span>';
       return;
    }
    else {
      var formData = new FormData();
      formData.append('fileAjax', file, file.name);
      formData.append('domain', domain);
      formData.append('subdomain', subdomain);
      formData.append('protocol', protocol);
      
      var xhr = new XMLHttpRequest();
      xhr.open('POST', '/upload', true);

      xhr.onload = function () {
        if (xhr.status == 200) {
          updatestatus.innerHTML = '<span class=\"is-success fadeOut\">Added!</span>';
        } else {
          updatestatus.innerHTML = '<span class=\"is-error fadeOut\">' + xhr.responseText + '</span>';
        }
      };

      xhr.send(formData);
    }    
  }  
}


if (document.getElementById('editconfigformAjax')) {
    var myDomainForm = document.getElementById('editconfigformAjax');
    var updatestatus = document.getElementById('updatestatus');
    myDomainForm.onsubmit = function(event) {
    event.preventDefault();
    updatestatus.innerHTML = '<br><br><br>&nbsp;&nbsp;&nbsp;Processing...<br><div class=\"loader\"><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span><span class=\"loader-block\"></span></div>';
    var formDomainData = new FormData();
    let domains = document.getElementById('domains').value;
    formDomainData.append('domains', domains);
    var xhr2 = new XMLHttpRequest();
    xhr2.open('POST', '/setdomains', true);
    xhr2.onload = function () {
      if (xhr2.status == 200) {
        updatestatus.innerHTML = '<span class=\"is-success fadeOut\">Updated!</span>';
      } else {
        updatestatus.innerHTML = '<span class=\"is-error fadeOut\">Failed! ' + xhr2.responseText + '</span>';
      }
    };
    xhr2.send(formDomainData);
   }
}

function getfilename(myFile){
  var file = myFile.files[0];
  var filename = file.name;
  uploadfile.innerHTML = filename;
}

function resetwarning(){
  var resetqresult = confirm("Sure? This will reset the database and delete all file entries?");
  if (resetqresult) {
    location.href='/reset';
  }
}


function deleteit(delid){
    var xmlhttp;
    if(window.XMLHttpRequest){
        xmlhttp = new XMLHttpRequest();
    }
    else {
        xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    }

    xmlhttp.onreadystatechange = function(){
        if(xmlhttp.readyState == 4){
	      window.location.reload()
        }
    }
    const data = new FormData();
    data.append('id', delid); 
    xmlhttp.open("POST", "/delete/", true);
    xmlhttp.send(data);
}


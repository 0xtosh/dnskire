console.log("");
console.log("██████╗ ███╗   ██╗███████╗██╗  ██╗██╗██████╗ ███████╗");
console.log("██╔══██╗████╗  ██║██╔════╝██║ ██╔╝██║██╔══██╗██╔════╝");
console.log("██║  ██║██╔██╗ ██║███████╗█████╔╝ ██║██████╔╝█████╗  ");
console.log("██║  ██║██║╚██╗██║╚════██║██╔═██╗ ██║██╔══██╗██╔══╝  ");
console.log("██████╔╝██║ ╚████║███████║██║  ██╗██║██║  ██║███████╗");
console.log("╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════");
console.log("├─ https://github.com/0xtosh/dnskire ─ 2022 ────────");
console.log("│");

const PORT = 8081;

var express = require('express');
var app = express();
const isAlphanumeric = require('is-alphanumeric');
const DNSZONEFILEDIR="/etc/bind/zones/"; // needs trailing slash!
const dbFile = "./db/dnskire.db";
const uploadDir = "./uploads/";
const https = require('https')
const url = require('url');
const isValidDomain = require('is-valid-domain')
const cors = require('cors');
const bodyParser = require('body-parser');
const filesize = require('filesize');
const fileUpload = require('express-fileupload');
const fs = require("fs");
const logfs = require('fs');
const path = require('path');
const bindip = require("ip");
const sqlite3 = require("sqlite3").verbose();
const exists = fs.existsSync(dbFile);
const db = new sqlite3.Database(dbFile);
const logfile = "dnskire.log";
const MaximumFileSize    = 52428800; // File size maximum UDP+TCP - 50M default
const MaximumFileSizeUDP = 10485760; // File size maximum UDP only - 10M default

// check for sqlite3 db and tables, if any of the two don't exist then create them
createfreshtablesifnone();

app.use(fileUpload({
    createParentPath: true
}));

app.use(cors());
app.use(bodyParser.urlencoded({extended: true}));
app.use(express.static('public'));
app.use(express.static('uploads'));
app.use('/favicon.ico', express.static('./public/images/favicon.ico'));

// Replace bindip.address() with a static string for your custom IP
https.createServer({
  key: fs.readFileSync('./certs/dnsKIRE.local.key'),
  cert: fs.readFileSync('./certs/dnsKIRE.local.crt')
}, app).listen(PORT, bindip.address(), () => {
  console.log("└─ Ready to chop! Go to https://" + bindip.address() + ":" + PORT + "\n");
  logfs.appendFileSync(logfile, 'dnsKIRE started!\n');
})

async function execShellCommand(incmd) {
 const exec = require('child_process').exec;
 return new Promise((resolve, reject) => {
  exec(incmd, (error, stdout, stderr) => {
   if (error) {
    console.warn(error);
   }
   resolve(stdout? stdout : stderr);
  });
 });
}

async function db_all(query){
    return new Promise(function(resolve,reject){
        db.all(query, function(err,rows){
           if(err){return reject(err);}
           resolve(rows);
         });
    });
}


async function istaken(istakensubdomain, istakendomain) {
      let istakenrows = await db_all(`SELECT Subdomain from files where SUBDOMAIN = "${istakensubdomain}" AND DOMAIN = "${istakendomain}"`);
      if (!istakenrows.length) {
        return "ok"; 
      }
      else { 
        return "double";
      }
}

async function haveid(dbid) {
  if (Number(dbid)) {
    let haveit = await db_all(`SELECT Slotid FROM files where Slotid = "${dbid}"`);
    if (haveit.length == 0) { 
      return false;
    }
    else {
      return true;
    }
  }
  else {
    return false;
  }
}

async function adddomain(newdomain) {
  new Promise(resolve => {
      db_all(`INSERT INTO domains VALUES(null,"${newdomain}")`);
      });
}

async function deldomain(newdeldomain) {
  new Promise(resolve => {
      db_all(`DELETE FROM domains WHERE Domain = "${newdeldomain}"`);
      });
}

async function deldomainentries(newdeldomainentries) {
  new Promise(resolve => {
      db_all(`DELETE FROM files WHERE Domain = "${newdeldomainentries}"`);
      });
}

async function resetdb() {
  new Promise(resolve => {
      db_all(`DELETE FROM files`);
      db_all(`DELETE FROM domains`);
      });
}

async function createdb() {
  new Promise(resolve => {
      db_all(`CREATE TABLE domains (Domainid INTEGER PRIMARY KEY,Domain varchar(255))`);
      db_all(`CREATE TABLE files (Slotid INTEGER PRIMARY KEY AUTOINCREMENT,Subdomain varchar(255),Domain varchar(255),Filename varchar(255),Slices INTEGER,Size varchar(255),Webpath varchar(255),Protocol varchar(6))`);
      });
}

async function createfreshtablesifnone() {
  new Promise(resolve => {
      db_all(`CREATE TABLE if not exists domains (Domainid INTEGER PRIMARY KEY,Domain varchar(255))`);
      db_all(`CREATE TABLE if not exists files (Slotid INTEGER PRIMARY KEY AUTOINCREMENT,Subdomain varchar(255),Domain varchar(255),Filename varchar(255),Slices INTEGER,Size varchar(255),Webpath varchar(255),Protocol varchar(6))`);
      });
}

app.post('/upload', async function (req, res) {
        if(!req.files.fileAjax || !req.body.subdomain || !req.body.domain || !req.body.protocol) {
           res.status(500).send("Missing<br>input!");
        }
	else if(!(isAlphanumeric(req.body.subdomain))) {
           res.status(500).send("Only 0-9 a-z!");
        }
	else if(!(req.body.protocol == "udp" || req.body.protocol == "udptcp")) {
           res.status(500).send("Protocol error!");
        }
	else if((req.body.protocol == "udp" && req.files.fileAjax.size > MaximumFileSizeUDP)) {
           res.status(500).send("Too big for UDP only!");
        }
	else if((req.body.subdomain.length > 63)) {
           res.status(500).send("Max 63 chars!");
        }
	else if((req.files.fileAjax.size > MaximumFileSize)) {
           res.status(500).send("File max " + (MaximumFileSize / (1024*1024)).toFixed(0) + "MB");
        }
	else if((req.files.fileAjax.size == 0)) {
           res.status(500).send("Empty file!");
        }
        else {
            let subdomain = req.body.subdomain;
            let domain = req.body.domain;
            let protocol = req.body.protocol;

            //name of html input fields
            var slipfile = req.files.fileAjax;
            var size = slipfile.size;
	    var maxfilenamelen = 100; // max filename size is 100 chars for practical reasons

	    // sanitize filename
	    slipfile.name = slipfile.name.replace(/[^a-zA-Z0-9 ._-]/g, ""); // sanitize filename
            slipfile.name = slipfile.name.replace(/ /g, "_");
            slipfile.name = slipfile.name.substring(0, maxfilenamelen);

            // check for doubles
            let checkrows = await db_all(`SELECT domain from files where SUBDOMAIN = "${subdomain}" AND DOMAIN = "${domain}"`);

            if(checkrows.length == 0) {
              // we don't have it yet, we better add it
              let uuid = require('uuid');
              let dir = '/' + uuid.v4();
              dirpath = './uploads' + dir;

              fs.mkdirSync(dirpath);
              uploadpath = dirpath + '/' + slipfile.name;
              Webpath = '/' + dir + '/' + slipfile.name;

              slipfile.mv(uploadpath, function (err) {

                if (err) {
                    res.status(500).send("File move failed!");
                }
                else {
                  (async() => {
		      var transport = "udptcp";
		      if(protocol == "udp") {
		         transport = "udp";
		      }
		      // mkzoneslices.sh launches rndc reload DOMAIN
                      let makeitcmd = './scripts/mkzoneslices.sh \"' + slipfile.name + '\" ' + domain + ' ' + subdomain + ' ' + dirpath + ' ' + transport;

                      function runcmd(cmd) {
                        return execShellCommand(cmd);
                      }
      
		      let slices = await runcmd(makeitcmd);
                      slices.replace(/[\n\r]/g, '');
                      let ret = await db_all(`INSERT INTO files VALUES(null,"${subdomain}","${domain}","${slipfile.name}","${slices}","${size}","${dir}","${protocol}")`);
	              let date_ob = new Date();
                      let date = ("0" + date_ob.getDate()).slice(-2);
                      let month = ("0" + (date_ob.getMonth() + 1)).slice(-2);
                      let year = date_ob.getFullYear();
                      let hours = ("0" + (date_ob.getHours() + 1)).slice(-2);
                      let minutes = ("0" + (date_ob.getMinutes() + 1)).slice(-2);
                      let seconds = ("0" + (date_ob.getSeconds() + 1)).slice(-2);

                      console.log(`${year}-${month}-${date}-${hours}:${minutes}:${seconds} Added "${slipfile.name}" into "${subdomain}.${domain}" with ${slices} slice(s) using ${protocol} and ${size} bytes`);
		      logfs.appendFileSync(logfile, `${year}-${month}-${date}-${hours}:${minutes}:${seconds} Added "${slipfile.name}" into "${subdomain}.${domain}" with ${slices} slice(s) using ${protocol} and ${size} bytes\n`);
                      res.status(200).send("ok");
                    
                  })();
                }
              });
            }
            else {
              res.status(500).send("Already<br>exists!");
            }
      }
});

app.get('/', async function (req, res) {
  res.redirect('/files');
});

async function deldir(delpath){
  fs.rmdir(delpath, { recursive: true }, (err) => {
    if (err) {
      console.error(err);
    }
  });
}

app.get('/reset', async function (req, res) {

  let zonepath   = DNSZONEFILEDIR;	
  let uploadpath = uploadDir;	
  
  let date_ob = new Date();
  let date = ("0" + date_ob.getDate()).slice(-2);
  let month = ("0" + (date_ob.getMonth() + 1)).slice(-2);
  let year = date_ob.getFullYear();
  let hours = ("0" + (date_ob.getHours() + 1)).slice(-2);
  let minutes = ("0" + (date_ob.getMinutes() + 1)).slice(-2);
  let seconds = ("0" + (date_ob.getSeconds() + 1)).slice(-2);

  console.log(`${year}-${month}-${date}-${hours}:${minutes}:${seconds} Resetting database and removing files`);
  logfs.appendFileSync(logfile, `${year}-${month}-${date}-${hours}:${minutes}:${seconds} Resetting database and removing files\n`);	

  // drop FILES and DOMAINS tables from database
  resetdb();

  // remove all the .inc and zone files from the bind zones directory
  fs.readdir(DNSZONEFILEDIR, (err, rmfiles) => {
  if (err) throw err;

  for (const rmfile of rmfiles) {
    fs.unlink(path.join(DNSZONEFILEDIR, rmfile), err => {
      if (err) throw err;
    });
  }
});

  // replace named.conf.local with a new file. nasty.
  fs.open('/etc/bind/named.conf.local', 'w', (err, file) => {
    if (err) {
        throw err;
    }
  });

  // remove all the uploaded files from all generated directories
  fs.readdir(uploadpath, function (err, files) {
      if (err) {
          return console.log('Unable to scan directory: ' + err);
      }
      files.forEach(function (file) {
        try {
              deldir(uploadpath + file);
        } catch (err) {
            console.error("Error while deleting " + file);
        }
      });
  });
  
  function runcmd(cmd) {
     return execShellCommand(cmd);
  }
 
  var reloadcmd = 'rndc reconfig';
  var reloadcmdret = runcmd(reloadcmd);
  res.redirect('/config');
});

function htmlheader(res){
	res.write(`
        <html>
        <head>
          <meta content=\"text/html;charset=utf-8\" http-equiv=\"Content-Type\">
          <meta content=\"utf-8\" http-equiv=\"encoding\">
          <link rel=\"shortcut icon\" href=\"/favicon.ico\">
        </head>
        <body>
          <link href=\"/css/PressStart2P.css\" rel=\"stylesheet\">
          <link href=\"/css/nes.css\" rel=\"stylesheet\" />
          <link href=\"/css/style.css\" rel=\"stylesheet\" />
          <script type=\"text/javascript\" src=\"/js/crunch.js\" defer></script>

          <div class=\"content is-centered\" style=\"display: flex;\">

           <div style="margin: 10px 0 20px 0;"></div>
	   <h2><section><img src=\"/images/katana.png\" border=\"0\">dnsKIRE</section></h2>
           <div style="margin: 10px 0 30px 0;"></div>
        `);
}

app.get('/add', async function (req, res) {

await htmlheader(res);
res.write(`
          <section class="topic">
           <div class=\"nes-container is-centered\">
             <a href=\"/add\"><button class=\"nes-btn is-warning\">Add File</button></a>
             <a href=\"/files\"><button class=\"nes-btn\">Loaded Files</button></a>
             <a href=\"/config\"><button class=\"nes-btn\">Domains</button></a>
           </div>
	  </section>
	   <div style="margin: 10px 0 30px 0;"></div>
           <section class=\"nes-container with-title is-centered\">
            <h3 class=\"title\">Load File Into Zone</h3> 
            <div id=\"tables\" class=\"item\">  
              <br>
        `);              
              let domainrows = await db_all("SELECT Domain FROM domains");
              if(domainrows.length != 0) {

                res.write(`
                    <form action=\"/upload\" id=\"formAjax\" name=\"formAjax\" enctype=\"multipart/form-data\" method=\"POST\">
                      <div class=\"form-group is-centered\" style=\"text-align: left;\">
                        <label for=\"subdomain\">Create subdomain</label>
                        <br>
                        <input type=\"text\" class=\"form-control nes-input\" id=\"subdomain\" name=\"subdomain\" alt=\"Enter the desired subdomain e.g. cdn-serv1.domain.com\" placeholder=\"Enter subdomain\">
                        <br><br>
                        <label for=\"domain\">Select domain</label>
                        <div class=\"nes-field is-inline\">
                          <div class=\"nes-select\">
                            <select alt=\"Select the domain\" name=\"domain\" id=\"domain\">
                `);
                              domainrows.forEach(function (domainrow) {
                                 res.write(`<option value=\"${domainrow.Domain}\">${domainrow.Domain}</option>`);
                              });

                res.write(`              
                            </select>
                          </div>
                        </div>
                        <br>
			<div align="center">
			<label><input type="radio" class="nes-radio" name="protocol" value="udptcp" checked="checked"><span>UDP+TCP</span></input></label>
		        <label><input type="radio" class="nes-radio" name="protocol" value="udp"><span>UDP Only</span></input></label>
			</div>
			<br>
			<div align="center">
                        <label class=\"nes-btn is-warning\">
                          <span alt=\"Select the file you want to transfer over DNS\">Select File</span>
                          <input onchange=\"getfilename(this);\" type=\"file\" id=\"fileAjax\" name=\"fileAjax\">
                        </label> 
			  <br><br><div id=\"uploadfile\"></div>
			</div>
                      </div>
                      <br><br>
                      <button type=\"submit\" name=\"submit\" class=\"nes-btn is-primary\">Upload</button>
                    </form>
                `);
              }
              else {
                res.write("<br><br><br><br><div>You haven't added any domains yet. Add a domain first.</div><br><br><br><a href=\"/config\"><button class=\"nes-btn is-primary\">Add Domain</button></a><br>");
              }
              res.write(`
                    <br>
                  </div>
                 </section>
		 <br>
		 <span class=\"nes-badge\">
                    <div id=\"updatestatus\"></div>
                  </span>
                </div>
		<br><br><br>

                  <div id="footer">
                <div id="footerContainer">
                  <div id="grass"></div>
                </div>
                  <div id="samurai">
                    <img src="/images/samurai.gif" width="200" height="107">
                  </div>
                  <div id="lantern">
                    <img src="/images/lantern.png" width="306" height="72">
                  </div>
<section class="nes-container">
  <section class="message-list">
  <section class="message -left">
    <div class="nes-balloon from-left">
      <p>Remember to encrypt your files</p>
    </div>
  </section>
  </section>
</section>
              </div>
               <div id="credits">
                   <span class="nes-text is-disabled" style="font-size: 12px;">dnsKIRE <a href="https://github.com/0xtosh/dnskire"><span class="nes-icon github is-small"></a> <a href="https://twitter.com/0xtosh/"><span class="nes-icon twitter is-small"></span></a> </a></a></span>
                 </div>
               </div>
             </body>
           </html>
             `);
res.end();
});


app.post('/delete', async function (req, res)  {
        if(!req.body.id) {
            res.sendStatus(500);
        } 
	else if(await haveid(req.body.id) === false) {
	    res.status(500).send("Invalid ID!");
	}
	else {
          let date_ob = new Date();
          let date = ("0" + date_ob.getDate()).slice(-2);
          let month = ("0" + (date_ob.getMonth() + 1)).slice(-2);
          let year = date_ob.getFullYear();
          let hours = ("0" + (date_ob.getHours() + 1)).slice(-2);
          let minutes = ("0" + (date_ob.getMinutes() + 1)).slice(-2);
          let seconds = ("0" + (date_ob.getSeconds() + 1)).slice(-2);
          let killid = req.body.id;
          let killwebpaths = await db_all(`SELECT Filename, Domain, Subdomain, Webpath FROM files where Slotid = "${killid}"`);

	  killwebpaths.forEach(function (killrow) {
	    // remove the original and generated files
	    let killwebpath = './uploads' + killrow.Webpath;
	    deldir(killwebpath);

	    function runcmd(cmd) {
              return execShellCommand(cmd);
            }

            let removezonecmd = './scripts/rmzoneslices.sh ' + killrow.Domain + ' ' + killrow.Subdomain;
            let removezonecmdstatus = runcmd(removezonecmd);
            console.log(`${year}-${month}-${date}-${hours}:${minutes}:${seconds} Removed "${killrow.Filename}" for "${killrow.Subdomain}.${killrow.Domain}"`);
	    logfs.appendFileSync(logfile, `${year}-${month}-${date}-${hours}:${minutes}:${seconds} Removed "${killrow.Filename}" for "${killrow.Subdomain}.${killrow.Domain}"\n`); 
          });

          // delete the subdomain entry from the database
	  let delret = await db_all(`DELETE FROM files WHERE Slotid = ${killid}`);
          res.sendStatus(200);
        }
});

app.get('/files', async function (req, res) {

await htmlheader(res);
res.write(`
	   <section class="topic">
           <div class=\"nes-container is-centered\">
             <a href=\"/add\"><button class=\"nes-btn\">Add File</button></a>
             <a href=\"/files\"><button class=\"nes-btn is-warning\">Loaded Files</button></a>
             <a href=\"/config\"><button class=\"nes-btn\">Domains</button></a>
           </div>
	   </section>

           <div style="margin: 10px 0 30px 0;"></div> 

         <div class="form-group is-centered">
          <section class="nes-container with-title is-centered">
            <h3 class="title">Active Files</h3> 

         `);

          let rows = await db_all("SELECT Slotid, Domain, Subdomain, Filename, Size, Slices, Webpath, Protocol FROM files");
          if(rows.length != 0) {

            res.write(`<table class="nes-table is-bordered is-centered">
              <thead>
                <tr>
                  <th style="text-align: left; font-size: 13px;">Domain</th>
                  <th style="text-align: left; font-size: 13px;">Filename</th>
                  <th style="text-align: center; font-size: 13px;">Size</th>
                  <th style="text-align: center; font-size: 13px;">Requests</th>
                  <th style="text-align: center; font-size: 13px;">Method</th>
                  <th style="text-align: left; font-size: 13px;">File Fetchers</th>
                  <th style="text-align: center; font-size: 13px;">Delete</th>
                </tr>
              </thead>
              <tbody>
            `);
            
            rows.forEach(function (row) {
               let humansize = filesize(row.Size);
	       let humanprotocol = "";
	       if (row.Protocol == "udp") {
	          humanprotocol = "udp only";
	       }
	       else if (row.Protocol == "udptcp") {
	          humanprotocol = "udp+tcp";
	       }
               res.write(`<tr>
		<td style="text-align: left; vertical-align: top;"><a href='${row.Webpath}/${row.Filename}.subs.txt'>${row.Subdomain}.[subs].${row.Domain}</a></td>
                <td style="text-align: left; vertical-align: top;"><a href='${row.Webpath}/${row.Filename}'>${row.Filename}</a></td>
                <td style="text-align: center; vertical-align: top;">${humansize}</td>
                <td style="text-align: center; vertical-align: top;">${row.Slices}</td>
                <td style="text-align: center; vertical-align: top;">${humanprotocol}</td>
		<td>
                   <a href=\"${row.Webpath}/get-${row.Subdomain}.${row.Domain}.ps1\" class=\"nes-btn is-primary\" style=\" font-size: 13px;\"><img src=\"/images/term.png\"> .ps1</a>
                   <a href=\"${row.Webpath}/ducky-ps-${row.Subdomain}.${row.Domain}.txt\" class=\"nes-btn is-warning\"><img src=\"/images/duckicon.png\"></a>
                   <a href=\"${row.Webpath}/ps-${row.Subdomain}.${row.Domain}.png\" class=\"nes-btn is-success\"><img src=\"/images/cat.png\"></a>
                   <br>
                   <a href=\"${row.Webpath}/get-${row.Subdomain}.${row.Domain}.vbs\" class=\"nes-btn is-primary\" style=\" font-size: 13px;\"><img src=\"/images/term.png\"> .vbs</a>
                   <a href=\"${row.Webpath}/ducky-vbs-${row.Subdomain}.${row.Domain}.txt\" class=\"nes-btn is-warning\"><img src=\"/images/duckicon.png\"></a>
                   <a href=\"${row.Webpath}/vbs-${row.Subdomain}.${row.Domain}.png\" class=\"nes-btn is-success\"><img src=\"/images/cat.png\"></a>
                   <br>
                   <a href=\"${row.Webpath}/get-${row.Subdomain}.${row.Domain}.sh\" class=\"nes-btn is-primary\" style=\" font-size: 13px;\"><img src=\"/images/term.png\"> .sh&nbsp;</a>
                   <a href=\"${row.Webpath}/ducky-sh-${row.Subdomain}.${row.Domain}.txt\" class=\"nes-btn is-warning\"><img src=\"/images/duckicon.png\"></a>
                   <a href=\"${row.Webpath}/sh-${row.Subdomain}.${row.Domain}.png\" class=\"nes-btn is-success\"><img src=\"/images/cat.png\"></a>
                   <br>
                   <a href=\"${row.Webpath}/get-${row.Subdomain}.${row.Domain}.py\" class=\"nes-btn is-primary\" style=\" font-size: 13px;\"><img src=\"/images/term.png\"> .py&nbsp;</a>
                   <a href=\"${row.Webpath}/ducky-py-${row.Subdomain}.${row.Domain}.txt\" class=\"nes-btn is-warning\"><img src=\"/images/duckicon.png\"></a>
                   <a href=\"${row.Webpath}/py-${row.Subdomain}.${row.Domain}.png\" class=\"nes-btn is-success\"><img src=\"/images/cat.png\"></a>
                   <br>
                </td>
		<td style="text-align: center; vertical-align: top;">
                 <button onclick=\"deleteit(this.id)\" id=\"${row.Slotid}\" class="nes-btn is-error" style="font-size: 80%;">x</button></a>
                </td>
               </tr>`);
            });    
            res.write("</tbody></table>");
          }
          else {
            res.write("<br><br><br><br><div class=\"page\">You haven't added any files yet?</div><br><br><br><a href=\"/add\"><button class=\"nes-btn is-primary\">Add File</button></a><br><br>");
          }
        
          res.write(`
                  </section>  
                </div>
              </div>
	      <br><br><br>
	      <div id="footer">
                <div id="footerContainer">
                  <div id="grass"></div>
                </div>
                  <div id="samurai">
		    <img src="/images/samurai.gif" width="200" height="107">
                  </div>
                  <div id="lantern">
                    <img src="/images/lantern.png" width="306" height="72">
                  </div>
              </div>
              <div id="credits">
                 <span class="nes-text is-disabled" style="font-size: 12px;">dnsKIRE <a href="https://github.com/0xtosh/dnskire"><span class="nes-icon github is-small"></a> <a href="https://twitter.com/0xtosh/"><span class="nes-icon twitter is-small"></span></a> </a></span>
              </div>
            </div>
          </body>
        </html>`);
res.end();
});


app.get('/config', async function (req, res) {

await htmlheader(res);
res.write(`
        <section class="topic">
         <div class=\"nes-container is-centered\">
           <a href=\"/add\"><button class=\"nes-btn\">Add File</button></a>
           <a href=\"/files\"><button class=\"nes-btn\">Loaded Files</button></a>
           <a href=\"/config\"><button class=\"nes-btn is-warning\">Domains</button></a>
         </div>
	</section>

	<div style="margin: 10px 0 30px 0;"></div>
         <section class=\"nes-container with-title is-centered\">

          <h3 class=\"title\">Configure Domains</h3> 
          <div id=\"tables\" class=\"item\">  
            <br>
      `);

            let domainrows = await db_all("SELECT Domain FROM domains");
            res.write(`
            <form onload=\"document.editconfigformAjax.reset();\" action=\"/setdomains\" id=\"editconfigformAjax\" name=\"editconfigformAjax\" enctype=\"multipart/form-data\" method=\"POST\">
              <textarea placeholder=\"Add domains here, one per line without whitespace, then click update e.g.: \n\nsomecdn.com\nlegitlookingsite.com\n...\" class=\"nes-textarea\" autocomplete=\"off\" id=\"domains\" name=\"domains\" rows=\"10\" cols=\"30\">`);

            if(domainrows.length != 0) {
              domainrows.forEach(function (domainrow) {
                res.write(`${domainrow.Domain}&#13;&#10;`);
              });
            }
            res.write(`</textarea>
                      <br><br>
                      <button type=\"submit\" id=\"submit\" class=\"nes-btn is-primary\">Update</button>
		      <button class=\"nes-btn is-error\" onclick=\"resetwarning();\" type=\"button\">Reset All</button>
                    </form>
                  </div>
                  </section><br><br>
		  <span class=\"nes-badge\">
		    <div id=\"updatestatus\"></div>
                  </span>
                     <div id="footer">
                <div id="footerContainer">
                  <div id="grass"></div>
                </div>
                  <div id="samurai">
                    <img src="/images/samurai.gif" width="200" height="107">
                  </div>
                  <div id="lantern">
                    <img src="/images/lantern.png" width="306" height="72">
                  </div>
              </div>
              <div id="credits">
                      <span class="nes-text is-disabled" style="font-size: 12px;">dnsKIRE <a href="https://github.com/0xtosh/dnskire"><span class="nes-icon github is-small"></a> <a href="https://twitter.com/0xtosh/"><span class="nes-icon twitter is-small"></span></a> </a></span>
                    </div>
                 </div>
               </body>
             </html>
          `);
res.end();
});


app.post('/setdomains', async function (req, res) {
	    res.setHeader('Content-Type', 'text/html');

	    var tocreate = "";
	    var todel = "";
            let textareaDomainArrayClean=[];

	    let date_ob = new Date();
            let date = ("0" + date_ob.getDate()).slice(-2);
            let month = ("0" + (date_ob.getMonth() + 1)).slice(-2);
            let year = date_ob.getFullYear();
            let hours = ("0" + (date_ob.getHours() + 1)).slice(-2);
            let minutes = ("0" + (date_ob.getMinutes() + 1)).slice(-2);
            let seconds = ("0" + (date_ob.getSeconds() + 1)).slice(-2);

            function isEmptyOrSpaces(str){
              return str === null || str.match(/^[\s\n\r]*$/) !== null;
            }

            let updatedomains = req.body.domains; 
            updatedomains = updatedomains.replace(/\r/g, "");

            let textareaDomainArray = updatedomains.split(/\n/);
            let DomainsFromSQL=[];
            let sqldomainrows = await db_all("SELECT Domain FROM domains");

            if(sqldomainrows.length != 0) {
               sqldomainrows.forEach(function (sqldomainrow) {
                 DomainsFromSQL.push(`${sqldomainrow.Domain}`);
               }); 
	    }

	    textareaDomainArray.forEach(function (textarealine) {
              if(!isEmptyOrSpaces(textarealine) && isValidDomain(textarealine, {wildcard: false})) {
                textarealine = textarealine.replace(/\r\n|\r/g, "");
                textareaDomainArrayClean.push(textarealine);
	      } 
            });

            tocreate = textareaDomainArrayClean.filter(x => DomainsFromSQL.indexOf(x) === -1); // what was added to the textarea list
            todel = DomainsFromSQL.filter(y => textareaDomainArray.indexOf(y) === -1);    // what was removed from the textarea list

	    function runcmd(cmd) {
               return execShellCommand(cmd);
            }

            if (tocreate.length == 0) {
            }
            else {
              jsoncreate = JSON.stringify(tocreate);
              cleancreate = jsoncreate.replace(/[\[\]\"]/g, ""); 
              cleancreate = cleancreate.replace(/[\n\r]/g, ""); 
              let createDomainArray = cleancreate.split(/,/);

              createDomainArray.forEach(domaintoadd => {
		adddomain(domaintoadd);
		var addcmd = './scripts/zoneadm.sh add \"' + domaintoadd + '\"';
		var addcmdret = runcmd(addcmd);
		var reloadcmd = 'rndc reconfig';
                var reloadcmdret = runcmd(reloadcmd);
		console.log(`${year}-${month}-${date}-${hours}:${minutes}:${seconds} Added domain "${domaintoadd}"`);
		logfs.appendFileSync(logfile, `${year}-${month}-${date}-${hours}:${minutes}:${seconds} Added domain "${domaintoadd}"\n`);
              });

            }
           
            if (todel.length == 0 || DomainsFromSQL.length == 0) {
              // meditate. nothing to delete.
            }
            else {
              jsondel = JSON.stringify(todel);
              cleandel = jsondel.replace(/[\[\]\"]/g, "");
              cleandel = cleandel.replace(/[\n\r]/g, ""); 

              let delDomainArray = cleandel.split(/,/);

              let date_ob = new Date();
              let date = ("0" + date_ob.getDate()).slice(-2);
              let month = ("0" + (date_ob.getMonth() + 1)).slice(-2);
              let year = date_ob.getFullYear();
              let hours = ("0" + (date_ob.getHours() + 1)).slice(-2);
              let minutes = ("0" + (date_ob.getMinutes() + 1)).slice(-2);
              let seconds = ("0" + (date_ob.getSeconds() + 1)).slice(-2);

              delDomainArray.forEach(domaintodel => {
		var zonefile = DNSZONEFILEDIR + "db." + domaintodel;
		// delete the domain from the DOMAINS table
                deldomain(domaintodel);
		// delete the file subdomain entries from the FILES table
                deldomainentries(domaintodel);
		// remove the zone file /etc/bind/zones/db. + domain.tld
                deldir(zonefile);
		// remove the include file /etc/bind/zones/domain.tld + .inc
	        deldir(DNSZONEFILEDIR + domaintodel + ".inc");
		// remove the domain entry from /etc/bind/named.conf.local
		var rmdomaincmd = './scripts/zoneadm.sh remove \"' + domaintodel + '\"';
                var rmdomaincmdret = runcmd(rmdomaincmd);
		var reloadcmd = 'rndc reconfig';
                var reloadcmdret = runcmd(reloadcmd);
                console.log(`${year}-${month}-${date}-${hours}:${minutes}:${seconds} Removed domain "${domaintodel}" and all related file entries`);
		logfs.appendFileSync(logfile, `${year}-${month}-${date}-${hours}:${minutes}:${seconds} Removed domain "${domaintodel}" and all related file entries\n`);
              });
            }
	res.redirect('/config');
});

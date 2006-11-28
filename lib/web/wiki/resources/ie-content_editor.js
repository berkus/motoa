var bLoad=false
var pureText=true
var bTextMode=false

public_description=new Editor

function Editor() {
  this.put_html=SetHtml
  this.get_html=GetHtml
}

function GetHtml() {
  if (bTextMode)
    return Composition.document.body.innerText
  else
    return Composition.document.body.innerHTML
}

function SetHtml(sVal) {
  if (bTextMode) 
    Composition.document.body.innerText=sVal 
  else 
    Composition.document.body.innerHTML=sVal
}

// Check if toolbar is being used when in text mode
function validateMode() {
  if (! bTextMode) return true;
  alert("Please uncheck the \"View HTML source\" checkbox to use the toolbars");
  Composition.focus();
  return false;
}

//Formats text in composition.
function format(what,opt) {
  if (!validateMode()) return;

  if (opt=="removeFormat") {
    what=opt;
    opt=null;
  }

  if (opt==null) Composition.document.execCommand(what);
  else Composition.document.execCommand(what,"",opt);
  
  pureText = false;
  Composition.focus();
}

//Switches between text and html mode.
function setMode(newMode) {
  bTextMode = newMode;
  var cont;
  if (bTextMode) {
    cont=Composition.document.body.innerHTML;
    Composition.document.body.innerText=cont;
  } else {
    cont=Composition.document.body.innerText;
    Composition.document.body.innerHTML=cont;
  }
  
  Composition.focus();
}

//Finds and returns an element.
function getEl(sTag,start) {
  while ((start!=null) && (start.tagName!=sTag)) start = start.parentElement;
  return start;
}

function createLink() {
  if (!validateMode()) return;
  
  var isA = getEl("A",Composition.document.selection.createRange().parentElement());
  var str=prompt("Enter link location (e.g. http://www.domainName.com):", isA ? isA.href : "http:\/\/");
  
  if ((str!=null) && (str!="http://")) {
    if (Composition.document.selection.type=="None") {
      var sel=Composition.document.selection.createRange();
      sel.pasteHTML("<A HREF=\""+str+"\">"+str+"</A> ");
      sel.select();
    }
    else format("CreateLink",str);
  }
  else Composition.focus();
}

//Sets the text color.
function foreColor() {
//alert("This Function is not yet Implemneted");
  if (! validateMode()) return;
  var arr = showModalDialog("ColorSelect.html", "", "font-family:Verdana; font-size:12; dialogWidth:30em; dialogHeight:35em");
  if (arr != null) format('forecolor', arr);
  else Composition.focus();
}

//Sets the background color.
function backColor() {
//alert("This Function is not yet Implemneted");
  if (!validateMode()) return;
  var arr = showModalDialog("ColorSelect.html", "", "font-family:Verdana; font-size:12; dialogWidth:30em; dialogHeight:35em");
  if (arr != null) format('backcolor', arr);
  else Composition.focus()
}

function cleanHtml() {
  var fonts = Composition.document.body.all.tags("FONT");
  var curr;
  for (var i = fonts.length - 1; i >= 0; i--) {
    curr = fonts[i];
    if (curr.style.backgroundColor == "#ffffff") curr.outerHTML = curr.innerHTML;
  }
}

function removeWordFonts() {
  var spans = Composition.document.body.all.tags("SPAN");
  var curr;
  for (var i = spans.length - 1; i >= 0; i--) {
    curr = spans[i];
	if (curr.style.cssText.indexOf("mso-bidi-font-size") != -1) {
		curr.outerHTML = curr.innerHTML;
	}
  }
  
  // strip out face information
  var fonts = Composition.document.body.all.tags("FONT");
  for (var i = fonts.length - 1; i >= 0; i--) {
  	curr = fonts[i];
	curr.face = "";
  }
  
  // remove extra font tags
  for (var i = fonts.length - 1; i >= 0; i--) {
    curr = fonts[i];
	if (curr.color == "" && curr.size == "" ) {
	  curr.outerHTML = curr.innerHTML;
	}
  }
}

function getPureHtml() {
  var str = "";
  var paras = Composition.document.body.all.tags("P");
  if (paras.length > 0) {
    for (var i=paras.length-1; i >= 0; i--) str = paras[i].innerHTML + "\n" + str;
  } else {
    str = Composition.document.body.innerHTML;
  }
  return str;
}

function createImage(dirname) {
  if (!validateMode()) return;
  var isA = getEl("A",Composition.document.selection.createRange().parentElement())
  var openstr = 'image.php?dirname=' + escape( dirname );
  var Win = window.open(openstr, '_new','status=yes,scrollbars=yes,resizable=yes,width=600,height=480');
}

function insertImage(imgstr) {
 if (!validateMode()) {
   displayError()
   return false;
 }
 //var isA = getEl("A",idEdit.document.selection.createRange().parentElement())
 if ((imgstr!=null) && (imgstr!='<IMG alt="" src=""')) {
	 Composition.focus();
     var sel=Composition.document.selection.createRange();
     sel.pasteHTML("<img src='{$page.download_link}" + imgstr + "' border=0>");
     sel.select();
 }
 else
   Composition.focus()
}

function insertOneHalf() {
    if (!validateMode()) {
        displayError()
        return false;
    } else {
        fraction = "<font size='1'><sup>1/2</sup></font>";
        Composition.focus();
        var sel = Composition.document.selection.createRange();
        sel.pasteHTML(fraction);
    }
}

function superscript() {
    if (!validateMode()) {
        displayError()
        return false;
    } else {
        Composition.focus();
        var sel = Composition.document.selection.createRange();
        sel.pasteHTML("<sup>" + sel.htmlText + "</sup>");
    }
}

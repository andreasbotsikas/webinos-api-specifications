#!/bin/sh

if [ $# -eq 2 ] # good arguments 
then
   echo "Using " $1 " as repository for API stuff " $2 " as the spec destination"
   SPECHOME=$2
   REPOS=$1
else
   echo "This script requires 2 arguments: The location of the repository and the destination directory for the spec (both full paths). The first argument should point to a folder with three folders: static (where static html files are stored), widl (where WebIDL sources are stored) and resources (where additional resources such as wildproc, dtd, xsl... are stored). If the operation completes successfully the spec will be generated at the apis folder created on the specified destination folder."
   exit
fi

# API Files that do not come from widls (edited manually) 
#STATICFILES='geolocation.html webinos-apis.js webinos-apis.css'
STATICFILES=$(ls "$REPOS/static/")

# Device API widls
#WIDLFILES='foo.widl'
WIDLFILES=$(ls -I "*~" $REPOS/widl/) 

# For widlproc processing
XSL=widlprocxmltohtml.xsl
XMLSOURCES=widlprocxmlsources.xml
DTD=widlprocxml.dtd

# get the right tools for unix of windows cygnus
$(widlproc 2> /dev/null)
[ $? != 127 ] && WIDLPROC=widlproc || WIDLPROC=$REPOS/resources/linux/widlproc 
[ -n "$OS" ] && [ "$OS" = "Windows_NT" ] && WIDLPROC=$REPOS/resources/win32/widlproc.exe
[ "$(uname)" = "Darwin" ] && WIDLPROC=$REPOS/resources/macos/widlproc

$(ls /opt/bitnami/common/lib/libxslt.so > /dev/null 2>&1)
[ $? = 0 ] && XSLTLIB=/opt/bitnami/common/lib
XSLPROC=xsltproc 
[ -n "$OS" ] && [ "$OS" = "Windows_NT" ] && XSLPROC=$REPOS/resources/win32/xsltproc.exe



#[ $? != 127 ] && WIDLPROC=widlproc.exe || WIDLPROC=$REPOS/resources/win32/widlproc.exe

# TODO: Here we should include an update to check the latest repository version is available
# Clean Directories used for the generation of the specs
rm -rf "$SPECHOME/apis"
mkdir "$SPECHOME/apis"

# Copy static content
for i in $STATICFILES
do
  cp "$REPOS/static/$i" "$SPECHOME/apis/"
done

# Generating dynamic content

# those files are required to be in the destination folder for HTML generation
cp "$REPOS/resources/$DTD" "$SPECHOME/apis/"
cp "$REPOS/resources/$XSL" "$SPECHOME/apis/"

# is done in three steps in order to build the cross-references
for i in $WIDLFILES
do
	"$WIDLPROC" "$REPOS/widl/$i" > "$SPECHOME/apis/$(basename "$i" .widl).widlprocxml"
	if [ $? != 0 ]
	then
		echo Error: could not process $i
		WIDLFILES=${WIDLFILES//$i} # remove widl with error from further process
	       	rm "$SPECHOME/apis/$(basename "$i" .widl).widlprocxml" 
	fi
done

cat > "$SPECHOME/apis/$XMLSOURCES" <<DELIM
<?xml version="1.0" encoding="utf-8"?>
<widlprocxml>
DELIM

for i in $WIDLFILES
do
	cp "$REPOS/widl/$i" "$SPECHOME/apis/"
	echo "<file>$(basename "$i" .widl).widlprocxml</file>" >> "$SPECHOME/apis/$XMLSOURCES"
done
echo "</widlprocxml>" >> "$SPECHOME/apis/$XMLSOURCES"

unset GIT_DIR
for i in $WIDLFILES
do
	DATE=$(cd "$REPOS/widl" ; git log --pretty=format:'%aD' -1 "$i"|cut -d " " -f 2-4)
	LD_LIBRARY_PATH="${XSLTLIB}" "$XSLPROC" --stringparam date "$DATE" "$SPECHOME/apis/$XSL" "$SPECHOME/apis/${i}procxml" > "$SPECHOME/apis/$(basename "$i" .widl).html"
done

cat > "$SPECHOME/apis/index.html" <<DELIM
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<link media="screen" href="webinos-apis.css" type="text/css" rel="stylesheet">
<title>Webinos Device APIs</title>
</head>
<body id="content">
<div class="api">
     <a href="http://webinos.org"><img src="http://webinos.org/wp-content/uploads/2011/press_releases/webinos_thumb_150x48.png" alt="Webinos Logo"></a>

     <h1 class="head">Webinos Device APIs</h1>
</div>
<div id="content"><table><thead><tr><th>Specification</th><th>Summary</th></thead><tbody>
DELIM

for i in $WIDLFILES
do
    if [ "$i" != "foo.widl" ] ; 
    then
	basename2=$(basename "$i" .widl)
	htmlfile="$SPECHOME/apis/"$basename2".html"
	LD_LIBRARY_PATH="${XSLTLIB}" "$XSLPROC" --novalid --stringparam basename "$basename2" --html  "$REPOS/resources/getAPIdata.xsl" "$htmlfile" >> "$SPECHOME/apis/index.html"
    fi
	#basename2="$(echo ${basename2:0:1} | tr 'a-z' 'A-Z' )""${basename2:1}"
	#echo '<li><a href="./'"$(basename "$i" .widl).html"'">'"$basename2"' API</a><br /></li>' >> "$SPECHOME/apis/index.html"
done
echo '</tbody></table></div>'  >> "$SPECHOME/apis/index.html"
echo '<p>See also the <a href="patterns.html">Webinos design patterns and guidelines for APIs</a></p>'  >> "$SPECHOME/apis/index.html"
echo '</body>' >> "$SPECHOME/apis/index.html"
echo '</html>' >> "$SPECHOME/apis/index.html"

rm "$SPECHOME"/apis/*.widlprocxml
rm "$SPECHOME"/apis/*.widl
rm "$SPECHOME/apis/$DTD"
rm "$SPECHOME/apis/$XSL"
rm "$SPECHOME/apis/$XMLSOURCES"


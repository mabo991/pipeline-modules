<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" xmlns:c="http://www.w3.org/ns/xproc-step" xmlns:px="http://www.daisy.org/ns/pipeline/xproc" xmlns:d="http://www.daisy.org/ns/pipeline/data"
    type="px:zedai-to-epub3" name="zedai-to-epub3" version="1.0">

    <p:documentation xmlns="http://www.w3.org/1999/xhtml">
        <h1 px:role="name">ZedAI to EPUB3</h1>
        <p px:role="desc">Transforms a ZedAI (DAISY 4 XML) document into an EPUB 3 publication.</p>
    </p:documentation>

    <p:input port="source" primary="true" px:name="source" px:media-type="application/z3998-auth+xml">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <h2 px:role="name">ZedAI document</h2>
            <p px:role="desc">Input ZedAI.</p>
        </p:documentation>
    </p:input>

    <p:option name="output-dir" required="true" px:output="result" px:type="anyDirURI">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <h2 px:role="name">Output directory</h2>
            <p px:role="desc">Output directory for the EPUB.</p>
        </p:documentation>
    </p:option>

    <p:option name="temp-dir" required="true" px:output="temp" px:type="anyDirURI">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <h2 px:role="name">Temporary directory</h2>
            <p px:role="desc">Directory used for temporary files.</p>
        </p:documentation>
    </p:option>

    <p:option name="tts-config" required="false" px:type="anyURI" select="''">
      <p:documentation xmlns="http://www.w3.org/1999/xhtml">
	<h2 px:role="name"> Text-To-Speech configuration file</h2>
	<p px:role="desc">Configuration file for the Text-To-Speech.</p>
      </p:documentation>
    </p:option>

    <p:import href="zedai-to-epub3.convert.xpl"/>

    <p:import href="http://www.daisy.org/pipeline/modules/epub3-nav-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/epub3-ocf-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/epub3-pub-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/fileset-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/common-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/zedai-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/css-speech/library.xpl"/>
    <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>

    <p:variable name="input-uri" select="base-uri(/)"/>

    <p:xslt name="output-dir-uri">
        <p:with-param name="href" select="concat($output-dir,'/')"/>
        <p:input port="source">
            <p:inline>
                <d:file/>
            </p:inline>
        </p:input>
        <p:input port="stylesheet">
            <p:inline>
                <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pf="http://www.daisy.org/ns/pipeline/functions" version="2.0">
                    <xsl:import href="http://www.daisy.org/pipeline/modules/file-utils/uri-functions.xsl"/>
                    <xsl:param name="href" required="yes"/>
                    <xsl:template match="/*">
                        <xsl:copy>
                            <xsl:attribute name="href" select="pf:normalize-uri($href)"/>
                        </xsl:copy>
                    </xsl:template>
                </xsl:stylesheet>
            </p:inline>
        </p:input>
    </p:xslt>
    <p:sink/>

    <p:group>
        <p:variable name="output-dir-uri" select="/*/@href">
            <p:pipe port="result" step="output-dir-uri"/>
        </p:variable>
        <p:variable name="epub-file-uri" select="concat($output-dir-uri,replace($input-uri,'^.*/([^/]*?)(\.[^/\.]*)?$','$1'),'.epub')"/>

        <px:zedai-load name="load">
            <p:input port="source">
                <p:pipe port="source" step="zedai-to-epub3"/>
            </p:input>
        </px:zedai-load>

	<p:choose name="load-tts-config">
	  <p:when test="$tts-config != ''">
	    <p:output port="result" primary="true"/>
	    <p:load>
	      <p:with-option name="href" select="$tts-config"/>
	    </p:load>
	  </p:when>
	  <p:otherwise>
	    <p:output port="result" primary="true">
	      <p:inline>
		<d:config/>
	      </p:inline>
	    </p:output>
	    <p:sink/>
	  </p:otherwise>
	</p:choose>

	<p:choose name="css-inlining">
	  <p:when test="$tts-config != ''">
	    <p:output port="result" primary="true"/>
	    <px:inline-css-speech>
	      <p:input port="source">
		<p:pipe port="in-memory.out" step="load"/>
	      </p:input>
	      <p:input port="fileset.in">
		<p:pipe port="fileset.out" step="load"/>
	      </p:input>
	      <p:input port="config">
		<p:pipe port="result" step="load-tts-config"/>
	      </p:input>
	      <p:with-option name="content-type" select="'application/z3998-auth+xml'"/>
	    </px:inline-css-speech>
	  </p:when>
	  <p:otherwise>
	    <p:output port="result" primary="true"/>
	    <p:identity>
	      <p:input port="source">
		<p:pipe port="in-memory.out" step="load"/>
	      </p:input>
	    </p:identity>
	  </p:otherwise>
	</p:choose>

        <px:zedai-to-epub3-convert name="convert">
	    <p:input port="fileset.in">
	        <p:pipe port="fileset.out" step="load"/>
	    </p:input>
            <p:input port="in-memory.in">
                <p:pipe port="result" step="css-inlining"/>
            </p:input>
	    <p:input port="tts-config">
	      <p:pipe port="result" step="load-tts-config"/>
	    </p:input>
            <p:with-option name="output-dir" select="$temp-dir"/>
	    <p:with-option name="audio" select="$tts-config != ''"/>
        </px:zedai-to-epub3-convert>

        <px:epub3-store>
            <p:with-option name="href" select="$epub-file-uri"/>
            <p:input port="in-memory.in">
                <p:pipe port="in-memory.out" step="convert"/>
            </p:input>
        </px:epub3-store>
    </p:group>

</p:declare-step>

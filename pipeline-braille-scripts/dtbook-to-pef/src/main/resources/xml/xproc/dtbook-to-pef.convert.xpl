<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step type="px:dtbook-to-pef.convert" version="1.0"
                xmlns:p="http://www.w3.org/ns/xproc"
                xmlns:px="http://www.daisy.org/ns/pipeline/xproc"
                xmlns:pxi="http://www.daisy.org/ns/pipeline/xproc/internal"
                xmlns:d="http://www.daisy.org/ns/pipeline/data"
                xmlns:c="http://www.w3.org/ns/xproc-step"
                xmlns:pef="http://www.daisy.org/ns/2008/pef"
                xmlns:css="http://www.daisy.org/ns/pipeline/braille-css"
                xmlns:math="http://www.w3.org/1998/Math/MathML"
                exclude-inline-prefixes="#all"
                name="main">
    
    <p:input port="source" px:media-type="application/x-dtbook+xml"/>
    <p:output port="result" px:media-type="application/x-pef+xml"/>

    <p:option name="default-stylesheet" required="true"/>
    <p:option name="stylesheet" required="true"/>
    <p:option name="transform" required="true"/>
    
    <p:option name="page-width" required="true"/>
    <p:option name="page-height" required="true"/>
    <!-- <p:option name="predefined-page-formats" required="true"/> -->
    <!-- <p:option name="left-margin" required="true"/> -->
    <!-- <p:option name="duplex" required="true"/> -->
    <!-- <p:option name="levels-in-footer" required="true"/> -->
    <!-- <p:option name="main-document-language" required="true"/> -->
    <!-- <p:option name="contraction-grade" required="true"/> -->
    <!-- <p:option name="hyphenation-with-single-line-spacing" required="true"/> -->
    <!-- <p:option name="hyphenation-with-double-line-spacing" required="true"/> -->
    <!-- <p:option name="line-spacing" required="true"/> -->
    <!-- <p:option name="tab-width" required="true"/> -->
    <!-- <p:option name="capital-letters" required="true"/> -->
    <!-- <p:option name="accented-letters" required="true"/> -->
    <!-- <p:option name="polite-forms" required="true"/> -->
    <!-- <p:option name="downshift-ordinal-numbers" required="true"/> -->
    <!-- <p:option name="include-captions" required="true"/> -->
    <!-- <p:option name="include-images" required="true"/> -->
    <!-- <p:option name="include-image-groups" required="true"/> -->
    <!-- <p:option name="include-line-groups" required="true"/> -->
    <!-- <p:option name="text-level-formatting" required="true"/> -->
    <!-- <p:option name="include-note-references" required="true"/> -->
    <!-- <p:option name="include-production-notes" required="true"/> -->
    <!-- <p:option name="show-braille-page-numbers" required="true"/> -->
    <!-- <p:option name="show-print-page-numbers" required="true"/> -->
    <!-- <p:option name="force-braille-page-break" required="true"/> -->
    <p:option name="toc-depth" required="true"/>
    <!-- <p:option name="ignore-document-title" required="true"/> -->
    <!-- <p:option name="include-symbols-list" required="true"/> -->
    <!-- <p:option name="choice-of-colophon" required="true"/> -->
    <!-- <p:option name="footnotes-placement" required="true"/> -->
    <!-- <p:option name="colophon-metadata-placement" required="true"/> -->
    <!-- <p:option name="rear-cover-placement" required="true"/> -->
    <!-- <p:option name="number-of-pages" required="true"/> -->
    <!-- <p:option name="maximum-number-of-pages" required="true"/> -->
    <!-- <p:option name="minimum-number-of-pages" required="true"/> -->
    <!-- <p:option name="sbsform-macros" required="true"/> -->

    <!-- Empty temporary directory dedicated to this conversion -->
    <p:option name="temp-dir" required="true"/>

    <p:import href="http://www.daisy.org/pipeline/modules/braille/common-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/braille/css-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/braille/pef-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/dtbook-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/file-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/fileset-utils/library.xpl"/>
    <p:import href="fileset-add-tempfile.xpl"/>
    <p:import href="generate-toc.xpl"/>

    <p:variable name="lang" select="(/*/@xml:lang,'und')[1]"/>
    
    <px:fileset-create name="temp-dir">
        <p:with-option name="base" select="$temp-dir">
            <p:empty/>
        </p:with-option>
    </px:fileset-create>
    
    <pxi:fileset-add-tempfile media-type="text/css" suffix=".scss">
        <p:input port="source">
            <p:inline>
                        <c:data>@page {
  size: $page-width $page-height;
}
</c:data>
            </p:inline>
        </p:input>
    </pxi:fileset-add-tempfile>
            
    <p:choose>
        <p:when test="not($toc-depth='0')">
            <pxi:fileset-add-tempfile media-type="text/css" suffix=".css">
                <p:input port="source">
                    <p:inline>
                        <c:data>#generated-document-toc {
  flow: document-toc;
  display: -obfl-toc;
  -obfl-toc-range: document;
}

#generated-volume-toc {
  flow: volume-toc;
  display: -obfl-toc;
  -obfl-toc-range: volume;
}
</c:data>
                    </p:inline>
                </p:input>
            </pxi:fileset-add-tempfile>
        </p:when>
        <p:otherwise>
            <p:identity/>
        </p:otherwise>
    </p:choose>
    <p:identity name="generated-css"/>
    
    <px:dtbook-load name="load">
        <p:input port="source">
            <p:pipe step="main" port="source"/>
        </p:input>
    </px:dtbook-load>
    
    <pxi:generate-toc>
        <p:input port="source">
            <p:pipe step="load" port="in-memory.out"/>
        </p:input>
        <p:with-option name="depth" select="$toc-depth"/>
    </pxi:generate-toc>
    
    <css:inline>
        <p:with-option name="default-stylesheet" select="string-join((
                                                           $default-stylesheet,
                                                           //d:file/resolve-uri(@href, base-uri(.)),
                                                           $stylesheet),' ')">
            <p:pipe step="generated-css" port="result"/>
        </p:with-option>
        <p:with-param port="sass-variables" name="page-width" select="$page-width"/>
        <p:with-param port="sass-variables" name="page-height" select="$page-height"/>
    </css:inline>

    <p:viewport match="math:math">
        <px:transform>
            <p:with-option name="query" select="concat('(input:mathml)(locale:',$lang,')')"/>
            <p:with-option name="temp-dir" select="$temp-dir"/>
        </px:transform>
    </p:viewport>

    <px:transform name="pef">
        <p:with-option name="query" select="concat('(input:css)(output:pef)',$transform,'(locale:',$lang,')')"/>
        <p:with-option name="temp-dir" select="$temp-dir"/>
    </px:transform>

    <p:xslt name="metadata">
        <p:input port="source">
            <p:pipe step="main" port="source"/>
        </p:input>
        <p:input port="stylesheet">
            <p:document href="../xslt/dtbook-to-metadata.xsl"/>
        </p:input>
        <p:input port="parameters">
            <p:empty/>
        </p:input>
    </p:xslt>

    <pef:add-metadata>
        <p:input port="source">
            <p:pipe step="pef" port="result"/>
        </p:input>
        <p:input port="metadata">
            <p:pipe step="metadata" port="result"/>
        </p:input>
    </pef:add-metadata>

</p:declare-step>

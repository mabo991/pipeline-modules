<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" xmlns:c="http://www.w3.org/ns/xproc-step" xmlns:px="http://www.daisy.org/ns/pipeline/xproc" xmlns:d="http://www.daisy.org/ns/pipeline/data"
    type="px:nordic-dtbook-to-html.step" name="main" version="1.0" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:dtbook="http://www.daisy.org/z3986/2005/dtbook/"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:cx="http://xmlcalabash.com/ns/extensions">

    <p:input port="fileset.in" primary="true"/>
    <p:input port="in-memory.in" sequence="true">
        <p:empty/>
    </p:input>
    <p:input port="report.in" sequence="true">
        <p:empty/>
    </p:input>
    <p:input port="status.in">
        <p:inline>
            <d:validation-status result="ok"/>
        </p:inline>
    </p:input>

    <p:output port="fileset.out" primary="true">
        <p:pipe port="fileset.out" step="choose"/>
    </p:output>
    <p:output port="in-memory.out" sequence="true">
        <p:pipe port="in-memory.out" step="choose"/>
    </p:output>
    <p:output port="report.out" sequence="true">
        <p:pipe port="report.in" step="main"/>
        <p:pipe port="report.out" step="choose"/>
    </p:output>
    <p:output port="status.out">
        <p:pipe port="result" step="status"/>
    </p:output>

    <p:option name="fail-on-error" required="true"/>
    <p:option name="temp-dir" required="true"/>

    <p:import href="pretty-print.xpl">
        <p:documentation>
            px:nordic-pretty-print
        </p:documentation>
    </p:import>
    <p:import href="validation-status.xpl"/>
    <p:import href="update-epub-prefixes.xpl">
        <p:documentation>
            px:nordic-update-epub-prefixes
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/fileset-utils/library.xpl"/>
    <p:import href="http://www.daisy.org/pipeline/modules/file-utils/library.xpl">
        <p:documentation>
            px:set-base-uri
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/common-utils/library.xpl"/>

    <px:assert message="'fail-on-error' should be either 'true' or 'false'. was: '$1'. will default to 'true'.">
        <p:with-option name="param1" select="$fail-on-error"/>
        <p:with-option name="test" select="$fail-on-error = ('true','false')"/>
    </px:assert>

    <p:choose name="choose">
        <p:xpath-context>
            <p:pipe port="status.in" step="main"/>
        </p:xpath-context>
        <p:when test="/*/@result='ok' or $fail-on-error = 'false'">
            <p:output port="fileset.out" primary="true">
                <p:pipe port="result" step="dtbook-to-html.step.result.fileset"/>
            </p:output>
            <p:output port="in-memory.out" sequence="true">
                <p:pipe port="result" step="dtbook-to-html.step.result.in-memory"/>
            </p:output>
            <p:output port="report.out" sequence="true">
                <p:empty/>
            </p:output>










            <p:variable name="href" select="resolve-uri((//d:file[@media-type='application/x-dtbook+xml'])[1]/@href,base-uri(/))"/>

            <px:fileset-load media-types="application/x-dtbook+xml" name="dtbook-to-html.step.load-dtbook">
                <p:input port="in-memory">
                    <p:pipe port="in-memory.in" step="main"/>
                </p:input>
            </px:fileset-load>
            <px:assert test-count-max="1" message="There are multiple DTBooks in the fileset; only the first one will be converted."/>
            <px:assert test-count-min="1" message="There must be a DTBook file in the fileset." error-code="NORDICDTBOOKEPUB004"/>
            <p:split-sequence initial-only="true" test="position()=1" name="dtbook-to-html.step.only-use-first-dtbook"/>
            <p:identity name="dtbook-to-html.step.dtbook"/>

            <p:xslt name="dtbook-to-html.step.dtbook-to-epub3">
                <p:input port="parameters">
                    <p:empty/>
                </p:input>
                <p:input port="stylesheet">
                    <p:document href="http://www.daisy.org/pipeline/modules/dtbook-to-html/dtbook-to-epub3.xsl"/>
                </p:input>
            </p:xslt>
            <px:nordic-update-epub-prefixes/>

            <p:viewport match="/html:html/html:head" name="dtbook-to-html.step.viewport-html-head">
                <!-- TODO: consider dropping this if it causes performance issues -->
                <px:nordic-pretty-print preserve-empty-whitespace="false"/>
            </p:viewport>
            <!-- TODO: add ASCIIMathML.js if there are asciimath elements -->

            <px:set-base-uri>
                <p:with-option name="base-uri" select="concat($temp-dir,(//dtbook:meta[@name='dtb:uid']/@content,'missing-uid')[1],'.xhtml')">
                    <p:pipe port="result" step="dtbook-to-html.step.dtbook"/>
                </p:with-option>
            </px:set-base-uri>
            <p:identity name="dtbook-to-html.step.result.in-memory"/>
            <p:sink/>

            <px:fileset-filter not-media-types="application/x-dtbook+xml text/css" name="dtbook-to-html.step.filter-resources">
                <p:input port="source">
                    <p:pipe port="fileset.in" step="main"/>
                </p:input>
            </px:fileset-filter>
            <px:fileset-copy name="dtbook-to-html.step.move-resources">
                <p:with-option name="target" select="$temp-dir"/>
            </px:fileset-copy>
            <p:viewport match="/*/*[starts-with(@media-type,'image/')]" name="dtbook-to-html.step.viewport-images">
                <p:add-attribute match="/*" attribute-name="href" name="dtbook-to-html.step.viewport-images.change-href">
                    <p:with-option name="attribute-value" select="concat('images/',/*/@href)"/>
                </p:add-attribute>
            </p:viewport>
            <p:identity name="dtbook-to-html.step.fileset.existing-resources"/>

            <px:fileset-create name="dtbook-to-html.step.create-temp-dir-fileset">
                <p:with-option name="base" select="$temp-dir"/>
            </px:fileset-create>
            <px:fileset-add-entry media-type="application/xhtml+xml" name="dtbook-to-html.step.add-html-to-fileset">
                <p:with-option name="href" select="base-uri(/*)">
                    <p:pipe port="result" step="dtbook-to-html.step.result.in-memory"/>
                </p:with-option>
            </px:fileset-add-entry>
            <p:add-attribute match="//d:file[@media-type='application/xhtml+xml']" attribute-name="omit-xml-declaration" attribute-value="false" name="dtbook-to-html.step.dont-omit-xml-declaration"/>
            <p:add-attribute match="//d:file[@media-type='application/xhtml+xml']" attribute-name="version" attribute-value="1.0" name="dtbook-to-html.step.set-xml-version"/>
            <p:add-attribute match="//d:file[@media-type='application/xhtml+xml']" attribute-name="encoding" attribute-value="utf-8" name="dtbook-to-html.step.set-xml-encoding"/>
            <p:identity name="dtbook-to-html.step.fileset.new-resources"/>
            <px:fileset-join name="dtbook-to-html.step.fileset.join-old-and-new-resources">
                <p:input port="source">
                    <p:pipe port="result" step="dtbook-to-html.step.fileset.existing-resources"/>
                    <p:pipe port="result" step="dtbook-to-html.step.fileset.new-resources"/>
                </p:input>
            </px:fileset-join>
            <p:identity name="dtbook-to-html.step.result.fileset"/>










        </p:when>
        <p:otherwise>
            <p:output port="fileset.out" primary="true"/>
            <p:output port="in-memory.out" sequence="true">
                <p:pipe port="fileset.in" step="main"/>
            </p:output>
            <p:output port="report.out" sequence="true">
                <p:empty/>
            </p:output>

            <p:identity/>
        </p:otherwise>
    </p:choose>

    <p:choose name="status">
        <p:xpath-context>
            <p:pipe port="status.in" step="main"/>
        </p:xpath-context>
        <p:when test="/*/@result='ok' and $fail-on-error='true'">
            <p:output port="result"/>
            <px:nordic-validation-status>
                <p:input port="source">
                    <p:pipe port="report.out" step="choose"/>
                </p:input>
            </px:nordic-validation-status>
        </p:when>
        <p:otherwise>
            <p:output port="result"/>
            <p:identity>
                <p:input port="source">
                    <p:pipe port="status.in" step="main"/>
                </p:input>
            </p:identity>
        </p:otherwise>
    </p:choose>

</p:declare-step>

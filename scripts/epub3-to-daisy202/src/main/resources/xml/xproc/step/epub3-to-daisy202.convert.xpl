<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" version="1.0"
                xmlns:px="http://www.daisy.org/ns/pipeline/xproc"
                xmlns:pxi="http://www.daisy.org/ns/pipeline/xproc/internal"
                xmlns:d="http://www.daisy.org/ns/pipeline/data"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                type="px:epub3-to-daisy202" name="main">

    <p:input port="source.fileset" primary="true"/>
    <p:input port="source.in-memory" sequence="true"/>

    <p:output port="result.fileset" primary="true"/>
    <p:output port="result.in-memory" sequence="true">
        <p:pipe step="rename-xhtml" port="in-memory"/>
    </p:output>

    <p:option name="bundle-dtds" select="'false'"/>

    <p:import href="http://www.daisy.org/pipeline/modules/common-utils/library.xpl">
        <p:documentation>
            px:assert
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/file-utils/library.xpl">
        <p:documentation>
            px:set-base-uri
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/fileset-utils/library.xpl">
        <p:documentation>
            px:fileset-filter
            px:fileset-load
            px:fileset-join
            px:fileset-rebase
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/epub3-utils/pub/library.xpl">
        <p:documentation>
            px:opf-spine-to-fileset
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/html-utils/library.xpl">
        <p:documentation>
            px:html-upgrade
            px:html-downgrade
        </p:documentation>
    </p:import>
    <p:import href="create-ncc.xpl">
        <p:documentation>
            pxi:create-ncc
        </p:documentation>
    </p:import>
    
    <p:documentation>
        Extract and verify the OPF.
    </p:documentation>
    <px:fileset-load media-types="application/oebps-package+xml">
        <p:input port="in-memory">
            <p:pipe step="main" port="source.in-memory"/>
        </p:input>
    </px:fileset-load>
    <px:assert test-count-min="1" test-count-max="1" error-code="PED01" message="The EPUB must contain exactly one OPF document"/>
    <px:assert error-code="PED02" message="There must be at least one dc:identifier meta element in the OPF document">
        <p:with-option name="test" select="exists(/opf:package/opf:metadata/dc:identifier)"/>
    </px:assert>
    <p:identity name="opf"/>
    <p:sink/>

    <p:documentation>
        Convert from EPUB 3 SMIL to DAISY 2.02 SMIL.
    </p:documentation>
    <px:fileset-load media-types="application/smil+xml" name="epub3.smil.in-memory">
        <p:documentation>
            Load SMIL files.
        </p:documentation>
        <p:input port="fileset">
            <p:pipe step="main" port="source.fileset"/>
        </p:input>
        <p:input port="in-memory">
            <p:pipe step="main" port="source.in-memory"/>
        </p:input>
    </px:fileset-load>
    <p:for-each px:message="Converting SMIL-file from 3.0 (EPUB3 MO profile) to 1.0 (DAISY 2.02 profile)">
        <p:variable name="smil-original-base" select="base-uri(/*)"/>
        <p:xslt px:message="- {$smil-original-base}" px:message-severity="DEBUG">
            <p:input port="parameters">
                <p:empty/>
            </p:input>
            <p:input port="stylesheet">
                <p:document href="../../xslt/smil3-to-smil1.xsl"/>
            </p:input>
        </p:xslt>
    </p:for-each>
    <p:identity name="daisy202.smil.in-memory"/>
    <p:sink/>

    <p:documentation>
        Convert from EPUB 3 HTML to DAISY 2.02 HTML.
    </p:documentation>
    <px:opf-spine-to-fileset>
        <p:documentation>
            Get spine.
        </p:documentation>
        <p:input port="source.fileset">
            <p:pipe step="main" port="source.fileset"/>
        </p:input>
        <p:input port="source.in-memory">
            <p:pipe step="opf" port="result"/>
        </p:input>
    </px:opf-spine-to-fileset>
    <px:fileset-load>
        <p:documentation>
            Load content documents.
        </p:documentation>
        <p:input port="in-memory">
            <p:pipe step="main" port="source.in-memory"/>
        </p:input>
    </px:fileset-load>
    <p:for-each px:message="Converting HTML5 to HTML4">
        <p:variable name="base-uri" select="base-uri()"/>
        <p:identity px:message="- {$base-uri}" px:message-severity="DEBUG"/>
        <px:html-upgrade>
            <p:documentation>Normalize HTML5.</p:documentation>
            <!-- hopefully this preserves all IDs -->
        </px:html-upgrade>
        <px:html-downgrade>
            <p:documentation>Downgrade to HTML4. This preserves all ID.</p:documentation>
        </px:html-downgrade>
    </p:for-each>
    <p:identity name="daisy202.xhtml.in-memory"/>
    <p:sink/>

    <p:documentation>
        Create DAISY 2.02 fileset manifest.
    </p:documentation>
    <p:identity>
        <p:input port="source">
            <p:pipe step="main" port="source.fileset"/>
        </p:input>
    </p:identity>
    <px:fileset-rebase>
        <p:with-option name="new-base" select="replace(base-uri(/*),'[^/]+$','')">
            <p:pipe step="opf" port="result"/>
        </p:with-option>
    </px:fileset-rebase>
    <p:group>
        <p:documentation>
            - Delete package document (OPF).
            - Delete table of contents (NCX).
            - Delete original navigation document. It will be replaced with the generated NCC.
            - Delete mimetype and META-INF/.
            - Delete files outside of the directory that contains the OPF.
        </p:documentation>
        <p:variable name="nav" select="(//opf:item[tokenize(@properties,'\s+')='nav']/resolve-uri(@href,base-uri()))[1]">
            <p:pipe step="opf" port="result"/>
        </p:variable>
        <p:delete>
            <p:with-option name="match"
                           select="concat('
                                     //d:file[@media-type=(&quot;application/oebps-package+xml&quot;,
                                                           &quot;application/x-dtbncx+xml&quot;)
                                              or (&quot;',$nav,'&quot;!=&quot;&quot;
                                                  and @media-type=&quot;application/xhtml+xml&quot;
                                                  and &quot;',$nav,'&quot;=resolve-uri(@href,base-uri()))
                                              or starts-with(@href,&quot;..&quot;)
                                              or starts-with(@href,&quot;META-INF/&quot;)
                                              or @href=&quot;mimetype&quot;]
                                   ')"/>
        </p:delete>
    </p:group>

    <p:documentation>
        Create NCC file.
    </p:documentation>
    <pxi:create-ncc name="create-ncc" px:message="Creating NCC">
        <p:input port="source.in-memory">
            <p:pipe port="result" step="daisy202.xhtml.in-memory"/>
            <p:pipe port="result" step="daisy202.smil.in-memory"/>
        </p:input>
        <p:input port="opf">
            <p:pipe step="opf" port="result"/>
        </p:input>
    </pxi:create-ncc>

    <p:documentation>
        Rename content documents to .html.
    </p:documentation>
    <p:group name="rename-xhtml" px:message="Renaming content documents to .html">
        <p:output port="fileset" primary="true"/>
        <p:output port="in-memory" sequence="true">
            <p:pipe step="in-memory" port="result"/>
        </p:output>
        <px:fileset-filter media-types="application/xhtml+xml" name="xhtml"/>
        <px:fileset-load>
            <p:input port="in-memory">
                <p:pipe step="create-ncc" port="result.in-memory"/>
            </p:input>
        </px:fileset-load>
        <p:for-each>
            <px:set-base-uri>
                <p:documentation>
                    Change base URI.
                </p:documentation>
                <p:with-option name="base-uri" select="replace(base-uri(/*),'^(.*)\.([^/\.]*)$','$1.html')"/>
            </px:set-base-uri>
            <p:group>
                <p:documentation>
                    Update links to other HTML files.
                </p:documentation>
                <p:viewport match="//html:*[matches(@href,'\.xhtml(#|$)')]">
                    <p:add-attribute match="/*" attribute-name="href">
                        <p:with-option name="attribute-value" select="replace(/*/@href,'.xhtml(#|$)','.html$1')"/>
                    </p:add-attribute>
                </p:viewport>
                <p:viewport match="//html:*[matches(@src,'\.xhtml(#|$)')]">
                    <p:add-attribute match="/*" attribute-name="src">
                        <p:with-option name="attribute-value" select="replace(/*/@src,'.xhtml(#|$)','.html$1')"/>
                    </p:add-attribute>
                </p:viewport>
                <p:viewport match="//html:*[matches(@cite,'\.xhtml(#|$)')]">
                    <p:add-attribute match="/*" attribute-name="cite">
                        <p:with-option name="attribute-value" select="replace(/*/@cite,'.xhtml(#|$)','.html$1')"/>
                    </p:add-attribute>
                </p:viewport>
                <p:viewport match="//html:*[matches(@longdesc,'\.xhtml(#|$)')]">
                    <p:add-attribute match="/*" attribute-name="longdesc">
                        <p:with-option name="attribute-value" select="replace(/*/@longdesc,'.xhtml(#|$)','.html$1')"/>
                    </p:add-attribute>
                </p:viewport>
                <p:viewport match="//html:object[matches(@data,'\.xhtml(#|$)')]">
                    <p:add-attribute match="/*" attribute-name="data">
                        <p:with-option name="attribute-value" select="replace(/*/@data,'.xhtml(#|$)','.html$1')"/>
                    </p:add-attribute>
                </p:viewport>
                <p:viewport match="//html:form[matches(@action,'\.xhtml(#|$)')]">
                    <p:add-attribute match="/*" attribute-name="action">
                        <p:with-option name="attribute-value" select="replace(/*/@action,'.xhtml(#|$)','.html$1')"/>
                    </p:add-attribute>
                </p:viewport>
                <p:viewport match="//html:head[matches(@profile,'\.xhtml(#|$)')]">
                    <p:add-attribute match="/*" attribute-name="profile">
                        <p:with-option name="attribute-value" select="replace(/*/@profile,'.xhtml(#|$)','.html$1')"/>
                    </p:add-attribute>
                </p:viewport>
            </p:group>
        </p:for-each>
        <p:identity name="processed-xhtml"/>
        <p:sink/>
        <px:fileset-filter media-types="application/smil+xml" name="smil">
            <p:input port="source">
                <p:pipe step="create-ncc" port="result.fileset"/>
            </p:input>
        </px:fileset-filter>
        <px:fileset-load>
            <p:input port="in-memory">
                <p:pipe step="create-ncc" port="result.in-memory"/>
            </p:input>
        </px:fileset-load>
        <p:for-each>
            <p:documentation>
                Update links from SMIL to HTML.
            </p:documentation>
            <p:viewport match="//text[@src]" xmlns="">
                <p:add-attribute match="/*" attribute-name="src">
                    <p:with-option name="attribute-value" select="replace(/*/@src,'\.xhtml(#|$)','.html$1','i')"/>
                </p:add-attribute>
            </p:viewport>
        </p:for-each>
        <p:identity name="processed-smil"/>
        <p:sink/>
        <p:documentation>Rename files in XHTML fileset</p:documentation>
        <p:viewport match="d:file" name="xhtml-renamed.fileset">
            <p:viewport-source>
                <p:pipe step="xhtml" port="result"/>
            </p:viewport-source>
            <p:add-attribute attribute-name="href" match="/*">
                <p:with-option name="attribute-value" select="replace(/*/@href,'^(.*)\.([^/\.]*)$','$1.html')"/>
            </p:add-attribute>
        </p:viewport>
        <p:sink/>
        <p:documentation>Combine filesets</p:documentation>
        <p:identity name="in-memory">
            <p:input port="source">
                <p:pipe step="processed-xhtml" port="result"/>
                <p:pipe step="processed-smil" port="result"/>
                <p:pipe step="smil" port="not-matched.in-memory"/>
            </p:input>
        </p:identity>
        <p:sink/>
        <px:fileset-join>
            <p:input port="source">
                <p:pipe step="xhtml-renamed.fileset" port="result"/>
                <p:pipe step="xhtml" port="not-matched"/>
            </p:input>
        </px:fileset-join>
    </p:group>

    <p:documentation>
        Finalize DAISY 2.02 fileset manifest: set DOCTYPE on XHTML and SMIL files
    </p:documentation>
    <p:add-attribute match="d:file[@media-type='application/xhtml+xml']"
                     attribute-name="doctype-public"
                     attribute-value="-//W3C//DTD XHTML 1.0 Transitional//EN"/>
    <p:add-attribute match="d:file[@media-type='application/xhtml+xml']"
                     attribute-name="doctype-system"
                     attribute-value="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
    <p:add-attribute match="d:file[@media-type='application/smil+xml']"
                     attribute-name="doctype-public"
                     attribute-value="-//W3C//DTD SMIL 1.0//EN"/>
    <p:add-attribute match="d:file[@media-type='application/smil+xml']"
                     attribute-name="doctype-system"
                     attribute-value="http://www.w3.org/TR/REC-SMIL/SMIL10.dtd"/>

</p:declare-step>

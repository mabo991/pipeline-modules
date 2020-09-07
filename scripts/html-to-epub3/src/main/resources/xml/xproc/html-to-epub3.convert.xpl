<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" version="1.0"
                xmlns:px="http://www.daisy.org/ns/pipeline/xproc"
                xmlns:d="http://www.daisy.org/ns/pipeline/data"
                xmlns:html="http://www.w3.org/1999/xhtml"
                type="px:html-to-epub3" name="main"
                exclude-inline-prefixes="#all">

    <p:documentation>Transforms XHTML into an EPUB 3 publication.</p:documentation>

    <p:input port="input.fileset" primary="true"/>
    <p:input port="input.in-memory" sequence="true">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>Input HTML document(s) and resources</p>
            <p>If the fileset includes a navigation document, it should be marked with a
            <code>role</code> attribute with value <code>nav</code>, and it should be a HTML
            document. At most one navigation document may be specified. If no navigation document is
            specified, one is generated from all the HTML documents.</p>
            <p>If the fileset includes a <a
            href="http://www.idpf.org/epub/301/spec/epub-publications.html#cover-image"><code>cover-image</code></a>,
            it should be marked with a <code>role</code> attribute with value
            <code>cover-image</code>.</p>
        </p:documentation>
    </p:input>
    <p:input port="metadata" sequence="true">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>Metadata</p>
        </p:documentation>
        <p:empty/>
    </p:input>
    <p:input port="tts-config">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>TTS configuration file</p>
            <p>Configuration file that contains text-to-speech properties, links to aural CSS
            stylesheets and links to PLS lexicons.</p>
      </p:documentation>
      <p:inline><d:config/></p:inline>
    </p:input>

    <p:output port="fileset.out" primary="true"/>
    <p:output port="in-memory.out" sequence="true">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>The EPUB 3 publication (not zipped)</p>
        </p:documentation>
        <p:pipe step="ocf" port="in-memory"/>
    </p:output>
    <p:output port="status" px:media-type="application/vnd.pipeline.status+xml">
        <p:pipe step="tts" port="status"/>
    </p:output>
    <p:output port="temp-audio-files">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <h2 px:role="name">List of audio files</h2>
            <p px:role="desc">List of audio files generated by the TTS step. May be deleted when the
            result fileset is stored.</p>
        </p:documentation>
        <p:pipe step="add-mediaoverlays" port="temp-audio.fileset"/>
    </p:output>
    <p:output port="tts-log" sequence="true">
        <p:pipe step="tts" port="log"/>
    </p:output>

    <p:option name="output-dir" required="true">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>Root directory of the (expanded) EPUB 3.</p>
        </p:documentation>
    </p:option>
    <p:option name="temp-dir" select="''">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>Empty directory dedicated to this conversion. May be left empty in which
            case a temporary directory will be automaticall created.</p>
        </p:documentation>
    </p:option>
    <p:option name="skip-cleanup" required="false" select="'false'">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>Skip the HTML upgrade and clean up steps.</p>
        </p:documentation>
    </p:option>
    <p:option name="audio" required="false" select="'false'">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>Enable TTS</p>
            <p>Whether to use a speech synthesizer to produce audio files.</p>
        </p:documentation>
    </p:option>
    <p:option name="process-css" required="false" select="'true'">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
            <p>Set to false to bypass aural CSS processing.</p>
        </p:documentation>
    </p:option>

    <p:import href="http://www.daisy.org/pipeline/modules/epub-utils/library.xpl">
        <p:documentation>
            px:epub3-safe-uris
            px:epub3-ensure-core-media
            px:epub3-add-navigation-doc
            px:epub3-create-mediaoverlays
            px:epub3-create-package-doc
            px:epub3-ocf-finalize
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/fileset-utils/library.xpl">
        <p:documentation>
            px:fileset-load
            px:fileset-join
            px:fileset-rebase
            px:fileset-purge
            px:fileset-update
            px:fileset-filter-in-memory
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/common-utils/library.xpl">
        <p:documentation>
            px:assert
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/html-utils/library.xpl">
        <p:documentation>
            px:html-fixer
            px:html-upgrade
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/zedai-to-html/library.xpl">
        <p:documentation>
            px:diagram-to-html
        </p:documentation>
    </p:import>
    <p:import href="http://www.daisy.org/pipeline/modules/epub3-tts/library.xpl">
        <p:documentation>
            px:tts-for-epub3
        </p:documentation>
    </p:import>
    <p:import href="html-to-opf-metadata.xpl"/>

    <p:variable name="content-dir" select="concat($output-dir,'EPUB/')">
        <p:empty/>
    </p:variable>

    <!--=========================================================================-->
    <!-- MOVE FILESET TO NEW LOCATION                                            -->
    <!--=========================================================================-->

    <p:documentation>Move to EPUB/ directory</p:documentation>
    <px:fileset-copy name="move">
        <p:input port="source.in-memory">
            <p:pipe step="main" port="input.in-memory"/>
        </p:input>
        <p:with-option name="target" select="$content-dir"/>
    </px:fileset-copy>

    <!--=========================================================================-->
    <!-- CONVERT DIAGRAM TO HTML                                                 -->
    <!--=========================================================================-->

    <px:diagram-to-html name="diagram-to-html">
        <p:input port="source.in-memory">
            <p:pipe step="move" port="result.in-memory"/>
        </p:input>
    </px:diagram-to-html>

    <!--=========================================================================-->
    <!-- CLEANUP                                                                 -->
    <!--=========================================================================-->

    <p:choose name="clean">
        <p:when test="$skip-cleanup='true'">
            <p:output port="fileset" primary="true"/>
            <p:output port="in-memory" sequence="true">
                <p:pipe step="diagram-to-html" port="result.in-memory"/>
            </p:output>
            <p:identity/>
        </p:when>
        <p:otherwise>
            <p:output port="fileset" primary="true"/>
            <p:output port="in-memory" sequence="true">
                <p:pipe step="clean-resource-refs" port="result.in-memory"/>
            </p:output>

            <!--=========================================================================-->
            <!-- FILESET CLEANUP                                                         -->
            <!--=========================================================================-->

            <p:documentation>Remove resources that do not exist on disk or in memory</p:documentation>
            <px:fileset-purge>
                <p:documentation>Also normalizes @href, @original-href and @xml:base</p:documentation>
                <p:input port="source.in-memory">
                    <p:pipe step="diagram-to-html" port="result.in-memory"/>
                </p:input>
            </px:fileset-purge>

            <p:documentation>Change @href with EPUB-safe URIs</p:documentation>
            <px:epub3-safe-uris name="safe-uris">
                <p:input port="source.in-memory">
                    <p:pipe step="diagram-to-html" port="result.in-memory"/>
                </p:input>
            </px:epub3-safe-uris>

            <!--=========================================================================-->
            <!-- XHTML CLEANUP                                                           -->
            <!--=========================================================================-->

            <p:group name="clean-html">
                <p:output port="fileset" primary="true"/>
                <p:output port="in-memory" sequence="true">
                    <p:pipe step="update" port="result.in-memory"/>
                </p:output>

                <px:fileset-load media-types="application/xhtml+xml" name="html">
                    <p:input port="in-memory">
                        <p:pipe step="safe-uris" port="result.in-memory"/>
                    </p:input>
                </px:fileset-load>
                <px:assert message="No XHTML documents found." test-count-min="1" error-code="PEZE00"/>

                <p:for-each name="cleaned">
                    <p:output port="result" sequence="true"/>

                    <p:documentation>Upgrade to XHTML 5</p:documentation>
                    <px:html-upgrade/>

                    <p:documentation>Clean http-equiv</p:documentation>
                    <p:delete match="/html:html/html:head/html:meta[matches(@http-equiv,'Content-Type','i')]"/>

                    <p:documentation>Set language</p:documentation>
                    <p:group>
                        <p:variable name="lang"
                                    select="/*/(if (@lang|@xml:lang) then (@lang|@xml:lang)
                                            else p:system-property('p:language'))"/>
                        <p:add-attribute match="/*" attribute-name="lang">
                            <p:with-option name="attribute-value" select="$lang"/>
                        </p:add-attribute>
                        <p:add-attribute match="/*" attribute-name="xml:lang">
                            <p:with-option name="attribute-value" select="$lang"/>
                        </p:add-attribute>
                    </p:group>

                    <p:documentation>Fix content models</p:documentation>
                    <px:html-fixer/>

                    <p:documentation>Clean outline</p:documentation>
                    <!--TODO: try to add sections where missing -->

                </p:for-each>
                <p:sink/>
                <px:fileset-update name="update">
                    <p:input port="source.fileset">
                        <p:pipe step="safe-uris" port="result.fileset"/>
                    </p:input>
                    <p:input port="source.in-memory">
                        <p:pipe step="safe-uris" port="result.in-memory"/>
                    </p:input>
                    <p:input port="update.fileset">
                        <p:pipe step="html" port="result.fileset"/>
                    </p:input>
                    <p:input port="update.in-memory">
                        <p:pipe step="cleaned" port="result"/>
                    </p:input>
                </px:fileset-update>
            </p:group>

            <p:documentation>Clean resource references</p:documentation>
            <px:epub3-ensure-core-media name="clean-resource-refs">
                <p:input port="source.in-memory">
                    <p:pipe step="clean-html" port="in-memory"/>
                </p:input>
            </px:epub3-ensure-core-media>
        </p:otherwise>
    </p:choose>

    <!--=========================================================================-->
    <!-- GENERATE THE NAVIGATION DOCUMENT                                        -->
    <!--=========================================================================-->

    <!-- Don't include (converted) DIAGRAM in navigation doc and primary spine -->
    <px:fileset-diff>
        <p:input port="secondary">
            <p:pipe step="diagram-to-html" port="mapping"/>
        </p:input>
    </px:fileset-diff>
    <px:fileset-load media-types="application/xhtml+xml" name="content-docs-except-nav-and-diagram">
        <p:input port="in-memory">
            <p:pipe step="clean" port="in-memory"/>
        </p:input>
    </px:fileset-load>
    <p:sink/>

    <p:documentation>Generate the EPUB 3 navigation document</p:documentation>
    <px:epub3-add-navigation-doc name="add-navigation-doc">
        <p:input port="source.fileset">
            <p:pipe step="clean" port="fileset"/>
        </p:input>
        <p:input port="source.in-memory">
            <p:pipe step="clean" port="in-memory"/>
        </p:input>
        <p:input port="content">
            <p:pipe step="content-docs-except-nav-and-diagram" port="result.fileset"/>
        </p:input>
        <p:with-option name="output-base-uri" select="concat($content-dir,'toc.xhtml')"/>
    </px:epub3-add-navigation-doc>
    <p:identity px:message="Navigation Document Created."/>

    <!--=========================================================================-->
    <!-- CALL THE TTS                                                            -->
    <!--=========================================================================-->

    <!-- FIXME: include resources such as lexicons in input -->
    <px:tts-for-epub3 name="tts">
      <p:input port="source.in-memory">
          <p:pipe step="add-navigation-doc" port="result.in-memory"/>
      </p:input>
      <p:input port="config">
          <p:pipe step="main" port="tts-config"/>
      </p:input>
      <p:with-option name="audio" select="$audio"/>
      <p:with-option name="process-css" select="$process-css"/>
      <p:with-option name="temp-dir" select="$temp-dir"/>
    </px:tts-for-epub3>

    <!--=========================================================================-->
    <!-- GENERATE THE MEDIA-OVERLAYS                                             -->
    <!--=========================================================================-->

    <p:documentation>Add SMIL and audio files</p:documentation>
    <p:group name="add-mediaoverlays">
        <p:output port="fileset" primary="true"/>
        <p:output port="in-memory" sequence="true">
            <p:pipe step="tts" port="result.in-memory"/>
            <p:pipe step="mo" port="result.in-memory"/>
        </p:output>
        <p:output port="temp-audio.fileset">
            <p:pipe step="mo" port="original-audio.fileset"/>
        </p:output>
        <p:documentation>Generate SMIL files and copy audio files</p:documentation>
        <px:epub3-create-mediaoverlays flatten="true" name="mo">
            <p:input port="source.in-memory">
                <p:pipe step="tts" port="result.in-memory"/>
            </p:input>
            <p:input port="audio-map">
                <p:pipe step="tts" port="audio-map"/>
            </p:input>
            <p:with-option name="mediaoverlay-dir" select="concat($content-dir,'mo/')">
                <p:empty/>
            </p:with-option>
            <p:with-option name="audio-dir" select="concat($content-dir,'audio/')">
                <p:empty/>
            </p:with-option>
        </px:epub3-create-mediaoverlays>
        <p:sink/>
        <px:fileset-join>
            <p:input port="source">
                <p:pipe step="tts" port="result.fileset"/>
                <p:pipe step="mo" port="result.fileset"/>
            </p:input>
        </px:fileset-join>
    </p:group>
    <p:sink/>

    <!--=========================================================================-->
    <!-- GENERATE THE PACKAGE DOCUMENT                                           -->
    <!--=========================================================================-->

    <p:documentation>Extract metadata</p:documentation>
    <!-- FIXME: adapt to multiple XHTML input docs -->
    <p:split-sequence test="position()=1">
        <p:input port="source">
            <p:pipe step="content-docs-except-nav-and-diagram" port="result"/>
        </p:input>
    </p:split-sequence>
    <px:html-to-opf-metadata name="metadata"/>
    <p:sink/>

    <p:documentation>Generate the EPUB 3 package document</p:documentation>
    <p:group name="add-package-doc">
        <p:output port="fileset" primary="true"/>
        <p:output port="in-memory" sequence="true">
            <p:pipe step="add-mediaoverlays" port="in-memory"/>
            <p:pipe step="package-doc" port="result"/>
        </p:output>
        <px:epub3-create-package-doc compatibility-mode="false" name="create-package-doc">
            <p:input port="source.fileset">
                <p:pipe step="add-mediaoverlays" port="fileset"/>
            </p:input>
            <p:input port="source.in-memory">
                <p:pipe step="add-mediaoverlays" port="in-memory"/>
            </p:input>
            <p:input port="spine">
                <p:pipe step="content-docs-except-nav-and-diagram" port="result.fileset"/>
            </p:input>
            <p:input port="metadata">
                <p:pipe step="main" port="metadata"/>
                <p:pipe step="metadata" port="result"/>
            </p:input>
            <p:with-option name="output-base-uri" select="concat($content-dir,'package.opf')"/>
        </px:epub3-create-package-doc>
        <p:identity name="package-doc" px:message="Package Document Created."/>
        <p:sink/>
        <px:fileset-join>
            <p:input port="source">
                <p:pipe step="add-mediaoverlays" port="fileset"/>
                <p:pipe step="create-package-doc" port="result.fileset"/>
            </p:input>
        </px:fileset-join>
        <p:delete match="d:file/@role[.='nav']"/>
    </p:group>

    <!--=========================================================================-->
    <!-- GENERATE THE OCF DOCUMENTS                                              -->
    <!-- (container.xml, manifest.xml, metadata.xml, rights.xml, signature.xml)  -->
    <!--=========================================================================-->

    <!--
        change fileset base from EPUB/ directory to top directory because this is what
        px:epub3-ocf-finalize expects
    -->
    <px:fileset-rebase>
        <p:with-option name="new-base" select="$output-dir"/>
    </px:fileset-rebase>

    <!--TODO clean file set for non-existing files ?-->

    <p:group name="ocf">
        <p:output port="fileset" primary="true">
            <p:pipe step="ocf-finalize" port="result"/>
        </p:output>
        <p:output port="in-memory" sequence="true">
            <p:pipe step="filter-in-memory" port="result.in-memory"/>
        </p:output>
        <px:epub3-ocf-finalize name="ocf-finalize"/>
        <p:documentation>
            Remove files from memory that are not in fileset
        </p:documentation>
        <px:fileset-filter-in-memory name="filter-in-memory">
            <p:input port="source.in-memory">
                <p:pipe step="ocf-finalize" port="in-memory.out"/>
                <p:pipe step="add-package-doc" port="in-memory"/>
            </p:input>
        </px:fileset-filter-in-memory>
        <p:sink/>
    </p:group>

</p:declare-step>

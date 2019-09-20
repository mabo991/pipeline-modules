<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:f="http://www.daisy.org/ns/pipeline/internal-functions"
                xmlns="http://www.idpf.org/2007/opf"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all">

    <xsl:include href="../epub3-vocab.xsl"/>

    <xsl:param name="reserved-prefixes" required="yes"/>

    <!--=========================================-->
    <!-- Merges EPUB Publications Metadata
        
         Input: 
           a set of 'metadata' element in the OPF
           namespace, wrapped in a common root element
           (the name of the wrapper is insignificant)
           
         Output:
           a single 'metadata' element in the OPF
           namespace, containing the 'merged' metadata.
    -->
    <!--TODO: document merge rules. For now, see the tests.-->
    <!--=========================================-->

    <xsl:key name="refines" match="//meta[@refines]" use="f:unified-id(@refines)"/>

    <xsl:template match="/">
        <xsl:apply-templates select="/*">
            <xsl:with-param tunnel="yes" name="manifest" select="collection()[2]"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="/*" priority="1">
        <xsl:variable name="implicit" as="element(f:vocab)*" select="f:parse-prefix-decl($reserved-prefixes)"/>
        <xsl:variable name="all" as="element()*" select="f:all-prefix-decl(/)"/>
        <xsl:variable name="unified" as="element(f:vocab)*" select="f:unified-prefix-decl($all//f:vocab,$implicit)"/>
        <xsl:next-match>
            <xsl:with-param name="implicit" tunnel="yes" select="$implicit"/>
            <xsl:with-param name="all" tunnel="yes" select="$all"/>
            <xsl:with-param name="unified" tunnel="yes" select="$unified"/>
        </xsl:next-match>
    </xsl:template>

    <xsl:template match="/*">
        <xsl:param name="implicit" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:param name="all" as="element()*" tunnel="yes" required="yes"/>
        <xsl:param name="unified" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:param name="manifest" tunnel="yes" as="document-node()?" select="()"/>
        <metadata>
            <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>

            <xsl:if test="exists($unified)">
                <xsl:attribute name="prefix"
                    select="for $vocab in $unified return concat($vocab/@prefix,': ',$vocab/@uri)"
                />
            </xsl:if>

            <!-- dc:title(s) and refines -->
            <xsl:variable name="title" select="(//metadata/dc:title[not(@refines)])[1]"/>
            <xsl:apply-templates select="$title"/>
            <xsl:apply-templates
                select="$title/ancestor::metadata/dc:title[not(@refines) and (. != $title)]"/>

            <!-- dc:identifier(s) and refines -->
            <xsl:variable name="identifier" select="(//metadata/dc:identifier[not(@refines)])[1]"/>
            <xsl:apply-templates select="$identifier"/>
            <xsl:apply-templates
                select="$identifier/ancestor::metadata/dc:identifier[not(@refines) and (. != $identifier)]"/>

            <!-- dc:language(s) and refines -->
            <xsl:variable name="language" select="(//metadata/dc:language[not(@refines)])[1]"/>
            <xsl:apply-templates select="$language"/>
            <xsl:apply-templates
                select="$language/ancestor::metadata/dc:language[not(@refines) and (. != $language)]"/>

            <!--generate dc:modified-->
            <meta property="dcterms:modified">
                <xsl:value-of
                    select="format-dateTime(
                    adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),
                    '[Y0001]-[M01]-[D01]T[H01]:[m01]:[s01]Z')"
                />
            </meta>

            <!--DCMES Optional Elements [0 or more]
               * NOTE: several dc:type are allowed in EPUB 3.01 
               * only one: date | source
            -->
            <xsl:for-each-group
                select="//(dc:contributor|dc:coverage|dc:creator|dc:date|dc:description|dc:format
                          |dc:publisher|dc:relation|dc:rights|dc:source|dc:subject|dc:type)[empty(@refines)]"
                group-by="name()">
                <xsl:choose>
                    <xsl:when test="self::dc:date|self::dc:source">
                        <xsl:apply-templates select="current()"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates
                            select="current-group()[ancestor::metadata is current()/ancestor::metadata]"
                        />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>

            <!--meta [0 or more]-->
            <xsl:for-each-group select="//meta[empty(@refines)]"
                group-by="f:expand-property(@property,$implicit,$all,$unified)/@uri">
                <xsl:if test="current-grouping-key()">
                    <xsl:apply-templates
                        select="current-group()[ancestor::metadata is current()/ancestor::metadata]"
                    />
                </xsl:if>
            </xsl:for-each-group>

            <!-- process meta that refine manifest items -->
            <xsl:apply-templates select="//meta[replace(@refines,'^#','')=$manifest//item/@id]">
                <xsl:with-param name="copy-refines" tunnel="yes" select="true()"/>
            </xsl:apply-templates>

            <xsl:apply-templates select="//link"/>
        </metadata>
    </xsl:template>

    <xsl:template match="dc:identifier">
        <dc:identifier id="{f:unique-id((@id,generate-id())[1],//@id except @id)}">
            <xsl:apply-templates select="node() | @* except @id"/>
        </dc:identifier>
        <xsl:apply-templates select="key('refines',f:unified-id(@id))"/>
    </xsl:template>

    <xsl:template match="dc:*">
        <xsl:next-match/>
        <xsl:apply-templates select="key('refines',f:unified-id(@id))"/>
    </xsl:template>

    <xsl:template match="meta">
        <xsl:param name="implicit" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:param name="all" as="element()*" tunnel="yes" required="yes"/>
        <xsl:param name="unified" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:variable name="property" select="f:expand-property(@property,$implicit,$all,$unified)"/>
        <xsl:choose>
            <xsl:when test="$property/@uri='http://purl.org/dc/terms/modified'"/>
            <xsl:when test="not(normalize-space())">
                <xsl:message>[WARNING] Discarding empty property '<xsl:value-of select="@property"
                    />'.</xsl:message>
            </xsl:when>
            <xsl:when test="$property/@uri=''">
                <xsl:message>[WARNING] Discarding property '<xsl:value-of select="@property"/>' from
                    an undeclared vocab.</xsl:message>
            </xsl:when>
            <xsl:when
                test="$property/@prefix='' and $property/@name=('display-seq','meta-auth')">
                <xsl:message>[WARNING] The deprecated property '<xsl:value-of select="@property"
                    />' was found.</xsl:message>
                    <xsl:next-match/>
            </xsl:when>
            <xsl:when
                test="$property/@prefix='' and not($property/@name=('alternate-script','display-seq',
                'file-as','group-position','identifier-type','meta-auth','role','title-type'))">
                <xsl:message>[WARNING] Discarding unknown property '<xsl:value-of select="@property"
                    />'.</xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="key('refines',f:unified-id(@id))"/>
    </xsl:template>

    <xsl:template match="link">
        <xsl:param name="implicit" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:param name="all" as="element()*" tunnel="yes" required="yes"/>
        <xsl:param name="unified" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:variable name="rel" select="f:expand-property(@rel,$implicit,$all,$unified)"/>
        <xsl:choose>
            <xsl:when test="not(@href) or not(@rel)">
                <xsl:message>[WARNING] Discarding link with no @href or @rel
                    attributes.</xsl:message>
            </xsl:when>
            <!-- EPUB3.2: values marc21xml-record, mods-record, onix-record, and xmp-signature of @rel are deprecated and should be replaced by 'record'-->
            <xsl:when
                test="$rel/@prefix='' and $rel/@name=('marc21xml-record',
                'mods-record','onix-record','xml-signature xmp-record')">
                <xsl:message>[WARNING] Found link with deprecated @rel value '<xsl:value-of
                        select="@rel"/>'. This value should be replaced by 'record' with a corresponding 'media-type' attribute.</xsl:message>
                    <xsl:next-match/>
            </xsl:when>
            <xsl:when
                test="$rel/@prefix='' and not($rel/@name=('marc21xml-record',
                'mods-record','onix-record','xml-signature xmp-record','record','acquire','alternate'))">
                <xsl:message>[WARNING] Discarding link with unknown @rel value '<xsl:value-of
                        select="@rel"/>'.</xsl:message>
            </xsl:when>
            <xsl:when test="$rel/@uri=''">
                <xsl:message>[WARNING] Discarding link with @rel value '<xsl:value-of
                        select="@property"/>' from an undeclared vocab.</xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="@property">
        <xsl:param name="implicit" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:param name="all" as="element()*" tunnel="yes" required="yes"/>
        <xsl:param name="unified" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:attribute name="property" select="f:expand-property(.,$implicit,$all,$unified)/@name"/>
    </xsl:template>
    <xsl:template match="@scheme">
        <xsl:param name="implicit" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:param name="all" as="element()*" tunnel="yes" required="yes"/>
        <xsl:param name="unified" as="element(f:vocab)*" tunnel="yes" required="yes"/>
        <xsl:attribute name="scheme" select="f:expand-property(.,$implicit,$all,$unified)/@name"/>
    </xsl:template>
    <xsl:template match="@id">
        <xsl:attribute name="id" select="f:unified-id(.)"/>
    </xsl:template>
    <xsl:template match="@refines">
        <xsl:param name="copy-refines" tunnel="yes" as="xs:boolean?" select="false()"/>
        <xsl:choose>
            <xsl:when test="$copy-refines">
                <xsl:sequence select="."/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="refines" select="concat('#',f:unified-id(.))"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/phony" xpath-default-namespace="">
        <!-- avoid SXXP0005 warning -->
        <xsl:next-match/>
    </xsl:template>

    <!-- 
        Returns a non-conflicting ID for an *existing* ID or IDREF attribute
        The non-conflicting ID is created by appending the position number
        of the parent metadata set for all sets after the first
    -->
    <xsl:function name="f:unified-id" as="xs:string">
        <xsl:param name="id" as="attribute()?"/>
        <xsl:variable name="count" select="count($id/ancestor::metadata/preceding-sibling::*)"
            as="xs:integer"/>
        <xsl:sequence
            select="concat(if (starts-with($id,'#')) then substring($id,2) else $id, if ($count) then $count+1 else '')"
        />
    </xsl:function>

    
    <!-- 
        Returns a non-conflicting ID for a *new* ID or IDREF attribute, given
        a sequence of existing IDs.
        The non-conflicting ID is created by prepending a number of 'x'
        to the ID until it doesn't conflict with existing ones.
        This rule guarantees it won't conflict with IDs created by f:unified-id().
    -->
    <xsl:function name="f:unique-id" as="xs:string">
        <xsl:param name="id" as="xs:string"/>
        <xsl:param name="existing" as="xs:string*"/>
        <xsl:sequence
            select="
            if (not($id=$existing)) then $id
            else f:unique-id(concat('x',$id),$existing)
            "
        />
    </xsl:function>

    <!--
        Returns a sequence of `f:property` elements from a property-typeed attribute where:
        
         * @prefix contains the resolved, unified prefix for the property
         * @uri contains the resolved absolute URI of the property
         * @name contains the resolved name for the property, prefixed by the unified prefix
    -->
    <!--TODO move to a generic util ?-->
    <xsl:function name="f:expand-property" as="element(f:property)">
        <xsl:param name="property" as="attribute()?"/>
        <xsl:param name="implicit" as="element(f:vocab)*"/>
        <xsl:param name="all" as="element()*"/>
        <xsl:param name="unified" as="element(f:vocab)*"/>
        <xsl:variable name="prefix" select="substring-before($property,':')" as="xs:string"/>
        <xsl:variable name="reference" select="replace($property,'(.+:)','')" as="xs:string"/>
        <xsl:variable name="vocab"
            select="($all[@id=generate-id($property/ancestor::metadata)]/f:vocab[@prefix=$prefix]/@uri,
                     if ($prefix='') then $vocab-package-uri else (),
                     $f:default-prefixes[@prefix=$prefix]/@uri,
                     ''
                     )[1]"
            as="xs:string"/>
        <xsl:variable name="unified-prefix"
            select="(if ($vocab=$vocab-package-uri) then '' else (),
                     $implicit[@uri=$vocab]/@prefix,
                     $unified[@uri=$vocab]/@prefix
                     )[1]"
            as="xs:string?"/>
        <f:property prefix="{$unified-prefix}"
            uri="{if($vocab) then concat($vocab,$reference) else ''}"
            name="{if ($unified-prefix) then concat($unified-prefix,':',$reference)  else $reference}"
        />
    </xsl:function>

    <!--
        Returns all the vocabs declared in the various metadata sets, as `f:vocab` elements
        grouped by `metadata` elements (these latter having `@id` attributes generated by
        `generate-id()`.
        
        Vocabs that are not used in `@property`, `@scheme` or `@rel` are discarded.
    -->
    <xsl:function name="f:all-prefix-decl" as="element()*">
        <xsl:param name="doc" as="document-node()?"/>
        <xsl:for-each select="$doc//metadata">
            <metadata id="{generate-id(.)}">
                <xsl:variable name="used-prefixes" as="xs:string*"
                              select="distinct-values(
                                        for $prop in distinct-values(.//meta/(@property|@scheme)|.//link/@rel)[contains(.,':')]
                                        return substring-before($prop,':'))"/>
                <xsl:variable name="parsed-prefix-attr" as="element(f:vocab)*" select="f:parse-prefix-decl(@prefix)"/>
                <xsl:sequence select="for $prefix in $used-prefixes return
                                      ($parsed-prefix-attr[@prefix=$prefix],$f:default-prefixes[@prefix=$prefix])[1]"/>
            </metadata>
        </xsl:for-each>
    </xsl:function>

    <!--
        Returns a sequence of `f:vocab` elements representing unified vocab declarations
    throughout the document passed as argument.
        
        * reserved vocabs are discarded (don't have to be declared)
        * @prefix are unified, if it is overriding a reserved prefix, a new prefix is defined
        
    -->
    <xsl:function name="f:unified-prefix-decl" as="element()*">
        <xsl:param name="all" as="element(f:vocab)*"/>
        <xsl:param name="implicit" as="element(f:vocab)*"/>
        <xsl:for-each-group select="f:merge-prefix-decl($all)
                                    [not(@uri=($vocab-package-uri,
                                               $implicit/@uri))]"
                            group-by="@uri">
            <xsl:sequence select="current()"/>
        </xsl:for-each-group>
    </xsl:function>

</xsl:stylesheet>

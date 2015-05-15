<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
                xmlns:pxi="http://www.daisy.org/ns/pipeline/xproc/internal"
                xmlns:css="http://www.daisy.org/ns/pipeline/braille-css"
                type="pxi:fix-page-break"
                exclude-inline-prefixes="#all"
                version="1.0">
    
    <p:documentation>
        Change, add and remove page-break properties so that they can be mapped one-to-one on OBFL
        properties.
    </p:documentation>
    
    <p:input port="source">
        <p:documentation>
            The input is assumed to be a tree-of-boxes representation of a document that consists of
            only css:box elements and text nodes (and css:_ elements if they are document
            elements). Text and inline boxes must not have sibling block boxes, and there should be
            no block boxes inside inline boxes. The 'page-break' properties of block boxes must be
            declared in css:page-break-before, css:page-break-after and css:page-break-inside
            attributes.
        </p:documentation>
    </p:input>
    
    <p:output port="result">
        <p:documentation>
            A 'page-break-before' property with value 'left', 'right' or 'always' is converted into
            a 'page-break-before' property on the first descendant-or-self block box with no child
            block boxes. A 'page-break-after' property with value 'avoid' is converted into a
            'page-break-after' property on the last descendant-or-self block box with no child block
            boxes. A 'page-break-before' property with value 'avoid' is converted into a
            'page-break-after' property on the first preceding block box with no child block
            boxes. A 'page-break-after' property with value 'left', 'right' or 'always' is converted
            into a 'page-break-before' property on the first following block box with no child block
            boxes. A 'page-break-inside' property with value 'avoid' on a box with child block boxes
            is propagated to all its children, and all children except the last get a
            'page-break-after' property with value 'avoid'. In case of conflicts, the value 'always'
            takes precedence over 'avoid', and 'avoid' takes precedence over 'auto'.
        </p:documentation>
    </p:output>
    
    <p:xslt>
        <p:input port="stylesheet">
            <p:document href="fix-page-break.xsl"/>
        </p:input>
        <p:input port="parameters">
            <p:empty/>
        </p:input>
    </p:xslt>
    
    <p:add-attribute match="css:box[@type='block']
                                   [not(child::css:box[@type='block'])]
                                   [preceding::css:box[@type='block'][not(child::css:box[@type='block'])][1]/@css:page-break-after='always']"
                     attribute-name="css:page-break-before"
                     attribute-value="always"/>
    <p:add-attribute match="css:box[@type='block']
                                   [not(child::css:box[@type='block'])]
                                   [following::css:box[@type='block'][not(child::css:box[@type='block'])][1]/@css:page-break-before='avoid']"
                     attribute-name="css:page-break-after"
                     attribute-value="avoid"/>
    <p:delete match="@css:page-break-before[.='avoid']"/>
    <p:delete match="@css:page-break-after[.='always']"/>
    
</p:declare-step>

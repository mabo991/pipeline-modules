<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step
	xmlns:p="http://www.w3.org/ns/xproc"
	xmlns:px="http://www.daisy.org/ns/pipeline/xproc"
	xmlns:cx="http://xmlcalabash.com/ns/extensions"
	exclude-inline-prefixes="px"
	type="px:mark-transitions" name="mark-transitions" version="1.0">
	
	<p:input port="source" primary="true" px:media-type="application/z3998-auth+xml"/>
	<p:output port="result" primary="true" px:media-type="application/z3998-auth+xml"/>
	<p:option name="predicate" required="true"/>
	<p:option name="announcement" required="true"/>
	<p:option name="deannouncement" required="true"/>
	
	<p:import href="http://www.daisy.org/pipeline/modules/common-utils/library.xpl"/>
	
	<px:message message="[progress px:mark-transitions 50 mark-transitions.xsl] Marking transitions (compiling stylesheet)"/>
	<p:xslt name="stylesheet">
		<p:input port="stylesheet">
			<p:document href="mark-transitions.xsl"/>
		</p:input>
		<p:input port="parameters">
			<p:empty/>
		</p:input>
		<p:with-param name="predicate" select="$predicate">
			<p:empty/>
		</p:with-param>
	</p:xslt>
	
	<px:message cx:depends-on="stylesheet" message="[progress px:mark-transitions 50] Marking transitions (applying compiled stylesheet)">
		<p:input port="source">
			<p:pipe step="mark-transitions" port="source"/>
		</p:input>
	</px:message>
	<p:xslt>
		<p:input port="stylesheet">
			<p:pipe step="stylesheet" port="result"/>
		</p:input>
		<p:input port="parameters">
			<p:empty/>
		</p:input>
		<p:with-param name="announcement" select="$announcement">
			<p:empty/>
		</p:with-param>
		<p:with-param name="deannouncement" select="$deannouncement">
			<p:empty/>
		</p:with-param>
	</p:xslt>
	
</p:declare-step>

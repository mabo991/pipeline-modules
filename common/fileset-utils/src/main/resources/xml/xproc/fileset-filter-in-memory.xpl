<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" version="1.0"
                xmlns:px="http://www.daisy.org/ns/pipeline/xproc"
                type="px:fileset-filter-in-memory" name="main">
	
	<p:documentation xmlns="http://www.w3.org/1999/xhtml">
		<p>Remove the entries from a fileset that are not loaded into memory.</p>
	</p:documentation>
	
	<p:input port="source.fileset" primary="true"/>
	<p:input port="source.in-memory" sequence="true"/>
	<p:output port="result" primary="true">
		<p:documentation xmlns="http://www.w3.org/1999/xhtml">
			<p>The pruned fileset manifest.</p>
		</p:documentation>
		<p:pipe step="intersect" port="result"/>
	</p:output>
	<p:output port="not-in-manifest">
		<p:documentation xmlns="http://www.w3.org/1999/xhtml">
			<p>Fileset of in-memory documents that are not contained in the input fileset.</p>
		</p:documentation>
		<p:pipe step="not-in-manifest" port="result"/>
	</p:output>
	
	<p:import href="fileset-create.xpl"/>
	<p:import href="fileset-add-entry.xpl"/>
	<p:import href="fileset-join.xpl"/>
	<p:import href="fileset-intersect.xpl"/>
	<p:import href="fileset-diff.xpl"/>
	
	<px:fileset-create name="base" base="/"/>
	
	<p:for-each>
		<p:iteration-source>
			<p:pipe step="main" port="source.in-memory"/>
		</p:iteration-source>
		<px:fileset-add-entry>
			<p:with-option name="href" select="resolve-uri(base-uri(/*))"/>
			<p:input port="source">
				<p:pipe step="base" port="result"/>
			</p:input>
		</px:fileset-add-entry>
	</p:for-each>
	<px:fileset-join name="fileset-from-in-memory">
		<p:documentation>Also normalizes @href</p:documentation>
	</px:fileset-join>
	<p:sink/>
	
	<px:fileset-join name="fileset-normalized">
		<p:documentation>Normalize @href, so that px:fileset-intersect and px:fileset-diff work correctly.</p:documentation>
		<p:input port="source">
			<p:pipe step="main" port="source.fileset"/>
		</p:input>
	</px:fileset-join>
	
	<px:fileset-intersect name="intersect">
		<p:input port="source">
			<p:pipe step="fileset-normalized" port="result"/>
			<p:pipe step="fileset-from-in-memory" port="result"/>
		</p:input>
	</px:fileset-intersect>
	<p:sink/>
	
	<px:fileset-diff name="not-in-manifest">
		<p:input port="source">
			<p:pipe step="fileset-from-in-memory" port="result"/>
		</p:input>
		<p:input port="secondary">
			<p:pipe step="fileset-normalized" port="result"/>
		</p:input>
	</px:fileset-diff>
	<p:sink/>
	
</p:declare-step>

<?xml version="1.0" encoding="UTF-8"?>
<p:library xmlns:p="http://www.w3.org/ns/xproc" version="1.0">
	<p:import href="pub/epub3-pub-library.xpl">
		<p:documentation xmlns="http://www.w3.org/1999/xhtml">
			<p>Steps related to the <a
			href="http://www.idpf.org/epub/301/spec/epub-publications.html">EPUB Package
			Document</a> (the .opf file)</p>
		</p:documentation>
	</p:import>
	<p:import href="nav/epub3-nav-library.xpl">
		<p:documentation xmlns="http://www.w3.org/1999/xhtml">
			<p>Steps related to <a
			href="http://www.idpf.org/epub/30/spec/epub30-contentdocs.html#sec-xhtml-nav">EPUB
			Navigation Documents</a></p>
		</p:documentation>
	</p:import>
	<p:import href="ocf/epub3-ocf-library.xpl">
		<p:documentation xmlns="http://www.w3.org/1999/xhtml">
			<p>Steps related to the <a href="https://www.w3.org/publishing/epub3/epub-ocf.html">EPUB
			Open Container Format (OCF)</a> (the ZIP, the mimetype file, the META-INF/container.xml
			file, etc.)</p>
		</p:documentation>
	</p:import>
	<p:import href="mo/create-mediaoverlays.xpl">
		<p:documentation xmlns="http://www.w3.org/1999/xhtml">
			<p>Steps related to EPUB 3 Media Overlays.</p>
		</p:documentation>
	</p:import>
	<p:import href="validate/epub3-validate.xpl">
		<p:documentation xmlns="http://www.w3.org/1999/xhtml">
			<p>Validation with EpubCheck and Ace.</p>
		</p:documentation>
	</p:import>
	<p:import href="epub3-safe-uris.xpl"/>
	<p:import href="epub3-rename-files.xpl"/>
	<p:import href="epub3-update-links.xpl"/>
</p:library>

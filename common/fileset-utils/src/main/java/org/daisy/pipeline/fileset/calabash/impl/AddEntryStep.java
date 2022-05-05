package org.daisy.pipeline.fileset.calabash.impl;

import java.net.URI;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

import javax.xml.namespace.QName;
import static javax.xml.stream.XMLStreamConstants.END_DOCUMENT;
import static javax.xml.stream.XMLStreamConstants.END_ELEMENT;
import static javax.xml.stream.XMLStreamConstants.START_DOCUMENT;
import static javax.xml.stream.XMLStreamConstants.START_ELEMENT;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;
import javax.xml.XMLConstants;

import com.xmlcalabash.core.XProcRuntime;
import com.xmlcalabash.io.ReadablePipe;
import com.xmlcalabash.io.WritablePipe;
import com.xmlcalabash.library.DefaultStep;
import com.xmlcalabash.model.RuntimeValue;
import com.xmlcalabash.runtime.XAtomicStep;

import net.sf.saxon.s9api.XdmNode;
import net.sf.saxon.s9api.SaxonApiException;

import org.daisy.common.saxon.SaxonHelper;
import org.daisy.common.stax.BaseURIAwareXMLStreamReader;
import org.daisy.common.stax.BaseURIAwareXMLStreamWriter;
import org.daisy.common.stax.XMLStreamWriterHelper;
import org.daisy.common.stax.XMLStreamWriterHelper.BufferedXMLStreamWriter;
import org.daisy.common.stax.XMLStreamWriterHelper.FutureWriterEvent;
import org.daisy.common.transform.TransformerException;
import org.daisy.common.xproc.calabash.XProcStep;
import org.daisy.common.xproc.calabash.XProcStepProvider;
import org.daisy.common.xproc.calabash.XMLCalabashInputValue;
import org.daisy.common.xproc.calabash.XMLCalabashOutputValue;
import org.daisy.pipeline.file.FileUtils;

import org.osgi.service.component.annotations.Component;

import org.slf4j.Logger;

public class AddEntryStep extends DefaultStep implements XProcStep {

	@Component(
		name = "pxi:fileset-add-entry",
		service = { XProcStepProvider.class },
		property = { "type:String={http://www.daisy.org/ns/pipeline/xproc/internal}fileset-add-entry" }
	)
	public static class StepProvider implements XProcStepProvider {
		@Override
		public XProcStep newStep(XProcRuntime runtime, XAtomicStep step) {
			return new AddEntryStep(runtime, step);
		}
	}

	private static final QName _HREF = new QName("href");
	private static final QName _MEDIA_TYPE = new QName("media-type");
	private static final QName _ORIGINAL_HREF = new QName("original-href");
	private static final net.sf.saxon.s9api.QName _FIRST = new net.sf.saxon.s9api.QName("first");
	private static final net.sf.saxon.s9api.QName _REPLACE = new net.sf.saxon.s9api.QName("replace");
	private static final net.sf.saxon.s9api.QName _REPLACE_ATTRIBUTES = new net.sf.saxon.s9api.QName("replace-attributes");
	private static final QName XML_BASE = new QName(XMLConstants.XML_NS_URI, "base", "xml");
	private static final QName D_FILE = new QName("http://www.daisy.org/ns/pipeline/data", "file", "d");

	private ReadablePipe sourceFilesetPipe = null;
	private ReadablePipe sourceInMemoryPipe = null;
	private ReadablePipe entryPipe = null;
	private WritablePipe resultFilesetPipe = null;
	private WritablePipe resultInMemoryPipe = null;
	private Map<QName,String> fileAttributes = null;

	private AddEntryStep(XProcRuntime runtime, XAtomicStep step) {
		super(runtime, step);
	}

	@Override
	public void setInput(String port, ReadablePipe pipe) {
		if ("source.fileset".equals(port))
			sourceFilesetPipe = pipe;
		else if ("source.in-memory".equals(port))
			sourceInMemoryPipe = pipe;
		else if ("entry".equals(port))
			entryPipe = pipe;
	}

	@Override
	public void setOutput(String port, WritablePipe pipe) {
		if ("result.fileset".equals(port))
			resultFilesetPipe = pipe;
		else if ("result.in-memory".equals(port))
			resultInMemoryPipe = pipe;
	}

	@Override
	public void reset() {
		sourceFilesetPipe.resetReader();
		sourceInMemoryPipe.resetReader();
		entryPipe.resetReader();
		resultFilesetPipe.resetWriter();
		resultInMemoryPipe.resetWriter();
		if (fileAttributes != null) fileAttributes.clear();
	}

	public void setParameter(net.sf.saxon.s9api.QName name, RuntimeValue value) {
		if (fileAttributes == null)
			fileAttributes = new HashMap<>();
		fileAttributes.put(SaxonHelper.jaxpQName(name), value.getString());
	}

	public void setParameter(String port, net.sf.saxon.s9api.QName name, RuntimeValue value) {
		setParameter(name, value);
	}

	@Override
	public void run() throws SaxonApiException {
		super.run();
		try {
			File entry; {
				String href = getOption(new net.sf.saxon.s9api.QName(_HREF), "");
				if ("".equals(href)) {
					if (!entryPipe.moreDocuments())
						throw TransformerException.wrap(
							new IllegalArgumentException("Expected 1 document on the entry port"));
					entry = new File(entryPipe.read());
				} else {
					if (entryPipe.moreDocuments())
						throw TransformerException.wrap(
							new IllegalArgumentException("Expected 0 documents on the entry port"));
					entry = new File(URI.create(href));
				}
			}
			URI originalHref; {
				String option = getOption(new net.sf.saxon.s9api.QName(_ORIGINAL_HREF), "");
				if ("".equals(option))
					originalHref = null;
				else
					originalHref = URI.create(option);
			}
			String mediaType = getOption(new net.sf.saxon.s9api.QName(_MEDIA_TYPE), "");
			if ("".equals(mediaType)) mediaType = null;
			entry.originalHref = originalHref;
			entry.mediaType = mediaType;
			entry.otherAttributes = fileAttributes;
			boolean first = getOption(_FIRST, false);
			boolean replace = getOption(_REPLACE, false);
			boolean replaceAttributes = getOption(_REPLACE_ATTRIBUTES, false);
			List<File> added = addEntry(new XMLCalabashInputValue(sourceFilesetPipe).asXMLStreamReader(),
			                             new XMLCalabashOutputValue(resultFilesetPipe, runtime).asXMLStreamWriter(),
			                             entry, first, replace, replaceAttributes, logger);
			if (first)
				for (File f : added)
					if (f.node != null)
						resultInMemoryPipe.write(f.node);
			while (sourceInMemoryPipe.moreDocuments())
				resultInMemoryPipe.write(sourceInMemoryPipe.read());
			if (!first)
				for (File f : added)
					if (f.node != null)
						resultInMemoryPipe.write(f.node);
		} catch (Throwable e) {
			throw XProcStep.raiseError(e, step);
		}
	}

	private static List<File> addEntry(BaseURIAwareXMLStreamReader source, BaseURIAwareXMLStreamWriter result,
	                                   File entry, boolean first, boolean replace, boolean replaceAttributes, Logger logger)
			throws XMLStreamException {
		FileSet added = new FileSet();
		URI filesetBase = source.getBaseURI();
		result.setBaseURI(filesetBase);
		result.writeStartDocument();
		result = new BufferedXMLStreamWriter(result);
		int depth = 0;
		boolean exists = false;
		boolean hasXmlBase = false;
	  document: while (true)
			try {
				int event = source.next();
				switch (event) {
				case START_DOCUMENT:
					break;
				case END_DOCUMENT:
					break document;
				case START_ELEMENT:
					if (depth == 0) {
						// <d:fileset>
						for (int i = 0; i < source.getAttributeCount(); i++)
							if (XML_BASE.equals(source.getAttributeName(i))) {
								hasXmlBase = true;
								filesetBase = filesetBase.resolve(source.getAttributeValue(i));
								break;
							}
						filesetBase = FileUtils.normalizeURI(filesetBase);
						entry.base = FileUtils.normalizeURI(filesetBase.resolve(entry.href));
						if (hasXmlBase)
							entry.href = FileUtils.relativizeURI(entry.base, filesetBase);
						else if (!entry.href.isAbsolute())
							logger.warn("Adding a relative resource to a file set with no base directory");
						if (entry.originalHref != null)
							entry.originalHref = FileUtils.normalizeURI(filesetBase.resolve(entry.originalHref));
						XMLStreamWriterHelper.writeStartElement(result, source.getName());
						XMLStreamWriterHelper.writeAttributes(result, source);
						depth++;
						if (first)
							// insert entry
							((BufferedXMLStreamWriter)result).writeEvent(added);
					} else if (depth == 1) {
						// <d:file>
						boolean match = false; {
							if (!exists)
								for (int i = 0; i < source.getAttributeCount(); i++)
									if (_HREF.equals(source.getAttributeName(i))) {
										URI base = FileUtils.normalizeURI(filesetBase.resolve(source.getAttributeValue(i)));
										match = entry.base.equals(base);
										break;
									}
						}
						if (match) {
							exists = true;
							if (replace) {
								// skip entry
							  element: while (true) {
									event = source.next();
									switch (event) {
									case START_ELEMENT:
										depth++;
										break;
									case END_ELEMENT:
										if (depth == 1) break element;
										depth--;
										break;
									default:
									}
								}
							} else if (replaceAttributes) {
								// update entry
								XMLStreamWriterHelper.writeStartElement(result, source.getName());
								Map<QName,String> existingAttributes = new HashMap<>(); {
									for (int i = 0; i < source.getAttributeCount(); i++)
										existingAttributes.put(source.getAttributeName(i), source.getAttributeValue(i));
								}
								writeFileAttributes(result, existingAttributes, entry.originalHref, entry.mediaType, entry.otherAttributes);
								depth++;
							} else
								// keep entry
								XMLStreamWriterHelper.writeElement(result, source);
						} else
							// keep entry
							XMLStreamWriterHelper.writeElement(result, source);
					} else
						// keep entry
						XMLStreamWriterHelper.writeElement(result, source);
					break;
				case END_ELEMENT:
					depth--;
					if (depth == 0) {
						// </d:fileset>
						if (!first)
							// insert entry
							((BufferedXMLStreamWriter)result).writeEvent(added);
					}
				default:
					XMLStreamWriterHelper.writeEvent(result, source);
				}
			} catch (NoSuchElementException e) {
				break;
			}
		result.writeEndDocument();
		if (replace || !exists)
			added.add(entry);
		added.ready = true;
		result.flush();
		return added;
	}

	private static void writeFileAttributes(XMLStreamWriter result, Map<QName,String> existingAttributes,
	                                        URI originalHref, String mediaType, Map<QName,String> otherAttributes)
			throws XMLStreamException {
		if (originalHref != null)
			XMLStreamWriterHelper.writeAttribute(result, _ORIGINAL_HREF, originalHref.toASCIIString());
		if (mediaType != null)
			XMLStreamWriterHelper.writeAttribute(result, _MEDIA_TYPE, mediaType);
		if (otherAttributes != null)
			for (QName attr : otherAttributes.keySet())
				if (_HREF.equals(attr) ||
				    _ORIGINAL_HREF.equals(attr) ||
				    _MEDIA_TYPE.equals(attr))
					throw TransformerException.wrap(
						new IllegalArgumentException(
							"href, original-href and media-type are not allowed file attributes"));
				else
					XMLStreamWriterHelper.writeAttribute(result, attr, otherAttributes.get(attr));
		if (existingAttributes != null)
			for (QName attr : existingAttributes.keySet())
				if ((originalHref == null || !_ORIGINAL_HREF.equals(attr)) &&
				    (mediaType == null || !_MEDIA_TYPE.equals(attr)) &&
				    (otherAttributes == null || !otherAttributes.containsKey(attr)))
					XMLStreamWriterHelper.writeAttribute(result, attr, existingAttributes.get(attr));
	}

	private static class File {
		XdmNode node;
		URI base = null; // absolute
		URI href; // relative or absolute
		URI originalHref = null; // absolute
		String mediaType = null;
		Map<QName,String> otherAttributes = null;
		public File(URI href) {
			this.node = null;
			this.href = href;
		}
		public File(XdmNode node) {
			this.node = node;
			this.href = node.getBaseURI();
		}
	}

	private static class FileSet extends ArrayList<File> implements FutureWriterEvent {
		boolean ready = false;
		public void writeTo(XMLStreamWriter writer) throws XMLStreamException {
			for (File f : this) {
				XMLStreamWriterHelper.writeStartElement(writer, D_FILE);
				XMLStreamWriterHelper.writeAttribute(writer, _HREF, f.href.toASCIIString());
				writeFileAttributes(writer, null, f.originalHref, f.mediaType, f.otherAttributes);
				writer.writeEndElement();
			}
		}
		public boolean isReady() {
			return ready;
		}
	}
}

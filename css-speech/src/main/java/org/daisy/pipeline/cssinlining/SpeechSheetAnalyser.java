package org.daisy.pipeline.cssinlining;

import java.net.URL;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import org.w3c.dom.Document;

import cz.vutbr.web.css.CSSFactory;
import cz.vutbr.web.css.StyleSheet;
import cz.vutbr.web.css.SupportedCSS;
import cz.vutbr.web.domassign.Analyzer;
import cz.vutbr.web.domassign.StyleMap;
import cz.vutbr.web.domassign.SupportedCSS21;

public class SpeechSheetAnalyser {
	private static SupportedCSS SupportedCSS;
	private static final String Medium = "speech";

	static {
		SupportedCSS = SupportedCSS21.getInstance();
		CSSFactory.registerSupportedCSS(SupportedCSS);
		CSSFactory.registerDeclarationTransformer(new SpeechDeclarationTransformer());
	}

	private Analyzer mAnalyzer;

	public void analyse(Collection<String> URIs) {

		if (!SupportedCSS.isSupportedMedia(Medium)) {
			throw new IllegalStateException("medium '" + Medium + "' is not supported");
		}
		// create a CSS matcher for the given stylesheets
		List<StyleSheet> styleSheets = new ArrayList<StyleSheet>();
		try {
			for (String uri : URIs) {
				styleSheets.add(CSSFactory.parse(new URL(uri), "utf-8"));
			}
		} catch (Exception e) {
			throw new IllegalArgumentException(
			        "could not analyse one of the CSS stylesheet(s): " + e.getMessage());
		}

		mAnalyzer = new Analyzer(styleSheets);
	}

	public StyleMap evaluateDOM(Document doc) {
		return mAnalyzer.evaluateDOM(doc, Medium, false);
	}
}

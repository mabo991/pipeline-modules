package org.daisy.pipeline.tts.synthesize;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentLinkedQueue;

import net.sf.saxon.s9api.XdmNode;

import org.daisy.pipeline.audio.AudioEncoder;
import org.daisy.pipeline.tts.TTSService;
import org.daisy.pipeline.tts.TTSService.RawAudioBuffer;
import org.daisy.pipeline.tts.TTSService.SynthesisException;
import org.daisy.pipeline.tts.TTSService.Voice;
import org.daisy.pipeline.tts.synthesize.SynthesisWorkerPool.Speakable;
import org.daisy.pipeline.tts.synthesize.SynthesisWorkerPool.UndispatchableSection;

/**
 * The SynthesisWorkerThread is meant to be used by a SynthesisWorkerPool. It
 * works as follow: when it receives a new piece of SSML, it calls the
 * synthesizer to transform it to raw audio data. The data is added to the
 * thread's internal audio buffer and when the buffer is about to be full, the
 * threads call the encoder to transform the buffer into a compressed audio
 * file.
 */
public class SynthesisWorkerThread extends Thread implements FormatSpecifications {

	// 20 seconds with 24kHz 16 bits audio
	private static final int MAX_ESTIMATED_SYNTHESIZED_BYTES = 24000 * 2 * 20;

	// 2 minutes, i.e. ~6MBytes
	private static final int AUDIO_BUFFER_BYTES = 24000 * 2 * 60 * 2;

	//number of tries before giving up synthesizing a piece of SSML
	private static final int SYNTHESIS_TRIES = 3;

	private AudioEncoder mEncoder; // must be thread-safe!
	private byte[] mOutput;
	private RawAudioBuffer mAudioBuffer;
	private List<SoundFragment> mGlobalSoundFragments; // must be thread-safe!
	private List<SoundFragment> mCurrentFragments;
	private IPipelineLogger mLogger;
	private TTSService mLastUsedSynthesizer; // must be thread-safe!
	private ConcurrentLinkedQueue<UndispatchableSection> mSectionsQueue;
	private Map<TTSService, Object> mResources;
	private int mCurrentDocPosition;
	private int mSectionFiles;

	public void init(AudioEncoder encoder, IPipelineLogger logger,
	        List<SoundFragment> allSoundFragments,
	        ConcurrentLinkedQueue<UndispatchableSection> sectionQueue) {
		mOutput = new byte[AUDIO_BUFFER_BYTES];
		mResources = new HashMap<TTSService, Object>();
		mEncoder = encoder;
		mAudioBuffer = new RawAudioBuffer();
		mAudioBuffer.offsetInOutput = 0;
		mAudioBuffer.output = mOutput;

		mCurrentFragments = new LinkedList<SoundFragment>();
		mGlobalSoundFragments = allSoundFragments;
		mLogger = logger;
		mSectionsQueue = sectionQueue;
	}

	private void encodeAudio() {
		String preferredFileName = String.format("section%04d_%04d", mCurrentDocPosition,
		        mSectionFiles);

		String soundFile = mEncoder.encode(mAudioBuffer.output, mAudioBuffer.offsetInOutput,
		        mLastUsedSynthesizer.getAudioOutputFormat(), this, preferredFileName);

		if (soundFile == null) {
			float sec = mAudioBuffer.offsetInOutput
			        / mLastUsedSynthesizer.getAudioOutputFormat().getFrameRate();
			mLogger.printInfo("" + sec + " seconds of audio data could not be encoded!");
		} else {
			for (SoundFragment sf : mCurrentFragments) {
				sf.soundFileURI = soundFile;
			}
			mGlobalSoundFragments.addAll(mCurrentFragments); // must be thread-safe
		}

		// reset the state of the thread
		mAudioBuffer.offsetInOutput = 0;
		mAudioBuffer.output = mOutput;
		mCurrentFragments.clear();
		++mSectionFiles;
	}

	private double convertBytesToSecond(int bytes) {
		return (bytes / (mLastUsedSynthesizer.getAudioOutputFormat().getFrameRate() * mLastUsedSynthesizer
		        .getAudioOutputFormat().getFrameSize()));
	}

	public void allocateResourcesFor(TTSService s) throws SynthesisException {
		mResources.put(s, s.allocateThreadResources());
	}

	public void releaseResources() throws SynthesisException {
		for (Map.Entry<TTSService, Object> resource : mResources.entrySet()) {
			resource.getKey().releaseThreadResources(resource.getValue());
		}
	}

	private void processOneSentence(XdmNode sentence, Voice voice) throws SynthesisException {
		if (mAudioBuffer.offsetInOutput + MAX_ESTIMATED_SYNTHESIZED_BYTES > mAudioBuffer.output.length) {
			encodeAudio();
		}
		Object resource = mResources.get(mLastUsedSynthesizer);
		List<Map.Entry<String, Integer>> marks = new ArrayList<Map.Entry<String, Integer>>();

		//try to synthesize the SSML using an ending mark to know whether if anything went wrong
		int tries;
		boolean valid = false;
		int begin = mAudioBuffer.offsetInOutput;
		for (tries = SYNTHESIS_TRIES; !valid && tries > 0; --tries) {
			mAudioBuffer.offsetInOutput = begin;
			marks.clear();
			mLastUsedSynthesizer.synthesize(sentence, voice, mAudioBuffer, resource, marks,
			        (tries != SYNTHESIS_TRIES));

			if (mLastUsedSynthesizer.endingMark() == null
			        || (marks.size() > 0 && mLastUsedSynthesizer.endingMark().equals(
			                marks.get(marks.size() - 1).getKey()))) {
				valid = true;
			} else {
				try {
					Thread.sleep(2000);
				} catch (InterruptedException e) {
					throw new SynthesisException(e.getMessage(), e.getCause());
				}
			}
		}
		if (!valid) {
			throw new SynthesisException("TTS Processor " + mLastUsedSynthesizer.getName()
			        + "-" + mLastUsedSynthesizer.getVersion()
			        + " was enable to synthesize a piece of SSML.");
		}
		if (mLastUsedSynthesizer.endingMark() != null) {
			marks = marks.subList(0, marks.size() - 1);
		}

		// keep track of where the sound begins and where it ends in the audio buffer
		if (marks.size() == 0) {
			SoundFragment sf = new SoundFragment();
			sf.id = sentence.getAttributeValue(Sentence_attr_id);
			sf.clipBegin = convertBytesToSecond(begin);
			sf.clipEnd = convertBytesToSecond(mAudioBuffer.offsetInOutput);
			mCurrentFragments.add(sf);
		} else {
			Map<String, Integer> starts = new HashMap<String, Integer>();
			Map<String, Integer> ends = new HashMap<String, Integer>();
			Set<String> all = new HashSet<String>();

			for (Map.Entry<String, Integer> e : marks) {
				String[] mark = e.getKey().split(FormatSpecifications.MarkDelimiter, -1);
				if (!mark[0].isEmpty()) {
					ends.put(mark[0], e.getValue());
					all.add(mark[0]);
				}
				if (!mark[1].isEmpty()) {
					starts.put(mark[1], e.getValue());
					all.add(mark[1]);
				}
			}
			for (String id : all) {
				SoundFragment sf = new SoundFragment();
				sf.id = id;
				if (starts.containsKey(id))
					sf.clipBegin = convertBytesToSecond(begin + starts.get(id));
				else
					sf.clipBegin = convertBytesToSecond(begin);
				if (ends.containsKey(id))
					sf.clipEnd = convertBytesToSecond(begin + ends.get(id));
				else
					sf.clipEnd = convertBytesToSecond(mAudioBuffer.offsetInOutput);
				mCurrentFragments.add(sf);
			}
		}
	}

	@Override
	public void run() {
		while (true) {
			UndispatchableSection section = mSectionsQueue.poll();
			if (section == null) {
				break;
			}
			try {
				mCurrentDocPosition = section.documentPosition;
				mSectionFiles = 0;
				mLastUsedSynthesizer = section.synthesizer;
				for (Speakable speakable : section.speakables) {
					processOneSentence(speakable.sentence, speakable.voice);
				}
				if (mAudioBuffer.offsetInOutput > 0)
					encodeAudio();
			} catch (Exception e) {
				StringWriter sw = new StringWriter();
				e.printStackTrace(new PrintWriter(sw));
				mLogger.printInfo("error in synthesis thread: " + e.getMessage() + " : "
				        + sw.toString());
			}
		}
	}
}

@import "smuck"
@import "SMIR.ck"

public class bufferState
{
    1.5 => float silenceThreshold; // seconds of silence to end a phrase
    4.0 => float rollingWindow;    // seconds retained in rolling buffer
    60.0 => float refBpm;          // 1 beat = 1 sec

    ezMeasure phraseBuffer;
    SMIR      phraseSmir;
    ezMeasure completedPhrase;
    SMIR      completedSmir;
    ezMeasure rollingBuffer;
    SMIR      rollingSmir;

    int     _device;
    MidiIn  min;
    MidiMsg msg;

    time recStart;
    time absStart;
    time _lastNoteTime;
    int  _inPhrase;

    ezNote _lastNote;

    Event phraseStartEvent;
    Event phraseCompleteEvent;
    Event noteReceivedEvent;
    Event noteOffEvent;
    Event silenceSustainedEvent;

    int _lastNoteOffPitch;

    fun bufferState()
    {
        phraseSmir.set(phraseBuffer.notes());
        completedSmir.set(completedPhrase.notes());
        rollingSmir.set(rollingBuffer.notes());
    }

    // IMPORTANT: deep-copy phraseBuffer into completedPhrase so agents
    // can read it without racing against new incoming notes
    fun void _snapshotCompletedPhrase()
    {
        completedPhrase.notes().clear();
        phraseBuffer.notes() @=> ezNote src[];
        // <<< "snapshot:", src.size(), "notes" >>>;
        for(int i; i < src.size(); i++)
        {
            ezNote n(src[i].onset(), src[i].beats(), src[i].pitch(), src[i].velocity());
            completedPhrase.add(n);
        }
    }

    fun void device(int d)
    {
        d => _device;
        if (!min.open(_device))
        {
            <<< "bufferState: failed to open MIDI device", d >>>;
            me.exit();
        }
        <<< "bufferState MIDI device:", min.num(), "->", min.name() >>>;
    }

    fun float silenceSeconds() { return (now - _lastNoteTime) / second; }
    fun int inPhrase() { return _inPhrase; }

    // MIDI listener (similar pattern to ezScore importMIDI parser)
    fun void listen()
    {
        float phrase_note_on_time[128];
        int   phrase_note_index[128];

        60000.0 / refBpm => float ms_per_beat;
        now => recStart;
        now => absStart;
        now => _lastNoteTime;

        while (true)
        {
            min => now;
            while (min.recv(msg))
            {
                (now - recStart) / ms => float phrase_elapsed_ms;
                (now - absStart) / ms => float abs_elapsed_ms;

                // Note-On
                if (msg.data1 == 144 && msg.data3 > 0)
                {
                    msg.data2 => int pitch;
                    msg.data3 => int velocity;

                    // first note after a gap = phrase start
                    if (!_inPhrase)
                    {
                        phraseBuffer.notes().clear();
                        now => recStart;
                        0.0 => phrase_elapsed_ms;
                        1 => _inPhrase;
                        phraseStartEvent.broadcast();
                        // <<< "--- phrase start ---" >>>;
                    }

                    phrase_elapsed_ms => phrase_note_on_time[pitch];
                    phrase_elapsed_ms / ms_per_beat => float phrase_onset;
                    abs_elapsed_ms / ms_per_beat => float abs_onset;

                    // NOTE: duration is 0 here, gets filled in on note-off
                    ezNote phraseNote(phrase_onset, 0, pitch, velocity / 127.0);
                    ezNote rollingNote(abs_onset, 0, pitch, velocity / 127.0);

                    phraseBuffer.add(phraseNote);
                    phraseBuffer.notes().size() - 1 => phrase_note_index[pitch];
                    rollingBuffer.add(rollingNote);

                    now => _lastNoteTime;
                    rollingNote @=> _lastNote;
                    noteReceivedEvent.broadcast();
                    // <<< "noteOn:", pitch, velocity >>>;
                }
                // Note-Off
                else if (msg.data1 == 128 || (msg.data1 == 144 && msg.data3 == 0))
                {
                    msg.data2 => int pitch;
                    (phrase_elapsed_ms - phrase_note_on_time[pitch]) / ms_per_beat => float dur_beats;
                    // <<< "noteOff:", pitch, "dur:", dur_beats >>>;
                    if (phrase_note_index[pitch] < phraseBuffer.notes().size())
                        dur_beats => phraseBuffer.notes()[phrase_note_index[pitch]].beats;
                    pitch => _lastNoteOffPitch;
                    noteOffEvent.broadcast();
                }
            }
        }
    }

    // NOTE: broadcastInterval limits how often silenceSustained fires,
    // otherwise agents would get spammed every 100ms
    fun void silenceWatcher()
    {
        100::ms => dur check;
        500::ms => dur broadcastInterval;
        dur sinceLastBroadcast;

        while (true)
        {
            check => now;
            silenceSeconds() => float silence_s;

            if (_inPhrase && silence_s >= silenceThreshold)
            {
                0 => _inPhrase;
                _snapshotCompletedPhrase();
                phraseCompleteEvent.broadcast();
                0::ms => sinceLastBroadcast;
                // <<< "phrase complete, notes:", completedPhrase.notes().size() >>>;
            }

            if (!_inPhrase && silence_s >= silenceThreshold)
            {
                check +=> sinceLastBroadcast;
                if (sinceLastBroadcast >= broadcastInterval)
                {
                    silenceSustainedEvent.broadcast();
                    // <<< "silence sustained:", silence_s >>>;
                    0::ms => sinceLastBroadcast;
                }
            }
        }
    }

    fun void rollingReaper()
    {
        250::ms => dur check;
        60000.0 / refBpm => float ms_per_beat;

        while (true)
        {
            check => now;
            (now - absStart) / ms / ms_per_beat => float abs_elapsed_beats;
            abs_elapsed_beats - rollingWindow => float cutoff_beats;

            rollingBuffer.notes() @=> ezNote current[];
            ezNote kept[0];
            for (int i; i < current.size(); i++)
            {
                if (current[i].onset() >= cutoff_beats)
                    kept << current[i];
            }

            if (kept.size() != current.size())
            {
                rollingBuffer.notes().clear();
                for (int i; i < kept.size(); i++)
                    rollingBuffer.add(kept[i]);
                // <<< "reaped rolling buffer:", current.size(), "->", kept.size() >>>;
            }
        }
    }
}

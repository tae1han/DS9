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
    Event midiQueueEvent;

    512 => int _MIDI_Q_MAX;
    int _mqIsOn[512];
    int _mqPitch[512];
    float _mqVel[512];
    int _mqHead;
    int _mqTail;
    int _mqCount;

    int _lastNoteOffPitch;
    int _pedalDown;
    int _pedalPendingOff[128];

    fun void _mqPush(int isOn, int pitch, float vel)
    {
        if(_mqCount >= _MIDI_Q_MAX)
        {
            <<< "bufferState: MIDI queue overflow", isOn, pitch >>>;
            return;
        }
        isOn => _mqIsOn[_mqTail];
        pitch => _mqPitch[_mqTail];
        vel => _mqVel[_mqTail];
        (_mqTail + 1) % _MIDI_Q_MAX => _mqTail;
        _mqCount + 1 => _mqCount;

        if(isOn)
        {
            ezNote n(0, 0, pitch, vel);
            n @=> _lastNote;
            noteReceivedEvent.broadcast();
        }
        else
        {
            pitch => _lastNoteOffPitch;
            noteOffEvent.broadcast();
        }
        midiQueueEvent.broadcast();
    }

    fun int mqPop(int isOn[], int pitch[], float vel[])
    {
        if(_mqCount <= 0) return 0;
        _mqIsOn[_mqHead] => isOn[0];
        _mqPitch[_mqHead] => pitch[0];
        _mqVel[_mqHead] => vel[0];
        (_mqHead + 1) % _MIDI_Q_MAX => _mqHead;
        _mqCount - 1 => _mqCount;
        return 1;
    }

    fun int mqPending() { return _mqCount; }

    fun void _emitNoteOff(int pitch, float phrase_elapsed_ms, float phrase_note_on_time[], int phrase_note_index[], float ms_per_beat)
    {
        (phrase_elapsed_ms - phrase_note_on_time[pitch]) / ms_per_beat => float dur_beats;
        if(phrase_note_index[pitch] < phraseBuffer.notes().size())
            dur_beats => phraseBuffer.notes()[phrase_note_index[pitch]].beats;
        _mqPush(0, pitch, 0.0);
    }
    fun bufferState()
    {
        for(0 => int p; p < 128; p++)
            0 => _pedalPendingOff[p];
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
        completedPhrase.notes() @=> ezNote snap[];
        SMIR.finalizePhraseDurations(snap, 0.12, 0.5);
        completedSmir.set(completedPhrase.notes());
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

    fun void device(string name)
    {
        if (!min.open(name))
        {
            <<< "bufferState: failed to open MIDI device", name >>>;
            me.exit();
        }
        min.num() => _device;
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

                    0 => _pedalPendingOff[pitch];

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
                    rollingSmir.set(rollingBuffer.notes());

                    now => _lastNoteTime;
                    rollingNote @=> _lastNote;
                    _mqPush(1, pitch, velocity / 127.0);
                    // <<< "noteOn:", pitch, velocity >>>;
                }
                // Note-Off
                else if (msg.data1 == 128 || (msg.data1 == 144 && msg.data3 == 0))
                {
                    msg.data2 => int pitch;
                    if(_pedalDown)
                        1 => _pedalPendingOff[pitch];
                    else
                        _emitNoteOff(pitch, phrase_elapsed_ms, phrase_note_on_time, phrase_note_index, ms_per_beat);
                }
                // Sustain pedal (CC 64)
                else if((msg.data1 & 0xF0) == 0xB0 && msg.data2 == 64)
                {
                    if(msg.data3 >= 64)
                    {
                        1 => _pedalDown;
                    }
                    else
                    {
                        0 => _pedalDown;
                        for(0 => int pitch; pitch < 128; pitch++)
                        {
                            if(_pedalPendingOff[pitch])
                            {
                                _emitNoteOff(pitch, phrase_elapsed_ms, phrase_note_on_time, phrase_note_index, ms_per_beat);
                                0 => _pedalPendingOff[pitch];
                            }
                        }
                    }
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
                rollingSmir.set(rollingBuffer.notes());
                // <<< "reaped rolling buffer:", current.size(), "->", kept.size() >>>;
            }
        }
    }
}

@import "smuck"
@import "SMIR.ck"
@import "bufferState.ck"

// client-side bufferState that receives note data from server via OSC instead of local MIDI. phrase boundary
// detection is handled by the server -- client listen for the events and reconstruct buffers locally.

public class oscBufferState extends bufferState
{
    OscIn oin;
    OscMsg omsg;

    float _oscNoteOnTime[128];
    int   _oscNoteIndex[128];

    fun void oscPort(int port)
    {
        port => oin.port;
        oin.addAddress("/ds9/noteOn");
        oin.addAddress("/ds9/noteOff");
        oin.addAddress("/ds9/phraseStart");
        oin.addAddress("/ds9/phraseComplete");
        oin.addAddress("/ds9/silenceSustained");
        <<< "oscBufferState listening on port", port >>>;
    }

    // replaces bufferState.listen() -- do NOT spork listen() on clients
    fun void oscListen()
    {
        60000.0 / refBpm => float ms_per_beat;
        now => recStart;
        now => absStart;
        now => _lastNoteTime;

        while(true)
        {
            oin => now;
            while(oin.recv(omsg))
            {
                if(omsg.address == "/ds9/noteOn")
                {
                    omsg.getInt(0) => int pitch;
                    omsg.getFloat(1) => float velocity;

                    (now - recStart) / ms => float phrase_elapsed_ms;
                    (now - absStart) / ms => float abs_elapsed_ms;
                    phrase_elapsed_ms / ms_per_beat => float phrase_onset;
                    abs_elapsed_ms / ms_per_beat => float abs_onset;

                    phrase_elapsed_ms => _oscNoteOnTime[pitch];

                    ezNote phraseNote(phrase_onset, 0, pitch, velocity);
                    ezNote rollingNote(abs_onset, 0, pitch, velocity);

                    phraseBuffer.add(phraseNote);
                    phraseBuffer.notes().size() - 1 => _oscNoteIndex[pitch];
                    rollingBuffer.add(rollingNote);

                    now => _lastNoteTime;
                    rollingNote @=> _lastNote;
                    noteReceivedEvent.broadcast();
                    // <<< "osc noteOn:", pitch, velocity >>>;
                }
                else if(omsg.address == "/ds9/noteOff")
                {
                    omsg.getInt(0) => int pitch;

                    (now - recStart) / ms => float phrase_elapsed_ms;
                    60000.0 / refBpm => float ms_per_beat_local;
                    (phrase_elapsed_ms - _oscNoteOnTime[pitch]) / ms_per_beat_local => float dur_beats;

                    if(_oscNoteIndex[pitch] < phraseBuffer.notes().size())
                        dur_beats => phraseBuffer.notes()[_oscNoteIndex[pitch]].beats;

                    pitch => _lastNoteOffPitch;
                    noteOffEvent.broadcast();
                    // <<< "osc noteOff:", pitch, "dur:", dur_beats >>>;
                }
                else if(omsg.address == "/ds9/phraseStart")
                {
                    phraseBuffer.notes().clear();
                    now => recStart;
                    1 => _inPhrase;
                    phraseStartEvent.broadcast();
                    // <<< "--- osc phrase start ---" >>>;
                }
                else if(omsg.address == "/ds9/phraseComplete")
                {
                    0 => _inPhrase;
                    _snapshotCompletedPhrase();
                    phraseCompleteEvent.broadcast();
                    // <<< "osc phrase complete, notes:", completedPhrase.notes().size() >>>;
                }
                else if(omsg.address == "/ds9/silenceSustained")
                {
                    omsg.getFloat(0) => float seconds;
                    silenceSustainedEvent.broadcast();
                }
            }
        }
    }
}

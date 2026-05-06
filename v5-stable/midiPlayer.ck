@import "smuck"

public class midiPlayer {
    int _device;
    MidiIn min;
    MidiMsg msg;
    int _logOutput;

    ezInstrument inst;
    int _pedal;
    int _pedaledNotes[];
    0 => int _minPitch;
    127 => int _maxPitch;

    fun midiPlayer() { device(0); }

    fun midiPlayer(int d) {
        d => _device;
        device(d);
    }

    fun void device(int d) {
        d => _device;
        if (!min.open(_device))
            me.exit();
        <<< "MIDI device:", min.num(), " -> ", min.name() >>>;
    }

    fun void device(string name) {
        if (!min.open(name))
        {
            <<< "midiPlayer: failed to open MIDI device", name >>>;
            me.exit();
        }
        min.num() => _device;
        <<< "MIDI device:", min.num(), " -> ", min.name() >>>;
    }

    fun void logOutput(int toggle) { toggle => _logOutput; }
    fun void setInstrument(ezInstrument i) {
        i @=> inst;
        new int[inst._numVoices] @=> _pedaledNotes;
        // _pedaledNotes.zero();
    }

    fun void range(int min, int max) {
        min => _minPitch;
        max => _maxPitch;
    }

    fun void listen() {
        while (true) {
            min => now;

            while (min.recv(msg)) {
                if (_logOutput) {
                    <<< msg.data1, msg.data2, msg.data3 >>>;
                }

                if (msg.data1 == 144) {
                    msg.data2 => int pitch;
                    msg.data3 => int velocity;

                    if (pitch >= _minPitch && pitch <= _maxPitch) {
                        if (velocity == 0)
                            noteOff(pitch, velocity);
                        else
                            noteOn(pitch, velocity);
                    }
                } else if (msg.data1 == 128) {
                    msg.data2 => int pitch;
                    msg.data3 => int velocity;

                    if (pitch >= _minPitch && pitch <= _maxPitch) {
                        noteOff(pitch, velocity);
                    }
                } else if (msg.data1 == 176 && msg.data2 == 64) {
                    if (msg.data3 == 127) {
                        if (_logOutput) {
                            chout <= "Pedal On" <= IO.newline();
                        }
                        true => _pedal;
                    } else {
                        if (_logOutput) {
                            chout <= "Pedal Off" <= IO.newline();
                        }
                        false => _pedal;
                        flushNotes();
                    }
                }
            }
        }
    }

    spork ~ listen();


    fun int pitch_to_voice(int pitch) {
        inst.voice_to_note @=> ezNote v2n[];
        for (int i; i < v2n.size(); i++) {
            if (v2n[i].pitch() == pitch) {
                return i;
            }
        }
        return 0;
    }

    fun void flushNotes() {
        for (int i; i < inst._numVoices; i++) {
            if (_pedaledNotes[i] == 1) {
                ezNote dummy;
                inst.noteOff(dummy, i);
                inst.release_voice(i);
                0 => _pedaledNotes[i];
            }
        }
    }
    fun void noteOn(int pitch, int velocity) {
        ezNote note;
        note.pitch(pitch);
        note.velocity((velocity / 127.0));

        inst.allocate_voice(note) => int voice_index;
        inst.noteOn(note, voice_index);
        if (_logOutput) {
            chout <= "Note On: " <= note.pitch() <= " on voice " <= voice_index <=
                "with velocity " <= note.velocity() <= IO.newline();
        }
    }

    fun void noteOff(int pitch, int velocity) {
        ezNote note;
        note.pitch(pitch);
        note.velocity((velocity / 127.0));
        pitch_to_voice(pitch) => int voice_index;
        if (!_pedal) {
            inst.noteOff(note, voice_index);
            if (_logOutput) {
                chout <= "Note Off: " <= note.pitch() <= " on voice " <= voice_index <=
                    "with velocity " <= note.velocity() <= IO.newline();
            }
            inst.release_voice(voice_index);
        } else {
            1 => _pedaledNotes[voice_index];
        }
    }
}

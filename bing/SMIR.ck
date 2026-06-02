@import "smuck"

public class SMIR
{
    ezNote notes[0];

    .25 => float quantizationResolution;

    fun SMIR(ezNote n[])
    {
        set(n);
    }

    fun void set(ezNote n[])
    {
        n @=> notes;
    }

    // Must match config.ck OWL_MIDI_TOGGLE (static methods cannot read imported globals).
    fun static int skipForPitchSet(int pitch)
    {
        return pitch == 28;
    }

    fun static ezNote[] filterControlPitches(ezNote n[])
    {
        if(n == null) return n;
        ezNote out[0];
        for(int i; i < n.size(); i++)
        {
            n[i].pitch() $ int => int p;
            if(!skipForPitchSet(p)) out << n[i];
        }
        return out;
    }

    fun void setFiltered(ezNote n[])
    {
        set(filterControlPitches(n));
    }

    // Phrase-complete often fires on silence before the last note-off (sustain).
    // Infer missing durations so agents and phrase memory play the full phrase.
    fun static void finalizePhraseDurations(ezNote n[], float minBeat, float minLastBeat)
    {
        if(n == null || n.size() == 0) return;

        for(0 => int i; i < n.size() - 1; i++)
        {
            n[i].beats() => float b;
            if(b >= minBeat) continue;

            n[i+1].onset() - n[i].onset() => float gap;
            if(gap < minBeat) minBeat => gap;
            n[i].beats(gap);
        }

        n[n.size() - 1].beats() => float lb;
        if(lb < minLastBeat)
            n[n.size() - 1].beats(minLastBeat);
    }

    // Transformations

    // quantize the onsets of the notes (returns new note array)
    fun ezNote[] quantizeOnsets(float resolution, float strength)
    {
        ezNote newNotes[0];

        for(int i; i < notes.size(); i++)
        {
            notes[i].onset() => float onset;
            Math.remainder(onset, resolution) => float onsetDiff;
            onset - (onsetDiff * strength) => float quantizedOnset;

            ezNote newNote(quantizedOnset, notes[i].beats(), notes[i].pitch(), notes[i].velocity());
            newNotes << newNote;
        }
        return newNotes;
    }

    // quantize the durations of the notes (returns new note array)
    fun ezNote[] quantizeDurations(float resolution, float strength)
    {
        ezNote newNotes[0];

        for(int i; i < notes.size(); i++)
        {

            notes[i].beats() => float beats;
            Math.remainder(beats, resolution) => float beatsDiff;
            beats - (beatsDiff * strength) => float quantizedBeats;

            ezNote newNote(notes[i].onset(), quantizedBeats, notes[i].pitch(), notes[i].velocity());
            newNotes << newNote;
        }
        return newNotes;
    }


    // Pitch Statistics

    // return the lowest pitch in the notes
    fun float pitchMin(ezNote n[])
    {
        Math.FLOAT_MAX => float min;
        for (int i; i < n.size(); i++) {
            n[i].pitch() $ int => int p;
            if(skipForPitchSet(p)) continue;
            p => float pitch;
            if (pitch < min) {
                pitch => min;
            }
        }
        return min;
    }

    fun float pitchMin()
    {
        return pitchMin(notes);
    }

    // return the highest pitch in the notes
    fun float pitchMax(ezNote n[])
    {
        -Math.FLOAT_MAX => float max;
        for (int i; i < n.size(); i++) {
            n[i].pitch() $ int => int p;
            if(skipForPitchSet(p)) continue;
            p => float pitch;
            if (pitch > max) {
                pitch => max;
            }
        }
        return max;
    }

    fun float pitchMax()
    {
        return pitchMax(notes);
    }

    // return the range of pitches in the notes
    fun float pitchRange(ezNote n[])
    {
        return pitchMax(n) - pitchMin(n);
    }

    fun float pitchRange()
    {
        return pitchRange(notes);
    }

    // return the pitch that is closest to the center of the pitch range
    fun float pitchCenter(ezNote n[])
    {
        (pitchRange(n) / 2.0) + pitchMin(n) => float center;

        Math.FLOAT_MAX => float minDiff;
        float closestPitch;

        for (int i; i < n.size(); i++) {
            n[i].pitch() $ int => int p;
            if(skipForPitchSet(p)) continue;
            p => float pitch;
            Math.fabs(pitch - center) => float diff;
            if (diff < minDiff) {
                diff => minDiff;
                pitch => closestPitch;
            }
        }
        return closestPitch;
    }

    fun float pitchCenter()
    {
        return pitchCenter(notes);
    }

    // return the counts of each pitch (distinct octaves)
    fun int[] pitchSet(ezNote n[])
    {
        int set[128];
        for (int i; i < n.size(); i++) {
            n[i].pitch() $ int => int pitch;
            if(skipForPitchSet(pitch)) continue;
            set[pitch]++;
        }
        return set;
    }

    fun int[] pitchSet()
    {
        return pitchSet(notes);
    }

    // return the counts of each pitch (distinct octaves), weighted by duration
    fun float[] pitchSetWeighted(ezNote n[])
    {
        float weightedSet[128];
        for(int i; i < n.size(); i++)
        {
            n[i].pitch() $ int => int pitch;
            if(skipForPitchSet(pitch)) continue;
            n[i].beats() +=> weightedSet[pitch];
        }
        return weightedSet;
    }

    fun float[] pitchSetWeighted()
    {
        return pitchSetWeighted(notes);
    }


    // return the pitch that appears most frequently in the notes
    fun float pitchMode(ezNote n[])
    {
        pitchSet(n) @=> int set[];
        int maxCount;
        int mode;
        for(int i; i < set.size(); i++) {
            if(set[i] > maxCount) {
                set[i] => maxCount;
                i => mode;
            }
        }
        return mode $ float;
    }

    fun float pitchMode()
    {
        return pitchMode(notes);
    }

    // return the octave-invariant pitchset of the notes, with normalized counts (0 - 1.0) 
    fun float[] pitchNormSet(ezNote n[])
    {
        float normSet[12];
        pitchSet(n) @=> int set[];
        float sum;
        for(int i; i < set.size(); i++) {
            i % 12 => int pitchClass;
            set[i] +=> normSet[pitchClass];
            set[i] +=> sum;
        }
        if(sum > 0) {
            for(int i; i < normSet.size(); i++) {
                normSet[i] / sum => normSet[i];
            }
        }
        return normSet;
    }

    fun float[] pitchNormSet()
    {
        return pitchNormSet(notes);
    }

    fun float[] pitchSetWeightedNorm(ezNote n[])
    {
        float normSet[12];
        pitchSetWeighted(n) @=> float weightedSet[];
        float sum;
        for(int i; i < weightedSet.size(); i++)
        {
            i % 12 => int pitchClass;
            weightedSet[i] +=> normSet[pitchClass];
            weightedSet[i] +=> sum;
        }
        if(sum > 0)
        {
            for(int i; i < normSet.size(); i++)
            {
                normSet[i] / sum => normSet[i];
            }
        }
        return normSet;
    }

    fun float[] pitchSetWeightedNorm()
    {
        return pitchSetWeightedNorm(notes);
    }

    fun int countMatches(float array[], float value)
    {
        int count;
        for(int i; i < array.size(); i++)
        {
            if(array[i] == value)
            {
                count++;
            }
        }
        return count;
    }

    // calculate pitch variance
    fun float pitchVariance(ezNote n[])
    {
        float sum;
        float variance;

        if(n.size() == 0)
        {
            return variance;
        }

        int count;
        for(int i; i < n.size(); i++)
        {
            n[i].pitch() $ int => int p;
            if(skipForPitchSet(p)) continue;
            p => float pitch;
            pitch +=> sum;
            count++;
        }
        if(count <= 0) return variance;
        sum / count => float mean;

        for(int i; i < n.size(); i++)
        {
            n[i].pitch() $ int => int p;
            if(skipForPitchSet(p)) continue;
            p => float pitch;
            (pitch - mean) * (pitch - mean) +=> variance;
        }

        return variance / count;
    }

    fun float pitchVariance()
    {
        return pitchVariance(notes);
    }

    // Rhythm Statistics

    fun float rhythmMin(ezNote n[])
    {
        Math.FLOAT_MAX => float min;
        for(int i; i < n.size(); i++)
        {
            n[i].beats() => float beats;
            if(beats < min)
            {
                beats => min;
            }
        }
        return min;
    }

    fun float rhythmMin()
    {
        return rhythmMin(notes);
    }

    fun float rhythmMax(ezNote n[])
    {
        -Math.FLOAT_MAX => float max;
        for(int i; i < n.size(); i++)
        {
            n[i].beats() => float beats;
            if(beats > max)
            {
                beats => max;
            }
        }
        return max;
    }

    fun float rhythmMax()
    {
        return rhythmMax(notes);
    }

    fun float rhythmRange(ezNote n[])
    {
        return rhythmMax(n) - rhythmMin(n);
    }

    fun float rhythmRange()
    {
        return rhythmRange(notes);
    }

    fun float rhythmMean(ezNote n[])
    {
        float sum;
        for(int i; i < n.size(); i++)
        {
            n[i].beats() => float beats;
            beats +=> sum;
        }
        return sum / n.size();
    }
    
    fun float rhythmMean()
    {
        return rhythmMean(notes);
    }

    fun float rhythmVariance(ezNote n[])
    {
        float variance;

        rhythmMean(n) => float mean;

        if(n.size() == 0)
        {
            return variance;
        }

        for(int i; i < n.size(); i++)
        {
            n[i].beats() => float beats;
            (beats - mean) * (beats - mean) +=> variance;
        }

        return variance / n.size();
    }

    fun float density(ezNote n[])
    {
        float density;

        if(n.size() == 0)
        {
            return density;
        }

        ezMeasure temp(n);
        n.size() / temp.beats() => density;

        return density;
    }

    // Filtering

    fun ezNote[] matchOnset(ezNote n[], float value)
    {
        ezNote newNotes[0];
        for(int i; i < n.size(); i++)
        {
            n[i].onset() => float onset;
            if(onset == value)
            {
                newNotes << n[i];
            }
        }
        return newNotes;
    }

    fun ezNote[] matchOnset(ezNote n[], float values[])
    {
        ezNote newNotes[0];
        for(int i; i < n.size(); i++)
        {
            n[i].onset() => float onset;
            if(countMatches(values, onset) > 0)
            {
                newNotes << n[i];
            }
        }
        return newNotes;
    }

    // filters out notes with beats less than cutoff
    fun ezNote[] beatsHPF(ezNote n[], float cutoff)
    {
        ezNote newNotes[0];
        for(int i; i < n.size(); i++)
        {
            n[i].beats() => float beats;
            if(beats > cutoff)
            {
                newNotes << n[i];
            }
        }
        return newNotes;
    }

    fun ezNote[] beatsHPF(float cutoff)
    {
        return beatsHPF(notes, cutoff);
    }

    // filters out notes with beats greater than cutoff
    fun ezNote[] beatsLPF(ezNote n[], float cutoff)
    {
        ezNote newNotes[0];
        for(int i; i < n.size(); i++)
        {
            n[i].beats() => float beats;
            if(beats < cutoff)
            {
                newNotes << n[i];
            }
        }
        return newNotes;
    }

    fun ezNote[] beatsLPF(float cutoff)
    {
        return beatsLPF(notes, cutoff);
    }

    // return only chords (notes with onset within threshold of each other)
    // mode 0 = return chords only
    // mode 1 = return non-chords only

    fun ezNote[] extractChords(int mode)
    {
        ezNote newNotes[0];

        quantizeOnsets(quantizationResolution, 1.0) @=> ezNote qNotes[];

        float onsets[0];

        for(int i; i < qNotes.size(); i++)
        {
            qNotes[i].onset() => float onset;
            onsets << onset;
        }

        for(int i; i < onsets.size(); i++)
        {
            if(countMatches(onsets, onsets[i]) > 1)
            {
                if(mode == 0)
                {
                    newNotes << qNotes[i];
                }
            }
            else
            {
                if(mode == 1)
                {
                    newNotes << qNotes[i];
                }
            }
        }
        return newNotes;
    }

    fun ezNote[] extractChords()
    {
        return extractChords(0);
    }

    fun ezNote[] extractNonChords()
    {
        return extractChords(1);
    }

    // direction: +1 for top voice, -1 for bottom voice
    fun ezNote[] extremeLine(int direction, float gateInterval, float maxLeap, float reacquireBeats)
    {
        ezNote result[0];
        if(notes == null || notes.size() == 0) return result;

        quantizeOnsets(quantizationResolution, 1.0) @=> ezNote qNotes[];
        if(qNotes.size() == 0) return result;

        float registerRef;
        if(direction > 0) pitchMax(qNotes) => registerRef;
        else pitchMin(qNotes) => registerRef;

        ezNote candidates[0];
        for(int i; i < qNotes.size(); i++)
        {
            qNotes[i].pitch() => float p;
            if(direction > 0)
            {
                if(p >= registerRef - gateInterval) candidates << qNotes[i];
            }
            else
            {
                if(p <= registerRef + gateInterval) candidates << qNotes[i];
            }
        }
        if(candidates.size() == 0) return result;

        float onsets[0];
        for(int i; i < candidates.size(); i++)
        {
            candidates[i].onset() => float o;
            if(countMatches(onsets, o) == 0) onsets << o;
        }

        int haveLast;
        float lastPitch;
        float lastOnset;

        for(int i; i < onsets.size(); i++)
        {
            matchOnset(candidates, onsets[i]) @=> ezNote group[];
            if(group.size() == 0) continue;

            ezNote picked;
            float pickedPitch;
            if(direction > 0) -Math.FLOAT_MAX => pickedPitch;
            else Math.FLOAT_MAX => pickedPitch;

            for(int j; j < group.size(); j++)
            {
                group[j].pitch() => float p;
                if(direction > 0)
                {
                    if(p > pickedPitch)
                    {
                        p => pickedPitch;
                        group[j] @=> picked;
                    }
                }
                else
                {
                    if(p < pickedPitch)
                    {
                        p => pickedPitch;
                        group[j] @=> picked;
                    }
                }
            }

            if(haveLast)
            {
                onsets[i] - lastOnset => float beatsSinceLast;
                Math.fabs(pickedPitch - lastPitch) => float leap;
                if(leap > maxLeap && beatsSinceLast < reacquireBeats) continue;
            }

            result << picked;
            pickedPitch => lastPitch;
            onsets[i] => lastOnset;
            1 => haveLast;
        }

        return result;
    }

    // return the top melodic line, with register gate + leap hysteresis
    fun ezNote[] topLine(float gateInterval, float maxLeap, float reacquireBeats)
    {
        return extremeLine(1, gateInterval, maxLeap, reacquireBeats);
    }

    // defaults: wide 2-octave gate, minor-10th max leap, quick 2-beat re-acquire
    fun ezNote[] topLine()
    {
        return extremeLine(1, 24.0, 15.0, 2.0);
    }

    // return the bottom melodic line, with register gate + leap hysteresis
    fun ezNote[] bottomLine(float gateInterval, float maxLeap, float reacquireBeats)
    {
        return extremeLine(-1, gateInterval, maxLeap, reacquireBeats);
    }

    // defaults: tight 1-octave gate, 1-octave max leap, slow 4-beat re-acquire
    fun ezNote[] bottomLine()
    {
        return extremeLine(-1, 7.0, 7.0, 4.0);
    }


    // Inter-onset intervals

    // sorted ascending-by-onset copy of the notes array, used to compute IOIs
    fun ezNote[] notesSortedByOnset(ezNote n[])
    {
        ezNote copy[0];
        for(int i; i < n.size(); i++) copy << n[i];

        // simple insertion sort -- buffers are small
        for(1 => int i; i < copy.size(); i++)
        {
            copy[i] @=> ezNote cur;
            i - 1 => int j;
            while(j >= 0 && copy[j].onset() > cur.onset())
            {
                copy[j] @=> copy[j + 1];
                j - 1 => j;
            }
            cur @=> copy[j + 1];
        }
        return copy;
    }

    // return the inter-onset intervals
    fun float[] iois(ezNote n[])
    {
        float out[0];
        if(n == null || n.size() < 2) return out;

        notesSortedByOnset(n) @=> ezNote sorted[];
        for(1 => int i; i < sorted.size(); i++)
        {
            sorted[i].onset() - sorted[i - 1].onset() => float diff;
            if(diff > 0) out << diff;
        }
        return out;
    }

    fun float[] iois() { return iois(notes); }

    fun float meanIOI(ezNote n[])
    {
        iois(n) @=> float xs[];
        if(xs.size() == 0) return 0.0;
        float sum;
        for(int i; i < xs.size(); i++) xs[i] +=> sum;
        return sum / xs.size();
    }

    fun float meanIOI() { return meanIOI(notes); }

    fun float medianIOI(ezNote n[])
    {
        iois(n) @=> float xs[];
        if(xs.size() == 0) return 0.0;

        // insertion sort the IOIs
        for(1 => int i; i < xs.size(); i++)
        {
            xs[i] => float cur;
            i - 1 => int j;
            while(j >= 0 && xs[j] > cur)
            {
                xs[j] => xs[j + 1];
                j - 1 => j;
            }
            cur => xs[j + 1];
        }

        xs.size() / 2 => int mid;
        if(xs.size() % 2 == 1) return xs[mid];
        return (xs[mid - 1] + xs[mid]) / 2.0;
    }

    fun float medianIOI() { return medianIOI(notes); }

    // derive a BPM suggestion from the median IOI, clamped to a sane range.
    // Assumes onsets are stored with 1 beat == 1 second (refBpm=60 recording).
    fun float suggestedBpm(ezNote n[], float minBpm, float maxBpm)
    {
        medianIOI(n) => float m;
        if(m <= 0) return 120.0;
        60.0 / m => float bpm;
        if(bpm < minBpm) minBpm => bpm;
        if(bpm > maxBpm) maxBpm => bpm;
        return bpm;
    }

    fun float suggestedBpm(ezNote n[]) { return suggestedBpm(n, 40.0, 200.0); }
    fun float suggestedBpm()           { return suggestedBpm(notes, 40.0, 200.0); }


    // Pitch-class quantization

    fun int[] pitchClassMask(ezNote n[], float threshold)
    {
        int mask[12];
        if(n == null || n.size() == 0)
        {
            for(int i; i < 12; i++) 1 => mask[i];
            return mask;
        }

        pitchSetWeightedNorm(n) @=> float w[];
        int anyOn;
        for(int i; i < 12; i++)
        {
            if(w[i] >= threshold)
            {
                1 => mask[i];
                1 => anyOn;
            }
        }
        if(!anyOn)
        {
            for(int i; i < 12; i++) 1 => mask[i];
        }
        return mask;
    }

    fun int[] pitchClassMask(float threshold) { return pitchClassMask(notes, threshold); }
    fun int[] pitchClassMask()                { return pitchClassMask(notes, 0.05); }

    // Quantize a single MIDI pitch to the nearest pitch whose pitch-class is
    // allowed by `mask`. On tie (equidistant pitches up and down), rounds up.
    fun int quantizeToMask(int pitch, int mask[])
    {
        if(mask == null || mask.size() < 12) return pitch;

        // quick allow
        if(mask[((pitch % 12) + 12) % 12]) return pitch;

        for(1 => int delta; delta <= 12; delta++)
        {
            pitch + delta => int up;
            pitch - delta => int down;
            if(up <= 127 && mask[((up % 12) + 12) % 12]) return up;
            if(down >= 0 && mask[((down % 12) + 12) % 12]) return down;
        }
        return pitch;
    }

    fun ezNote[] quantizeToMask(ezNote n[], int mask[])
    {
        ezNote out[0];
        for(int i; i < n.size(); i++)
        {
            n[i].pitch() $ int => int p;
            quantizeToMask(p, mask) => int q;
            ezNote note(n[i].onset(), n[i].beats(), q, n[i].velocity());
            out << note;
        }
        return out;
    }

    // Motivic transformation IDs (integer codes for callers; define constants in superParrot if desired):
    // 0 Repetition, 1 Sequence, 2 Retrograde, 3 Inversion,
    // 4 Truncation, 5 Fragmentation, 6 Diminution, 7 Augmentation

    fun static ezNote[] copyNotes(ezNote n[])
    {
        ezNote out[0];
        if(n == null) return out;
        for(int i; i < n.size(); i++)
        {
            ezNote nn(n[i].onset(), n[i].beats(), n[i].pitch(), n[i].velocity());
            out << nn;
        }
        return out;
    }

    // Chuck reserves the identifier `repeat`; this is motivic repetition (= copyNotes).
    fun static ezNote[] motifRepetition(ezNote n[])
    {
        return copyNotes(n);
    }

    fun static ezNote[] retrograde(ezNote n[])
    {
        SMIR helper;
        helper.notesSortedByOnset(n) @=> ezNote sorted[];

        ezNote out[0];
        int sz;
        sorted.size() => sz;
        if(sz == 0) return out;

        for(0 => int j; j < sz; j++)
        {
            sz - 1 - j => int idx;
            sorted[idx].beats() => float b;
            sorted[idx].pitch() => float p;
            sorted[idx].velocity() => float v;

            0.0 => float onset;
            if(j > 0)
            {
                sorted[sz - j].onset() - sorted[sz - 1 - j].onset() => float dt;
                out[j - 1].onset() + dt => onset;
            }
            ezNote nn(onset, b, p, v);
            out << nn;
        }
        return out;
    }

    fun static ezNote[] sequence(ezNote n[], int semis)
    {
        ezNote out[0];
        if(n == null) return out;
        for(int i; i < n.size(); i++)
        {
            n[i].pitch() + (semis $ float) => float p;
            if(p < 0.0) 0.0 => p;
            if(p > 127.0) 127.0 => p;
            ezNote nn(n[i].onset(), n[i].beats(), p, n[i].velocity());
            out << nn;
        }
        return out;
    }

    fun static ezNote[] invert(ezNote n[], int axisPitch)
    {
        ezNote out[0];
        if(n == null || n.size() == 0) return out;

        axisPitch => float axisFloat;
        if(axisPitch < 0)
        {
            SMIR helper;
            helper.notesSortedByOnset(n) @=> ezNote sorted[];
            sorted[0].pitch() => axisFloat;
        }

        for(int i; i < n.size(); i++)
        {
            float p;
            2.0 * axisFloat - n[i].pitch() => p;
            if(p < 0.0) 0.0 => p;
            if(p > 127.0) 127.0 => p;
            ezNote nn(n[i].onset(), n[i].beats(), p, n[i].velocity());
            out << nn;
        }
        return out;
    }

    fun static ezNote[] truncate(ezNote n[], int maxNotes)
    {
        SMIR helper;
        helper.notesSortedByOnset(n) @=> ezNote sorted[];

        ezNote out[0];
        int sz;
        sorted.size() => sz;
        if(maxNotes <= 0 || sz == 0) return out;

        if(maxNotes < sz) maxNotes => sz;

        sorted[0].onset() => float anchorOnset;

        for(int i; i < sz; i++)
        {
            sorted[i].onset() - anchorOnset => float on;
            sorted[i].beats() => float b;
            sorted[i].pitch() => float p;
            sorted[i].velocity() => float v;
            ezNote nn(on, b, p, v);
            out << nn;
        }
        return out;
    }

    fun static ezNote[] fragment(ezNote n[], float maxRatio)
    {
        SMIR helper;
        helper.notesSortedByOnset(n) @=> ezNote sorted[];

        int total;
        sorted.size() => total;
        if(total == 0)
        {
            ezNote empty[0];
            return empty;
        }

        Math.floor(maxRatio * (total $ float)) $ int => int take;
        if(take <= 0)
        {
            ezNote empty[0];
            return empty;
        }
        if(take > total) total => take;
        return truncate(sorted, take);
    }

    fun static ezNote[] augmentRhythm(ezNote n[], float factor)
    {
        SMIR helper;
        helper.notesSortedByOnset(n) @=> ezNote sorted[];

        ezNote out[0];
        .25 => float minBeats;

        for(int i; i < sorted.size(); i++)
        {
            sorted[i].onset() * factor => float on;
            Math.max(sorted[i].beats() * factor, minBeats) => float b;
            ezNote nn(on, b, sorted[i].pitch(), sorted[i].velocity());
            out << nn;
        }
        return out;
    }

    fun static ezNote[] diminishRhythm(ezNote n[], float factor)
    {
        SMIR helper;
        helper.notesSortedByOnset(n) @=> ezNote sorted[];
        ezNote out[0];
        .25 => float minBeats;

        for(int i; i < sorted.size(); i++)
        {
            sorted[i].onset() * factor => float on;
            Math.max(sorted[i].beats() * factor, minBeats) => float b;
            ezNote nn(on, b, sorted[i].pitch(), sorted[i].velocity());
            out << nn;
        }
        return out;
    }

    fun static ezNote[] quantizeNotesToMask(ezNote n[], int mask[])
    {
        SMIR helper;
        return helper.quantizeToMask(n, mask);
    }

    // Sorted MIDI pitches with present[p] != 0 (Peacock / Swan pitch pools).
    fun static int[] orderedMidiInRange(int present[], int lowMidi, int highMidi)
    {
        int out[0];
        for(lowMidi => int p; p <= highMidi; p++)
        {
            if(p < present.size() && present[p])
                out << p;
        }
        return out;
    }

    fun static int quantizeToOrderedMidi(int pitch, int ordered[])
    {
        if(ordered.size() == 0) return pitch;
        -1 => int best;
        127 => int bestDist;
        for(0 => int i; i < ordered.size(); i++)
        {
            ordered[i] => int p;
            Math.abs(p - pitch) => int d;
            if(d < bestDist)
            {
                d => bestDist;
                p => best;
            }
        }
        if(best < 0) return pitch;
        return best;
    }

    fun static int nextOrderedIndex(int idx, int step, int dir, int n)
    {
        if(n <= 0) return 0;
        idx + dir * step => int ni;
        while(ni < 0) n + ni => ni;
        while(ni >= n) ni - n => ni;
        return ni;
    }

    fun static string transformLabel(int id)
    {
        if(id == 0) return "Repetition";
        if(id == 1) return "Sequence";
        if(id == 2) return "Retrograde";
        if(id == 3) return "Inversion";
        if(id == 4) return "Truncation";
        if(id == 5) return "Fragmentation";
        if(id == 6) return "Diminution";
        if(id == 7) return "Augmentation";
        return "Unknown transform";
    }

    fun static string formatChain(int ids[])
    {
        if(ids == null || ids.size() == 0) return "";

        transformLabel(ids[0]) => string chain;
        for(1 => int i; i < ids.size(); i++)
        {
            chain + " -> " + transformLabel(ids[i]) => chain;
        }
        return chain;
    }

    fun void printPitchStats()
    {
        if(notes == null || notes.size() == 0)
        {
            // chout <= "Empty buffer" <= IO.newline();
            return;
        }

        chout <= "Pitch range: " + Smuck.mid2str(pitchMin()) + " - " + Smuck.mid2str(pitchMax()) <= IO.newline();
        chout <= "Pitch center: " + Smuck.mid2str(pitchCenter()) <= IO.newline();
        chout <= "Pitch mode: " + Smuck.mid2str(pitchMode()) <= IO.newline();

        chout <= "Normalized pitch set: " <= IO.newline();
        pitchSetWeightedNorm() @=> float normSet[];
        for(int i; i < normSet.size(); i++)
        {
            chout <= Smuck.mid2str(i + 12) + ": " + normSet[i] <= IO.newline();
        }
    }

    // Randomized chord inversion: for each note, displace up/down one octave with probability `prob`. clamp to register range [lowClamp, highClamp]
    fun static ezNote[] randomInversion(ezNote n[], float prob,
                                        int lowClamp, int highClamp)
    {
        ezNote out[0];
        for(int i; i < n.size(); i++)
        {
            n[i].pitch() $ int => int p;
            if(Math.randomf() < prob)
            {
                if(Math.random2(0, 1) == 0)
                    12 +=> p;
                else
                    12 -=> p;
                while(p < lowClamp) 12 +=> p;
                while(p > highClamp) 12 -=> p;
            }
            ezNote nn(n[i].onset(), n[i].beats(), p, n[i].velocity());
            out << nn;
        }
        return out;
    }

    fun static ezNote[] randomInversion(ezNote n[], float prob)
    {
        return randomInversion(n, prob, 30, 96);
    }

    fun static ezNote[] randomInversion(ezNote n[])
    {
        return randomInversion(n, 0.5, 30, 96);
    }
}
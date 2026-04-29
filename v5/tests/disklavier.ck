////////////////////////////////////////////////////////////////////////////////////////////
// MIDI Device setup
1 => int deviceIn;
0 => int deviceOut;
2 => int deviceVr;

//MidiIn min;
MidiIn mins[8];
MidiOut mout;

for(int i; i < mins.size(); i++)
{
    if(!mins[i].open(2)) me.exit();
}
//if(!min.open(1)) me.exit();
if(!mout.open(2)) me.exit();


//MidiMsg msgIn;
MidiMsg msgIns[8];
MidiMsg msgOut;

// Internal preset
0 => int preset;

////////////////////////////////////////////////////////////////////////////////////////////
// MIDI In API

int noteStatus[88];
noteStatus.zero();

int pitchGrid[12];
pitchGrid.zero();

0 => int pedalIsDown;

fun void printMIDIMsg(MidiMsg msg)
{
    if(msg.data1 == 144)
    {
        chout <= "Note On--";
        chout <= "Pitch: " <= msg.data2 <= ", Velocity: " <= msg.data3 <= IO.newline();
    }
    if(msg.data1 == 128)
    {
        chout <= "Note Off--";
        chout <= "Pitch: " <= msg.data2 <= ", Velocity: " <= msg.data3 <= IO.newline();
    }
    if(msg.data1 == 176)
    {
        chout <= "Pedal--";
        if(msg.data2 == 64)
        {
            chout <= "Right: " <= msg.data3 <= IO.newline();
        }
        if(msg.data2 == 67)
        {
            chout <= "Left: " <= msg.data3 <= IO.newline();
        }
    }
}

// fun void MIDImonitor(int mode)
// {
//     while( true )
//     {
//         // wait on the event 'min'
//         min => now;

//         // get the message(s)
//         while( min.recv(msgIn) )
//         {
//             // print out midi message
//             if(mode == 0)
//             {
//                 <<< msgIn.data1, msgIn.data2, msgIn.data3 >>>;
//             }
//             if(mode == 1)
//             {
//                 printMIDIMsg(msgIn);
//             }
//             else
//             {
//                 <<< msgIn.data1, msgIn.data2, msgIn.data3 >>>;
//             }
//         }
//     }
// }

// fun void updateNotesIn()
// {
//     while(true)
//     {
//         min => now;

//         while(min.recv(msgIn))
//         {
//             0 => int index;
//             if(msgIn.data1 == 144)
//             {
//                 msgIn.data2 - 21 => index;
//                 1 => noteStatus[index];
//             }
//             if(msgIn.data1 == 128)
//             {
//                 msgIn.data2 - 21 => index;
//                 0 => noteStatus[index];
//             }
//         }
//     }
// }

fun void countVoices()
{
    while(true)
    {
        0 => int count;
        for(int i; i < noteStatus.size(); i++)
        {
            if(noteStatus[i] == 1)
            {
                count++;
            }
        }
        <<<count>>>;
        50::ms => now;
    }

}

// fun void listenPedal()
// {
//     while(true)
//     {
//         min => now;

//         while(min.recv(msgIn))
//         {
//             if(msgIn.data1 == 176 && msgIn.data2 == 67)
//             {
//                 if(msgIn.data3 > 0)
//                 {
//                     if(pedalIsDown == 0)
//                     {
//                         //pitchGrid.zero();
//                     }
//                     1 => pedalIsDown;
//                 }
//                 else
//                 {
//                     0 => pedalIsDown;
//                 }
//                 <<<pedalIsDown>>>;
//             }
//         }
//     }
// }

fun void parsePedal(int data1, int data2, int data3)
{
    if(data1 == 176 && data2 == 67)
    {
        if(data3 > 0)
        {
            if(pedalIsDown == 0)
            {
                pitchGrid.zero();
            }
            1 => pedalIsDown;
        }
        else
        {
            0 => pedalIsDown;
        }
        //<<<pedalIsDown>>>;
    }
}

// MIDI In - index 0
fun void listenHarmony(int minPitch, int maxPitch)
{
    while(true)
    {
        mins[0] => now;

        while(mins[0].recv(msgIns[0]))
        {
            parsePedal(msgIns[0].data1, msgIns[0].data2, msgIns[0].data3);
            0 => int index;
            if(msgIns[0].data1 == 144 && pedalIsDown)
            {
                if(msgIns[0].data2 >= minPitch && msgIns[0].data2 <= maxPitch)
                {
                    msgIns[0].data2 % 12 => index;
                    1 => pitchGrid[index];
                    //printPitchGrid();
                }
            }
        }
    }
}
spork~listenHarmony(21, 72);

// MIDI In - index 1
[36, 24] @=> int bypass_seq[];
[48, 50, 51, 53, 55] @=> int steam_seq[];
[47, 49, 51, 53, 54] @=> int cascade_seq[];
[45, 47, 49, 50, 52] @=> int melody_seq[];
[50, 54, 56, 60] @=> int blocks_seq[];
[48, 49, 55, 56] @=> int shatter_seq[];
[48, 47, 45, 43, 41] @=> int beams_seq[];
[48, 49, 47, 48] @=> int ligeti_seq[];
[72, 67, 74, 69, 76, 71, 66, 73, 68, 75, 70, 65] @=> int lick1_seq[];
[65, 64, 60, 55, 53, 52, 48, 43, 36] @=> int phrase1_seq[];

int triggers[10][0];
bypass_seq @=> triggers[0];
steam_seq @=> triggers[1];
cascade_seq @=> triggers[2];
melody_seq @=> triggers[3];
blocks_seq @=> triggers[4];
shatter_seq @=> triggers[5];
beams_seq @=> triggers[6];
ligeti_seq @=> triggers[7];
lick1_seq @=> triggers[8];
phrase1_seq @=> triggers[9];

int trigger_ixs[triggers.size()];
trigger_ixs.zero();

fun void listenPreset()
{
    while(true)
    {
        mins[1] => now;

        while(mins[1].recv(msgIns[1]))
        {
            if(msgIns[1].data1 == 144)
            {
                for(int i; i < triggers.size(); i++)
                {
                    if(msgIns[1].data2 == triggers[i][trigger_ixs[i]])
                    {
                        trigger_ixs[i]++;
                        if(trigger_ixs[i] == triggers[i].size())
                        {
                            i => preset;
                            <<<"Match! Set preset to: ", preset>>>;
                            0 => trigger_ixs[i];
                        }
                        
                    }
                    else
                    {
                        0 => trigger_ixs[i];
                    }
                }
                
            }

        }
    }
}
spork~listenPreset();

fun void printPitchGrid()
{
    while(true)
    {
        chout <= "[" <= pitchGrid[0] <= ", ";
        chout <= pitchGrid[1] <= ", ";
        chout <= pitchGrid[2] <= ", ";
        chout <= pitchGrid[3] <= ", ";
        chout <= pitchGrid[4] <= ", ";
        chout <= pitchGrid[5] <= ", ";
        chout <= pitchGrid[6] <= ", ";
        chout <= pitchGrid[7] <= ", ";
        chout <= pitchGrid[8] <= ", ";
        chout <= pitchGrid[9] <= ", ";
        chout <= pitchGrid[10] <= ", ";
        chout <= pitchGrid[11] <= "]" <= IO.newline();
        500::ms => now;
    }

}

spork~printPitchGrid();

// MIDI In - index 2
fun void listenFlush()
{
    while(true)
        {
            mins[2] => now;

            while(mins[2].recv(msgIns[2]))
            {
                if(msgIns[2].data1 == 176 && msgIns[2].data2 == 66)
                {
                    <<<"FLUSH">>>;
                    MIDIflush();
                }
                if(msgIns[2].data1 == 144 && msgIns[2].data2 == 21)
                {
                    <<<"FLUSH">>>;
                    MIDIflush();                    
                }
            }
        }
}
spork~listenFlush();


////////////////////////////////////////////////////////////////////////////////////////////
// MIDI Out API

fun void MIDIflush()
{
    for(21 => int i; i < 109; i++)
    {
        128 => msgOut.data1;
        i => msgOut.data2;
        127 => msgOut.data3;
        mout.send(msgOut);
    }
}

fun void cycleFlush()
{
    while(true)
    {
        MIDIflush();
        2::second => now;
    }
}
//spork~cycleFlush();


fun void MIDIsend(MidiOut out, MidiMsg msg, int data1, int data2, int data3)
{
    data1 => msg.data1;
    data2 => msg.data2;
    data3 => msg.data3;

    mout.send(msg);
}

fun void playNote(int pitch, int velocity, dur duration)
{
    MIDIsend(mout, msgOut, 144, pitch, velocity);
    duration => now;
    MIDIsend(mout, msgOut, 128, pitch, 0);
}

////////////////////////////////////////////////////////////////////////////////////////////
// MIDI Effect API

fun int fitPitch(int pitch)
{
    Math.INT_MAX => int offset;
    pitch % 12 => int pitchClass;
    for(int i; i < 12; i++)
    {
        if(pitchGrid[i] == 1)
        {
            i - pitchClass => int diff;
            if(Math.abs(diff - 12) < Math.abs(diff))
            {
                Math.abs(diff - 12) => diff;
            }
            if(Math.abs(diff + 12) < Math.abs(diff))
            {
                Math.abs(diff + 12) => diff;
            }
            //<<<diff>>>;
            if(Math.abs(diff) < Math.abs(offset))
            {
                diff => offset;
            }
        }
    }
    if(offset > 12)
    {
        return pitch;
    }
    else
    {
        return pitch + offset;
    }
}

fun float[][] generateSequence(int beats, int seed, int stepsize)
{
    // Generate rhythms
    [1, 1, 2, 2, 2, 3, 3, 4] @=> int rhythms[];

    float durations[0];
    for(int i; i < beats; i++)
    {
        Math.random2(0, rhythms.size()-1) => int which;
        rhythms[which] => int div;
        for(int j; j < div; j++)
        {
            durations << 1.0/div;
        }
    }

    chout <= "durations: [";
    for(int i; i < durations.size(); i++)
    {
        chout <= durations[i] <= " ";
    }
    chout <= "]" <= IO.newline();

    // Generate pitches
    float pitches[durations.size()];
    pitches.zero();
    seed => pitches[0];
    seed => float last;

    for(1 => int i; i < pitches.size(); i++)
    {
        Math.random2(-1*stepsize, stepsize) => int step;
        last + step => pitches[i];
        last + step => last;
    }

    chout <= "pitches: [";
    for(int i; i < pitches.size(); i++)
    {
        chout <= pitches[i] <= " ";
    }
    chout <= "]" <= IO.newline();

    float generated[2][0];
    durations @=> generated[0];
    pitches @=> generated[1];

    return generated;

}

fun void playSequence(float gen[][], float tempo)
{
    gen[0] @=> float durations[];
    gen[1] @=> float pitches[];

    for(int i; i < durations.size(); i++)
    {
        //send note-on
        144 => msgOut.data1;
        fitPitch(pitches[i] $ int) => msgOut.data2;
        Math.random2(20, 75) => msgOut.data3;
        mout.send(msgOut);

        // wait for note duration
        durations[i] * 60000 / tempo => float waittime;
        (Math.random2f(-50, 50) + waittime)::ms => now;

        //send note-off
        128 => msgOut.data1;
        fitPitch(pitches[i] $ int) => msgOut.data2;
        Math.random2(20, 50) => msgOut.data3;
        mout.send(msgOut);
    }
    MIDIflush();
}

fun void delayNote(int status, int pitch, int velocity, dur delayTime)
{
    delayTime => now;
    chout <= "playing delayed note: " <= pitch <= ", " <= velocity <= IO.newline();
    status => msgOut.data1;
    pitch => msgOut.data2;
    velocity => msgOut.data3;

    mout.send(msgOut);
}

fun void delayFeedback(int status, int pitch, int velocity, dur delayTime, int repetitions, float decayFactor)
{
    if(status == 144)
    {
        for(int i; i < repetitions; i++)
        {
            delayTime => now;
            chout <= "playing delayed note: " <= pitch <= ", " <= velocity <= IO.newline();
            144 => msgOut.data1;
            pitch => msgOut.data2;
            Math.round(Math.pow(decayFactor, i + 1) * velocity)$int => velocity;
            velocity => msgOut.data3;
            mout.send(msgOut);

            200::ms => now;

            128 => msgOut.data1;
            pitch => msgOut.data2;
            120 => msgOut.data3;
            mout.send(msgOut);
        }
    }
}

fun void delayTranspose(int status, int pitch, int velocity, int transposition, dur delayTime, int repetitions, float decayFactor)
{
    for(int i; i < repetitions; i++)
    {
        delayTime => now;
        
        status => msgOut.data1;
        fitPitch(pitch + transposition) => msgOut.data2;
        Math.round(Math.pow(decayFactor, i + 1) * velocity)$int => velocity;
        if(velocity > 127)
        {
            127 => velocity;
        }
        velocity => msgOut.data3;
        chout <= "playing delayed note: " <= pitch <= ", " <= velocity <= IO.newline();
        mout.send(msgOut);
    }
}


// Preset 1 - "steam"
fun void steam(int status, int pitch, int velocity, int transposition)
{
    Math.randomf() => float gate;
    6 => int repetitions;
    Math.floor(Math.map2(velocity $ float, 0, 127, 1, 8)) $ int => repetitions;
    .9 => float decayFactor;
    .5 => float threshold;

    [5, 7, 10, 12, 14, 15, 17, 19] @=> int offsets[];
    
    if(status == 144)
    {
        if(gate <= threshold)
        {
            for(int i; i < repetitions; i++)
            {
                Math.random2(150, 400) => int randDelay;
                randDelay::ms => now;
                
                144 => msgOut.data1;
                pitch + transposition + offsets[i] => int newPitch;
                fitPitch(newPitch) => msgOut.data2;
                Math.round(Math.pow(decayFactor, i + 1) * velocity)$int => velocity;
                if(velocity > 127)
                {
                    127 => velocity;
                }
                
                Math.ceil(Math.map2(velocity $ float, 0, 127, 75, 120)) $ int => int scaledVelocity;
                scaledVelocity => msgOut.data3;
                100 => msgOut.data3;
                mout.send(msgOut);

                250::ms => now;

                128 => msgOut.data1;
                fitPitch(newPitch) => msgOut.data2;
                90 => msgOut.data3;
                mout.send(msgOut);
            }
        }
        MIDIflush();
    }
}

// Preset 2: cascades
0 => int runUpActive;
0 => int runDownActive;

fun void runUp(int status, int pitch, int velocity)
{
    50 => int minVel;

    if(status == 144)
    {
        1 => runUpActive;
        pitch + 48 => int maxPitch;
        pitch => int currPitch;
        minVel => int currVel;
        while(currPitch < maxPitch)
        {
            // send note-off
            128 => msgOut.data1;
            currPitch => msgOut.data2;
            100 => msgOut.data3;
            mout.send(msgOut);

            currPitch++;
            if(Math.randomf() < .05)
            {
                currPitch - 7 => currPitch;
                currVel - 20 => currVel;
                //100 => currVel;
            }
            currPitch % 12 => int pitchClass;
            if(pitchGrid[pitchClass] == 1)
            {
                // send note-on
                144 => msgOut.data1;
                currPitch => msgOut.data2;
                currVel + Math.random2(-5, 5) => currVel;
                if(currVel < minVel)
                {
                    minVel => currVel;
                }
                if(currVel > 120)
                {
                    120 => currVel;
                }
                currVel => msgOut.data3;
                //100 => msgOut.data3;
                mout.send(msgOut);

                (100 + Math.random2(-25,25))::ms => now;
            }
        }
        MIDIflush();
        0 => runUpActive;
    }
}

fun void runDown(int status, int pitch, int velocity)
{
    50 => int minVel;
    if(status == 144)
    {
        1 => runDownActive;
        pitch - 36 => int minPitch;
        pitch => int currPitch;
        minVel => int currVel;
        while(currPitch > minPitch)
        {
            // send note-off
            128 => msgOut.data1;
            currPitch => msgOut.data2;
            100 => msgOut.data3;
            mout.send(msgOut);

            currPitch--;
            if(Math.randomf() < .05)
            {
                currPitch + 5 => currPitch;
                currVel - 20 => currVel;
                //90 => currVel;
            }
            currPitch % 12 => int pitchClass;
            if(pitchGrid[pitchClass] == 1)
            {
                // send note-on
                144 => msgOut.data1;
                currPitch => msgOut.data2;
                currVel + Math.random2(-5, 5) => currVel;
                if(currVel < minVel)
                {
                    minVel => currVel;
                }
                if(currVel > 127)
                {
                    127 => currVel;
                }
                
                currVel => msgOut.data3;
                //100 => msgOut.data3;
                mout.send(msgOut);

                (100 + Math.random2(-25,25))::ms => now;
            }
        }
        MIDIflush();
        0 => runDownActive;
    }
}

// Preset 4 - Blocks
fun void blocks(int status, int pitch, int velocity)
{
    2 => int voices;

    if(status == 144)
    {
        for(int i; i < voices; i++)
        {
            144 => msgOut.data1;
            fitPitch(pitch + 4*(i+1)) => msgOut.data2;
            velocity => msgOut.data3;
            mout.send(msgOut);
        }
        250::ms => now;
        for(int i; i < voices; i++)
        {
            128 => msgOut.data1;
            fitPitch(pitch + 4*(i+1)) => msgOut.data2;
            velocity => msgOut.data3;
            mout.send(msgOut);
        }
    }
}

// Preset 5 - Shatter

12 => int shatterOffset;

fun void shatterSeed()
{
    while(true)
    {
        Math.random2(7, 31) => int offset;
        (Math.random2(0, 1) * 2) - 1 => int direction;
        offset*direction => shatterOffset;
        2.5::second => now;
    }
}
spork~shatterSeed();

fun void shatter(int status, int pitch, int velocity)
{
    1 => int repetitions;

    if(status == 144)
    {
        for(int i; i < repetitions; i++)
        {

            Math.random2(500, 2000)::ms => now;
            shatterOffset => int offset;
            144 => msgOut.data1;
            fitPitch(pitch + offset) => msgOut.data2;
            velocity => msgOut.data3;
            mout.send(msgOut);
            
            Math.random2(250, 800)::ms => now;

            128 => msgOut.data1;
            fitPitch(pitch + offset) => msgOut.data2;
            velocity => msgOut.data3;
            mout.send(msgOut);
        }
    }
}


// Preset 6 - Beams
fun void beams(int status, int pitch, int velocity)
{
    .25 => float thresholdHi;
    .1 => float thresholdLow;

    if(status == 144)
    {
        pitch % 12 => int pitchClass;

        if(pitch < 60 && Math.randomf() < thresholdHi)
        {
            72 + (Math.random2(0,1)*12) => int oct;
            144 => msgOut.data1;
            oct + pitchClass => msgOut.data2;
            Math.random2(60, 90) => msgOut.data3;
            //120 => msgOut.data3;
            mout.send(msgOut);

            Math.random2(0, 80)::ms => now;

            144 => msgOut.data1;
            oct + 12 + pitchClass => msgOut.data2;
            Math.random2(60, 90) => msgOut.data3;
            //120 => msgOut.data3;
            mout.send(msgOut);

            700::ms => now;

            128 => msgOut.data1;
            oct + pitchClass => msgOut.data2;
            Math.random2(70, 100) => msgOut.data3;
            //120 => msgOut.data3;
            mout.send(msgOut);

            128 => msgOut.data1;
            oct + 12 + pitchClass => msgOut.data2;
            Math.random2(70, 100) => msgOut.data3;
            //120 => msgOut.data3;
            mout.send(msgOut);
        
        }
        if(pitch > 72 && Math.randomf() < thresholdLow)
        {
            24 + (Math.random2(0,2)*12) => int oct;
            144 => msgOut.data1;
            oct + pitchClass => msgOut.data2;
            Math.random2(60, 90) => msgOut.data3;
            //120 => msgOut.data3;
            mout.send(msgOut);

            Math.random2(0, 80)::ms => now;

            144 => msgOut.data1;
            oct + 12 + pitchClass => msgOut.data2;
            Math.random2(60, 90) => msgOut.data3;
            //120 => msgOut.data3;
            mout.send(msgOut);

            700::ms => now;

            128 => msgOut.data1;
            oct + pitchClass => msgOut.data2;
            Math.random2(70, 100) => msgOut.data3;
            //120 => msgOut.data3;
            mout.send(msgOut);

            128 => msgOut.data1;
            oct + 12 + pitchClass => msgOut.data2;
            Math.random2(70, 100) => msgOut.data3;
            //120 => msgOut.data3;
            mout.send(msgOut);
        }
    }
}

//Preset 7 - Ligeti
[-4, -3, -1, 2, 3, 5] @=> int cluster0[];
[-3, -2, 1, 3, 4] @=> int cluster1[];
[-4, -2, 2, 4, 7] @=> int cluster2[];
[-6, -3, -2, 1, 4] @=> int cluster3[];
[-3, -2, 1, 5, 7] @=> int cluster4[];

int clusters[5][0];
cluster0 @=> clusters[0];
cluster1 @=> clusters[1];
cluster2 @=> clusters[2];
cluster3 @=> clusters[3];
cluster4 @=> clusters[4];

0 => int clusterSeed;
0 => int clusterActive;

fun void clusterReseed()
{
    while(true)
    {
        Math.random2(0,4) => clusterSeed;
        5::second => now;
    }
}
spork~clusterReseed();

fun void ligeti(int status, int pitch, int velocity)
{
    if(status == 144)
    {
        velocity $ float => float velFloat;
        Math.ceil(Math.map2(velFloat, 0, 127, 1, 5)) $ int => int pitchScale;
        Math.random2(1,8) => int repetitions;

        for(1 => int i; i <= pitchScale; i++)
        {
            spork~delayFeedback(144, pitch + i, velocity, Math.random2(300, 800)::ms, repetitions, .9);
            //spork~delayFeedback(144, pitch - i, velocity, Math.random2(300, 800)::ms, repetitions, .9);
        }
    }

}

fun void clusterDelay(int status, int pitch, int velocity, dur delayTime, int repetitions, float decayFactor)
{
    if(status == 144)
    {
        
        for(int i; i < repetitions; i++)
        {
            1 => clusterActive;
            delayTime => now;
            chout <= "playing delayed note: " <= pitch <= ", " <= velocity <= IO.newline();
            144 => msgOut.data1;
            pitch => msgOut.data2;
            Math.round(Math.pow(decayFactor, i + 1) * velocity)$int => velocity;
            velocity => msgOut.data3;
            mout.send(msgOut);

            200::ms => now;

            128 => msgOut.data1;
            pitch => msgOut.data2;
            120 => msgOut.data3;
            mout.send(msgOut);
        }
        0 => clusterActive;
    }
}

fun void lick1(int startNote)
{
    [0, -5, 2, -3, 4, -1, -6, 1, -4, 3, -2, -7] @=> int notes[];
    startNote => int seed;
    4 => int repetitions;

    for(int j; j < repetitions; j++)
    {
        for(int i; i < notes.size(); i++)
        {
            144 => msgOut.data1;
            seed + notes[i] => msgOut.data2;
            50 => msgOut.data3;
            mout.send(msgOut);
            
            110::ms => now;

            128 => msgOut.data1;
            seed + notes[i] => msgOut.data2;
            50 => msgOut.data3;
            mout.send(msgOut);
        }
        seed -3 => seed;
    }

}

fun void lick2(int startNote)
{
    [0, -5, 2, -3, 4, -1, -6, 1, -4, 3, -2, -7] @=> int notes[];
    startNote => int seed;
    4 => int repetitions;

    for(int j; j < repetitions; j++)
    {
        for(int i; i < notes.size(); i++)
        {
            144 => msgOut.data1;
            seed + notes[i] => msgOut.data2;
            50 => msgOut.data3;
            mout.send(msgOut);
            
            120::ms => now;

            128 => msgOut.data1;
            seed + notes[i] => msgOut.data2;
            120 => msgOut.data3;
            mout.send(msgOut);
        }
        seed -3 => seed;
    }

}

"[df2:f4 ef bf af2:f4 ef bf ef3:f3 ef4 bf f ef c4 bf efd c bf//df2:c3 ef bfu af2:c4 efd f bf ef3:ef4 f bfd c f ef bf f ef//c2:f4 e gd c2:f4 e c d3:g3 d4 c g f c4 g f e g//c2:f3 c e g2:f3 g f d3:c4 d e fd c4 d gd c d e]" @=> string phrase1_p;
"[sx16 sx16 sx16 sx16]" @=> string phrase1_r;

EZscore phrase1(phrase1_p, phrase1_r);
0 => int phrase1_active;

fun void score2disk(EZscore score, float bpm, int repetitions)
{
    (60000/bpm)::ms => dur beat;
    score.pitches @=> int pitches[][];
    score.rhythms @=> float rhythms[];

    1 => phrase1_active;
    for(int r; r < repetitions; r++)
    {
        for(int i; i < rhythms.size(); i++)
            {
                for(int j; j < pitches[i].size(); j++)
                {
                    if(pitches[i][j] > 0)
                    {
                        144 => msgOut.data1;    
                        pitches[i][j] => msgOut.data2;
                        50 => msgOut.data3;
                        mout.send(msgOut);
                    }
                }
                rhythms[i]*(60000/bpm)::ms => now;
                for(int j; j < pitches[i].size(); j++)
                {
                    if(pitches[i][j] > 0)
                    {
                        128 => msgOut.data1;    
                        pitches[i][j] => msgOut.data2;
                        120 => msgOut.data3;
                        mout.send(msgOut);
                    }
                }
            }
    }
    0 => phrase1_active;
}

fun void control()
{
    while( true )
    {
        mins[-1] => now;
        while( mins[-1].recv(msgIns[-1]) )
        {
            if(msgIns[-1].data1 == 144 || msgIns[-1].data1 == 128)
            {
                if(preset == 0)
                {
                    MIDIflush();
                }
                if(preset == 1)
                {
                    if(msgIns[-1].data2 >= 48 && msgIns[-1].data2 <= 77)
                    {
                        spork~steam(msgIns[-1].data1, msgIns[-1].data2, msgIns[-1].data3, 7);
                        spork~steam(msgIns[-1].data1, msgIns[-1].data2, msgIns[-1].data3, 12);
                    }
                }
                if(preset == 2)
                {
                    if(msgIns[-1].data2 >= 48 && msgIns[-1].data2 <= 67 && runUpActive == 0)
                    {
                        spork~runUp(msgIns[-1].data1, msgIns[-1].data2, msgIns[-1].data3);
                    }
                    if(msgIns[-1].data2 > 67 && msgIns[-1].data2 <= 96 && runDownActive == 0)
                    {
                        spork~runDown(msgIns[-1].data1, msgIns[-1].data2, msgIns[-1].data3);
                    }
                }
                if(preset == 3)
                {
                    if(msgIns[-1].data2 >= 60 && msgIns[-1].data2 <= 72 )
                    {
                        generateSequence(2, msgIns[-1].data2 + 12 , 4) @=> float generated[][];
                        playSequence(generated, 100);
                    }
                    //generateSequence(4, 72, 4) @=> float generated[][];
                    //playSequence(generated, 80);
                }
                if(preset == 4)
                {
                    spork~blocks(msgIns[-1].data1, msgIns[-1].data2, msgIns[-1].data3);
                }
                if(preset == 5)
                {
                    spork~shatter(msgIns[-1].data1, msgIns[-1].data2, msgIns[-1].data3);
                    if(Math.randomf() < .3)
                    {
                        spork~shatter(msgIns[-1].data1, msgIns[-1].data2, msgIns[-1].data3);
                    }
                    if(Math.randomf() > .3)
                    {
                        spork~delayFeedback(msgIns[-1].data1, msgIns[-1].data2 + 12, msgIns[-1].data3, 1::second, 1, .85);                    
                    }
                }
                if(preset == 6)
                {
                    spork~beams(msgIns[-1].data1, msgIns[-1].data2, msgIns[-1].data3);
                }
                if(preset == 7)
                {
                    if(msgIns[-1].data1 == 144 && msgIns[-1].data2 > 43 && msgIns[-1].data2 < 76)
                    {
                        if(clusterActive == 0)
                        {
                            clusters[clusterSeed] @=> int offsets[];

                            for(int i; i < offsets.size(); i++)
                            {
                                spork~clusterDelay(msgIns[-1].data1, msgIns[-1].data2 + offsets[i], msgIns[-1].data3, Math.random2(250, 700)::ms, Math.random2(2,8), .9);
                            }
                        }
                    }
                }
                if(preset == 8)
                {
                    if(msgIns[-1].data1 == 144 && msgIns[-1].data2 > 48)
                    {
                        spork~lick1(msgIns[-1].data2);
                    }
                }
                if(preset == 9)
                {
                    if(phrase1_active == 0 && msgIns[-1].data2 < 72)
                    {
                        spork~score2disk(phrase1, 116, 2);
                    }

                }
            }
        }
    }
}

//generateSequence(4, 72, 4) @=> float generated[][];
//playSequence(generated, 80);

spork~control();
//spork~score2disk(phrase1, 120);
////////////////////////////////////////////////////////////////////////////////////////////

// Mvt. 1: Clusters, Shatter
// --------------------------
//      Start with clusters around G4, pinging melody above
//      Gradually move center down to C3
// Trigger CLUSTERS: C Db B C
//      Play repeated notes in LH middle register, upper structures in RH
// Trigger SHATTER: C Db G Ab
//      Focus on simple intervals, start with P5 with "manual delay"
//      Eventually, use left pedal to fit harmony:
//          [C D E G] & improvise around FmM7 C
// Trigger RESET: C2 C1

// Mvt. 2: Sailing
// ---------------------------
//      Start by improvising freely over changes: | Cadd9 C7/E | Fm9 | Eb | Dm9 | Dbmaj7 |
//      Move to improvising using steady 16th note pulse over | Dbmaj7 | C9 |
// Trigger SAILING: C major descending lick
//      Solo over low register accompaniment, start in high register, improvising melodically
//      Eventually move into low register almost doubling the ostinato
// Trigger RESET: C2 C1
//      Continue improv similar to the ostinato to hide the transition

// Mvt. 3: Blocks, mini-reprise Mvt. 1
// ---------------------------
//      Start by playing around C7alt, Cdim, Caug
// Trigger BLOCKS: D F# G# C
//      Play staccato, angular across registers
//      Outline maj7 shapes, play supralocrian runs
// Trigger CLUSTERS: C Db B C
//      Briefly play clusters but even more clustered than Mvt 1
//      Left pedal: [C Db F G Ab]
// Trigger SHATTER: C Db G Ab
//      Play with harmony-fit Shatter on C Phrygian, then F lydian
//      Start playing scale runs and sweeping textures to set up next section
//          Fmaj 1 3 4 7 descending pattern
// Trigger BEAMS: C B A G F

// Mvt. 4: Beams, Cascades
// ---------------------------
//      Play dense textures alternating high and low registers
//      Use tremolo, arpeggiation, scale runs (emphasizing scale runs as time goes on)
//      Alternate between F lydian and Db lydian
//      End up in B lydian, playing ascending and descending scale runs
// Trigger CASCADES: B Db Eb F Gb
//      Play strong octaves, sixths in mid-upper register, allowing the runs to take over
//      Left pedal: B lydian, C minor, B lydian
//      Left pedal: [Eb Bb]
//          Play: | Bmaj7 | Abmaj7 | Emaj7 Gbmaj7 | Ebmaj7 | x2 
// Trigger RESET: C2 C1 ( Cm7 )

// Mvt. 5: Calling
// ----------------------------
//      Transition with Cm7 Baug7 Bm9 Aaug7
//      Play Abmaj written section
//      Ending: Gbmaj7 G7alt --> Abo7 ascending line
//      Left pedal: Amaj
// Trigger MELODY: A B C# D E
//      Improvise very diatonic chord progression in A, staying below C4
//      Occasionally trigger melodies by playing SINGLE NOTES above C4
//      Accompany the generated melodies
//      Left pedal: occasionally use F lydian in between A major
// Trigger RESET: C2 C1
//      Improvise out

while( true )
{
    1::second => now;
}
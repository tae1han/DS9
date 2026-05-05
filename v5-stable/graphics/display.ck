class AgentConsole extends GGen
{
    GLines frame --> this --> GG.scene();

    3 * .85 => float x_width;
    3 * .8 => float y_width;
    [ @(-x_width/2, -y_width/2), @(x_width/2, -y_width/2), @(x_width/2, y_width/2), @(-x_width/2, y_width/2), @(-x_width/2, -y_width/2) ] @=> vec2 frame_positions[];
    [ Color.WHITE ] @=> vec3 frame_colors[];

    frame_positions => frame.positions;
    frame_colors => frame.colors;
    .01 => frame.width;

    GText nickname --> this;
    "Agent" => nickname.text;
    nickname.font("chugl:proggy-clean");
    // nickname.color(Color.hsv2rgb(@(Math.random2(0, 360), 1, 1)));
    nickname.color(@(1, 1, 1));
    nickname.size(.25);
    nickname.posY((y_width /2) * 1.2);
    nickname.posX(0);

    GText status[2];
    "Status:" => status[0].text;
    "Inactive" => status[1].text;
    for(int i; i < 2; i++)
    {
        status[i].font("chugl:proggy-clean");
        status[i].color(@(1, 1, 1));
        status[i].size(.2);
        status[i].posY((y_width /2) * .8);
        status[i].align(0);
        status[i] --> this;
    }
    status[0].posX((-x_width/2) * .625);
    status[1].posX(0);

    GText body --> this;
    // "lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua." => body.text;
    "" => body.text;
    body.font("chugl:proggy-clean");
    body.color(@(1, 1, 1));
    body.size(.2);
    body.posY((y_width /2) * .2);
    body.posX(0);

    body.maxWidth(x_width*.9);

    fun AgentConsole(vec3 center_pos)
    {
        center_pos => this.pos;
    }

    fun string setName(string n)
    {
        n => nickname.text;
        return n;
    }

    fun void setStatus(int val)
    {
        if(val == 0)
        {
            "Idle" => status[1].text;
            Color.ORANGE => status[1].color;
        }
        else if(val == 1)
        {
            "Thinking" => status[1].text;
            Color.BLUE => status[1].color;
        }
        else if(val == 2)
        {
            "Playing" => status[1].text;
            Color.GREEN => status[1].color;
        }
    }

    fun void setBody(string s)
    {
        s => body.text;
    }
}

public class Waveform extends GGen
{
    1024 => int WINDOW_SIZE;
    1 => float x_width;

    GLines lines --> this;
    lines.width(.01);

    Gain inlet => Flip accum => blackhole;
    WINDOW_SIZE => accum.size;
    Windowing.hann(WINDOW_SIZE) @=> float window[];
    vec2 positions[WINDOW_SIZE];

    float samples[0];

    fun void map2waveform(float in[], vec2 out[])
    {
        if( in.size() != out.size() )
        {
            <<< "size mismatch in map2waveform()", "" >>>;
            return;
        }

        x_width => float width;
        for(int i; i < in.size(); i++)
        {
            // space evenly in X
            -width/2 + width/WINDOW_SIZE*i => out[i].x;
            // map y, using window function to taper the ends
            in[i] * 2 * window[i] => out[i].y;
        }
    }

    fun void doAudio()
    {
        while(true)
        {
            accum.upchuck();
            accum.output(samples);
            WINDOW_SIZE::samp/2 => now;
        }
    }
    spork ~ doAudio();

    fun void doGraphics()
    {
        while(true)
        {
            GG.nextFrame() => now;
            map2waveform(samples, positions);
            lines.positions(positions);
        }
    }
    spork ~ doGraphics();

    fun void setColor(vec3 color)
    {
        color => lines.color;
    }
}

public class DisplayConsole extends GGen
{
    GLines frame_bg --> this;

    9.25 => float x_width;
    6.25 => float y_width;
    [ @(-x_width/2, -y_width/2), @(x_width/2, -y_width/2), @(x_width/2, y_width/2), @(-x_width/2, y_width/2), @(-x_width/2, -y_width/2) ] @=> vec2 frame_positions[];
    [ Color.WHITE ] @=> vec3 frame_colors[];

    frame_positions => frame_bg.positions;
    frame_colors => frame_bg.colors;
    .01 => frame_bg.width;

    6 => int num_agents;

    Waveform waveforms[num_agents];


    AgentConsole agent_consoles[num_agents];
    [-3.0, 0.0, 3.0, -3.0, 0.0, 3.0] @=> float x_positions[];
    [1.5, 1.5, 1.5, -1.5, -1.5, -1.5] @=> float y_positions[];
    ["Parrot", "Parakeet", "Albatross", "Peacock", "Emu", "Falcon"] @=> string nicknames[];
    [Color.RED, Color.GREEN, Color.CYAN, Color.BLUE, Color.YELLOW, Color.MAGENTA] @=> vec3 agent_colors[];
    for(int i; i < num_agents; i++)
    {
        @(x_positions[i], y_positions[i], 0) => vec3 center_pos;
        nicknames[i] => agent_consoles[i].setName;
        agent_colors[i] => agent_consoles[i].nickname.color;
        agent_consoles[i].pos(center_pos);
        waveforms[i] --> this;
        agent_colors[i] => waveforms[i].setColor;
        waveforms[i].pos(center_pos + @(0, -.5, 0));
    }

    fun void setStatus(int agent_index, int status)
    {
        agent_consoles[agent_index].setStatus(status);
    }

    fun void setBody(int agent_index, string body)
    {
        agent_consoles[agent_index].setBody(body);
    }
}

public class ClientDisplay extends GGen
{
    GLines frame_bg --> this;

    9.25 => float x_width;
    6.25 => float y_width;
    [ @(-x_width/2, -y_width/2), @(x_width/2, -y_width/2), @(x_width/2, y_width/2), @(-x_width/2, y_width/2), @(-x_width/2, -y_width/2) ] @=> vec2 frame_positions[];
    [ Color.WHITE ] @=> vec3 frame_colors[];

    frame_positions => frame_bg.positions;
    frame_colors => frame_bg.colors;
    .01 => frame_bg.width;

    ["Parrot", "Parakeet", "Albatross", "Peacock", "Emu", "Falcon"] @=> string nicknames[];
    [Color.RED, Color.GREEN, Color.CYAN, Color.BLUE, Color.YELLOW, Color.MAGENTA] @=> vec3 agent_colors[];

    AgentConsole console(@(0, 0, 0));
    console.sca(2);
    console.frame --< console;
    Waveform waveform --> this;
    waveform.scaX(2);
    waveform.scaY(2);

    fun void init(int agentIndex)
    {
        nicknames[agentIndex] => console.setName;
        agent_colors[agentIndex] => console.nickname.color;
        agent_colors[agentIndex] => waveform.setColor;
        3.5 => waveform.x_width;
        waveform.pos(@(0, -2.0, 0));
    }

    fun void setStatus(int status)
    {
        console.setStatus(status);
    }

    fun void setBody(string body)
    {
        console.setBody(body);
    }
}
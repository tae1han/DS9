public class oscBroadcaster
{
    6 => int MAX_CLIENTS;
    OscOut clients[MAX_CLIENTS];
    int _numClients;

    fun void addClient(string ip, int port)
    {
        if(_numClients >= MAX_CLIENTS)
        {
            <<< "oscBroadcaster: max clients reached" >>>;
            return;
        }
        clients[_numClients].dest(ip, port);
        // <<< "added client", ip, port >>>;
        _numClients++;
    }

    fun void noteOn(int pitch, float velocity)
    {
        for(int i; i < _numClients; i++)
        {
            clients[i].start("/ds9/noteOn");
            pitch => clients[i].add;
            velocity => clients[i].add;
            clients[i].send();
        }
    }

    fun void noteOff(int pitch)
    {
        for(int i; i < _numClients; i++)
        {
            clients[i].start("/ds9/noteOff");
            pitch => clients[i].add;
            clients[i].send();
        }
    }

    fun void phraseStart()
    {
        for(int i; i < _numClients; i++)
        {
            clients[i].start("/ds9/phraseStart");
            clients[i].send();
        }
    }

    fun void phraseComplete()
    {
        for(int i; i < _numClients; i++)
        {
            clients[i].start("/ds9/phraseComplete");
            clients[i].send();
        }
    }

    fun void silenceSustained(float seconds)
    {
        for(int i; i < _numClients; i++)
        {
            clients[i].start("/ds9/silenceSustained");
            seconds => clients[i].add;
            clients[i].send();
        }
    }
}

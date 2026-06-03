// Standalone read-only monitor (when server is not hosting ChuGL).
@import "performanceMonitor.ck"

"224.0.0.1" => string MULTICAST_ADDR;
for(0 => int i; i < me.args(); i++)
{
    if(me.arg(i) == "local") "127.0.0.1" => MULTICAST_ADDR;
}

PerformanceMonitor mon;
spork ~ mon.run(1);
<<< "performanceDisplay — read-only | OSC", MULTICAST_ADDR >>>;

while(true) 50::ms => now;

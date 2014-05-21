// constants
121 => int NUM_KEYS; // number of unique midi signals my LPK25 gives

// Sentinels
-1 => int END;
-2 => int SILENCE;

// State
int keys[NUM_KEYS];
float gains[NUM_KEYS];
0 => float masterGain;

fun void evtListener() {
    OscRecv recv;
    8008 => recv.port;
    recv.listen();

    // event types
    recv.event( "arp/begin, i" ) @=> OscEvent beginEvt;
    recv.event( "arp/key, i, f" ) @=> OscEvent keyEvt;

    // receive messages
    while (true) {
        beginEvt => now;
        while (beginEvt.nextMsg() != 0) {
            beginEvt.getInt() => int tap;
            <<< "tap! ", tap >>>;
        }

        keyEvt => now;

        while (keyEvt.nextMsg() != 0) {
            keyEvt.getInt() => int key;
            keyEvt.getFloat() => float gain;

            if (key == SILENCE) {
                0 => masterGain;
                break;
            } else if (key == END) {
                break;
            }

            // handle key
            <<< key, " ", gain >>>;
        }
    }
}

spork ~ evtListener();

while (true) {
    1 :: ms => now;
}

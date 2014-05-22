// constants
121 => int NUM_KEYS; // number of unique midi signals my LPK25 gives
10 => int MAX_CONCURRENT;

// Sentinels
-1 => int END;
-2 => int SILENCE;

// State
int keys[NUM_KEYS];
float gains[NUM_KEYS];
int curKeys[MAX_CONCURRENT];
int keysPlaying;
int lastKeyFilled;

50 => int durationMs;
.5 => float reverbiness;

fun void clearKeys() {
    0 => keysPlaying;
    0 => lastKeyFilled;
    for (0 => int i; i < NUM_KEYS; ++i) {
        0 => keys[i];
        0 => gains[i];
    }

    for (0 => int i; i < MAX_CONCURRENT; ++i) {
        -1 => curKeys[i];
    }
}
clearKeys();

0 => float masterGain;
Math.random2(1, 6) => int rate;

// setup instruments
SinOsc oscs[dac.channels()];
ADSR adsrs[dac.channels()];
NRev revs[dac.channels()];

for (0 => int i; i < dac.channels(); ++i) {
    oscs[i] => adsrs[i] => revs[i] => dac;
    Math.round(reverbiness * 500) $ int => int release;
    reverbiness / 2 => revs[i].mix;
    adsrs[i].set(10 :: ms, 0 :: ms, 1, release :: ms);
}

fun void triggerNote() {
    if (!keysPlaying) {
        return;
    }

    Math.random2(0, dac.channels() - 1) => int channel;

    Math.random2(0, lastKeyFilled - 1) => int randomIndex;
    curKeys[randomIndex] => int thisKey;
    gains[thisKey] => float thisGain;

    Std.mtof(thisKey) => oscs[channel].freq;
    thisGain / 4 => oscs[channel].gain;
    adsrs[channel].keyOn();
    durationMs :: ms => now;
    adsrs[channel].keyOff();
    durationMs * 2 :: ms => now;
}

fun void evtListener() {
    OscRecv recv;
    8008 => recv.port;
    recv.listen();

    // event types
    recv.event( "arp/begin, i" ) @=> OscEvent beginEvt;
    recv.event( "arp/key, i, f" ) @=> OscEvent keyEvt;

    // receive messages
    while (true) {
        // get tap number
        beginEvt => now;
        int tap;
        while (beginEvt.nextMsg() != 0) {
            beginEvt.getInt() => tap;
        }

        // get keys playing
        keyEvt => now;
        0 => int curIter;
        while (keyEvt.nextMsg() != 0) {
            keyEvt.getInt() => int thisKey;
            keyEvt.getFloat() => float thisGain;

            if (thisKey == SILENCE) {
                0 => keysPlaying;
                break;
            } else if (thisKey == END) {
                break;
            }

            if (curIter == 0) {
                clearKeys();
            }
            curIter++;

            1 => keys[thisKey];
            thisGain => gains[thisKey];
            1 => keysPlaying;
            thisKey => curKeys[lastKeyFilled];
            lastKeyFilled++;

            // handle key
            <<< thisKey, " ", thisGain >>>;
        }

        // decide to make sound
        if (tap % rate == 0) {
            spork ~ triggerNote();
        }
    }
}

spork ~ evtListener();

while (true) {
    1 :: ms => now;
}

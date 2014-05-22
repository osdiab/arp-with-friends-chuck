// constants
121 => int NUM_KEYS; // number of unique midi signals my LPK25 gives
15 => int MAX_CONCURRENT;

// Sentinels
-1 => int END;
-2 => int REVERBINESS;
-3 => int TEMPO;

// State
int keys[NUM_KEYS];
float gains[NUM_KEYS];
int curKeys[MAX_CONCURRENT];
int keysPlaying;
int lastKeyFilled;
0 => float probPlay;

10 :: ms => dur attack;
50 :: ms => dur duration;
0 => float reverbiness;
.2 => float durationiness;
240 :: ms => dur tempo;

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

fun dur calculateRelease() {
    return ((Math.round(reverbiness * 2500) $ int) + 50) :: ms;
}

for (0 => int i; i < dac.channels(); ++i) {
    oscs[i] => adsrs[i] => revs[i] => dac;
    reverbiness / 2 => revs[i].mix;
    adsrs[i].set(attack, 0 :: ms, 1, calculateRelease());
}

fun void triggerNote() {
    Math.random2(0, dac.channels() - 1) => int channel;

    Math.random2(0, lastKeyFilled - 1) => int randomIndex;
    curKeys[randomIndex] => int thisKey;
    gains[thisKey] => float thisGain;

    Std.mtof(thisKey) => oscs[channel].freq;
    thisGain / 4 => oscs[channel].gain;
    adsrs[channel].keyOn();
    duration + attack => now;
    adsrs[channel].keyOff();
    calculateRelease() * 3 + 200 :: ms => now;
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

            if (thisKey == END) {
                break;
            } else if (thisKey == REVERBINESS) {
                thisGain => reverbiness;
                for (0 => int i; i < dac.channels(); ++i) {
                    reverbiness / 2 => revs[i].mix;
                    adsrs[i].set(attack, 0 :: ms, 1, calculateRelease());
                }
                break;
            } else if (thisKey == TEMPO) {
                keyEvt.nextMsg();
                keyEvt.getInt() :: ms => tempo;
                keyEvt.getFloat();
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
        if (tap % rate == 0 && keysPlaying && Math.randomf() <= probPlay) {
            spork ~ triggerNote();
        }
    }
}

spork ~ evtListener();

fun void kbHandler() {
    Hid kb;
    HidMsg kmsg;

    // which keyboard
    0 => int kbNum;

    // open keyboard
    if( !kb.openKeyboard( kbNum ) ) me.exit();
    // successful! print name of device
    <<< "keyboard '", kb.name(), "' ready" >>>;

    while(true) {
        kb => now;
        while(kb.recv(kmsg)) {
            <<<kmsg.ascii>>>;

            if (kmsg.isButtonDown()) {
                if (kmsg.ascii >= 48 && kmsg.ascii <= 57) {
                    // 0-9
                    (kmsg.ascii - 48) / 10.0 => probPlay;
                } else if (kmsg.ascii == 32) {
                    // space
                    clearKeys();
                }
            }
        }
    }
}

kbHandler();

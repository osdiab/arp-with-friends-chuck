// constants

0 => int DEBUG;

if (me.args() == 1 && me.arg(0) == "debug") {
    1 => DEBUG;
}

0 => int LEFT;
1 => int RIGHT;
2 => int CENTER;

0 => int section;

121 => int NUM_KEYS; // number of unique midi signals my LPK25 gives
15 => int MAX_CONCURRENT;

// Sentinels
-1 => int END;
-2 => int REVERBINESS;
-3 => int TEMPO;

// State
0 => float legato;
0 => int cleared;
int keys[NUM_KEYS];
float gains[NUM_KEYS];
int curKeys[MAX_CONCURRENT];
int keysPlaying;
0 => int curKeyPlaying;
int lastKeyFilled;
0 => float probPlay;

0 => float reverbiness;
0 => float sectionDominance;
1 => float randomness;
0 => int curKey;
240 => int tempo;

fun void clearKeys() {
    0 => reverbiness;
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
Math.random2(0, 1) => int direction;

// setup instruments
SinOsc oscs[dac.channels()];
ADSR adsrs[dac.channels()];
NRev revs[dac.channels()];

fun dur calculateRelease() {
    if (cleared) {
        return 3 :: second;
    } else {
        return 50 :: ms;
    }
}

fun dur calculateAttack() {
    <<< "atk: ", (((10 + legato * tempo * rate + legato * 100 * (rate))) $ int)>>>;
    return (((10 + legato * tempo * rate + legato * 100 * (rate))) $ int) :: ms;
}

fun dur calculateDelay() {
    return (((50 + legato * tempo * 4) ) $ int) :: ms;
}

for (0 => int i; i < dac.channels(); ++i) {
    oscs[i] => adsrs[i] => revs[i] => dac;
    reverbiness / 6 => revs[i].mix;
    adsrs[i].set(calculateAttack(), calculateDelay(), .5, calculateRelease());
    1 - legato * .5 => adsrs[i].gain;
}

fun void triggerNote() {
    if (!keysPlaying) {
        return;
    }
    if (cleared) {
        for (0 => int i; i < dac.channels(); ++i) {
            adsrs[i].set(calculateAttack(), calculateDelay(), .5, calculateRelease());
            1 - legato * .5 => adsrs[i].gain;
        }
    }

    // choose a channel
    Math.random2(0, dac.channels() - 1) => int channel;

    // choose a key
    0 => int lower;
    lastKeyFilled - 1 => int upper;
    if (section == LEFT) {
        // top third keys
        Math.max(0,
            ((lastKeyFilled - 1) * (sectionDominance * .67))) $ int => lower;
    } else if (section == RIGHT) {
        // middle third keys
        Math.max(0,
            ((lastKeyFilled - 1) * (sectionDominance * .33))) $ int => lower;
        Math.min((lastKeyFilled - 1),
            ((lastKeyFilled - 1) * (1 - (sectionDominance * .33)))) $ int => upper;
    } else if (section == CENTER) {
        // bottom third keys
        Math.min((lastKeyFilled - 1),
            ((lastKeyFilled - 1) * (1 - (sectionDominance * .67)))) $ int => upper;
    } else {
        <<< "You have an invalid section.", " Something weird happened, call the police." >>>;
        me.exit();
    }

    Math.random2(lower, upper) => int randomIndex;

    randomIndex => int keyChosen;
    if (Math.random2f(0, 1) > randomness) {
        curKeyPlaying % lastKeyFilled => keyChosen;
        if (direction) {
            lastKeyFilled - keyChosen - 1 => keyChosen;
        }
    }

    // get the key
    curKeys[keyChosen] => int thisKey;
    gains[thisKey] => float thisGain;

    // set the frequency and gain
    Std.mtof(thisKey) => oscs[channel].freq;
    thisGain / 4 => oscs[channel].gain;

    // play
    adsrs[channel].keyOn();
    calculateAttack() + calculateDelay() => now;
    adsrs[channel].keyOff();

    // wait for sound to resolve
    calculateRelease() * 2 + 200 :: ms => now;

    curKeyPlaying++;
    if (cleared) {
        0 => cleared;
        for (0 => int i; i < dac.channels(); ++i) {
            adsrs[i].set(calculateAttack(), calculateDelay(), .5, calculateRelease());
            1 - legato * .5 => adsrs[i].gain;
        }
    }
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
                    reverbiness / 6 => revs[i].mix;
                    adsrs[i].set(calculateAttack(), calculateDelay(), .5, calculateRelease());
                    1 - legato * .5 => adsrs[i].gain;
                }
                break;
            } else if (thisKey == TEMPO) {
                keyEvt.nextMsg();
                keyEvt.getInt() => tempo;
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

            if (DEBUG) {
                <<< thisKey, " ", thisGain >>>;
            }
        }

        // decide to make sound
        if (tap % rate == 0 && keysPlaying && Math.randomf() <= probPlay && !cleared) {
            <<< ".", "" >>>;
            spork ~ triggerNote();
        }
    }
}

fun int selectSection(Hid kb, HidMsg kmsg) {
    <<< "Are you ", "[L]eft, [R]ight, or [C]enter?\n",
        "Type L for left, etc." >>>;

    while (true) {
        kb => now;
        while (kb.recv(kmsg)){
            if (DEBUG) {
                <<<kmsg.ascii>>>;
            }
            if (kmsg.isButtonDown()) {
                if (kmsg.ascii == 0) {
                    continue;
                }
                if (kmsg.ascii == 76) {
                    <<< "\nSelected ", "left. Play!\n" >>>;
                    return LEFT;
                }
                if (kmsg.ascii == 82) {
                    <<< "\nSelected ", "right. Play!\n" >>>;
                    return RIGHT;
                }
                if (kmsg.ascii == 67) {
                    <<< "\nSelected ", "center. Play!\n" >>>;
                    return CENTER;
                }

                <<< "\n\tL stands for left, R for right, C for center.", " Try again." >>>;
            }
        }
    }
}

fun void kbHandler() {
    Hid kb;
    HidMsg kmsg;

    // which keyboard
    0 => int kbNum;

    // open keyboard
    if( !kb.openKeyboard( kbNum ) ) me.exit();
    // successful! print name of device
    <<< "keyboard '", kb.name(), "' ready" >>>;

    selectSection(kb, kmsg) => section;
    spork ~ evtListener();

    <<< "Instructions: Press the following keys for these effects:\n\n",
        "\tQ:\t\tBecome more sectional\n",
        "\tA:\t\tBecome less sectional\n",
        "\tW:\t\tBecome more random (default is fully random)\n",
        "\tS:\t\tBecome less random\n",
        "\tE:\t\tBecome more legato/less staccato (default is staccato)\n",
        "\tD:\t\tLess legato/more staccato\n",
        "\t<space>:\tStop all sound\n",
        "\t<numbers>:\tSet probability of playback. 1 is 10%, 9 is 90%, 0 is 100%\n",
        "\n\n">>>;

    while(true) {
        kb => now;
        while(kb.recv(kmsg)) {
            if (DEBUG) {
                <<<kmsg.ascii>>>;
            }

            if (kmsg.isButtonDown()) {
                if (kmsg.ascii >= 48 && kmsg.ascii <= 57) {
                    // 0-9
                    kmsg.ascii - 48 => int amt;
                    if (amt == 0) {
                        10 => amt;
                    }
                    amt / 10.0 => probPlay;
                    <<< "\nSet probability to ", probPlay * 100, "%" >>>;
                } else if (kmsg.ascii == 32) {
                    // space
                    1 => cleared;
                    spork ~ triggerNote();

                    100 :: ms => now;
                    0 => probPlay;
                    clearKeys();
                    <<< "\n======================\n", "Cleared!", "\n======================\n" >>>;
                } else if (kmsg.ascii == 81) {
                    // Q: More section dominance
                    sectionDominance => float oldDom;
                    Math.min(sectionDominance + .25, 1) => sectionDominance;
                    if (oldDom == sectionDominance) {
                        <<< "\n", (sectionDominance * 4 $ int), "\tMaximum ", "sectionality!" >>>;
                    } else {
                        <<< "\n", (sectionDominance * 4 $ int), "\tMore ", "sectionality" >>>;
                    }
                } else if (kmsg.ascii == 65) {
                    // A: Less section dominance
                    sectionDominance => float oldDom;
                    Math.max(sectionDominance - .25, 0) => sectionDominance;
                    if (oldDom == sectionDominance) {
                        <<< "\n", (sectionDominance * 4 $ int), "\tMinimum ", "sectionality!" >>>;
                    } else {
                        <<< "\n", (sectionDominance * 4 $ int), "\tLess sectionality" >>>;
                    }
                } else if (kmsg.ascii == 87) {
                    // W: More random
                    randomness => float oldRandomness;
                    Math.min(randomness + .2, 1) => randomness;
                    if (oldRandomness == randomness) {
                        <<< "\nMaximum ", "randomness!" >>>;
                    } else {
                        <<< "\nMore ", "randomness" >>>;
                    }
                } else if (kmsg.ascii == 83) {
                    // S: Less random
                    randomness => float oldRandomness;
                    Math.max(randomness - .2, 0) => randomness;
                    if (oldRandomness == randomness) {
                        <<< "\nMinimum ", "randomness!" >>>;
                    } else {
                        <<< "\nLess ", "randomness" >>>;
                    }
                } else if (kmsg.ascii == 69) {
                    // E: more legato
                    legato => float oldLegato;
                    Math.min(legato + .1, 1) => legato;
                    if (oldLegato == legato) {
                        <<< "\nMaximum ", "legato!" >>>;
                    } else {
                        <<< "\nMore ", "legato!" >>>;
                    }
                    for (0 => int i; i < dac.channels(); ++i) {
                        adsrs[i].set(calculateAttack(), calculateDelay(), .5, calculateRelease());
                        1 - legato * .5 => adsrs[i].gain;
                    }
                } else if (kmsg.ascii == 68) {
                    // D: less legato
                    legato => float oldLegato;
                    Math.max(legato - .1, 0) => legato;
                    if (oldLegato == legato) {
                        <<< legato>>>;
                        <<< "\nMinimum ", "legato!" >>>;
                    } else {
                        <<< "\nLess ", "legato!" >>>;
                    }

                    for (0 => int i; i < dac.channels(); ++i) {
                        adsrs[i].set(calculateAttack(), calculateDelay(), .5, calculateRelease());
                        1 - legato * .5 => adsrs[i].gain;
                    }
                }
            }
        }
    }
}

kbHandler();

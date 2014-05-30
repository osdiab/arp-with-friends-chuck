["localhost"] @=> string slaves[];
// ["localhost",  "hamburger.local", "nachos.local", "meatloaf.local", "lasagna.local", "kimchi.local", "jambalaya.local", "icetea.local", "albacore.local", "donut.local","empanada.local","gelato.local"] @=> string slaves[];

slaves.size() => int NUM_SLAVES;
OscSend xmits[NUM_SLAVES];
8008 => int port;

0 => int tap; // current beat tap

Hid kb;
Hid mouse;
MidiIn midiKb;

HidMsg mmsg;
HidMsg kmsg;
MidiMsg midiKbMsg;

// keeps track of keys and their associated gains played on the midi kb
121 => int NUM_KEYS;
int keys[NUM_KEYS];
float gains[NUM_KEYS];

// Sentinels
-1 => int END;
-2 => int REVERBINESS;
-3 => int TEMPO;

0 => int reverbTriggered;
0 => int tempoTriggered;
0 => float reverbiness;

240 => int defaultTempo;
defaultTempo => int tempo;

//[0, 4, 7, 11] @=> int major[];
//[0, 3, 7, 10] @=> int minor[];
//[0, 4, 7, 10] @=> int majorDom[];
//[0, 4, 7, 9] @=> int majorSix[];
//[0, 4, 7, 10] @=> int majorNine[];
//[0, 4, 7, 9] @=> int majorSixN[];
//[0, 3, 7, 10] @=> int minorSix[];
//[0, 3, 6, 10] @=> int halfDim[];
//[0, 3, 6, 9] @=> int fullDim[];

fun void sendKeys() {
    for (0 => int j; j < NUM_SLAVES; j++) {
        xmits[j].startMsg("arp/begin, i");
        tap => xmits[j].addInt;

        for (0 => int k; k < NUM_KEYS; k++) {
            if (keys[k]) {
                xmits[j].startMsg("arp/key, i, f");

                k => xmits[j].addInt;
                gains[k] => xmits[j].addFloat;
            }
        }

        xmits[j].startMsg("arp/key, i, f");
        END => xmits[j].addInt;
        0 => xmits[j].addFloat;
    }
}

fun void sendReverb() {
    for (0 => int j; j < NUM_SLAVES; j++) {
        xmits[j].startMsg("arp/begin, i");
        tap => xmits[j].addInt;

        xmits[j].startMsg("arp/key, i, f");

        REVERBINESS => xmits[j].addInt;
        reverbiness => xmits[j].addFloat;
    }
}

fun void sendTempo() {
    for (0 => int j; j < NUM_SLAVES; j++) {
        xmits[j].startMsg("arp/begin, i");
        tap => xmits[j].addInt;

        xmits[j].startMsg("arp/key, i, f");

        TEMPO => xmits[j].addInt;
        0 => xmits[j].addFloat;

        xmits[j].startMsg("arp/key, i, f");
        tempo => xmits[j].addInt;
        0 => xmits[j].addFloat;
    }
}

fun void tempoMaster() {
    // aim the transmitter
    for(int i; i < NUM_SLAVES; i++){
        xmits[i].setHost( slaves[i], port );
    }

    // define message types

    while(true) {
        if (reverbTriggered) {
            sendReverb();
            0 => reverbTriggered;
        } else if (tempoTriggered) {
            sendTempo();
            0 => tempoTriggered;
        } else {
            sendKeys();
        }

        tap++;
        <<< ".", "" >>>;
        tempo :: ms => now;
    }
}

fun void setupListeners() {
    // which keyboard
    1 => int mouseNum;
    0 => int kbNum;
    0 => int midiNum;

    // get from command line
    if( me.args() ) me.arg(0) => Std.atoi => kbNum;

    // open mouse (get device number from command line)
    if( !mouse.openMouse( mouseNum ) ) me.exit();
    <<< "mouse '", mouse.name(), "' ready" >>>;

    // open keyboard
    if( !kb.openKeyboard( kbNum ) ) me.exit();
    // successful! print name of device
    <<< "keyboard '", kb.name(), "' ready" >>>;

    // open midi keyboard
    0 => int midiDevice;
    if (me.args()) me.arg(0) => Std.atoi => midiNum;
    if (!midiKb.open(midiDevice)) me.exit();

    // print out device that was opened
    <<< "MIDI device:", midiKb.num(), " -> ", midiKb.name() >>>;
}

fun void kbHandler() {
    while(true) {
        kb => now;
        while(kb.recv(kmsg)) {
            <<<kmsg.ascii>>>;

            if (kmsg.isButtonDown()) {
                if (kmsg.ascii == 48) {
                    // 0
                } else if (kmsg.ascii == 49) {
                    // 1
                } else if (kmsg.ascii == 50) {
                    // 2
                } else if(kmsg.ascii == 51) {
                    // 3
                } else if (kmsg.ascii == 52) {
                    // 4
                } else if (kmsg.ascii == 53) {
                    // 5
                } else if (kmsg.ascii == 54) {
                    // 6
                } else if (kmsg.ascii == 55) {
                    // 7
                } else if (kmsg.ascii == 56) {
                    // 8
                } else if (kmsg.ascii == 57) {
                    // 9
                } else if (kmsg.ascii == 32) {
                    clearKeys();
                    // space
                } else if (kmsg.ascii == 82) {
                    // R - reverb up
                    1 => reverbTriggered;
                    Math.min(1, reverbiness + .05) => reverbiness;
                } else if (kmsg.ascii == 70) {
                    // F - reverb down
                    1 => reverbTriggered;
                    Math.max(0, reverbiness - .05) => reverbiness;
                } else if (kmsg.ascii == 71) {
                    // G - speed down
                    1 => tempoTriggered;
                    (tempo * 1.1) $ int => tempo;
                } else if (kmsg.ascii == 84) {
                    // T - speed up
                    1 => tempoTriggered;
                    (tempo / 1.1) $ int => tempo;
                }
            }
        }
    }
}

fun void mouseHandler() {
    while(true) {
        mouse => now;
        while(mouse.recv(mmsg)) {
            <<<mmsg.deltaX>>>;
            <<<mmsg.deltaY>>>;

            if (mmsg.deltaX > 0) {
                if(tempo > 10) {
                    tempo / 1.001 $ int => tempo;
                }
            }
            if (mmsg.deltaX < 0) {
                if(tempo < 1000) {
                    tempo * 1.001 $ int => tempo;
                }
            }
            if (mmsg.deltaY > 0) {
                // increase something
            }
            if (mmsg.deltaY < 0) {
                // decrease something
            }
        }
    }
}

fun void clearKeys() {
    for (0 => int i; i < NUM_KEYS; i++) {
        0 => keys[i];
    }
}

fun void midiKbHandler() {
    144 => int MIDI_DOWN;
    128 => int MIDI_UP;

    // infinite time-loop
    while( true )
    {
        // wait on the event
        midiKb => now;

        // get the message(s)
        while(midiKb.recv(midiKbMsg))
        {
            midiKbMsg.data2 => int midiFreq; // get key played

            // get on/off
            if (midiKbMsg.data1 == MIDI_DOWN) {
                1 => keys[midiFreq];
                // get gain
                (midiKbMsg.data3) / 127.0 => gains[midiFreq];
            }
        }
    }
}

setupListeners();
// spork ~ mouseHandler();
spork ~ midiKbHandler();
spork ~ tempoMaster();

kbHandler();

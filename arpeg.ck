fun void arpeg() {
    1 => restart;
    while (restart) {
        for(0 => int i; i < chord.cap(); i++) {
            p.shift(Std.mtof(chord[i]) / 12.0);

            tempo => now;
            if (!restart) {
                p.shift(0);
                return;
            }
        }
        for(0 => int i; i < chord.cap(); i++) {
            p.shift(2 * Std.mtof(chord[i]) / 12.0);

            tempo => now;
            if (!restart) {
                p.shift(0);
                return;
            }
        }
    }
    p.shift(0);
}

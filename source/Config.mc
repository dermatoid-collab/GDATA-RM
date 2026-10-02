import Toybox.Application;
import Toybox.Lang;
import Toybox.UserProfile;

//! User settings, read from Application.Properties (Garmin Connect app / Express).
module Config {
    const MODE_AUTO = 0;
    const MODE_RACE = 1;
    const SLOTS = 8;

    var ftp as Number = 250;
    var cp as Number = 250;
    var wPrime as Number = 20000;
    var weightKg as Float = 0.0;
    var eatMin as Number = 20;
    var drinkMin as Number = 15;
    var wbalAlertPct as Number = 25;
    var mode as Number = MODE_AUTO;
    var smooth as Number = 3;
    var fitRecord as Boolean = true;
    var workoutSlots as Array<Number> = [1, 2, 22, 3, 7, 9, 8, 10];
    var raceSlots as Array<Number> = [1, 2, 3, 12, 7, 13, 14, 17];

    function load() as Void {
        ftp = readNumber("ftp", 250, 50, 700);
        var cpSetting = readNumber("cp", 0, 0, 700);
        cp = cpSetting > 0 ? cpSetting : ftp;
        wPrime = readNumber("wprime", 20000, 3000, 60000);
        eatMin = readNumber("eatMin", 20, 0, 120);
        drinkMin = readNumber("drinkMin", 15, 0, 120);
        wbalAlertPct = readNumber("wbalAlert", 25, 0, 90);
        mode = readNumber("mode", MODE_AUTO, 0, 1);
        smooth = readNumber("smooth", 3, 1, 10);
        fitRecord = readBoolean("fitRecord", true);

        var w = readNumber("weight", 0, 0, 200);
        if (w > 0) {
            weightKg = w.toFloat();
        } else {
            weightKg = profileWeightKg();
        }

        for (var i = 0; i < SLOTS; i++) {
            workoutSlots[i] = readNumber("w" + i, workoutSlots[i], 0, Metrics.M_COUNT - 1);
            raceSlots[i] = readNumber("r" + i, raceSlots[i], 0, Metrics.M_COUNT - 1);
        }
    }

    function profileWeightKg() as Float {
        var profile = UserProfile.getProfile();
        if (profile != null && profile.weight != null && profile.weight > 0) {
            // UserProfile weight is in grams.
            return profile.weight.toFloat() / 1000.0;
        }
        return 0.0;
    }

    function readNumber(key as String, def as Number, lo as Number, hi as Number) as Number {
        var v = null;
        try {
            v = Application.Properties.getValue(key);
        } catch (e) {
            v = null;
        }
        if (v == null) {
            return def;
        }
        var n = def;
        if (v instanceof Lang.Number) {
            n = v;
        } else if (v instanceof Lang.Float || v instanceof Lang.Double || v instanceof Lang.Long) {
            n = v.toNumber();
        } else if (v instanceof Lang.String) {
            var parsed = v.toNumber();
            n = parsed != null ? parsed : def;
        }
        if (n < lo) {
            n = lo;
        }
        if (n > hi) {
            n = hi;
        }
        return n;
    }

    function readBoolean(key as String, def as Boolean) as Boolean {
        try {
            var v = Application.Properties.getValue(key);
            if (v instanceof Lang.Boolean) {
                return v;
            }
        } catch (e) {
        }
        return def;
    }
}

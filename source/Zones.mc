import Toybox.Graphics;
import Toybox.Lang;
import Toybox.UserProfile;

//! Power (Coggan, % FTP) and heart-rate (Garmin user profile) zones and their colours.
module Zones {
    // Upper bound of zones 1..6 in % of FTP; anything above is zone 7.
    const POWER_UPPER = [55, 75, 90, 105, 120, 150];

    // Index = zone number, 0 = no data.
    const COLORS = [
        0x555555, // 0 n/a
        0xAAAAAA, // Z1 recovery
        0x0077FF, // Z2 endurance
        0x00AA44, // Z3 tempo
        0xFFCC00, // Z4 threshold
        0xFF7700, // Z5 VO2max
        0xFF0000, // Z6 anaerobic
        0xAA00FF  // Z7 neuromuscular
    ];

    // Colour cue for workout target compliance.
    const BELOW = 0x0077FF;
    const IN_RANGE = 0x00AA44;
    const ABOVE = 0xFF0000;

    var _hrZones as Array<Number>? = null;

    function reload() as Void {
        _hrZones = null;
        try {
            var z = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_BIKING);
            if (z != null && z.size() >= 6) {
                _hrZones = z;
            }
        } catch (e) {
            _hrZones = null;
        }
    }

    function powerZone(p as Numeric?, ftp as Number) as Number {
        if (p == null || ftp <= 0) {
            return 0;
        }
        var pct = p.toFloat() * 100.0 / ftp;
        for (var i = 0; i < POWER_UPPER.size(); i++) {
            if (pct <= POWER_UPPER[i]) {
                return i + 1;
            }
        }
        return 7;
    }

    //! Garmin layout: [z1 min, z1 max, z2 max, z3 max, z4 max, z5 max].
    function hrZone(hr as Numeric?) as Number {
        if (hr == null || hr <= 0 || _hrZones == null) {
            return 0;
        }
        var z = _hrZones as Array<Number>;
        for (var i = 1; i < 6; i++) {
            if (hr <= z[i]) {
                return i;
            }
        }
        return 5;
    }

    function maxHr() as Number {
        if (_hrZones == null) {
            return 0;
        }
        return (_hrZones as Array<Number>)[5];
    }

    //! HR zones 1..5 mapped onto the power palette (Z5 HR reads as red).
    function hrColor(zone as Number) as Number {
        return zone >= 5 ? COLORS[6] : COLORS[zone];
    }

    function powerColor(zone as Number) as Number {
        return COLORS[zone];
    }

    //! Text colour with enough contrast on the given background.
    function textOn(bg as Number) as Number {
        var r = (bg >> 16) & 0xFF;
        var g = (bg >> 8) & 0xFF;
        var b = bg & 0xFF;
        var luma = (299 * r + 587 * g + 114 * b) / 1000;
        return luma > 140 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
    }
}

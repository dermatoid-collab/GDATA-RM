import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

//! Drawing and formatting helpers shared by the cockpit and the alerts.
module Draw {
    // Largest first. Number fonts only contain digits and ":.-", so they are
    // used only for purely numeric strings.
    const NUMBER_FONTS = [
        Graphics.FONT_NUMBER_THAI_HOT,
        Graphics.FONT_NUMBER_HOT,
        Graphics.FONT_NUMBER_MEDIUM,
        Graphics.FONT_NUMBER_MILD
    ];
    const TEXT_FONTS = [
        Graphics.FONT_LARGE,
        Graphics.FONT_MEDIUM,
        Graphics.FONT_SMALL,
        Graphics.FONT_TINY,
        Graphics.FONT_XTINY
    ];
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    const LEFT = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
    const RIGHT = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;

    var _cache as Dictionary<String, Graphics.FontType> = {};

    function clearCache() as Void {
        _cache = {};
    }

    function isNumeric(s as String) as Boolean {
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (!((c >= '0' && c <= '9') || c == '.' || c == ':' || c == '-')) {
                return false;
            }
        }
        return chars.size() > 0;
    }

    //! Largest font whose rendering of `s` fits in w x h. Cached per box and
    //! string length so a value changing from 99 to 100 may shrink once only.
    function fitFont(dc as Graphics.Dc, s as String, w as Number, h as Number, numeric as Boolean) as Graphics.FontType {
        var key = w + "x" + h + "x" + s.length() + (numeric ? "n" : "t");
        var cached = _cache[key];
        if (cached != null) {
            return cached;
        }
        var font = Graphics.FONT_XTINY;
        var found = false;
        if (numeric) {
            for (var i = 0; i < NUMBER_FONTS.size() && !found; i++) {
                if (fits(dc, NUMBER_FONTS[i], s, w, h, true)) {
                    font = NUMBER_FONTS[i];
                    found = true;
                }
            }
        }
        for (var i = 0; i < TEXT_FONTS.size() && !found; i++) {
            if (fits(dc, TEXT_FONTS[i], s, w, h, false)) {
                font = TEXT_FONTS[i];
                found = true;
            }
        }
        if (_cache.size() > 64) {
            _cache = {};
        }
        _cache[key] = font;
        return font;
    }

    function fits(dc as Graphics.Dc, font as Graphics.FontType, s as String, w as Number, h as Number, numeric as Boolean) as Boolean {
        // Number fonts carry a lot of internal leading: the glyphs use ~75% of
        // the reported height, so allow some overlap with the box.
        var fh = dc.getFontHeight(font);
        var effective = numeric ? fh * 3 / 4 : fh;
        return effective <= h && dc.getTextWidthInPixels(s, font) <= w;
    }

    function value(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, s as String) as Void {
        var font = fitFont(dc, s, w, h, isNumeric(s));
        dc.drawText(x + w / 2, y + h / 2, font, s, CENTER);
    }

    function triangleUp(dc as Graphics.Dc, cx as Number, top as Number, size as Number) as Void {
        dc.fillPolygon([[cx, top], [cx - size, top + size], [cx + size, top + size]]);
    }

    function triangleDown(dc as Graphics.Dc, cx as Number, bottom as Number, size as Number) as Void {
        dc.fillPolygon([[cx, bottom], [cx - size, bottom - size], [cx + size, bottom - size]]);
    }

    // ---- formatting ----

    function duration(seconds as Numeric?) as String {
        if (seconds == null) {
            return "--";
        }
        var s = seconds.toNumber();
        var neg = s < 0;
        if (neg) {
            s = -s;
        }
        var h = s / 3600;
        var m = (s % 3600) / 60;
        var sec = s % 60;
        var out = h > 0
            ? h.format("%d") + ":" + m.format("%02d") + ":" + sec.format("%02d")
            : m.format("%d") + ":" + sec.format("%02d");
        return neg ? "-" + out : out;
    }

    function num(v as Numeric?) as String {
        if (v == null) {
            return "--";
        }
        return (v.toFloat() + (v < 0 ? -0.5 : 0.5)).toNumber().format("%d");
    }

    function dec(v as Numeric?, fmt as String) as String {
        if (v == null) {
            return "--";
        }
        return v.toFloat().format(fmt);
    }

    function isMetric() as Boolean {
        return System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
    }

    function isMetricElevation() as Boolean {
        return System.getDeviceSettings().elevationUnits == System.UNIT_METRIC;
    }

    function speed(mps as Numeric?) as String {
        if (mps == null) {
            return "--";
        }
        return (mps.toFloat() * (isMetric() ? 3.6 : 2.236936)).format("%.1f");
    }

    function speedUnit() as String {
        return isMetric() ? "km/h" : "mph";
    }

    function distance(m as Numeric?) as String {
        if (m == null) {
            return "--";
        }
        var d = m.toFloat() / (isMetric() ? 1000.0 : 1609.344);
        return d < 100 ? d.format("%.1f") : d.toNumber().format("%d");
    }

    function distanceUnit() as String {
        return isMetric() ? "km" : "mi";
    }

    function elevation(m as Numeric?) as String {
        if (m == null) {
            return "--";
        }
        return num(m.toFloat() * (isMetricElevation() ? 1.0 : 3.28084));
    }

    function elevationUnit() as String {
        return isMetricElevation() ? "m" : "ft";
    }

    function clock() as String {
        var t = System.getClockTime();
        var h = t.hour;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return h.format("%d") + ":" + t.min.format("%02d");
    }
}

import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! The master data field. Adapts to the space it gets:
//!  - full screen: header, workout banner, power hero, compliance / W' bar,
//!    2-column grid of configurable tiles and fuelling footer;
//!  - half screen: (banner) + hero + bar + 2 tiles;
//!  - small field: power hero with bar only.
//! "Workout" layout is used when a structured workout is running (mode Auto),
//! otherwise the "race" layout.
class CockpitView extends WatchUi.DataField {
    hidden var _engine as Engine;
    hidden var _workout as WorkoutTracker;
    hidden var _fit as FitRecorder;
    hidden var _info as Activity.Info? = null;
    hidden var _labels as Array<String>;
    hidden var _str as Dictionary<Symbol, String> = {};
    hidden var _lastWPrime as Number;
    hidden var _lastAlertS as Float = -100.0;

    hidden var _bg as Number = Graphics.COLOR_WHITE;
    hidden var _fg as Number = Graphics.COLOR_BLACK;
    hidden var _dim as Number = Graphics.COLOR_DK_GRAY;
    hidden var _track as Number = 0xCCCCCC;

    function initialize() {
        DataField.initialize();
        Zones.reload();
        _engine = new Engine();
        _workout = new WorkoutTracker();
        _fit = new FitRecorder(self);
        _labels = Labels.load();
        _lastWPrime = Config.wPrime;
        var ids = {
            :power => Rez.Strings.Power,
            :eat => Rez.Strings.Eat,
            :drink => Rez.Strings.Drink,
            :alertEat => Rez.Strings.AlertEat,
            :alertDrink => Rez.Strings.AlertDrink,
            :alertWbal => Rez.Strings.AlertWbal,
            :alertFeed => Rez.Strings.AlertFeed,
            :alertWbalSub => Rez.Strings.AlertWbalSub,
            :next => Rez.Strings.Next,
            :open => Rez.Strings.Open,
            :end => Rez.Strings.End,
            :int0 => Rez.Strings.IntActive,
            :int1 => Rez.Strings.IntRest,
            :int2 => Rez.Strings.IntWarmup,
            :int3 => Rez.Strings.IntCooldown,
            :int4 => Rez.Strings.IntRecovery,
            :int5 => Rez.Strings.IntInterval
        };
        var keys = ids.keys();
        for (var i = 0; i < keys.size(); i++) {
            _str[keys[i]] = WatchUi.loadResource(ids[keys[i]]) as String;
        }
    }

    function onSettingsChanged() as Void {
        Zones.reload();
        Draw.clearCache();
        _engine.onSettingsChanged(_lastWPrime);
        _lastWPrime = Config.wPrime;
    }

    // ------------------------------------------------------------------
    // Data
    // ------------------------------------------------------------------

    function compute(info as Activity.Info) {
        _info = info;
        _engine.update(info);
        if (_workout.update(info, _engine.timerMs)) {
            _engine.resetStep();
        }
        _fit.update(_engine);
        showPendingAlert();
        return null;
    }

    function onTimerLap() as Void {
        _engine.resetLap();
    }

    function onTimerReset() as Void {
        _engine.reset();
        _workout.reset();
        _lastAlertS = -100.0;
    }

    function onWorkoutStepComplete() as Void {
        _workout.markStepComplete();
    }

    hidden function workoutMode() as Boolean {
        return Config.mode == Config.MODE_AUTO && _workout.active;
    }

    hidden function showPendingAlert() as Void {
        if (!(self has :showAlert)) {
            _engine.alerts = [];
            return;
        }
        // One pop-up at a time; queued reminders wait a few seconds.
        if (_engine.alerts.size() == 0 || _engine.timerS - _lastAlertS < 8.0) {
            return;
        }
        var a = _engine.popAlert();
        var alert = null;
        if (a == Metrics.ALERT_EAT) {
            alert = new CockpitAlert(_str[:alertEat],
                _str[:alertFeed] + " #" + _engine.feeds + "  -  CHO " + Draw.num(_engine.cho) + " g",
                0xFF7700);
        } else if (a == Metrics.ALERT_DRINK) {
            alert = new CockpitAlert(_str[:alertDrink], "", 0x0077FF);
        } else if (a == Metrics.ALERT_WBAL) {
            alert = new CockpitAlert(_str[:alertWbal], _str[:alertWbalSub], 0xFF0000);
        }
        if (alert != null) {
            _lastAlertS = _engine.timerS;
            try {
                showAlert(alert);
            } catch (e) {
                // Another alert is on screen: drop this one rather than crash.
            }
        }
    }

    // ------------------------------------------------------------------
    // Layout
    // ------------------------------------------------------------------

    function onUpdate(dc as Graphics.Dc) as Void {
        if (_info == null) {
            _info = Activity.getActivityInfo();
        }
        _bg = getBackgroundColor();
        var dark = _bg == Graphics.COLOR_BLACK;
        _fg = dark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        _dim = dark ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
        _track = dark ? 0x333333 : 0xCCCCCC;
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(_fg, _bg);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var screenH = System.getDeviceSettings().screenHeight;
        if (h >= screenH * 7 / 10) {
            drawFull(dc, w, h);
        } else if (h >= screenH * 35 / 100) {
            drawMedium(dc, w, h);
        } else {
            drawCompact(dc, w, h);
        }
    }

    hidden function drawFull(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var xtiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var y = 0;
        var headerH = max(xtiny + 2, h * 6 / 100);
        drawHeader(dc, 0, y, w, headerH);
        y += headerH;

        var workout = workoutMode();
        if (workout) {
            var bh = h * 14 / 100;
            drawBanner(dc, 0, y, w, bh);
            y += bh;
        }
        var heroH = h * 22 / 100;
        drawHero(dc, 0, y, w, heroH, false);
        y += heroH;
        var barH = max(8, h * 4 / 100);
        drawBar(dc, 0, y, w, barH);
        y += barH;

        var footerH = max(xtiny + 4, h * 7 / 100);
        var gridH = h - y - footerH;
        var rows = gridH / 50;
        rows = rows < 2 ? 2 : (rows > 4 ? 4 : rows);
        drawGrid(dc, 0, y, w, gridH, rows, workout ? Config.workoutSlots : Config.raceSlots);
        drawFooter(dc, 0, h - footerH, w, footerH);
    }

    hidden function drawMedium(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var y = 0;
        var barH = max(6, h * 6 / 100);
        if (workoutMode()) {
            var bh = h * 30 / 100;
            drawBanner(dc, 0, y, w, bh);
            y += bh;
            var heroH = h - y - barH;
            drawHero(dc, 0, y, w, heroH, false);
            drawBar(dc, 0, y + heroH, w, barH);
            return;
        }
        var heroH = h * 58 / 100;
        drawHero(dc, 0, y, w, heroH, false);
        y += heroH;
        drawBar(dc, 0, y, w, barH);
        y += barH;
        drawGrid(dc, 0, y, w, h - y, 1, Config.raceSlots);
    }

    hidden function drawCompact(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var barH = max(4, h * 12 / 100);
        drawHero(dc, 0, 0, w, h - barH, true);
        drawBar(dc, 0, h - barH, w, barH);
    }

    // ------------------------------------------------------------------
    // Sections
    // ------------------------------------------------------------------

    hidden function drawHeader(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number) as Void {
        var cy = y + h / 2;
        var font = Graphics.FONT_XTINY;
        dc.setColor(_dim, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 4, cy, font, Draw.clock(), Draw.LEFT);
        var battery = System.getSystemStats().battery;
        dc.setColor(battery < 15 ? 0xFF0000 : _dim, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w - 4, cy, font, battery.toNumber().format("%d") + "%", Draw.RIGHT);
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, cy, font, Draw.duration(_engine.timerS), Draw.CENTER);
        dc.setColor(_track, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y + h - 1, x + w, y + h - 1);
    }

    //! Workout step: intensity strip, name, time/distance left, target, next step.
    hidden function drawBanner(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number) as Void {
        var wk = _workout;
        var strip = intensityColor(wk.intensity);
        dc.setColor(strip, strip);
        dc.fillRectangle(x, y, 6, h);

        var topH = h * 35 / 100;
        var font = Graphics.FONT_XTINY;
        var next = _str[:end];
        if (wk.hasNext) {
            next = _str[:next] + " " + durationText(wk.nextDurationType, wk.nextDuration);
            var tgt = targetText(wk.nextTargetType, wk.nextLow, wk.nextHigh);
            next += " " + (tgt.length() > 0 ? tgt + targetUnit(wk.nextTargetType) : intensityName(wk.nextIntensity));
        }
        var title = "#" + wk.stepNumber + " " + intensityName(wk.intensity);
        // Drop the step name when it would run into the next-step preview.
        if (wk.name.length() > 0) {
            var full = title + " " + wk.name;
            if (dc.getTextWidthInPixels(full, font) + dc.getTextWidthInPixels(next, font) + 8 <= w - 14) {
                title = full;
            }
        }
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 10, y + topH / 2, font, title, Draw.LEFT);
        dc.setColor(_dim, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w - 4, y + topH / 2, font, next, Draw.RIGHT);

        var by = y + topH;
        var bh = h - topH;
        var leftW = (w - 10) * 55 / 100;
        var left = "";
        if (wk.remaining == null) {
            left = "+" + Draw.duration(wk.elapsedS(_engine.timerMs));
        } else if (wk.durationType == WorkoutTracker.DURATION_DISTANCE) {
            left = Draw.distance(wk.remaining);
        } else {
            left = Draw.duration(wk.remaining);
        }
        // Last 10 s of a timed step: highlight the countdown.
        var ending = wk.remaining != null && wk.durationType == WorkoutTracker.DURATION_TIME
            && wk.remaining <= 10;
        dc.setColor(ending ? 0xFF7700 : _fg, Graphics.COLOR_TRANSPARENT);
        Draw.value(dc, x + 10, by, leftW, bh, left);

        var right = targetText(wk.targetType, wk.low, wk.high);
        if (right.length() == 0) {
            right = _str[:open];
        }
        var rx = x + 10 + leftW;
        var rw = w - rx - 4;
        var unitH = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(_dim, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w - 4, by + unitH / 2, Graphics.FONT_XTINY, targetUnit(wk.targetType), Draw.RIGHT);
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        Draw.value(dc, rx, by + unitH / 2, rw, bh - unitH / 2, right);

        dc.setColor(_track, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y + h - 1, x + w, y + h - 1);
    }

    //! Big power number on a zone-coloured background (or target-compliance
    //! colour when the workout step has a power target).
    hidden function drawHero(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, compact as Boolean) as Void {
        var p = _engine.powerSmooth;
        var zone = Zones.powerZone(p, Config.ftp);
        var color = Zones.powerColor(zone);
        var wk = _workout;
        var workout = workoutMode();
        if (workout && wk.hasTarget() && wk.targetType == WorkoutTracker.TARGET_POWER && p != null) {
            color = complianceColor(p, wk.low, wk.high);
        }
        var fg = Zones.textOn(color);
        dc.setColor(color, color);
        dc.fillRectangle(x, y, w, h);

        var labelH = dc.getFontHeight(Graphics.FONT_XTINY);
        var label = _str[:power] + " " + Config.smooth + "s" + (zone > 0 ? " Z" + zone : "");
        var right = "";
        if (compact && workout) {
            right = wk.remaining != null ? Draw.duration(wk.remaining) : "";
            var tgt = targetText(wk.targetType, wk.low, wk.high);
            if (tgt.length() > 0) {
                right += "  " + tgt + targetUnit(wk.targetType);
            }
        } else {
            var wkg = _engine.wkg();
            right = wkg != null ? Draw.dec(wkg, "%.1f") + " W/kg" : "";
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 4, y + labelH / 2 + 1, Graphics.FONT_XTINY, label, Draw.LEFT);
        dc.drawText(x + w - 4, y + labelH / 2 + 1, Graphics.FONT_XTINY, right, Draw.RIGHT);
        Draw.value(dc, x + 4, y + labelH, w - 8, h - labelH, p != null ? Draw.num(p) : "--");
    }

    //! Target compliance (workout with target) or W' balance gauge.
    hidden function drawBar(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number) as Void {
        dc.setColor(_track, _track);
        dc.fillRectangle(x, y, w, h);
        var wk = _workout;
        if (workoutMode() && wk.hasTarget()) {
            var v = targetMetric(wk.targetType);
            var span = wk.high - wk.low;
            if (span <= 0) {
                span = wk.high * 0.1 + 1;
            }
            var lo = wk.low - span;
            var hi = wk.high + span;
            var x0 = x + ((wk.low - lo) / (hi - lo) * w).toNumber();
            var x1 = x + ((wk.high - lo) / (hi - lo) * w).toNumber();
            dc.setColor(Zones.IN_RANGE, Zones.IN_RANGE);
            dc.fillRectangle(x0, y, x1 - x0, h);
            if (v != null) {
                var fv = v.toFloat();
                var pos = (fv - lo) / (hi - lo);
                pos = pos < 0.0 ? 0.0 : (pos > 1.0 ? 1.0 : pos);
                var mx = x + (pos * (w - 1)).toNumber();
                var cc = complianceColor(fv, wk.low, wk.high);
                dc.setColor(cc == Zones.IN_RANGE ? _fg : cc, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(mx - 2, y, 5, h);
            }
            return;
        }
        var pct = _engine.wbalPct();
        var color = pct > 60 ? Zones.IN_RANGE : (pct > 30 ? 0xFFCC00 : 0xFF0000);
        dc.setColor(color, color);
        dc.fillRectangle(x, y, w * (pct > 100 ? 100 : pct) / 100, h);
    }

    hidden function drawGrid(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, rows as Number, slots as Array<Number>) as Void {
        var colW = w / 2;
        var rowH = h / rows;
        for (var r = 0; r < rows; r++) {
            for (var c = 0; c < 2; c++) {
                drawTile(dc, x + c * colW, y + r * rowH, colW, rowH, slots[r * 2 + c]);
            }
        }
        dc.setColor(_track, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + colW, y + 2, x + colW, y + h - 2);
        for (var r = 1; r < rows; r++) {
            dc.drawLine(x, y + r * rowH, x + w, y + r * rowH);
        }
    }

    hidden function drawTile(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, id as Number) as Void {
        if (id == Metrics.M_NONE) {
            return;
        }
        var m = metric(id);
        var labelH = dc.getFontHeight(Graphics.FONT_XTINY);
        if (m[3] >= 0) {
            dc.setColor(m[3], m[3]);
            dc.fillRectangle(x + 1, y + 3, 4, h - 6);
        }
        dc.setColor(_dim, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 8, y + labelH / 2 + 1, Graphics.FONT_XTINY, m[0], Draw.LEFT);
        dc.drawText(x + w - 4, y + labelH / 2 + 1, Graphics.FONT_XTINY, m[2], Draw.RIGHT);
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        Draw.value(dc, x + 8, y + labelH, w - 12, h - labelH - 2, m[1]);
    }

    //! Fuel countdowns and carbohydrate estimate.
    hidden function drawFooter(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number) as Void {
        dc.setColor(_track, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y, x + w, y);
        var cellW = w / 3;
        var eat = _engine.eatIn();
        var drink = _engine.drinkIn();
        drawFooterCell(dc, x, y, cellW, h, _str[:eat] + " " + (eat != null ? Draw.duration(eat) : "--"),
            eat != null && eat < 60 ? 0xFF7700 : -1);
        drawFooterCell(dc, x + cellW, y, cellW, h, _str[:drink] + " " + (drink != null ? Draw.duration(drink) : "--"),
            drink != null && drink < 60 ? 0x0077FF : -1);
        drawFooterCell(dc, x + 2 * cellW, y, w - 2 * cellW, h, "CHO " + Draw.num(_engine.cho) + "g", -1);
    }

    hidden function drawFooterCell(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, text as String, highlight as Number) as Void {
        var fg = _fg;
        if (highlight >= 0) {
            dc.setColor(highlight, highlight);
            dc.fillRectangle(x + 1, y + 2, w - 2, h - 3);
            fg = Zones.textOn(highlight);
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        var font = Draw.fitFont(dc, text, w - 4, h - 2, false);
        dc.drawText(x + w / 2, y + h / 2 + 1, font, text, Draw.CENTER);
    }

    // ------------------------------------------------------------------
    // Metrics for tiles: [label, value, unit, accent colour or -1]
    // ------------------------------------------------------------------

    hidden function metric(id as Number) as Array {
        var e = _engine;
        var info = _info;
        var label = id < _labels.size() ? _labels[id] : "";
        switch (id) {
            case Metrics.M_HR: {
                var z = Zones.hrZone(e.hr);
                return [z > 0 ? label + " Z" + z : label, Draw.num(e.hr), "bpm", z > 0 ? Zones.hrColor(z) : -1];
            }
            case Metrics.M_CADENCE:
                return [label, Draw.num(e.cadence), "rpm", -1];
            case Metrics.M_SPEED:
                return [label, Draw.speed(e.speed), Draw.speedUnit(), -1];
            case Metrics.M_AVG_SPEED:
                return [label, Draw.speed(info != null ? info.averageSpeed : null), Draw.speedUnit(), -1];
            case Metrics.M_LAP_POWER:
                return powerMetric(label, e.lapS > 0 ? e.lapPower : null);
            case Metrics.M_AVG_POWER:
                return powerMetric(label, e.timerS > 0 ? e.avgPower : null);
            case Metrics.M_NP:
                return powerMetric(label, e.timerS > 0 ? e.np : null);
            case Metrics.M_IF:
                return [label, Draw.dec(e.intensity, "%.2f"), "", -1];
            case Metrics.M_TSS:
                return [label, Draw.num(e.tss), "", -1];
            case Metrics.M_KJ:
                return [label, Draw.num(e.kj), "kJ", -1];
            case Metrics.M_WKG:
                return [label, Draw.dec(e.wkg(), "%.1f"), "W/kg", -1];
            case Metrics.M_GRADE:
                return [label, Draw.dec(e.grade, "%.1f"), "%", gradeColor(e.grade)];
            case Metrics.M_VAM:
                return [label, Draw.num(e.vam), "m/h", -1];
            case Metrics.M_ASCENT:
                return [label, Draw.elevation(info != null ? info.totalAscent : null), Draw.elevationUnit(), -1];
            case Metrics.M_ALTITUDE:
                return [label, Draw.elevation(info != null ? info.altitude : null), Draw.elevationUnit(), -1];
            case Metrics.M_DISTANCE:
                return [label, Draw.distance(info != null ? info.elapsedDistance : null), Draw.distanceUnit(), -1];
            case Metrics.M_TO_DEST:
                return [label, Draw.distance(info != null ? info.distanceToDestination : null), Draw.distanceUnit(), -1];
            case Metrics.M_TIMER:
                return [label, Draw.duration(e.timerS), "", -1];
            case Metrics.M_LAP_TIME:
                return [label, Draw.duration(e.lapS), "", -1];
            case Metrics.M_WBAL: {
                var pct = e.wbalPct();
                return [label, pct.format("%d"), "%", pct > 60 ? Zones.IN_RANGE : (pct > 30 ? 0xFFCC00 : 0xFF0000)];
            }
            case Metrics.M_CHO:
                return [label, Draw.num(e.cho), "g", -1];
            case Metrics.M_STEP_POWER:
                return _workout.active ? powerMetric(label, e.stepS > 0 ? e.stepPower : null)
                    : powerMetric(_labels[Metrics.M_LAP_POWER], e.lapS > 0 ? e.lapPower : null);
            case Metrics.M_POWER_30S:
                return powerMetric(label, e.power30);
            case Metrics.M_HR_PCT: {
                var hrMax = Zones.maxHr();
                var v = (e.hr != null && hrMax > 0) ? (e.hr as Number) * 100.0 / hrMax : null;
                return [label, Draw.num(v), "%", -1];
            }
            case Metrics.M_KCAL:
                return [label, Draw.num(info != null ? info.calories : null), "kcal", -1];
        }
        return ["", "", "", -1];
    }

    hidden function powerMetric(label as String, p as Numeric?) as Array {
        var z = Zones.powerZone(p, Config.ftp);
        return [label, Draw.num(p), "W", z > 0 ? Zones.powerColor(z) : -1];
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    //! Live value compared against the step target (power uses the smoothed value).
    hidden function targetMetric(type as Number) as Numeric? {
        if (type == WorkoutTracker.TARGET_POWER) {
            return _engine.powerSmooth;
        } else if (type == WorkoutTracker.TARGET_HR) {
            return _engine.hr;
        } else if (type == WorkoutTracker.TARGET_CADENCE) {
            return _engine.cadence;
        } else if (type == WorkoutTracker.TARGET_SPEED) {
            return _engine.speed;
        }
        return null;
    }

    hidden function complianceColor(v as Numeric, lo as Float, hi as Float) as Number {
        if (v < lo) {
            return Zones.BELOW;
        }
        if (v > hi) {
            return Zones.ABOVE;
        }
        return Zones.IN_RANGE;
    }

    hidden function targetText(type as Number, lo as Float, hi as Float) as String {
        if (type == WorkoutTracker.TARGET_OPEN || hi <= 0) {
            return "";
        }
        if (type == WorkoutTracker.TARGET_SPEED) {
            return Draw.speed(lo) + "-" + Draw.speed(hi);
        }
        return Draw.num(lo) + "-" + Draw.num(hi);
    }

    hidden function targetUnit(type as Number) as String {
        if (type == WorkoutTracker.TARGET_POWER) {
            return "W";
        } else if (type == WorkoutTracker.TARGET_HR) {
            return "bpm";
        } else if (type == WorkoutTracker.TARGET_CADENCE) {
            return "rpm";
        } else if (type == WorkoutTracker.TARGET_SPEED) {
            return Draw.speedUnit();
        }
        return "";
    }

    hidden function durationText(type as Number, value as Float) as String {
        if (value <= 0) {
            return "";
        }
        if (type == WorkoutTracker.DURATION_TIME) {
            return Draw.duration(value);
        } else if (type == WorkoutTracker.DURATION_DISTANCE) {
            return Draw.distance(value) + Draw.distanceUnit();
        }
        return "";
    }

    hidden function intensityName(intensity as Number) as String {
        var keys = [:int0, :int1, :int2, :int3, :int4, :int5];
        if (intensity >= 0 && intensity < keys.size()) {
            return _str[keys[intensity]];
        }
        return "";
    }

    hidden function intensityColor(intensity as Number) as Number {
        // active, rest, warm-up, cool-down, recovery, interval
        var colors = [0xFF7700, 0x0077FF, 0xAAAAAA, 0xAAAAAA, 0x00AA44, 0xFF0000];
        if (intensity >= 0 && intensity < colors.size()) {
            return colors[intensity];
        }
        return _dim;
    }

    hidden function gradeColor(g as Float) as Number {
        if (g >= 10) {
            return 0xAA00FF;
        } else if (g >= 7) {
            return 0xFF0000;
        } else if (g >= 4) {
            return 0xFF7700;
        } else if (g >= 2) {
            return 0xFFCC00;
        } else if (g <= -2) {
            return 0x0077FF;
        }
        return -1;
    }

    hidden function max(a as Number, b as Number) as Number {
        return a > b ? a : b;
    }
}

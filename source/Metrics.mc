import Toybox.Activity;
import Toybox.Lang;
import Toybox.Math;

//! Metric ids used by the configurable tiles. Keep in sync with tools/gen_resources.py.
module Metrics {
    const M_NONE = 0;
    const M_HR = 1;
    const M_CADENCE = 2;
    const M_SPEED = 3;
    const M_AVG_SPEED = 4;
    const M_LAP_POWER = 5;
    const M_AVG_POWER = 6;
    const M_NP = 7;
    const M_IF = 8;
    const M_TSS = 9;
    const M_KJ = 10;
    const M_WKG = 11;
    const M_GRADE = 12;
    const M_VAM = 13;
    const M_ASCENT = 14;
    const M_ALTITUDE = 15;
    const M_DISTANCE = 16;
    const M_TO_DEST = 17;
    const M_TIMER = 18;
    const M_LAP_TIME = 19;
    const M_WBAL = 20;
    const M_CHO = 21;
    const M_STEP_POWER = 22;
    const M_POWER_30S = 23;
    const M_HR_PCT = 24;
    const M_KCAL = 25;
    const M_COUNT = 26;

    const ALERT_EAT = 1;
    const ALERT_DRINK = 2;
    const ALERT_WBAL = 3;
}

//! Derived cycling metrics, updated once per second from Activity.Info.
//! Everything that accumulates only advances while the activity timer runs,
//! so auto-pause and stops do not dilute NP, TSS or W' balance.
class Engine {
    const RING = 30;   // seconds of power history (NP window)
    const ALT_RING = 60;

    // Raw sensor values (null = no sensor)
    var power as Number? = null;
    var hr as Number? = null;
    var cadence as Number? = null;
    var speed as Float? = null;       // m/s

    // Power
    var powerSmooth as Number? = null;
    var power30 as Number? = null;
    var avgPower as Float = 0.0;
    var np as Float = 0.0;
    var intensity as Float = 0.0;     // IF
    var tss as Float = 0.0;
    var kj as Float = 0.0;
    var lapPower as Float = 0.0;
    var stepPower as Float = 0.0;

    // Time (seconds of timer)
    var timerS as Float = 0.0;
    var timerMs as Number = 0;
    var lapS as Float = 0.0;
    var stepS as Float = 0.0;
    var running as Boolean = false;

    // W' balance (J)
    var wbal as Float = 20000.0;
    var wbalMin as Float = 20000.0;

    // Terrain
    var grade as Float = 0.0;         // %
    var vam as Float = 0.0;           // m/h

    // Fuelling
    var cho as Float = 0.0;           // grams of carbohydrate burnt (estimate)
    var nextEatS as Float = 0.0;
    var nextDrinkS as Float = 0.0;
    var feeds as Number = 0;
    var alerts as Array<Number> = [];

    hidden var _ring as Array<Number>;
    hidden var _ringIdx as Number = 0;
    hidden var _ringCount as Number = 0;
    hidden var _ring30Sum as Number = 0;
    hidden var _np4Sum as Double = 0.0d;
    hidden var _np4N as Number = 0;
    hidden var _workJ as Double = 0.0d;
    hidden var _lapJ as Float = 0.0;
    hidden var _stepJ as Float = 0.0;
    hidden var _lastTimerMs as Number = -1;

    hidden var _alt as Array<Float>;
    hidden var _dist as Array<Float>;
    hidden var _altIdx as Number = 0;
    hidden var _altCount as Number = 0;

    hidden var _wbalArmed as Boolean = true;

    function initialize() {
        _ring = new Array<Number>[RING];
        _alt = new Array<Float>[ALT_RING];
        _dist = new Array<Float>[ALT_RING];
        reset();
    }

    function reset() as Void {
        for (var i = 0; i < RING; i++) {
            _ring[i] = 0;
        }
        for (var i = 0; i < ALT_RING; i++) {
            _alt[i] = 0.0;
            _dist[i] = 0.0;
        }
        _ringIdx = 0;
        _ringCount = 0;
        _ring30Sum = 0;
        _np4Sum = 0.0d;
        _np4N = 0;
        _workJ = 0.0d;
        _lastTimerMs = -1;
        _altIdx = 0;
        _altCount = 0;
        avgPower = 0.0;
        np = 0.0;
        intensity = 0.0;
        tss = 0.0;
        kj = 0.0;
        timerS = 0.0;
        timerMs = 0;
        grade = 0.0;
        vam = 0.0;
        cho = 0.0;
        feeds = 0;
        alerts = [];
        wbal = Config.wPrime.toFloat();
        wbalMin = wbal;
        _wbalArmed = true;
        resetLap();
        resetStep();
        rearmFuel();
    }

    function resetLap() as Void {
        _lapJ = 0.0;
        lapS = 0.0;
        lapPower = 0.0;
    }

    function resetStep() as Void {
        _stepJ = 0.0;
        stepS = 0.0;
        stepPower = 0.0;
    }

    //! Schedule the next fuel reminders relative to the current timer.
    function rearmFuel() as Void {
        nextEatS = Config.eatMin > 0 ? timerS + Config.eatMin * 60 : -1.0;
        nextDrinkS = Config.drinkMin > 0 ? timerS + Config.drinkMin * 60 : -1.0;
    }

    //! Settings changed mid-ride: keep W' balance proportional, re-plan reminders.
    function onSettingsChanged(oldWPrime as Number) as Void {
        if (oldWPrime > 0) {
            wbal = wbal * Config.wPrime / oldWPrime;
            wbalMin = wbalMin * Config.wPrime / oldWPrime;
        }
        rearmFuel();
    }

    function update(info as Activity.Info) as Void {
        power = info.currentPower;
        hr = info.currentHeartRate;
        cadence = info.currentCadence;
        speed = info.currentSpeed;

        var tms = 0;
        if (info.timerTime != null) {
            tms = info.timerTime as Number;
        }
        var dt = 0.0;
        if (_lastTimerMs >= 0 && tms > _lastTimerMs) {
            dt = (tms - _lastTimerMs) / 1000.0;
            if (dt > 5.0) {
                // Missed updates (e.g. app restart): count it as a single second.
                dt = 1.0;
            }
        }
        _lastTimerMs = tms;
        timerMs = tms;
        running = dt > 0.0;

        var p = 0;
        if (power != null) {
            p = power as Number;
        }
        if (running) {
            accumulatePower(p, dt);
            accumulateTerrain(info);
            checkFuel();
        }
        smoothPower();
        updateWbalAlert();
    }

    hidden function accumulatePower(p as Number, dt as Float) as Void {
        // 1 Hz ring buffer of the last 30 s
        _ring30Sum += p - _ring[_ringIdx];
        _ring[_ringIdx] = p;
        _ringIdx = (_ringIdx + 1) % RING;
        if (_ringCount < RING) {
            _ringCount++;
        }

        timerS += dt;
        lapS += dt;
        stepS += dt;
        var joules = p * dt;
        _workJ += joules;
        _lapJ += joules;
        _stepJ += joules;
        kj = (_workJ / 1000.0d).toFloat();
        avgPower = timerS > 0 ? (_workJ / timerS).toFloat() : 0.0;
        lapPower = lapS > 0 ? _lapJ / lapS : 0.0;
        stepPower = stepS > 0 ? _stepJ / stepS : 0.0;

        // Normalized Power: 4th-power mean of the 30 s rolling average
        if (_ringCount >= RING) {
            var m = _ring30Sum.toDouble() / RING;
            _np4Sum += m * m * m * m;
            _np4N++;
            np = Math.pow(_np4Sum / _np4N, 0.25).toFloat();
        } else {
            np = avgPower;
        }
        var ftp = Config.ftp;
        intensity = np / ftp;
        tss = timerS * np * intensity / (ftp * 3600.0) * 100.0;

        // W' balance, differential model (Froncioni, Skiba & Clarke)
        var cp = Config.cp;
        var wp = Config.wPrime.toFloat();
        if (p > cp) {
            wbal -= (p - cp) * dt;
        } else {
            wbal += (wp - wbal) * (cp - p) * dt / wp;
        }
        if (wbal > wp) {
            wbal = wp;
        }
        if (wbal < wbalMin) {
            wbalMin = wbal;
        }

        // Carbohydrate oxidation: mechanical kJ ~ metabolic kcal (gross efficiency
        // ~24% cancels 4.184 kJ/kcal); CHO share grows with intensity.
        if (p > 0) {
            var x = p.toFloat() / ftp;
            var share = 0.45 + (x - 0.5) * 0.9;
            share = share < 0.3 ? 0.3 : (share > 1.0 ? 1.0 : share);
            cho += (joules / 1000.0) * share / 4.0;
        }
    }

    hidden function smoothPower() as Void {
        if (!running || _ringCount == 0) {
            powerSmooth = power;
            power30 = power;
            return;
        }
        powerSmooth = ringAverage(Config.smooth);
        power30 = ringAverage(RING);
    }

    hidden function ringAverage(n as Number) as Number {
        if (n > _ringCount) {
            n = _ringCount;
        }
        if (n <= 0) {
            return 0;
        }
        if (n == RING) {
            return (_ring30Sum.toFloat() / RING + 0.5).toNumber();
        }
        var sum = 0;
        var idx = _ringIdx;
        for (var i = 0; i < n; i++) {
            idx = (idx - 1 + RING) % RING;
            sum += _ring[idx];
        }
        return (sum.toFloat() / n + 0.5).toNumber();
    }

    hidden function accumulateTerrain(info as Activity.Info) as Void {
        var alt = info.altitude;
        var dist = info.elapsedDistance;
        if (alt == null || dist == null) {
            return;
        }
        _alt[_altIdx] = alt.toFloat();
        _dist[_altIdx] = dist.toFloat();
        var cur = _altIdx;
        _altIdx = (_altIdx + 1) % ALT_RING;
        if (_altCount < ALT_RING) {
            _altCount++;
        }
        if (_altCount < 2) {
            return;
        }

        // Grade: look back until we have covered at least 25 m (max 20 s).
        var maxBack = _altCount - 1 < 20 ? _altCount - 1 : 20;
        for (var k = 1; k <= maxBack; k++) {
            var j = (cur - k + ALT_RING) % ALT_RING;
            var dd = _dist[cur] - _dist[j];
            if (dd >= 25.0 || (k == maxBack && dd >= 8.0)) {
                var g = (_alt[cur] - _alt[j]) / dd * 100.0;
                if (g > 30.0) {
                    g = 30.0;
                } else if (g < -30.0) {
                    g = -30.0;
                }
                grade = grade * 0.5 + g * 0.5;
                break;
            }
        }

        // VAM over the buffered window (up to 60 s of riding)
        var oldest = (cur - (_altCount - 1) + ALT_RING) % ALT_RING;
        var climb = _alt[cur] - _alt[oldest];
        vam = climb > 0 ? climb * 3600.0 / (_altCount - 1) : 0.0;
    }

    hidden function checkFuel() as Void {
        if (nextEatS > 0 && timerS >= nextEatS) {
            feeds++;
            alerts.add(Metrics.ALERT_EAT);
            nextEatS += Config.eatMin * 60;
        }
        if (nextDrinkS > 0 && timerS >= nextDrinkS) {
            alerts.add(Metrics.ALERT_DRINK);
            nextDrinkS += Config.drinkMin * 60;
        }
    }

    hidden function updateWbalAlert() as Void {
        if (Config.wbalAlertPct <= 0) {
            return;
        }
        var pct = wbalPct();
        if (_wbalArmed && pct < Config.wbalAlertPct) {
            _wbalArmed = false;
            alerts.add(Metrics.ALERT_WBAL);
        } else if (!_wbalArmed && pct > Config.wbalAlertPct + 20) {
            _wbalArmed = true;
        }
    }

    function wbalPct() as Number {
        var wp = Config.wPrime;
        if (wp <= 0) {
            return 100;
        }
        var pct = (wbal * 100.0 / wp).toNumber();
        return pct < 0 ? 0 : pct;
    }

    function wkg() as Float? {
        if (powerSmooth == null || Config.weightKg <= 0) {
            return null;
        }
        return (powerSmooth as Number).toFloat() / Config.weightKg;
    }

    //! Seconds until the next reminder, or null when disabled.
    function eatIn() as Number? {
        return nextEatS > 0 ? (nextEatS - timerS).toNumber() : null;
    }

    function drinkIn() as Number? {
        return nextDrinkS > 0 ? (nextDrinkS - timerS).toNumber() : null;
    }

    function popAlert() as Number? {
        if (alerts.size() == 0) {
            return null;
        }
        var a = alerts[0];
        alerts = alerts.slice(1, null);
        return a;
    }
}

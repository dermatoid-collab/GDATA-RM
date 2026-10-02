import Toybox.Activity;
import Toybox.Lang;

//! Follows the structured workout loaded on the Edge: current step, target
//! range, time/distance left and a preview of the next step.
class WorkoutTracker {
    // FIT wkt_step_target / wkt_step_duration / intensity values, as exposed
    // by Activity.WorkoutStep (numeric to stay independent of SDK symbol names).
    static const TARGET_SPEED = 0;
    static const TARGET_HR = 1;
    static const TARGET_OPEN = 2;
    static const TARGET_CADENCE = 3;
    static const TARGET_POWER = 4;
    static const DURATION_TIME = 0;
    static const DURATION_DISTANCE = 1;
    static const INTENSITY_REST = 1;
    static const INTENSITY_RECOVERY = 4;

    var active as Boolean = false;
    var stepNumber as Number = 0;
    var name as String = "";
    var intensity as Number = 0;
    var targetType as Number = TARGET_OPEN;
    var low as Float = 0.0;         // decoded: W, bpm, rpm or m/s
    var high as Float = 0.0;
    var durationType as Number = -1;
    var remaining as Float? = null; // s or m, null for open-ended steps
    var hasNext as Boolean = false;
    var nextName as String = "";
    var nextIntensity as Number = 0;
    var nextTargetType as Number = TARGET_OPEN;
    var nextLow as Float = 0.0;
    var nextHigh as Float = 0.0;
    var nextDurationType as Number = -1;
    var nextDuration as Float = 0.0;

    hidden var _signature as String = "";
    hidden var _forceNewStep as Boolean = false;
    hidden var _startTimerMs as Number = 0;
    hidden var _startDist as Float = 0.0;
    hidden var _duration as Float = 0.0;

    function initialize() {
    }

    function reset() as Void {
        active = false;
        stepNumber = 0;
        _signature = "";
        _forceNewStep = false;
    }

    //! Called from DataField.onWorkoutStepComplete(): identical consecutive
    //! steps (e.g. 5 x 4 min) would otherwise look like a single step.
    function markStepComplete() as Void {
        _forceNewStep = true;
    }

    function hasTarget() as Boolean {
        return active && targetType != TARGET_OPEN && high > 0;
    }

    //! Returns true when a new step has started (caller resets step averages).
    function update(info as Activity.Info, timerMs as Number) as Boolean {
        var stepInfo = null;
        if (Activity has :getCurrentWorkoutStep) {
            stepInfo = Activity.getCurrentWorkoutStep();
        }
        var step = resolve(stepInfo);
        if (step == null) {
            active = false;
            return false;
        }
        active = true;
        var si = stepInfo as Activity.WorkoutStepInfo;
        var dist = info.elapsedDistance != null ? info.elapsedDistance.toFloat() : 0.0;

        name = si.name != null ? si.name as String : "";
        intensity = si.intensity != null ? si.intensity as Number : 0;
        targetType = step.targetType != null ? step.targetType as Number : TARGET_OPEN;
        low = decodeTarget(targetType, step.targetValueLow);
        high = decodeTarget(targetType, step.targetValueHigh);
        if (low > high) {
            var t = low;
            low = high;
            high = t;
        }
        durationType = step.durationType != null ? step.durationType as Number : -1;
        _duration = decodeDuration(durationType, step.durationValue);

        var sig = name + "|" + intensity + "|" + targetType + "|" + low + "|" + high
            + "|" + durationType + "|" + _duration;
        var isNew = false;
        if (!sig.equals(_signature) || _forceNewStep) {
            _signature = sig;
            _forceNewStep = false;
            _startTimerMs = timerMs;
            _startDist = dist;
            stepNumber++;
            isNew = true;
        }

        if (durationType == DURATION_TIME && _duration > 0) {
            remaining = _duration - (timerMs - _startTimerMs) / 1000.0;
        } else if (durationType == DURATION_DISTANCE && _duration > 0) {
            remaining = _duration - (dist - _startDist);
        } else {
            remaining = null;
        }
        if (remaining != null && remaining < 0) {
            remaining = 0.0;
        }

        updateNext();
        return isNew;
    }

    //! Seconds elapsed in the current step (used for open-ended steps).
    function elapsedS(timerMs as Number) as Number {
        return (timerMs - _startTimerMs) / 1000;
    }

    hidden function updateNext() as Void {
        hasNext = false;
        if (!(Activity has :getNextWorkoutStep)) {
            return;
        }
        var ni = Activity.getNextWorkoutStep();
        var ns = resolve(ni);
        if (ns == null) {
            return;
        }
        var info = ni as Activity.WorkoutStepInfo;
        hasNext = true;
        nextName = info.name != null ? info.name as String : "";
        nextIntensity = info.intensity != null ? info.intensity as Number : 0;
        nextTargetType = ns.targetType != null ? ns.targetType as Number : TARGET_OPEN;
        nextLow = decodeTarget(nextTargetType, ns.targetValueLow);
        nextHigh = decodeTarget(nextTargetType, ns.targetValueHigh);
        nextDurationType = ns.durationType != null ? ns.durationType as Number : -1;
        nextDuration = decodeDuration(nextDurationType, ns.durationValue);
    }

    //! Repeat blocks come as WorkoutIntervalStep: pick the active or rest part.
    hidden function resolve(stepInfo) as Activity.WorkoutStep? {
        if (stepInfo == null) {
            return null;
        }
        var s = (stepInfo as Activity.WorkoutStepInfo).step;
        if (s == null) {
            return null;
        }
        if (s instanceof Activity.WorkoutIntervalStep) {
            var it = (stepInfo as Activity.WorkoutStepInfo).intensity;
            var isRest = it == INTENSITY_REST || it == INTENSITY_RECOVERY;
            if (isRest && s.restStep != null) {
                return s.restStep;
            }
            return s.activeStep;
        }
        return s as Activity.WorkoutStep;
    }

    //! Some firmware versions report custom power targets with the FIT +1000 W
    //! offset and speeds in mm/s; normalise both. %FTP / %HRmax targets come
    //! through as 0 and are treated as "no target".
    static function decodeTarget(type as Number, v) as Float {
        if (v == null) {
            return 0.0;
        }
        var x = v.toFloat();
        if (type == TARGET_POWER && x > 1000) {
            x -= 1000;
        } else if (type == TARGET_HR && x > 300) {
            x -= 100;
        } else if (type == TARGET_SPEED && x > 100) {
            x /= 1000.0;
        }
        return x;
    }

    //! Time in s (ms if implausibly large), distance in m (cm if > 100 km).
    static function decodeDuration(type as Number, v) as Float {
        if (v == null) {
            return 0.0;
        }
        var x = v.toFloat();
        if (type == DURATION_TIME && x > 86400) {
            x /= 1000.0;
        } else if (type == DURATION_DISTANCE && x > 100000) {
            x /= 100.0;
        }
        return x;
    }
}

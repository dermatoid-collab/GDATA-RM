import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.WatchUi;

//! Writes W' balance (per record) and session totals into the activity FIT file,
//! so they show up in Garmin Connect charts and summary.
class FitRecorder {
    // Must match resources/fit/fitcontributions.xml
    const FIT_WBAL = 0;
    const FIT_NP = 1;
    const FIT_TSS = 2;
    const FIT_CHO = 3;
    const FIT_WBAL_MIN = 4;

    hidden var _wbal = null;
    hidden var _np = null;
    hidden var _tss = null;
    hidden var _cho = null;
    hidden var _wbalMin = null;

    function initialize(field as WatchUi.DataField) {
        if (!Config.fitRecord) {
            return;
        }
        var rec = { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "J" };
        var ses = FitContributor.MESG_TYPE_SESSION;
        _wbal = field.createField("w_bal", FIT_WBAL, FitContributor.DATA_TYPE_UINT16, rec);
        _np = field.createField("np", FIT_NP, FitContributor.DATA_TYPE_UINT16,
            { :mesgType => ses, :units => "W" });
        _tss = field.createField("tss", FIT_TSS, FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => ses });
        _cho = field.createField("cho_burnt", FIT_CHO, FitContributor.DATA_TYPE_UINT16,
            { :mesgType => ses, :units => "g" });
        _wbalMin = field.createField("w_bal_min", FIT_WBAL_MIN, FitContributor.DATA_TYPE_UINT16,
            { :mesgType => ses, :units => "J" });
    }

    function update(e as Engine) as Void {
        if (_wbal == null || !e.running) {
            return;
        }
        _wbal.setData(clampU16(e.wbal));
        _np.setData(clampU16(e.np));
        _tss.setData(e.tss);
        _cho.setData(clampU16(e.cho));
        _wbalMin.setData(clampU16(e.wbalMin));
    }

    hidden function clampU16(v as Float) as Number {
        var n = (v + 0.5).toNumber();
        return n < 0 ? 0 : (n > 65534 ? 65534 : n);
    }
}

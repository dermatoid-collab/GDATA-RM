import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Full-width pop-up used for fuel and W' reminders (DataField.showAlert).
class CockpitAlert extends WatchUi.DataFieldAlert {
    hidden var _title as String;
    hidden var _sub as String;
    hidden var _color as Number;

    function initialize(title as String, sub as String, color as Number) {
        DataFieldAlert.initialize();
        _title = title;
        _sub = sub;
        _color = color;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var fg = Zones.textOn(_color);
        dc.setColor(_color, _color);
        dc.clear();
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        var big = Draw.fitFont(dc, _title, w * 9 / 10, h / 2, false);
        dc.drawText(w / 2, h * 2 / 5, big, _title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (_sub.length() > 0) {
            var small = Draw.fitFont(dc, _sub, w * 9 / 10, h / 5, false);
            dc.drawText(w / 2, h * 3 / 4, small, _sub,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

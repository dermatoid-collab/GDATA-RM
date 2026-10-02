import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class GDataApp extends Application.AppBase {
    hidden var _view = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        Config.load();
        _view = new CockpitView();
        return [_view];
    }

    function onSettingsChanged() as Void {
        Config.load();
        if (_view != null) {
            _view.onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }
}

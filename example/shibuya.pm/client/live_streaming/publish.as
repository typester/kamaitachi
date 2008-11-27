import flash.net.*;
import flash.events.*;
import flash.media.*;

private var nc:NetConnection;
private var ns:NetStream;

private function init():void {
    nc = new NetConnection();
    nc.addEventListener(NetStatusEvent.NET_STATUS, status_handler);
    nc.objectEncoding = ObjectEncoding.AMF0;
    nc.client = this;
    nc.connect("rtmp://localhost/stream/live");
}

private function status_handler(event:NetStatusEvent):void {
    switch (event.info.code) {
    case "NetConnection.Connect.Success":
        setStatus("Connected.");
        break;
    default:
        setStatus(event.info.code);
    }
}

private function setStatus(text:String):void {
    status.text = text;
}

private function start_publish():void {
    var channel_name:String = input.text;
    if (!channel_name) return;

    ns = new NetStream(nc);
    ns.addEventListener(NetStatusEvent.NET_STATUS, status_handler);

    var camera:Camera = Camera.getCamera();
    if (!camera) {
        setStatus("No camera found");
        return;
    }

    var mic:Microphone = Microphone.getMicrophone();
    if (!mic) {
        setStatus("No mic found");
        return;
    }

    publish_button.enabled = false;

    // set quality
    camera.setMode(320, 240, 30);
    camera.setQuality(0, 80);
    mic.setSilenceLevel(0);
    mic.rate = 22;

    video.attachCamera(camera);

    ns.attachCamera(camera);
    ns.attachAudio(mic);
    ns.publish(channel_name, "live");
}

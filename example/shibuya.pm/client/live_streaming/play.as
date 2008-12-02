import flash.net.*;
import flash.events.*;
import flash.media.*;
import mx.core.*;

private var nc:NetConnection;
private var ns:NetStream;

private function init():void {
    nc = new NetConnection();
    nc.addEventListener(NetStatusEvent.NET_STATUS, status_handler);
    nc.objectEncoding = ObjectEncoding.AMF0;
    nc.client = this;
    nc.connect("rtmp:/stream/live");
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

private function start_play():void {
    var channel_name:String = input.text;
    if (!channel_name) return;

    ns = new NetStream(nc);
    ns.addEventListener(NetStatusEvent.NET_STATUS, status_handler);

    var video:Video = new Video(320, 240);
    video.attachNetStream(ns);

    var ui:UIComponent = new UIComponent();
    ui.addChild(video);

    video_container.addChild(ui);

    ns.play(channel_name);
}

private function pause_play():void {
    ns.pause();
}

private function resume_play():void {
    ns.resume();
}

private function close_play():void {
    ns.close();
}

private function seek_play():void {
    ns.seek(100);
}

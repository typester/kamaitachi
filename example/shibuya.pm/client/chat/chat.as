import flash.net.*;
import flash.events.*;

private var nc:NetConnection;

private function init():void {
    nc = new NetConnection();
    nc.addEventListener(NetStatusEvent.NET_STATUS, status_handler);
    nc.objectEncoding = ObjectEncoding.AMF0;
    nc.client = this;
    nc.connect("rtmp://localhost/rpc/chat");
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

private function send():void {
    if (!input.text) return;
    if (input.length >= 200) return; // ignore long input ;)

    nc.call("send", new Responder(function ():void {}), input.text);
    onMessage(input.text);

    input.text = "";
}

public function onMessage(message:String):void {
    result.text = message + "\n" + result.text;
}

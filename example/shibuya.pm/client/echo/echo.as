import flash.net.*;
import flash.events.*;

private var nc:NetConnection;

private function init():void {
    nc = new NetConnection();
    nc.addEventListener(NetStatusEvent.NET_STATUS, status_handler);
    nc.objectEncoding = ObjectEncoding.AMF0;
    nc.connect("rtmp://localhost/rpc/echo");
}

private function status_handler(event:NetStatusEvent):void {
    switch (event.info.code) {
    case "NetConnection.Connect.Success":
        setStatus("connected.");
        break;
    default:
        setStatus(event.info.code);
    }
}

private function setStatus(text:String):void {
    status.text = text;
}

private function callEcho():void {
    if (!input.text) return;

    nc.call("echo", new Responder(callEchoResponse), input.text);
    input.text = "";
}

private function callEchoResponse(res:String):void {
    result.text = res + "\n" + result.text;
}

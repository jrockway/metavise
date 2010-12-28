jsSocket.swf = "/static/swf/jsSocket.swf";

var Status = {
    socket: null,
    init: function() {
        Status.socket = new jsSocket({ hostname: '127.0.0.1'
                                     , port: 5000
                                     , path: '@status'
                                     , onOpen: Status.onOpen
                                     , onClose: Status.onClose
                                     , onData: Status.onData
                                    });
    },
    onOpen: function () {
        var sd = $('#status_debug');
        sd.val(sd.val() + "\nopened\n");
    },
    onClose: function() {
        var sd = $('#status_debug');
        sd.val(sd.val() + "\nclosed\n");
    },
    onData: function(data) {
        var sd = $('#status_debug');
        sd.val(sd.val() + data);
    },
    send: function(data){
        Status.socket.send(data);
    }
};

$(document).ready(Status.init);
$(document).ready(function (){
    $('#status_debug').val( "ok " + Status.socket + "\n" );
    $('button').onclick(function () {
        alert("send");
        Status.send("this is a test\n");
    });
});

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
    onOpen: function () {},
    onClose: function() {},
    onData: function(data) {},
};

$(document).ready(Status.init);

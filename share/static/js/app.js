var GraphModel = Backbone.Model.extend({
    defaults: {
        width: 500,
        height: 100
    },
    url: function() {
        return "/process/" + this.get("process") + "/graphs/" +
            this.get("width") + "x" + this.get("height") + "/" +
            this.get("type") + ".png";
    }
});

var Process = Backbone.Model.extend({
    defaults: { needsConfirm: false, pendingCmd: "" },
    initialize: function() {
        this.graph = { small: {}, big: {} };
        this.graph.small.cpu = new GraphModel({
            process: this.id,
            type: "cpu",
            height: 40,
            width: 130,
        });
        this.graph.small.mem = new GraphModel({
            process: this.id,
            type: "memory",
            height: 40,
            width: 130,
        });

        this.graph.big.cpu = new GraphModel({
            process: this.id,
            type: "cpu",
            height: 150,
            width: 300,
        });
        this.graph.big.mem = new GraphModel({
            process: this.id,
            type: "memory",
            height: 150,
            width: 300,
        });
    },
    svc: function(c) {
        this.set({ want: this.get("want") + c });
    },
});

var ProcessCollection = Backbone.Collection.extend({
    model: Process,
    url: "/process/"
});

var ProcessList = new ProcessCollection();
var ProcessView;
var AppView;
var App;

var longPoll = {
    retryLater: function () {
        if(retryTimeout == undefined){
            longPoll.retryTimeout = setTimeout( longPoll.poll, 10000 );
        }
    },
    refresh: function(data) {
        ProcessList.refresh(data);
    },
    poll: function() {
        longPoll.retryTimeout = undefined;
        longPoll.xhr = $.ajax({
            url: "/process/long_poll",
            type: "GET",
            dataType: "json",
            timeout: 120000,
            error: function() { longPoll.retryLater() },
            success: function(data, status, xhr){
                if(data != undefined && data != null){
                    longPoll.refresh(data);
                    longPoll.poll();
                }
                else {
                    longPoll.retryLater();
                }
            },
        });
    },
};

$(document).ready(function() {
    ProcessView = Backbone.View.extend({
        tagName: "div",

        template: _.template($("#process_template").html()),

        initialize: function() {
            _.bindAll(this, "render", "svc");
            this.model.bind("change", this.render);
        },

        render: function() {
            var params = this.model.toJSON();
            params.cpu = { big: {}, small: {} };
            params.mem = { big: {}, small: {} };
            params.cpu.small.graphURL = this.model.graph.small.cpu.url();
            params.mem.small.graphURL = this.model.graph.small.mem.url();
            params.cpu.big.graphURL = this.model.graph.big.cpu.url();
            params.mem.big.graphURL = this.model.graph.big.mem.url();
            var html = this.template(params);
            $(this.el).html(html);
            $(this.el).find("img").tooltip().dynamic();
            return $(this.el);
        },

        events: {
            "click .process_act": "svc",
        },

        svc: function(e) {
            var cmd = $(e.currentTarget).text();
            if(this.model.get("needsConfirm") && cmd == "confirm"){
                this.model.set({"needsConfirm": false}, {silent: true});
                this.model.svc(this.model.get("pendingCmd"));
                longPoll.xhr.abort();
                this.model.save({}, {
                    success: longPoll.poll,
                    error: longPoll.poll,
                });
            }
            else if(this.model.get("needsConfirm") && cmd == "cancel") {
                this.model.set({"needsConfirm": false});
            }
            else {
                this.model.set({"needsConfirm": true, pendingCmd: cmd});
            }
        },

    });

    AppView = Backbone.View.extend({
        el: $("#processes"),

        initialize: function() {
            _.bindAll(this, "addOne", "addAll", "render");
            ProcessList.bind("add", this.addOne);
            ProcessList.bind("refresh", this.addAll);
        },

        addOne: function(proc) {
            var view = new ProcessView({model: proc});
            $(this.el).append(view.render());
        },

        addAll: function() {
            $(this.el).empty();
            ProcessList.each(this.addOne);
        },
    });

    App = new AppView();
    ProcessList.fetch();
    longPoll.poll();
});


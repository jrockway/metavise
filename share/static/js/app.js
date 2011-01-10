var GraphModel = Backbone.Model.extend({
    defaults: {
        width: 500,
        height: 100
    },
    url: function() {
        return document.URL +
            "process/" + this.get("process") + "/graphs/" +
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
            height: 45,
            width: 130,
        });
        this.graph.small.mem = new GraphModel({
            process: this.id,
            type: "memory",
            height: 45,
            width: 130,
        });

        this.graph.big.cpu = new GraphModel({
            process: this.id,
            type: "cpu",
            height: 200,
            width: 500,
        });
        this.graph.big.mem = new GraphModel({
            process: this.id,
            type: "memory",
            height: 200,
            width: 500,
        });
    },
    svc: function(c) {
        this.set({ want: this.get("want") + c });
    },
});

var ProcessCollection = Backbone.Collection.extend({
    model: Process,
    url: document.URL + "process/"
});

var ProcessList = new ProcessCollection();
var ProcessView;
var AppView;
var App;

var longPoll = {
    retryTimeout: undefined,
    retryLater: function () {
        if(longPoll.retryTimeout == undefined){
            longPoll.retryTimeout = setTimeout( longPoll.poll, 10000 );
        }
    },
    refresh: function(data) {
        ProcessList.refresh(data);
    },
    poll: function() {
        longPoll.retryTimeout = undefined;
        longPoll.xhr = $.ajax({
            url: document.URL + "process/long_poll",
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
            _.bindAll(this, "render", "svc", "hover", "unhover");
            this.model.bind("change", this.render);
        },

        render: function() {
            var params = this.model.toJSON();
            params.cpu = { graphURL: this.model.graph.small.cpu.url() };
            params.mem = { graphURL: this.model.graph.small.mem.url() };
            var html = this.template(params);
            $(this.el).html(html);
            return $(this.el);
        },

        events: {
            "click .process_act": "svc",
            "mouseenter img": "hover",
            "mouseleave img": "unhover",
        },

        svc: function(e) {
            var cmd = $(e.currentTarget).text();
            if(this.model.get("needsConfirm") && cmd == "confirm"){
                this.model.set({"needsConfirm": false}, {silent: true});
                this.model.svc(this.model.get("pendingCmd"));
                this.model.save();
            }
            else if(this.model.get("needsConfirm") && cmd == "cancel") {
                this.model.set({"needsConfirm": false});
            }
            else {
                this.model.set({"needsConfirm": true, pendingCmd: cmd});
            }
        },

        hover: function(e){
            var cmd = $(e.currentTarget).attr("class").match(/cpu|mem/);
            $("#hovergraph").append(
                "<img src='" + this.model.graph.big[cmd].url() + "'/>"
            );
            $("#hovergraph").show();
        },

        unhover: function(e){
            $("#hovergraph").hide();
            $("#hovergraph").empty();
        }

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


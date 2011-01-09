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
    initialize: function() {
        this.graph = {};
        this.graph.cpu = new GraphModel({
            process: this.id,
            type: "cpu",
            height: 40,
            width: 130,
        });
        this.graph.mem = new GraphModel({
            process: this.id,
            type: "memory",
            height: 40,
            width: 130,
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

$(document).ready(function() {
    ProcessView = Backbone.View.extend({
        tagName: "div",

        template: _.template($("#process_template").html()),

        initialize: function() {
            _.bindAll(this, "render", "svc", "graph");
            this.model.bind("change", this.render);
        },

        render: function() {
            var params = this.model.toJSON();
            params.cpu = {};
            params.mem = {};
            params.cpu.graphURL = this.model.graph.cpu.url();
            params.mem.graphURL = this.model.graph.mem.url();
            var html = this.template(params);
            $(this.el).html(html);
            return $(this.el);
        },

        events: {
            "click .process_act": "svc",
        },

        svc: function(e) {
            var cmd = $(e.currentTarget).text();
            this.model.svc(cmd);
            this.model.save();
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

    setInterval( function() { ProcessList.fetch() }, 10000 );
});


var Process = Backbone.Model.extend({
    svc: function(c) {
        this.set({ want: this.get("want") + c });
    },
});

var ProcessCollection = Backbone.Collection.extend({
    model: Process,
    url: "/process/"
});

var ProcessList = new ProcessCollection();

var GraphModel = Backbone.Model.extend({
    url: function() {
        return "/process/" + this.get("process") +
            "/graphs/" + this.get("type") + ".png";
    }
});

var CurrentGraph = new GraphModel({ type: undefined, process: undefined });

var ProcessView;
var AppView;
var GraphView;
var App;
var Graph;

$(document).ready(function() {
    ProcessView = Backbone.View.extend({
        tagName: "div",

        template: _.template($("#process_template").html()),

        initialize: function() {
            _.bindAll(this, "render", "svc", "graph");
            this.model.bind("change", this.render);
        },

        render: function() {
            var html = this.template(this.model.toJSON());
            $(this.el).html(html);
            return $(this.el);
        },

        events: {
            "click .process_act": "svc",
            "click .graphlink": "graph"
        },

        svc: function(e) {
            var cmd = $(e.currentTarget).text();
            this.model.svc(cmd);
            this.model.save();
        },

        graph: function(e) {
            var type = $(e.currentTarget).attr("title");
            CurrentGraph.set({ process: this.model.id, type: type });
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

    GraphView = Backbone.View.extend({
        el: $("#graph"),
        events: { "click": "click" },
        interval: undefined,
        initialize: function() {
            $(this.el).hide();
            _.bindAll(this, "render", "click");
            CurrentGraph.bind("change", this.render);
            $(this.el).hide();
        },

        render: function() {
            if(this.model.get("process") == undefined){
                $(this.el).hide();
            }
            else {
                console.log("graph " + this.model.url());
                $(this.el).attr("src", window.location + this.model.url());
                $(this.el).show();
            }
        },
        click: function() {
            this.model.set({ process: undefined });
        }
    });

    App = new AppView();
    Graph = new GraphView({ model: CurrentGraph });
    ProcessList.fetch();

    setInterval( function() { ProcessList.fetch() }, 10000 );
});


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

var ProcessView;
var AppView;
var App;

$(document).ready(function() {
    ProcessView = Backbone.View.extend({
        tagName: "div",

        template: _.template($("#process_template").html()),

        initialize: function() {
            _.bindAll(this, "render", "svc");
            this.model.bind("change", this.render);
        },

        render: function() {
            var html = this.template(this.model.toJSON());
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


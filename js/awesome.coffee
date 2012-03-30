
global = window

`(function() {
    var lastTime = 0;
    var vendors = ['ms', 'moz', 'webkit', 'o'];
    for(var x = 0; x < vendors.length && !window.requestAnimationFrame; ++x) {
        window.requestAnimationFrame = window[vendors[x]+'RequestAnimationFrame'];
        window.cancelRequestAnimationFrame = window[vendors[x]+
          'CancelRequestAnimationFrame'];
    }

    if (!window.requestAnimationFrame)
        window.requestAnimationFrame = function(callback, element) {
            var currTime = new Date().getTime();
            var timeToCall = Math.max(0, 16 - (currTime - lastTime));
            var id = window.setTimeout(function() { callback(currTime + timeToCall); }, 
              timeToCall);
            lastTime = currTime + timeToCall;
            return id;
        };

    if (!window.cancelAnimationFrame)
        window.cancelAnimationFrame = function(id) {
            clearTimeout(id);
        };
}())`

`if (typeof window.localStorage == 'undefined' || typeof window.sessionStorage == 'undefined') (function () {
	var Storage = function (type) {
	  function createCookie(name, value, days) {
	    var date, expires;

	    if (days) {
	      date = new Date();
	      date.setTime(date.getTime()+(days*24*60*60*1000));
	      expires = "; expires="+date.toGMTString();
	    } else {
	      expires = "";
	    }
	    document.cookie = name+"="+value+expires+"; path=/";
	  }

	  function readCookie(name) {
	    var nameEQ = name + "=",
	        ca = document.cookie.split(';'),
	        i, c;

	    for (i=0; i < ca.length; i++) {
	      c = ca[i];
	      while (c.charAt(0)==' ') {
	        c = c.substring(1,c.length);
	      }

	      if (c.indexOf(nameEQ) == 0) {
	        return c.substring(nameEQ.length,c.length);
	      }
	    }
	    return null;
	  }
	  
	  function setData(data) {
	    data = JSON.stringify(data);
	    if (type == 'session') {
	      window.name = data;
	    } else {
	      createCookie('localStorage', data, 365);
	    }
	  }
	  
	  function clearData() {
	    if (type == 'session') {
	      window.name = '';
	    } else {
	      createCookie('localStorage', '', 365);
	    }
	  }
	  
	  function getData() {
	    var data = type == 'session' ? window.name : readCookie('localStorage');
	    return data ? JSON.parse(data) : {};
	  }


	  // initialise if there's already data
	  var data = getData();

	  return {
	    length: 0,
	    clear: function () {
	      data = {};
	      this.length = 0;
	      clearData();
	    },
	    getItem: function (key) {
	      return data[key] === undefined ? null : data[key];
	    },
	    key: function (i) {
	      // not perfect, but works
	      var ctr = 0;
	      for (var k in data) {
	        if (ctr == i) return k;
	        else ctr++;
	      }
	      return null;
	    },
	    removeItem: function (key) {
	      delete data[key];
	      this.length--;
	      setData(data);
	    },
	    setItem: function (key, value) {
	      data[key] = value+''; // forces the value to a string
	      this.length++;
	      setData(data);
	    }
	  };
	};

	if (typeof window.localStorage == 'undefined') window.localStorage = new Storage('local');
	if (typeof window.sessionStorage == 'undefined') window.sessionStorage = new Storage('session');
})();`

`Storage.prototype.set = function(key, value) {
    this.setItem(key, JSON.stringify(value));
}

Storage.prototype.get = function(key) {
    var value = this.getItem(key);
    return value && JSON.parse(value);
}`

for prop in Object.getOwnPropertyNames(Math)
	global[prop] = Math[prop]

TAU = 2 * PI

global.V1 = V1 = (x) -> [x]
global.V2 = V2 = (x, y) -> [x, y]
global.V3 = V3 = (x, y, z) -> [x, y, z]

Vec = {}

Vec.check = (a, b) ->
	unless a.length == b.length
		throw new Error("Cant add vectors of diffrent length, tried to add #{a} and #{b}")

	{length: a.length}

Vec.eq = (a, b) ->
	{length} = Vec.check(a, b)
	for i in [0...length]
		return false if a[i] != b[i]

	return true

Vec.combine = (op) -> (a, b) -> 
	{length} = Vec.check(a, b)
	(op(a[i], b[i]) for i in [0...length])

Vec.add = Vec.combine (a, b) -> a + b

Vec.sub = Vec.combine (a, b) -> a - b

Vec.dot = (a, b) ->
	{length} = Vec.check(a, b)
	cum = 0
	for i in [0...length]
		cum += a[i] * b[i]
	cum

Vec.cross = (a, b) ->
	{length} = Vec.check(a, b)
	unless length == 3
		throw new Error("Cant determine cross product for vector other then a 3D vector, current vector was a #{length}D vector")

	[a[2]*b[3] - a[3]*b[2], a[3]*b[1] - a[1]*b[3], a[1]*b[2] - a[2]*b[1]]

Vec.mult = (vec, s) -> (field * s for field in vec)

Vec.div  = (vec, d) -> (field / d for field in vec)

Vec.length = (vec) ->
	cum = 0
	for field in vec
		cum += field * field
	sqrt(cum)

Vec.norm = (vec) -> Vec.div(vec, Vec.length(vec))

autorun = false
recompileTimeout = 200 #ms
project = null
editor = null
id_pool = localStorage.getItem("id_pool") ? 0

showError = (error = null) ->
	if error == null
		$('#compile-error').hide()
	else
		$('#compile-error').html(error).show()

initUI = ->
	$('#compile-controls').append("<a href=javascript:void(0) class=control id=run>Run</a> <a href=javascript:void(0) class=control id=autorun>Autorun</a>")
	$('#run.control').click -> canvas.run()
	$('#autorun.control').click -> autorun = !autorun

initEditor = ->
	ace_editor = ace.edit("ace-editor")
	ace_editor.setTheme ace.require('ace/theme/twilight')
	editor = ace_editor.getSession()

	editor.setTabSize      2
	editor.setUseWrapMode  yes
	editor.setMode         new (ace.require('ace/mode/coffee').Mode)

	compileTimeout = null
	editor.on    'change', ->
		clearTimeout(compileTimeout)
		compileTimeout = setTimeout (->
			contentUpdate()
		), recompileTimeout

initOutput = ->
	$wrap = $('#output')
	$output = $('#output .inner')

	global.mouse = {x: 0, y: 0}

	$output.bind 'mousemove', (e) ->
		mouse.x = e.layerX
		mouse.y = e.layerY

	state = null
	running = no

	ctx = null
	$canvas = null

	global.canvas = {
		size: (width, height) ->
			$output.html("<canvas>")
			$canvas = $('canvas', $output)
			ctx = $canvas.get(0).getContext("2d")

			$output.width width
			$output.height height
			$output.css 'margin-top', ($wrap.height() - height)/2

			$canvas.get(0).width = width
			$canvas.get(0).height = height

		run: ->
			state = {}

			state.__defineGetter__ 'width', -> $canvas.get(0).width
			state.__defineGetter__ 'height', -> $canvas.get(0).height

			Math.seedrandom()
			random = Math.random
			state.random = (low, high) -> low + random() * (high - low)

			try
				@init.call(state)
			catch error
				showError "Runtime error: "+error
			
			running = yes

		_tick: ->
			return null unless running

			try
				@update.call(state, 1)
				@draw.call(state, ctx)
			catch error
				showError "Runtime error: "+error
	}

updateFilelist = ->
	$('#project-files').empty()

	for id of project.files
		name = if id == 'index' then project.name else id
		current = if id == project.current_file then 'class=current' else ''
		$('#project-files').append("<li id=file-#{id} #{current}>#{name}</li>")
		$("#project-files #file-#{id}").bind 'click', do (id) ->
			(e) ->
				if e.ctrlKey
					$("#project-files #file-#{id}").empty().append("<input>")
					$("#project-files #file-#{id} input").val(id).focus().bind 'blur', ->
						new_id = $("#project-files #file-#{id} input").val()
						renameFile(id, new_id)
				else
					switchFile(id) 


	$('#project-files').append("<li id=add-#{project.id}>+ file</li>")

	$("#project-files #add-#{project.id}").bind 'click', addFile

enterLoop = ->
	animationLoop = ->
		canvas._tick()

		requestAnimationFrame(animationLoop)
	animationLoop()

	persistLoop = ->
		try
			persistProject project
		catch error
			showError "Fatal error when saving project: "+error 

		setTimeout(persistLoop, 10)
	persistLoop()

contentUpdate = ->
	project.files[project.current_file] = editor.getValue()

	runProject(project)

newProject = ->
	last_id = localStorage.get('id_pool') ? 0
	localStorage.set('id_pool', last_id + 1)

	id = last_id + 1
	project = {
		id
		files: {'index': 'example'}
		name: "Project #{id}"
		current_file: 'index'
	}

runProject = ->
	source = ""
	for name, content of project.files
		continue if name == 'index'
		source += content
		source += "\n"

	source += project.files['index']

	try
		showError null
		compiledJS = CoffeeScript.compile source, bare: on

	catch error
		showError "Compile time error: "+error

	try
		eval compiledJS
	catch error
		showError "Run time error: "+error

retriveProject = (id) -> localStorage.get("project_#{id}")

persistProject = (project) ->
	localStorage.set "project_#{project.id}", project
	localStorage.set "current_project", project.id

loadProject = ->
	switchFile(project.current_file)
	contentUpdate()
	canvas.run()

addFile = ->
	name = "new"

	while project.files[name]?
		name += "_"

	project.files[name] = ""

	switchFile(name)

renameFile = (id, new_id) ->
	project.files[new_id] = project.files[id]
	delete project.files[id]
	updateFilelist()

switchFile = (id) ->
	editor.setValue project.files[id]
	project.current_file = id
	updateFilelist()

initController = ->
	if (project_id = localStorage.get("current_project"))
		project = retriveProject(project_id)
	else
		project = newProject()
		persistProject(project)

	loadProject project

$ ->
	initEditor()
	initUI()
	initOutput()

	initController()

	enterLoop()

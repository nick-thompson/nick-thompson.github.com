// A variation of a classic Granulizer effect. Takes a list of resource urls,
// loads each, and plays back the buffers as interleaved grains.
(function (window, undefined) {

  // Granulizer constructor
  // @arg {AudioContext} context : the AudioContex to build the granulizer on
  // @arg {array} resources : a list of urls from which to load the buffers
  // @arg {object} opts : a set of properties to apply on the granulizer
  // @arg {function} callback : the function to fire when buffers are loaded
  var Granulizer = function (context, resources, opts, callback) {
    for (var prop in opts) {
      this[prop] = opts[prop];
    }
    if (!(this.attack && this.hold && this.grainSpacing && this.waveSpacing)) {
      throw new Error("Invalid initialization arguments.");
    }
    this.context = context;
    this.destination = context.destination;
    this.gainCoefficent = this.gainCoefficient || 0.0;
    this.panCoefficent = this.panCoefficient || 0.0;
    this.pitchCoefficient = this.pitchCoefficient || 0.0;
    this.load(resources, callback);
  };

  // Loads a list of sample resources, assigns necessary properties, and
  // issues the callback on completion.
  // @arg {array} resources : a list of urls from which to load the buffers
  // @arg {function} callback : function to fire when all buffers loaded
  Granulizer.prototype.load = function (resources, callback) {
    var buffers = []
      , left = resources.length
      , that = this;

    resources.forEach(function (resource) {
      var request = new XMLHttpRequest();
      request.open("get", resource, true);
      request.responseType = "arraybuffer";
      request.onload = function() {
        that.context.decodeAudioData(request.response, function (buffer) {
          buffers.push(buffer);
          if (--left === 0) {
            that.buffers = buffers;
            that.bufferIndex = 0;
            that.samplePointers = new Array(buffers.length);
            for (var j = 0; j < buffers.length; j++) {
              that.samplePointers[j] = 0.0;
            }
            callback();
          }
        }); 
      };
      request.send();
    });

  };

  // Start playback; indefinitely issue schedule calls
  Granulizer.prototype.start = function () {
    this.time = this.context.currentTime;
    this.schedule();
    this.interval = setInterval(this.schedule.bind(this), 1000);
  };

  // Stop playback
  Granulizer.prototype.stop = function () {
    if (this.interval) {
      clearInterval(this.interval);
    }
  };

  // Mimics the AudioNode.connect interface
  Granulizer.prototype.connect = function (dest) {
    this.destination = dest;
  };

  // Mimics the AudioNode.disconnect interface
  Granulizer.prototype.disconnect = function () {
    this.destination = null;
  };

  // The brains of the operation. Schedules eight seconds of continuous
  // grain-interleaved playback
  Granulizer.prototype.schedule = function () {
    var toSchedule = 1.0 / this.grainSpacing
      , buffer, pointer;

    for (var i = 0; i < toSchedule; i++) {

      // Select pointers
      buffer = this.buffers[this.bufferIndex];
      pointer = this.samplePointers[this.bufferIndex];

      // Validate pointers
      if (pointer === null) {
        if (++this.bufferIndex >= this.buffers.length) {
          this.bufferIndex -= this.buffers.length;
        }
        continue;
      }

      // Construct audio graph
      var node = this.context.createBufferSource();
      node.buffer = buffer;
      
      var rate = 1.0 + (this.pitchCoefficient / 2) - (Math.random() * this.pitchCoefficient);
      node.playbackRate.value = rate;

      var amp = this.context.createGainNode();
      var gain = this.context.createGainNode();
      gain.gain.value = 1.0 - (Math.random() * this.gainCoefficient);

      var panner = this.context.createPanner();
      var x = (10 * this.panCoefficient) - (Math.random() * 20 * this.panCoefficient);
      panner.setPosition(x, 0.0, 0.1);

      node.connect(amp);
      amp.connect(gain);
      gain.connect(panner);
      panner.connect(this.destination);

      var duration = this.hold + this.attack;
      node.start(this.time, pointer, duration);

      // Apply amplitude smoothing
      amp.gain.setValueCurveAtTime(grainCurve, this.time, duration);

      // Update the sample pointer
      var next = pointer + this.waveSpacing;
      if (next > buffer.duration) {
        if (this.forever) {
          next = next - buffer.duration;
        } else {
          next = null;
        }
      }
      this.samplePointers[this.bufferIndex] = next;

      // Update buffer index
      if (++this.bufferIndex >= this.buffers.length) {
        this.bufferIndex -= this.buffers.length;
      }

      // Update time tracker
      this.time += this.grainSpacing;

    }

  };

  // Grain amplitude smoothing curve
  var len = 16384
    , grainCurve = new Float32Array(len);

  for (var i = 0; i < len; i++) {
    grainCurve[i] = Math.sin(Math.PI * i / len);
  }

  // Expose granulizer
  window.Granulizer = Granulizer;

})(this);


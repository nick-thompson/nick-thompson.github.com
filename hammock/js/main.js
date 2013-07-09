var context = new webkitAudioContext();
var g = new Granulizer(
    context
  , [
      "audio/mononoaware.mp3",
      "audio/catw.mp3"
    ]
  , {
      attack: 0.03,
      hold: 0.005,
      grainSpacing: 0.012, //005, // 18
      waveSpacing: 0.024, //01,
      forever: true,
      gainCoefficient: 0.4,
      panCoefficient: 0.2,
      pitchCoefficient: 0.01
    }
  , function () {
      g.start();
    }
);

var compressor = context.createDynamicsCompressor();
var filter = context.createBiquadFilter();
filter.type = 0;
filter.frequency.value = 17000;

var reverb = new SimpleReverb(context);

g.connect(compressor);
compressor.connect(reverb.input);
reverb.output.connect(filter);
filter.connect(context.destination);

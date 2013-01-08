---
layout: post
title: "Sidechaining with AudioParams"
date: 2012-11-8 12:32
comments: true
categories: web-audio javascript
---

When I first dove into the Web Audio API, one of the things I quickly overlooked
was the AudioParam interface. So, I decided 
[sidechaining](http://en.wikipedia.org/wiki/Dynamic_range_compression#Side-chaining) 
would be a fun, and hopefully practical, introduction to automation in web audio. 
When I say sidechaining, I'm usually thinking of it's common application
in electronic music; something like [this](http://www.youtube.com/watch?v=2lCI-2ceR7g). 
As I found working through this [example](http://nick-thompson.github.com/examples/sidechain/), 
there's not really a straightforward way to 
acheive this effect with the api in it's current state, so this turned out to be more
interesting than I had planned. 
In other news, I feel like I have a tendancy to use more words than necessary to say things, so
I'm going to try to keep this relatively short.

A simple, naive approach to this would be something like this...
```javascript
var sound = context.createOscillator();
sound.frequency.value = 440;

var gain = context.createGainNode();
gain.gain.value = 0.0;

sound.connect(gain);
gain.connect(context.destination);

var sidechain = context.createOscillator();
sidechain.frequency.value = 1;

sidechain.connect(gain.gain);
sound.noteOn(0);
sidechain.noteOn(0);
```

And if you run that code, it'll work! But I want my example to work with a sidechain
source that has more impulses in it's waveform, like a drum loop, which the above code
won't handle properly. The reason for that is because the AudioGain param is an a-rate
parameter, so it's output is calculated for each sample: output(t) = input(t) * gainValue(t);
So therefore, if you were to run that example with a drum loop, what you would hear is a roughly
filtered version of the drum loop, because, by the symmetry of the equation above, you're
just modifying the volume of the drum loop output by a sine wave at 440Hz.

So I needed a different approach. After trying a few things out, and with some
awesome help from the guys on the w3 public audio mailing list, I came to a nice
[solution](http://nick-thompson.github.com/examples/sidechain/). The full code for
the example is [here](https://github.com/nick-thompson/nick-thompson.github.com/blob/master/examples/sidechain/sidechain.js),
and I'm only going to detail the important parts below.

The first step is to take a root mean square average of the PCM waveform with a given
(relatively large) window size, with which you can create a slim estimate of your
input's envelope. To do this, I push the calculated value of each window into a simple
array. The next part, then, is easy:

```javascript
var processor = context.createJavaScriptNode(windowSize, 1, 1);
processor.onaudioprocess = (function () {
  var i = 0;
  return function (e) {
    gain.gain.setTargetValueAtTime(env[i++], 0.0, 0.01);
    i = i % env.length;
  };
})();
```

So using a JavaScriptNode (or a scriptProcessor, as it's now called), I initialize
an automation of the gain parameter every "windowSize" samples. This way, the reduced
estimate of the envelope is captured at the right interval, and using the built-in
automation methods, I avoid the symmetric modulation problem that I was seeing with the
previous approach. So that's it, and it's a pretty nice sounding solution, I say.

I am a little reserved about using a scriptProcessor for delegating such a simple event.
I think repititious parameter automation is pretty common, and I wouldn't want to use
a scriptProcessor node to handle each case if I were composing, because that's an unnecessary
accumulation of event listeners. But for now it seems like that's the best we can do.

\* _Note: In the explanations I linked about sidechaining, a compressor was used to duck
the appropriate signal. I experimented with using a DynamicsProcesssorNode for this example,
but I found that the results weren't as dramatic (which I'd like them to be). Also, as the DynamicsCompressorNode
doesn't have a makeup gain parameter, I wonder if it automatically tries to apply makeup gain for you? Which defeats
the purpose of trying to use it for sidechaining._

\* _Note: A big thanks goes out to Chris Wilson, Chris Rogers, and Srikumar Subramanian for their help on the w3
public audio mailing list._

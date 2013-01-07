---
layout: post
title: "Phase Offsets with Web Audio WaveTables"
date: 2012-11-1 19:44
comments: true
categories: web-audio javascript
---

Being a long-time FL Studio user, and a big fan of the Sytrus plugin that comes
bundled with it, I thought a fun experiment would be to try to build a simplified
version of the harmonic editor that Sytrus offers with the Web Audio API. So I did
that ([link](http://nick-thompson.github.com/harmony/)), and it became a pretty
interesting challenge once I hit the point of assigning phase offsets to individual harmonics.

If you've read anything about generating simple waveforms with the Web Audio API,
then you've probably come across 0xFE's article on
[generating tones](http://0xfe.blogspot.com/2011/08/generating-tones-with-web-audio-api.html).
At first, this seemed like a pretty good option for handling phase offsets, right?
Each harmonic is its own node, with a specific processing function for handling
the related phase offset. And there's even some pretty cool libraries available
that I could look at for reference, like [this one](https://github.com/AlexanderParker/Oscillator.js).

Pretty quickly, though, I decided that probably isn't a very good idea. I had already
decided my harmonic editor should support somewhere around 60 harmonics, because
that's roughly what Sytrus does, and that would mean 60 JavaScriptNodes (scriptProcessorNodes)
each firing their callback every n sample frames? I don't know how detailed I should be
here because I haven't really established an audience for this blog, but javascript is single-threaded,
so every time the JavaScript nodes fire the "audioprocess" event, 60 callbacks would fill the event loop,
and my script would fill every index of the output buffer in each callback. There's no way that's
efficient. So with that, I decided I could probably find a better solution.

Enter [WaveTables](https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html#WaveTable).
Turns out there probably isn't much better a solution for this problem than wavetables. Constructing
a new wavetable lets me define any waveform I want, and I can play that back with a simple OscillatorNode.
Building a wavetable isn't that bad either:

```javascript
var context = new webkitAudioContext();
var real = new Float32Array(4096);
var imag = new Float32Array(4096);
imag[1] = 1.0;
var wt = context.createWaveTable(real, imag);
// ...
myOscillator.setWaveTable(wt);
```

Building a wavetable relies on supplying the fourier coefficients for the real
and imaginary terms. The real coefficients apply to cosine waves, and the imaginary
coefficients apply to sine waves. So, above, I'm just setting index 1 of the 
imaginary coefficients to 1.0, which sets the relative amplitude of the fundamental
frequency to 1.0, and because the associated cosine term has a coefficient of 0, the result
will just be a simple sine wave. Awesome. Ok what about phase offsets?

```javascript
var context = new webkitAudioContext();
var real = new Float32Array(4096);
var imag = new Float32Array(4096);

// Lets assume we're starting with a simple sine wave:
var a1 = 0.0;
var b1 = 1.0;

// Apply a simple rotation to the initial coefficients
var shift = 2 * Math.PI * 0.5; // Shift the waveform 50%
real[1] = a1 * Math.cos(shift) - b1 * Math.sin(shift);
imag[1] = a1 * Math.sin(shift) + b1 * Math.cos(shift);

var wt = context.createWaveTable(real, imag);
// ...
myOscillator.setWaveTable(wt);
```

Yep, that's it. Applying a simple [2D rotation](http://en.wikipedia.org/wiki/Rotation_matrix#In_two_dimensions)
by the shift amount (in radians) to the initial fourier coefficients yields a phase shifted waveform.
I was pretty surprised by how easy it turned out to be. And this means that I
can power my synth with just 1 oscillator node, so long as I build the wavetable
correctly. Sounds like an efficiency bonus to me!

And that's all for now. You can check out the end result of this little experiment
[here](http://nick-thompson.github.com/harmony/), and please leave thoughts or comments if you have them.

---
layout: post
title: "You Don't Need That ScriptProcessor"
date: 2013-01-07 20:34
comments: true
categories: web-audio javascript efficiency
---

In the past couple of weeks I've seen a striking number of examples of using the ScriptProcessor
(or JavaScriptAudioNode) to generate sounds in the Web Audio API. For the most part it's been for
the generation of unusual waveforms, which is understandable. But even for tasks that an OscillatorNode
could easily handle, I'm seeing a ScriptProcessor in use. Here's a simple example.

```javascript
var node = context.createScriptProcessor(1024, 1, 1);
node.onaudioprocess = function (e) {
  var output = e.outputBuffer.getChannelData(0);
  for (var i = 0; i < output.length; i++) {
    output[i] = Math.random();
  }
};
node.connect(context.destination);
```

Pretty simple, right? And you can see what it does... every sample frame of the output buffer 
is a random number - it generates white noise. This is an incredibly simple way of 
generating white noise, I agree. So it makes sense that the ScriptProcessor should lend itself to easily
building relatively complicated waveforms. Then why am I cautioning you?

To put it as simply as possible, excessively using ScriptProcessor nodes is _asking_ for
performance issues. I'm no efficiency expert, but I've learned enough to make me
cringe at the thought of using a ScriptProcessor for simple tasks where a better solution
is available. Especially because we're talking about audio! Human ears are terribly unforgiving.

Let me explain.

Initializing a ScriptProcessor takes 3 arguments, the first of which is the size of the
buffer that you want to process on each AudioProcessing Event. That buffer size then also
determines how frequently the AudioProcessing event needs to be fired. Puttering around the web,
most of the examples you'll find demonstrating a ScriptProcessor will use a buffer size
of 1024 or 4096 sample frames. Lets look at that for a second.

Using a buffer size of 1024 means that every 1024 sample frames, the AudioProcess event will fire,
and your callback will be called. The AudioContext uses a sample rate of 44100Hz (44.1 kHz) by default.
This is pretty standard in audio processing, and chances are that you won't have any reason to change it.
So, some simple math: each sample frame is `1 / 44100 = 0.00002267` seconds long. Each buffer then is
`1024 * 0.00002267 = 0.0232` seconds long, which is the length of time in between each invocation of your
callback. Woah. Every `.0232s` your event loop gets hit with another function call. That's 43 callbacks per second, just for one
ScriptProcessor! You can run through that math again with a buffer size of 4096 if you want to, 
you'll find that you're not saving yourself much trouble. Buffer size vs. latency 
is a tradeoff that you hopefully have already considered anyway.

Up front, you're probably thinking that's not that bad - "my callback runs quickly enough". And you're probably
right. The example callback I included above runs in a fraction of a millisecond according to Chrome's
profiler. For one ScriptProcessor especially, that's no problem. My concern more importantly resides
in the idea that using ScriptProcessors for simple tasks lends itself to having many ScriptProcessors.
Many ScriptProcessors is not so safe. To test this, I wrote up a quick [gist](https://gist.github.com/4480973) to
test how many ScriptProcessors it would take to noticeably affect the audible output. Turns out it's not that many.
In Chrome Canary v26.0.1367.0, it usually takes somewhere between 10 and 15 ScriptProcessor nodes performing
fairly simple operations to introduce noticeable latency between successive output buffers reaching the destination. And
that number is without any sort of DOM rendering, and without any other event handlers. Certainly if you're working
on any sort of interactive audiovisual experiment, you'll want to be mindful of cutting processor costs as much
as possible.

These numbers are enough to convince me to spend a little time thinking about alternative options
every time I feel the urge to use a ScriptProcessor!

Finally, to follow up my initial example and conclude my point about alternative options,
here's a different way to implement a white noise generator.

```javascript
var node = context.createBufferSource()
  , buffer = context.createBuffer(1, 4096, context.sampleRate)
  , data = buffer.getChannelData(0);

for (var i = 0; i < 4096; i++) {
  data[i] = Math.random();
}

node.buffer = buffer;
node.loop = true;
node.connect(context.destination);
node.start(0);
```

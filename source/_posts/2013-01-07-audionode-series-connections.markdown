---
layout: post
title: "AudioNode Series Connections"
date: 2013-01-07 17:56
comments: true
categories: web-audio javascript
---

If you find yourself playing around with the Web Audio API frequently enough, you may have come to a point where you have an array of AudioNodes that need to be connected in series.

The first approach that comes to my mind is a simple for loop:
```javascript
var nodes = [...];
for (var i = 0; i < nodes.length - 1; i++) {
  nodes[i].connect(nodes[i + 1]);
}
nodes[nodes.length - 1].connect(audioContext.destination);
```

This is fine, and it gets the job done, but I always found it annoying having to
pull the last AudioNode out of the list to manually connect to the AudioDestination.
More importantly, it's just ugly. So, my preferred method of accomplishing this as of late is a quick use of the 
Array#reduce function, now standard in EcmaScript 5 (though if you're playing
with the Web Audio API, you don't need to worry about it. All browsers that support
the Audio API support ES5).

```javascript
var nodes = [...];
nodes.reduce(function (prev, cur) {
  prev.connect(cur);
  return cur;
}).connect(audioContext.destination);
```

Tell me that's not prettier! The 
[reduce](https://developer.mozilla.org/en-US/docs/JavaScript/Reference/Global_Objects/Array/Reduce) 
function is pretty straight-forward. The key point is that the return value of 
the call to `reduce` is the value returned by the last call of the reduce function, 
which, in the case above, is the last AudioNode in our list. So I can just chain the 
connection to the output onto the end of the reduce call.

That's it! This is a highly insignificant detail, but I feel better about my code 
when I like how it looks, and personally I think that the latter implementation 
above is much easier to understand.

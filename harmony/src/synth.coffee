class Synth

  # The number of programmable harmonics presented in the interface
  numHarmonics: 60
  
  # Width of a bar on the canvas
  barWidth: 10

  # Color of a gain bar on the canvas
  gainColor: '#999'

  # Color of a phase bar on the canvas
  phaseColor: '#777'

  # Context for audio processing
  audioContext: new webkitAudioContext()

  # Need to initialize the master chain, the data array, the user interface,
  # and the event handlers when instantiated.
  constructor: ->

    # This data array stores the gain values of individual harmonics
    @data = new Float32Array @numHarmonics + 1

    # This array stores the phase value corresponding to the data points above
    @phase = new Float32Array @numHarmonics + 1

    # Because the event listeners get intertwined, make sure the mouseHandler
    # is bound to this synth instance.
    @mouseHandler = @mouseHandler.bind this

    [@canvas, @context] = @drawInterface()
    @master = @buildMaster()
    @attachHandlers()

  # Initialize and connect the master effects chain through which the osc
  # will be routed. Expect to handle clipping.
  buildMaster: ->
    gain = @audioContext.createGainNode()
    gain.gain.value = 0.1
    gain.connect @audioContext.destination
    gain

  # Create and draw the interface on the page
  drawInterface: ->
    canvas = document.createElement 'canvas'
    canvas.width = @numHarmonics * @barWidth
    canvas.height = 200
    context = canvas.getContext '2d'
    document.body.appendChild canvas
    [canvas, context]

  # (Re)draws the bar at index i on the graph
  drawBar: (i) ->
    # Erase any previous bar
    @context.fillStyle = "#fff"
    @context.fillRect (i * @barWidth), 0, @barWidth, 200
    # Draw the new data point
    @context.fillStyle = @gainColor
    @context.fillRect (i * @barWidth), 100, @barWidth, -(@data[i + 1] * 100)
    # Draw the new phase point
    @context.fillStyle = @phaseColor
    @context.fillRect (i * @barWidth), 100, @barWidth, (@phase[i + 1] * 100)

  # Handle mouse input
  mouseHandler: (e) =>
    idx = Math.floor(e.offsetX / @barWidth)
    if @clickDirection is 1
      offset = if e.offsetY < 100 then e.offsetY else 100
      @data[idx + 1] = (100 - offset) / 100
    else if @clickDirection is -1
      offset = if e.offsetY > 100 then e.offsetY else 100
      @phase[idx + 1] = (offset - 100) / 100
    @drawBar idx
    @buildWaveTable()

  # Attach event handlers for mouse input on the interface. The user should be
  # able to click and drag across the canvas to assign values.
  attachHandlers: ->

    # When the user clicks, process the click and enable mouse movement
    @canvas.addEventListener 'mousedown', (e) =>
      @clickDirection = if e.offsetY > 100 then -1 else 1
      @mouseHandler e
      @canvas.addEventListener 'mousemove', @mouseHandler

    # When the user lets up the mouse, disable mouse movement
    @canvas.addEventListener 'mouseup', (e) =>
      @canvas.removeEventListener 'mousemove', @mouseHandler

  # Builds the wave table from the data points on the canvas
  buildWaveTable: () ->
    # Fourier coefficients arrays
    an = new Float32Array @phase.length
    bn = new Float32Array @data
    # Calculate the coefficients from @data with @phase offsets
    for i in [0..(@data.length - 1)]
      shift = @phase[i]
      radians = 2 * Math.PI * shift
      ai = (an[i] * Math.cos radians) - (bn[i] * Math.sin radians)
      bi = (an[i] * Math.sin radians) + (bn[i] * Math.cos radians)
      an[i] = ai
      bn[i] = bi
    # Build the wavetable
    @waveTable = @audioContext.createWaveTable an, bn

  # Triggers a noteOn from this synth at the frequency value supplied
  voiceOn: (note) ->
    # Translate a midi note value into a frequency
    freqFromMidi = (note) -> 440 * Math.pow 2, ((note - 69) / 12)
    # Assign a new oscillator
    osc = @audioContext.createOscillator()
    osc.setWaveTable @waveTable
    osc.frequency.value = freqFromMidi note
    osc.connect @master
    osc.noteOn 0
    # Save this node so we can disable it on keyup
    @nodes ||= {}
    @nodes[note] = osc

  # Disconnect the node playing at frequency freq
  voiceOff: (note) ->
    if @nodes[note]?
      @nodes[note].noteOff 0
      @nodes[note].disconnect()
      delete @nodes[note]
    
# Start up the synth demo on window load
window.addEventListener 'load', (e) ->
  synth = new Synth()

  # Decode a midi message and trigger the synth accordingly
  decodeMessage = (msg) ->
    cmd = msg.data[0] >> 4
    channel = msg.data[0] & 0xf
    note = msg.data[1]
    vel = msg.data[2]
    synth.voiceOn note if cmd is 9
    synth.voiceOff note if cmd is 8

  # This will be our midi message handler for the midikeys.js events
  midiMessageReceived = (msgs) ->
    decodeMessage msg for msg in msgs

  MIDIKeys.onmessage = midiMessageReceived

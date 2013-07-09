## Audio preparation

audioContext = new webkitAudioContext()

# Master effects chain
filterNode = audioContext.createBiquadFilter()
filterNode.type = 0
filterNode.frequency.value = 1200
filterNode.Q.value = 0.4

gainNode = audioContext.createGainNode()
gainNode.gain.value = 0.1

delay1Node = audioContext.createDelayNode()
delay1GainNode = audioContext.createGainNode()
delay1Node.delayTime.value = 0.45
delay1GainNode.gain.value = 0.2

delay2Node = audioContext.createDelayNode()
delay2GainNode = audioContext.createGainNode()
delay2Node.delayTime.value = 0.90
delay2GainNode.gain.value = 0.1

compressorNode = audioContext.createDynamicsCompressor()
compressorNode.threshold = -10.0
compressorNode.ratio = 3.0
compressorNode.knee = 2.5

filterNode.connect gainNode

gainNode.connect delay1Node
gainNode.connect delay2Node
gainNode.connect compressorNode

delay1Node.connect delay1GainNode
delay1GainNode.connect compressorNode

delay2Node.connect delay2GainNode
delay2GainNode.connect compressorNode

compressorNode.connect audioContext.destination

# A pentatonic scale defined in half-steps up from A2.
scale = [
   1,  4,  6,  9, 11,
  13, 16, 18, 21, 23,
  25, 28, 30, 33, 35,
  37, 40, 42, 45, 47,
  49
]

# Returns the frequency of the note i half-steps up from A2.
freq = (i) -> 110 * Math.pow 2, (i / 12)

# The set to contain all playable buffers throughout the sequence of the game.
buffers = []

# Fill the buffer array with sine wav shots along the Bb scale.
for i in [0..(scale.length - 1)]
  buffer = audioContext.createBuffer 1, 32768, audioContext.sampleRate
  data = buffer.getChannelData 0
  for j in [0..(data.length - 1)]
    # Frequency determination
    f = freq scale[i]
    data[j] = Math.sin(2 * Math.PI * j * f / audioContext.sampleRate)
    # Amplitude modulation
    data[j] = data[j] * Math.pow (1 - (j / data.length)), 2
  buffers.push buffer

## Game implementation

class GameOfLife

  # number of rows and columns to populate
  gridSize: 42

  # size of the canvas
  canvasSize: 400

  # color to use for the lines on the grid
  lineColor: '#fff'

  # color to use for live cells on the grid
  liveColor: '#9fe9fc'

  # color to use for dead cells on the grid
  deadColor: '#fff'

  # initial probability that a given cell will be live
  initialLifeProbability: 0.4

  # In the constructor for the GameOfLife class we extend the game with any
  # passed in options, set the initial state of the world, and start the
  # circleOfLife.
  constructor: (options = {}) ->
    this[key] = value for key, value of options
    @world    = @createWorld()
    do @circleOfLife

    @nextTick = 1
    @metronome = new Metronome 220, 1
    @prepareRedraw()
    @metronome.start()
    @metronome.addListener "t#{@gridSize}", () =>
      @world = @travelWorld (cell) =>
        @resolveNextGeneration cell
      @nextTick = 1
      @prepareRedraw()
      @metronome.startFrom 1

    null

  # We iterate the world passing a callback that populates it with initial
  # organisms based on the initialLifeProbability.
  createWorld: ->
    @travelWorld (cell) =>
      cell.live = Math.random() < @initialLifeProbability
      cell

  # This is the main run loop for the game. At each step we iterate through
  # the world drawing each cell and resolving the next generation for that
  # cell. The results of this process become the state of the world for the
  # next generation.
  circleOfLife: =>
    @world = @travelWorld (cell) =>
      cell = @world[cell.row][cell.col]
      @draw cell
      @resolveNextGeneration cell

  # Load the metronome with redraw events such that on each tick, the next
  # column is redrawn.
  prepareRedraw: =>
    for row in [0...@gridSize]
      do (row) =>
        @metronome.addListener "t#{@nextTick++}", () =>
          for col in [0...@gridSize]
            do (col) =>
              cell = @world[row][col]
              @draw cell
              @fire buffers[col/2] if cell.live and col % 2 is 0
          true

  fire: (buffer) ->
    # Load the buffer
    node = audioContext.createBufferSource()
    node.buffer = buffer
    # Randomized spatial orientation
    panner = audioContext.createPanner()
    panner.setPosition (0.5 - Math.random()), 0, 0.1
    # Randomized gain
    gain = audioContext.createGainNode()
    gain.gain.value = Math.random()
    # Go!
    node.connect gain
    gain.connect panner
    panner.connect filterNode
    node.noteOn 0

  # Given a cell we determine if it should be live or dead in the next
  # generation based on Conway's rules.
  resolveNextGeneration: (cell) ->
    # Determine the number of living neighbors.
    count = @countNeighbors cell
    # Make a copy of the cells current state
    cell = row: cell.row, col: cell.col, live: cell.live
    # A living cell dies if it has less than two or greater than three living neighbors
    # A nonliving cell reproduces if it has exactly 3 living neighbors
    if cell.live or count is 3
      cell.live = 1 < count < 4
    cell

  # Count the living neighbors of a given cell by iterating around the clock
  # and checking each neighbor. The helper function isAlive allows for safely
  # checking without worrying about the boundaries of the world.
  countNeighbors: (cell) ->
    neighbors = 0
    # Iterate around each neighbor of the cell and check for signs of life.
    # If the neighbor is alive increment the neighbors counter.
    for row in [-1..1]
      for col in [-1..1] when (row or col) and @isAlive cell.row + row, cell.col + col
        ++neighbors
    neighbors

  # Safely check if there is a living cell at the specified coordinates without
  # overflowing the bounds of the world
  isAlive: (row, col) -> !!@world[row]?[col]?.live

  # Iterate through the grid of the world and fire the passed in callback at
  # each location.
  travelWorld: (callback) ->
    for row in [0...@gridSize]
      for col in [0...@gridSize]
        callback.call this, row: row, col: col

  # Draw a given cell
  draw: (cell) ->
    @context  ||= @createDrawingContext()
    @cellsize ||= @canvasSize/@gridSize
    coords = [cell.row * @cellsize, cell.col * @cellsize, @cellsize, @cellsize]
    @context.strokeStyle = @lineColor
    @context.strokeRect.apply @context, coords
    @context.fillStyle = if cell.live then @liveColor else @deadColor
    @context.fillRect.apply @context, coords

  # Create the canvas drawing context.
  createDrawingContext: ->
    canvas        = document.createElement 'canvas'
    canvas.width  = @canvasSize
    canvas.height = @canvasSize
    document.body.appendChild canvas
    canvas.getContext '2d'

# Start on load
window.addEventListener 'load', () ->
  game = new GameOfLife {}

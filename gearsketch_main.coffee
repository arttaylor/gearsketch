# By Frank Leenaars
# University of Twente - Department of Instructional Technology
"use strict"

# imports
Point = window.gearsketch.Point
Util = window.gearsketch.Util
Gear = window.gearsketch.model.Gear
ArcSegment = window.gearsketch.model.ArcSegment
LineSegment = window.gearsketch.model.LineSegment
Chain = window.gearsketch.model.Chain
Board = window.gearsketch.model.Board

# -- constants --
FPS = 60

# ---------------------------
# -------- GearSketch -------
# ---------------------------
class GearSketch
  # -- imported constants --
  MODULE = Util.MODULE
  AXIS_RADIUS = Util.AXIS_RADIUS
  MIN_GEAR_TEETH = Util.MIN_GEAR_TEETH

  BUTTON_INFO = [
    ["gearButton", "GearIcon.png"]
    ["chainButton", "ChainIcon.png"]
    ["momentumButton", "MomentumIcon.png"]
    ["playButton", "PlayIcon.png"]
    ["helpButton", "HelpIcon.png"]
  ]

  MovementAction =
    PEN_DOWN: "penDown"
    PEN_UP: "penUp"
    PEN_TAP: "penTap"

  MovementType =
    STRAIGHT: "straight"
    CIRCLE: "circle"

  buttons: {}
  loadedButtons: 0
  areButtonsLoaded: false
  selectedButton: BUTTON_INFO[0][0]

  gearImages: {}

  isPenDown: false
  stroke: []
  offset: new Point()

  board: new Board()

  # usage demo
  pointerLocation: new Point()
  currentDemoMovement: 0
  movementCompletion: 0
  restTimer: 0

  constructor: ->
    @loadButtons()
    @loadDemoPointer()
    @canvas = document.getElementById("gearsketch_canvas")
    @isDemoPlaying = false
    @updateCanvasSize()
    @addCanvasListeners()
    @lastUpdateTime = new Date().getTime()
    @updateAndDraw()
    Util.tempRegisterDrawMethod(this, @draw)
#    for x in [0...3]
#      for y in [0...3]
#        @board.addGear(new Gear(new Point(200 + x * 120, 200 + y * 120), 0, 20))


  buttonLoaded: ->
    @loadedButtons++
    if @loadedButtons is BUTTON_INFO.length
      @areButtonsLoaded = true

  loadButtons: ->
    x = y = 20
    for [name, file] in BUTTON_INFO
      button = new Image()
      button.name = name
      button.onload = => @buttonLoaded()
      button.src = file
      button.location = new Point(x, y)
      button.padding = 3
      @buttons[name] = button
      x += 80

  loadDemoPointer: ->
    image = new Image()
    image.onload = => @pointerImage = image
    image.src = "hand.png"

  # Input callback methods
  addCanvasListeners: ->
    @addCanvasListener("mousedown", @forwardPenDownEvent)
    @addCanvasListener("touchstart", @forwardPenDownEvent)
    @addCanvasListener("mousemove", @forwardPenMoveEvent)
    @addCanvasListener("touchmove", @forwardPenMoveEvent)
    @addCanvasListener("mouseup", @forwardPenUpEvent)
    @addCanvasListener("touchend", @forwardPenUpEvent)

  addCanvasListener: (event, callbackFunction) ->
    @canvas.addEventListener(event, ((e) => callbackFunction.call(this, e)), false)

  forwardPenDownEvent: (event) ->
    event.preventDefault()
    if @isDemoPlaying
      @stopDemo()
    else
      @handlePenDown(event.pageX, event.pageY)

  forwardPenMoveEvent: (event) ->
    event.preventDefault()
    unless @isDemoPlaying
      @handlePenMove(event.pageX, event.pageY)

  forwardPenUpEvent: (event) ->
    event.preventDefault()
    unless @isDemoPlaying
      @handlePenUp()

  handlePenDown: (x, y) ->
    point = new Point(x, y)
    if @isPenDown
      # pen released outside of canvas
      @handlePenUp()
    else
      button = @getButtonAt(x, y)
      if button
        if button.name is "helpButton"
          @playDemo()
        else
          @selectedButton = button.name
      else if @selectedButton is "gearButton"
        @selectedGear = @board.getGearAt(point)
        if @selectedGear
          @offset = point.minus(@selectedGear.location)
        else
          @stroke.push(point)
        @isPenDown = true
      else if @selectedButton is "chainButton"
        @stroke.push(point)
        @isPenDown = true
      else if @selectedButton is "momentumButton"
        @selectedGear = @board.getGearAt(point)
        if @selectedGear
          @board.removeMomentum(@selectedGear)
          @selectedGearMomentum = @calculateMomentumFromCoords(@selectedGear, x, y)
        @isPenDown = true

  handlePenMove: (x, y) ->
    point = new Point(x, y)
    if @isPenDown
      if @selectedButton is "gearButton"
        if @selectedGear
          goalLocation = point.minus(@offset)
          canPlaceGear = @board.placeGear(@selectedGear, goalLocation)
          if canPlaceGear
            @goalLocationGear = null
          else
            @goalLocationGear =
              new Gear(goalLocation, @selectedGear.rotation, @selectedGear.numberOfTeeth, @selectedGear.id)
        else
          @stroke.push(point)
      else if @selectedButton is "chainButton"
        @stroke.push(point)
      else if @selectedButton is "momentumButton"
        if @selectedGear
          @selectedGearMomentum = @calculateMomentumFromCoords(@selectedGear, x, y)

  handlePenUp: ->
    if @isPenDown
      if @selectedButton is "gearButton"
        unless @selectedGear
          @processGearStroke()
      else if @selectedButton is "chainButton"
        @processChainStroke()
      else if @selectedButton is "momentumButton"
        if @selectedGear
          MIN_MOMENTUM = 0.2
          if Math.abs(@selectedGearMomentum) > MIN_MOMENTUM
            @board.setMomentum(@selectedGear, @selectedGearMomentum)
          else
            @board.setMomentum(@selectedGear, 0)
        @selectedGearMomentum = 0
      @selectedGear = null
      @goalLocationGear = null
      @isPenDown = false

  isButtonAt: (x, y, button) ->
    x > button.location.x and
    x < button.location.x + button.width + 2 * button.padding and
    y > button.location.y and
    y < button.location.y + button.height + 2 * button.padding

  getButtonAt: (x, y) ->
    for own buttonName, button of @buttons
      if @isButtonAt(x, y, button)
        return button
    null

  normalizeStroke: (stroke) ->
    MIN_POINT_DISTANCE = 10
    normalizedStroke = []
    if stroke.length > 0
      [p1, strokeTail...] = stroke
      normalizedStroke.push(p1)
      for p2 in strokeTail
        if p1.distance(p2) > MIN_POINT_DISTANCE
          normalizedStroke.push(p2)
          p1 = p2
    normalizedStroke

  createGearFromStroke: (stroke) ->
    if stroke.length > 0
      minX = Number.MAX_VALUE
      maxX = Number.MIN_VALUE
      minY = Number.MAX_VALUE
      maxY = Number.MIN_VALUE
      sumX = 0
      sumY = 0
      for p in stroke
        sumX += p.x
        sumY += p.y
        minX = Math.min(minX, p.x)
        maxX = Math.max(maxX, p.x)
        minY = Math.min(minY, p.y)
        maxY = Math.max(maxY, p.y)
        width = maxX - minX
        height = maxY - minY
        t = Math.floor(0.5 * (width + height) / MODULE)

      # find area, based on http://stackoverflow.com/questions/451426
      # /how-do-i-calculate-the-surface-area-of-a-2d-polygon
      doubleArea = 0
      for i in [0...stroke.length]
        j = (i + 1) % stroke.length
        doubleArea += stroke[i].x * stroke[j].y
        doubleArea -= stroke[i].y * stroke[j].x

      # create a new gear if the stroke is sufficiently circle-like and large enough
      area = Math.abs(doubleArea) / 2
      radius = 0.25 * ((maxX - minX) + (maxY - minY))
      idealTrueAreaRatio = (Math.PI * Math.pow(radius, 2)) / area
      if idealTrueAreaRatio > 0.80 and idealTrueAreaRatio < 1.20 and t > MIN_GEAR_TEETH
        x = sumX / stroke.length
        y = sumY / stroke.length
        return new Gear(new Point(x, y), 0, t)
    null

  removeStrokedGears: (stroke) ->
    for own id, gear of @board.getGears()
      if Util.getPointPathDistance(gear.location, stroke, false) < gear.innerRadius
        @board.removeGear(gear)

  processGearStroke: ->
    normalizedStroke = @normalizeStroke(@stroke)
    gear = @createGearFromStroke(normalizedStroke)
    if gear?
      isGearAdded = @board.addGear(gear)
      if isGearAdded and !(gear.numberOfTeeth of @gearImages)
        @addGearImage(gear)
    else
      @removeStrokedGears(normalizedStroke)
    @stroke = []

  gearImageLoaded: (numberOfTeeth, image) ->
    @gearImages[numberOfTeeth] = image

  addGearImage: (gear) ->
    # draw gear on temporary canvas
    gearCanvas = document.createElement("canvas")
    size = 2 * (gear.outerRadius + MODULE) # slightly larger than gear diameter
    gearCanvas.height = size
    gearCanvas.width = size
    ctx = gearCanvas.getContext("2d")
    gearCopy = new Gear(new Point(0.5 * size, 0.5 * size), 0, gear.numberOfTeeth, gear.id)
    @drawGear(ctx, gearCopy)

    # convert canvas to png
    image = new Image()
    image.onload = => @gearImageLoaded(gear.numberOfTeeth, image)
    image.src = gearCanvas.toDataURL("image/png")

  # TODO: should stroke chain intersection be exmined instead?
  removeStrokedChains: (stroke) ->
    lineSegment = new LineSegment(stroke[0], stroke[stroke.length - 1])
    for own id, chain of @board.getChains()
      # TODO: remove + 2 when analytical segment distance methods are implemented
      if chain.getDistanceToLineSegment(lineSegment) < (Util.EPSILON + 2)
        @board.removeChain(chain)

  processChainStroke: ->
    normalizedStroke = @normalizeStroke(@stroke)
    @stroke = []
    gearsInChain = Util.findGearsInsidePolygon(normalizedStroke, @board.getGears())
    if normalizedStroke.length >= 3 and gearsInChain.length > 0
      chain = new Chain(normalizedStroke)
      @board.addChain(chain)
    else if normalizedStroke.length >= 2
      @removeStrokedChains(normalizedStroke)

  calculateMomentumFromCoords: (gear, x, y) ->
    angle = Math.atan2(y - gear.location.y, x - gear.location.x)
    angleFromTop = angle + 0.5 * Math.PI
    if angleFromTop < Math.PI
      angleFromTop
    else
      angleFromTop - 2 * Math.PI

  # -- updating --
  updateAndDraw: =>
    setTimeout((=>
      requestAnimationFrame(@updateAndDraw)
      @update()
      @draw()
    ), 1000 / FPS)

  update: =>
    updateTime = new Date().getTime()
    delta = updateTime - @lastUpdateTime
    if @selectedButton is "playButton"
      @board.rotateAllTurningObjects(delta / 1000)
    if @isDemoPlaying
      @updateDemo(delta)
    @lastUpdateTime = updateTime

  # -- rendering --
  drawGear: (ctx, gear, color = "black") ->
    {x, y} = gear.location
    rotation = gear.rotation
    numberOfTeeth = gear.numberOfTeeth

    gearImage = @gearImages[gear.numberOfTeeth]
    if color is "black" and gearImage?
      # use predrawn image instead of drawing it again
      gearImage = @gearImages[gear.numberOfTeeth]
      ctx.save()
      ctx.translate(x, y)
      ctx.rotate(rotation)
      ctx.drawImage(gearImage, -0.5 * gearImage.width, -0.5 * gearImage.height)
      ctx.restore()
      return

    # draw teeth
    angleStep = 2 * Math.PI / numberOfTeeth
    innerPoints = []
    outerPoints = []
    for i in [0...numberOfTeeth]
      for r in [0...4]
        if r is 0 or r is 3
          innerPoints.push(Point.polar((i + 0.25 * r) * angleStep, gear.innerRadius))
        else
          outerPoints.push(Point.polar((i + 0.25 * r) * angleStep, gear.outerRadius))

    ctx.save()
    ctx.fillStyle = "rgba(255, 255, 255, 0.8)"
    ctx.strokeStyle = color
    ctx.lineWidth = 2
    ctx.translate(x, y)
    ctx.rotate(rotation)
    ctx.beginPath()
    ctx.moveTo(gear.innerRadius, 0)
    for i in [0...numberOfTeeth * 2]
      if i % 2 is 0
        ctx.lineTo(innerPoints[i].x, innerPoints[i].y)
        ctx.lineTo(outerPoints[i].x, outerPoints[i].y)
      else
        ctx.lineTo(outerPoints[i].x, outerPoints[i].y)
        ctx.lineTo(innerPoints[i].x, innerPoints[i].y)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()

    # draw axis
    ctx.beginPath()
    ctx.moveTo(AXIS_RADIUS, 0)
    ctx.arc(0, 0, AXIS_RADIUS, 0, 2 * Math.PI, true)
    ctx.closePath()
    ctx.stroke()

    # draw rotation indicator line
    ctx.beginPath()
    ctx.moveTo(AXIS_RADIUS, 0)
    ctx.lineTo(gear.innerRadius, 0)
    ctx.closePath()
    ctx.stroke()
    ctx.restore()

  drawButton: (ctx, button) ->
    {x, y} = button.location
    padding = button.padding
    ctx.save()
    ctx.translate(x, y)
    ctx.beginPath()
    ctx.rect(0, 0, button.width + 2 * padding, button.height + 2 * padding)
    if button.name is @selectedButton
      ctx.fillStyle = "rgba(50, 150, 255, 0.8)"
    else
      ctx.fillStyle = "rgba(255, 255, 255, 0.8)"
    ctx.fill()
    ctx.lineWidth = 1
    ctx.strokeStyle = "black"
    ctx.stroke()
    ctx.drawImage(button, padding, padding)
    ctx.restore()

  drawMomentum: (ctx, gear, momentum, color = "red") ->
    pitchRadius = gear.pitchRadius
    top = new Point(gear.location.x, gear.location.y - pitchRadius)
    ctx.save()
    ctx.lineWidth = 5
    ctx.lineCap = "round"
    ctx.strokeStyle = color
    ctx.translate(top.x, top.y)

    # draw arc
    ctx.beginPath()
    ctx.arc(0, pitchRadius, pitchRadius, -0.5 * Math.PI, momentum - 0.5 * Math.PI, momentum < 0)
    ctx.stroke()

    # draw arrow head
    length = 15
    angle = 0.2 * Math.PI
    headX = -Math.cos(momentum + 0.5 * Math.PI) * pitchRadius
    headY = pitchRadius - Math.sin(momentum + 0.5 * Math.PI) * pitchRadius
    head = new Point(headX, headY)
    sign = momentum / Math.abs(momentum)
    p1 = head.minus(Point.polar(momentum + angle, sign * length))
    ctx.beginPath()
    ctx.moveTo(headX, headY)
    ctx.lineTo(p1.x, p1.y)
    ctx.stroke()
    p2 = head.minus(Point.polar(momentum - angle, sign * length))
    ctx.beginPath()
    ctx.moveTo(headX, headY)
    ctx.lineTo(p2.x, p2.y)
    ctx.stroke()
    ctx.restore()

  drawChain: (ctx, chain) ->
    ctx.save()
    ctx.lineWidth = Chain.WIDTH
    ctx.lineCap = "round"
    #ctx.strokeStyle = "rgba(0, 0, 255, 0.8)"
    ctx.strokeStyle = "rgb(0, 0, 255)"
    ctx.moveTo(chain.segments[0].start.x, chain.segments[0].start.y)
    for segment in chain.segments
      if segment instanceof ArcSegment
        isCounterClockwise = (segment.direction is Util.Direction.COUNTER_CLOCKWISE)
        ctx.beginPath()
        ctx.arc(segment.center.x, segment.center.y, segment.radius, segment.start, segment.end, isCounterClockwise)
        ctx.stroke()
      else
        ctx.beginPath()
        ctx.moveTo(segment.start.x, segment.start.y)
        ctx.lineTo(segment.end.x, segment.end.y)
        ctx.stroke()
    ctx.fillStyle = "white"
    for point in chain.findPointsOnChain(25)
      ctx.beginPath()
      ctx.arc(point.x, point.y, 3, 0, 2 * Math.PI, true)
      ctx.fill()
    ctx.restore()

  drawDemoPointer: (ctx, location) ->
    ctx.drawImage(@pointerImage, location.x - 0.5 * @pointerImage.width, location.y)

  draw: ->
    if @canvas.getContext?
      @updateCanvasSize()
      ctx = @canvas.getContext('2d')
      ctx.clearRect(0, 0, @canvas.width, @canvas.height)

      # draw gears
      sortedGears = @board.getGearsSortedByGroupsAndLevel()
      arrowsToDraw = []
      for i in [0...sortedGears.length]
        gear = sortedGears[i]
        group = @board.getGroup(gear)
        level = @board.getLevel(gear)
        momentum = @board.getMomentum(gear)
        if gear is @selectedGear and @goalLocationGear
          @drawGear(ctx, gear, "grey")
          if momentum
            arrowsToDraw.push([gear, momentum, "grey"])
        else
          @drawGear(ctx, gear)
          if momentum
            arrowsToDraw.push([gear, momentum, "red"])

        # draw chains and arrows when all the gears in current group on current level are drawn
        shouldDrawChainsAndArrows =
          (i is sortedGears.length - 1) or
          @board.getGroup(gear) isnt @board.getGroup(sortedGears[i + 1]) or
          @board.getLevel(gear) isnt @board.getLevel(sortedGears[i + 1])
        if shouldDrawChainsAndArrows
          for chain in @board.getChainsInGroupOnLevel(group, level)
            @drawChain(ctx, chain)
          for arrow in arrowsToDraw
            @drawMomentum(ctx, arrow[0], arrow[1], arrow[2])
          arrowsToDraw = []

      # draw goalLocationGear
      if @goalLocationGear
        @drawGear(ctx, @goalLocationGear, "red")

      # draw selected gear momentum
      if @selectedGear and @selectedGearMomentum
        @drawMomentum(ctx, @selectedGear, @selectedGearMomentum)

      # draw stroke
      if @stroke.length > 0
        ctx.save()
        if @selectedButton is "gearButton"
          ctx.strokeStyle = "black"
          ctx.lineWidth = 2
        else # chain stroke
          ctx.strokeStyle = "blue"
          ctx.lineWidth = 4
        ctx.beginPath()
        ctx.moveTo(@stroke[0].x, @stroke[0].y)
        for i in [1...@stroke.length]
          ctx.lineTo(@stroke[i].x, @stroke[i].y)
        ctx.stroke()
        ctx.restore()

      # draw buttons
      if @areButtonsLoaded
        for own buttonName of @buttons
          @drawButton(ctx, @buttons[buttonName])

      # draw demo text and pointer
      if @isDemoPlaying and @pointerImage
        ctx.save()
        ctx.fillStyle = "black"
        ctx.font = "bold 20px Arial"
        ctx.fillText("Click anywhere to stop the demonstration.", 20, 120)
        @drawDemoPointer(ctx, @pointerLocation)
        ctx.restore()

  updateCanvasSize: () ->
    @canvas.width = window.innerWidth
    @canvas.height = window.innerHeight
    @buttons["helpButton"].location.x =
      Math.max(@canvas.width - 100, @buttons["playButton"].location.x + 80)

  # -- usage demo --
  loadDemoMovements: ->
    @demoMovements = [
      from: @getButtonCenter("helpButton")
      to: @getButtonCenter("gearButton")
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_TAP
      type: MovementType.STRAIGHT
      duration: 2000
    ,
      from: @getButtonCenter("gearButton")
      to: new Point(150, 200)
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      from: new Point(150, 200)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.CIRCLE
      radius: 100
      duration: 1500
    ,
      from: new Point(150, 200)
      to: new Point(350, 300)
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      from: new Point(350, 300)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.CIRCLE
      radius: 40
      duration: 1000
    ,
      from: new Point(350, 300)
      to: new Point(350, 340)
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 500
    ,
      from: new Point(350, 340)
      to: new Point(150, 300)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      from: new Point(150, 300)
      to: new Point(400, 180)
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      from: new Point(400, 180)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.CIRCLE
      radius: 80
      duration: 1000
    ,
      from: new Point(400, 180)
      to: new Point(400, 260)
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 500
    ,
      from: new Point(400, 260)
      to: new Point(260, 260)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      from: new Point(260, 260)
      to: @getButtonCenter("momentumButton")
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_TAP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      from: @getButtonCenter("momentumButton")
      to: new Point(260, 180)
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      from: new Point(260, 180)
      to: new Point(300, 200)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      from: new Point(300, 200)
      to: @getButtonCenter("playButton")
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_TAP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      from: @getButtonCenter("playButton")
      to: @getButtonCenter("gearButton")
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_TAP
      type: MovementType.STRAIGHT
      duration: 3000
    ,
      from: @getButtonCenter("gearButton")
      to: new Point(20, 350)
      atStart: MovementAction.PEN_UP
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      from: new Point(20, 350)
      to: new Point(400, 200)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 2000
    ]

  getButtonCenter: (buttonName) ->
    button = @buttons[buttonName]
    buttonCorner = new Point(button.location.x, button.location.y)
    buttonCorner.plus(new Point(0.5 * button.width + button.padding, 0.5 * button.height + button.padding))

  updateDemo: (delta) ->
    # check if resting or if last movement completed
    if @restTimer > 0
      @restTimer = Math.max(@restTimer - delta, 0)
      return
    else if @currentDemoMovement is @demoMovements.length
      @stopDemo()
      return

    # advance movement
    movement = @demoMovements[@currentDemoMovement]
    if @movementCompletion is 0
      @pointerLocation = movement.from.clone()
      if movement.atStart is MovementAction.PEN_DOWN
        @handlePenDown(@pointerLocation.x, @pointerLocation.y)
    if @movementCompletion < 1
      @movementCompletion = Math.min(1, @movementCompletion + delta / movement.duration)
      @updatePointerLocation(movement, @movementCompletion)
      @handlePenMove(@pointerLocation.x, @pointerLocation.y)
    if @movementCompletion is 1
      if movement.atEnd is MovementAction.PEN_TAP
        @handlePenDown(@pointerLocation.x, @pointerLocation.y)
        @handlePenUp()
      else if movement.atEnd is MovementAction.PEN_UP
        @handlePenUp()
      @restTimer = 500
      @movementCompletion = 0
      @currentDemoMovement++

  updatePointerLocation: (movement, movementCompletion) ->
    if movement.type is MovementType.STRAIGHT
      delta = movement.to.minus(movement.from)
      @pointerLocation = movement.from.plus(delta.times(movementCompletion))
    else if movement.type is MovementType.CIRCLE
      center = new Point(movement.from.x , movement.from.y + movement.radius)
      @pointerLocation = center.plus(Point.polar(Math.PI - (movementCompletion - 0.25) * 2 * Math.PI, movement.radius))

  playDemo: ->
    @loadDemoMovements() # load these on each play in case canvas size changed
    @boardBackup = @board.saveBoard()
    @board.clearBoard()
    @currentDemoMovement = 0
    @movementCompletion = 0
    @isDemoPlaying = true

  stopDemo: ->
    @isDemoPlaying = false
    @restTimer = 0
    @stroke = []
    @selectedGear = null
    @selectedIcon = "gearIcon"
    @board.restoreBoardAfterDemo(@boardBackup)

window.gearsketch.GearSketch = GearSketch
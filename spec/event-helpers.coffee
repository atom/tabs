{$} = require 'atom-space-pen-views'

module.exports.triggerMouseEvent = (type, target, {which, ctrlKey}={}) ->
  event = new MouseEvent(type, {bubbles: true, cancelable: true})
  Object.defineProperty(event, 'which', get: -> which) if which?
  Object.defineProperty(event, 'ctrlKey', get: -> ctrlKey) if ctrlKey?
  Object.defineProperty(event, 'target', get: -> target)
  Object.defineProperty(event, 'srcObject', get: -> target)
  spyOn(event, "preventDefault")

  target.dispatchEvent(event)

  event

module.exports.buildDragEvents = (dragged, dropTarget) ->
  dataTransfer =
    data: {}
    setData: (key, value) -> @data[key] = "#{value}" # Drag events stringify data values
    getData: (key) -> @data[key]

  dragStartEvent = $.Event()
  dragStartEvent.target = dragged
  dragStartEvent.originalEvent = {dataTransfer}

  dropEvent = $.Event()
  dropEvent.target = dropTarget
  dropEvent.originalEvent = {dataTransfer}

  [dragStartEvent, dropEvent]

module.exports.buildWheelEvent = (delta) ->
  new WheelEvent("mousewheel", wheelDeltaY: delta)

module.exports.buildWheelPlusShiftEvent = (delta) ->
  new WheelEvent("mousewheel", wheelDeltaY: delta, shiftKey: true)

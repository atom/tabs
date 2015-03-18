{$} = require 'atom-space-pen-views'

module.exports.triggerMouseDownEvent = (target, {which, ctrlKey}) ->
  event =
    type: 'mousedown'
    which: which
    ctrlKey: ctrlKey
    preventDefault: jasmine.createSpy("preventDefault")
  $(target).trigger(event)

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
  $.Event "wheel", {originalEvent: {wheelDelta: delta}}

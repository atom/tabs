{closest, indexOf, matches} = require './html-helpers'

module.exports =

  activate: ->
    @view = document.createElement 'div'
    atom.views.getView(atom.workspace).appendChild @view
    @view.classList.add 'tabs-layout-overlay'

  deactivate: ->
    @view.parentElement?.removeChild @view

  test: {}

  drag: (e) ->
    @lastCoords = e
    pane = @getPaneAt e
    itemView = @getItemViewAt e
    if pane? and itemView?
      coords = if not (@isOnlyTabInPane(pane, e.target) or pane.getItems().length is 0)
        [e.clientX, e.clientY]
      @lastSplit = @updateView itemView, coords
    else
      @disableView()

  end: (e) ->
    @disableView()
    return unless @getItemViewAt @lastCoords
    target = @getPaneAt @lastCoords
    return unless target?
    toPane = switch @lastSplit
      when 'left'  then target.splitLeft()
      when 'right' then target.splitRight()
      when 'up'    then target.splitUp()
      when 'down'  then target.splitDown()
    tab = e.target
    toPane ?= target
    fromPane = @paneForTab tab
    return if toPane is fromPane
    item = @itemForTab tab
    fromPane.moveItemToPane item, toPane
    toPane.activateItem item
    toPane.activate()

  getElement: ({clientX, clientY}, selector = '*') ->
    closest document.elementFromPoint(clientX, clientY), selector

  getItemViewAt: (coords) ->
    @test.itemView or @getElement coords, '.item-views'

  getPaneAt: (coords) ->
    @test.pane or @getElement(@lastCoords, 'atom-pane')?.getModel()

  paneForTab: (tab) ->
    tab.parentElement.pane

  itemForTab: (tab) ->
    @paneForTab(tab).getItems()[indexOf(tab)]

  isOnlyTabInPane: (pane, tab) ->
    pane.getItems().length is 1 and pane is @paneForTab tab

  normalizeCoords: ({left, top, width, height}, [x, y]) ->
    [(x-left)/width, (y-top)/height]

  splitType: ([x, y]) ->
    if      x < 1/3 then 'left'
    else if x > 2/3 then 'right'
    else if y < 1/3 then 'up'
    else if y > 2/3 then 'down'

  boundsForSplit: (split) ->
    [x, y, w, h] = switch split
      when 'left'   then [0,   0,   0.5, 1  ]
      when 'right'  then [0.5, 0,   0.5, 1  ]
      when 'up'     then [0,   0,   1,   0.5]
      when 'down'   then [0,   0.5, 1,   0.5]
      else               [0,   0,   1,   1  ]

  innerBounds: ({left, top, width, height}, [x, y, w, h]) ->
    left += x*width
    top  += y*height
    width  *= w
    height *= h
    {left, top, width, height}

  updateViewBounds: ({left, top, width, height}) ->
    @view.style.left = "#{left}px"
    @view.style.top = "#{top}px"
    @view.style.width = "#{width}px"
    @view.style.height = "#{height}px"

  updateView: (pane, coords) ->
    @view.classList.add 'visible'
    rect = @test.rect or pane.getBoundingClientRect()
    split = if coords then @splitType @normalizeCoords rect, coords
    @updateViewBounds @innerBounds rect, @boundsForSplit split
    split

  disableView: ->
    @view.classList.remove 'visible'

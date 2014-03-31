BrowserIpc = require('remote').require('ipc')
RendererIpc = require('ipc')

{$, View} = require 'atom'
_ = require 'underscore-plus'
TabView = require './tab-view'

module.exports =
class TabBarView extends View
  @content: ->
    @ul tabindex: -1, class: "list-inline tab-bar inset-panel"

  initialize: (@pane) ->
    @command 'tabs:close-tab', => @closeTab()
    @command 'tabs:close-other-tabs', => @closeOtherTabs()
    @command 'tabs:close-tabs-to-right', => @closeTabsToRight()

    @on 'dragstart', '.sortable', @onDragStart
    @on 'dragend', '.sortable', @onDragEnd
    @on 'dragleave', @onDragLeave
    @on 'dragover', @onDragOver
    @on 'drop', @onDrop

    @paneContainer = @pane.getContainer()
    @addTabForItem(item) for item in @pane.getItems()

    @subscribe @paneContainer, 'pane:removed', (pane) =>
      @unsubscribe() if pane is @pane

    @subscribe @pane, 'pane:item-added', (e, item, index) =>
      @addTabForItem(item, index)
      true

    @subscribe @pane, 'pane:item-moved', (e, item, index) =>
      @moveItemTabToIndex(item, index)
      true

    @subscribe @pane, 'pane:item-removed', (e, item) =>
      @removeTabForItem(item)
      true

    @subscribe @pane, 'pane:active-item-changed', =>
      @updateActiveTab()
      true

    @updateActiveTab()

    @on 'mousedown', '.tab', ({target, which, ctrlKey}) =>
      tab = $(target).closest('.tab').view()
      if which is 3 or (which is 1 and ctrlKey is true)
        @find('.right-clicked').removeClass('right-clicked')
        tab.addClass('right-clicked')
        false
      else if which is 2
        @pane.destroyItem(tab.item)
        false

    @on 'dblclick', ({target}) =>
      if target is @[0]
        @pane.trigger('application:new-file')
        false

    @on 'click', '.tab .close-icon', ({target}) =>
      tab = $(target).closest('.tab').view()
      @pane.destroyItem(tab.item)
      false

    @on 'click', '.tab', ({target, which}) =>
      tab = $(target).closest('.tab').view()
      if which is 1 and not target.classList.contains('close-icon')
        @pane.showItem(tab.item)
        @pane.focus()
        false

    RendererIpc.on('tab:dropped', @onDropOnOtherWindow)

    @pane.prepend(this)

  beforeRemove: ->
    RendererIpc.removeListener('tab:dropped', @onDropOnOtherWindow)

  addTabForItem: (item, index) ->
    @insertTabAtIndex(new TabView(item, @pane), index)

  moveItemTabToIndex: (item, index) ->
    tab = @tabForItem(item)
    tab.detach()
    @insertTabAtIndex(tab, index)

  insertTabAtIndex: (tab, index) ->
    followingTab = @tabAtIndex(index) if index?
    if followingTab
      tab.insertBefore(followingTab)
    else
      @append(tab)
    tab.updateTitle()

  removeTabForItem: (item) ->
    @tabForItem(item).remove()
    tab.updateTitle() for tab in @getTabs()

  getTabs: ->
    @children('.tab').toArray().map (elt) -> $(elt).view()

  tabAtIndex: (index) ->
    @children(".tab:eq(#{index})").view()

  tabForItem: (item) ->
    _.detect @getTabs(), (tab) -> tab.item is item

  setActiveTab: (tabView) ->
    if tabView? and not tabView.hasClass('active')
      @find(".tab.active").removeClass('active')
      tabView.addClass('active')

  updateActiveTab: ->
    @setActiveTab(@tabForItem(@pane.activeItem))

  closeTab: (tab) ->
    tab ?= @children('.right-clicked').view()
    @pane.destroyItem(tab.item)

  closeOtherTabs: ->
    tabs = @getTabs()
    active = @children('.right-clicked').view()
    return unless active?
    @closeTab tab for tab in tabs when tab isnt active

  closeTabsToRight: ->
    tabs = @getTabs()
    active = @children('.right-clicked').view()
    index = tabs.indexOf(active)
    return if index is -1
    @closeTab tab for tab, i in tabs when i > index

  getProcessId: ->
    @processId ?= atom.getCurrentWindow().getProcessId()

  getRoutingId: ->
    @routingId ?= atom.getCurrentWindow().getRoutingId()

  onDragStart: (event) =>
    event.originalEvent.dataTransfer.setData 'atom-event', 'true'

    el = $(event.target).closest('.sortable')
    el.addClass 'is-dragging'
    event.originalEvent.dataTransfer.setData 'sortable-index', el.index()

    pane = $(event.target).closest('.pane')
    paneIndex = @paneContainer.indexOfPane(pane)
    event.originalEvent.dataTransfer.setData 'from-pane-index', paneIndex
    event.originalEvent.dataTransfer.setData 'from-process-id', @getProcessId()
    event.originalEvent.dataTransfer.setData 'from-routing-id', @getRoutingId()

    item = @pane.getItems()[el.index()]
    if item.getPath?
      event.originalEvent.dataTransfer.setData 'text/uri-list', 'file://' + item.getPath()
      event.originalEvent.dataTransfer.setData 'text/plain', item.getPath()

  onDragLeave: (event) =>
    @removePlaceholderElement()

  onDragEnd: (event) =>
    @find('.is-dragging').removeClass('is-dragging')
    @removeDropTargetClasses()
    @removePlaceholderElement()

  onDragOver: (event) =>
    unless event.originalEvent.dataTransfer.getData('atom-event') is 'true'
      event.preventDefault()
      event.stopPropagation()
      return

    event.preventDefault()
    newDropTargetIndex = @getDropTargetIndex(event)
    return unless newDropTargetIndex?

    @removeDropTargetClasses()

    tabBar = @getTabBar(event.target)
    sortableObjects = tabBar.find(".sortable")

    if newDropTargetIndex < sortableObjects.length
      el = sortableObjects.eq(newDropTargetIndex).addClass 'is-drop-target'
      @getPlaceholderElement().insertBefore(el)
    else
      el = sortableObjects.eq(newDropTargetIndex - 1).addClass 'drop-target-is-after'
      @getPlaceholderElement().insertAfter(el)

  onDropOnOtherWindow: (fromItemIndex, fromPaneIndex) =>
    fromPane = @paneContainer.paneAtIndex(fromPaneIndex)
    return unless @pane.is(fromPane)

    if itemToRemove = fromPane.itemAtIndex(fromItemIndex)
      fromPane.removeItem(itemToRemove)

    @clearDropTarget()

  clearDropTarget: ->
    @find(".is-dragging").removeClass 'is-dragging'
    @removeDropTargetClasses()
    @removePlaceholderElement()

  onDrop: (event) =>
    event.preventDefault()
    event.stopPropagation()
    {dataTransfer} = event.originalEvent

    return unless dataTransfer.getData('atom-event') is 'true'

    fromProcessId = parseInt(dataTransfer.getData('from-process-id'))
    fromRoutingId = parseInt(dataTransfer.getData('from-routing-id'))
    fromIndex     = parseInt(dataTransfer.getData('sortable-index'))
    fromPaneIndex = parseInt(dataTransfer.getData('from-pane-index'))

    @clearDropTarget()

    if fromProcessId is @getProcessId()
      fromPane = @paneContainer.paneAtIndex(fromPaneIndex)
      toIndex = @getDropTargetIndex(event)
      toPane = $(event.target).closest('.pane').view()
      {item} = fromPane.find(".tab-bar .sortable:eq(#{fromIndex})").view() ? {}
      @moveItemBetweenPanes(fromPane, fromIndex, toPane, toIndex, item) if item?
    else
      if droppedPath = dataTransfer.getData('text/plain')
        atom.workspace.open(droppedPath).then (item) =>
          toPane = $(event.target).closest('.pane').view()
          toIndex = @getDropTargetIndex(event)
          activePane = atom.workspaceView.getActivePaneView()
          activeItemIndex = activePane.getActiveItemIndex()
          @moveItemBetweenPanes(activePane, activeItemIndex, toPane, toIndex, item)
          BrowserIpc.sendChannel(fromProcessId, fromRoutingId, 'tab:dropped', fromIndex, fromPaneIndex)

        atom.focus()

  moveItemBetweenPanes: (fromPane, fromIndex, toPane, toIndex, item) ->
    if toPane is fromPane
      toIndex-- if fromIndex < toIndex
      toPane.moveItem(item, toIndex)
    else
      fromPane.moveItemToPane(item, toPane, toIndex--)
    toPane.showItem(item)
    toPane.focus()

  removeDropTargetClasses: ->
    atom.workspaceView.find('.tab-bar .is-drop-target').removeClass 'is-drop-target'
    atom.workspaceView.find('.tab-bar .drop-target-is-after').removeClass 'drop-target-is-after'

  getDropTargetIndex: (event) ->
    target = $(event.target)
    tabBar = @getTabBar(event.target)

    return if @isPlaceholderElement(target)

    sortables = tabBar.find('.sortable')
    el = target.closest('.sortable')
    el = sortables.last() if el.length == 0

    return 0 unless el.length

    elementCenter = el.offset().left + el.width() / 2

    if event.originalEvent.pageX < elementCenter
      sortables.index(el)
    else if el.next('.sortable').length > 0
      sortables.index(el.next('.sortable'))
    else
      sortables.index(el) + 1

  getPlaceholderElement: ->
    @placeholderEl ?= $('<li/>', class: 'placeholder')

  removePlaceholderElement: ->
    @placeholderEl?.remove()
    @placeholderEl = null

  isPlaceholderElement: (element) ->
    element.is('.placeholder')

  getTabBar: (target) ->
    target = $(target)
    if target.is('.tab-bar') then target else target.parents('.tab-bar')

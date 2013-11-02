{_, $, View} = require 'atom'
TabView = require './tab-view'

module.exports =
class TabBarView extends View
  @content: ->
    @ul tabindex: -1, class: "list-inline tab-bar inset-panel"

  initialize: (@pane) ->
    @on 'dragstart', '.sortable', @onDragStart
    @on 'dragend', '.sortable', @onDragEnd
    @on 'dragover', @onDragOver
    @on 'drop', @onDrop

    @paneContainer = @pane.getContainer()
    @addTabForItem(item) for item in @pane.getItems()

    @pane.on 'pane:item-added', (e, item, index) => @addTabForItem(item, index)
    @pane.on 'pane:item-moved', (e, item, index) => @moveItemTabToIndex(item, index)
    @pane.on 'pane:item-removed', (e, item) => @removeTabForItem(item)
    @pane.on 'pane:active-item-changed', => @updateActiveTab()

    @updateActiveTab()

    @on 'click', '.tab', (e) =>
      tab = $(e.target).closest('.tab').view()
      @pane.showItem(tab.item)
      @pane.focus()

    @on 'click', '.tab .close-icon', (e) =>
      tab = $(e.target).closest('.tab').view()
      @pane.destroyItem(tab.item)
      false

    @pane.prepend(this)

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

  shouldAllowDrag: ->
    (@paneContainer.getPanes().length > 1) or (@pane.getItems().length > 1)

  onDragStart: (event) =>
    if @shouldAllowDrag()
      event.originalEvent.dataTransfer.setData 'atom-event', 'true'

    el = $(event.target).closest('.sortable')
    el.addClass 'is-dragging'
    event.originalEvent.dataTransfer.setData 'sortable-index', el.index()

    @placeholderEl = $('<li/>', class: 'placeholder')

    pane = $(event.target).closest('.pane')
    paneIndex = @paneContainer.indexOfPane(pane)
    event.originalEvent.dataTransfer.setData 'from-pane-index', paneIndex

    item = @pane.getItems()[el.index()]
    if item.getPath?
      event.originalEvent.dataTransfer.setData 'text/uri-list', 'file://' + item.getPath()
      event.originalEvent.dataTransfer.setData 'text/plain', item.getPath()

  onDragEnd: (event) =>
    @find(".is-dragging").removeClass 'is-dragging'
    @removeDropTargetClasses()
    @placeholderEl.remove()
    @placeholderEl = null

  onDragOver: (event) =>
    unless event.originalEvent.dataTransfer.getData('atom-event') is 'true'
      event.preventDefault()
      event.stopPropagation()
      return

    event.preventDefault()
    newDropTargetIndex = @getDropTargetIndex(event)
    return unless newDropTargetIndex?

    @removeDropTargetClasses()

    sortableObjects = @find(".sortable")
    if newDropTargetIndex < sortableObjects.length
      el = sortableObjects.eq(newDropTargetIndex).addClass 'is-drop-target'
      @placeholderEl.insertBefore(el)
    else
      el = sortableObjects.eq(newDropTargetIndex - 1).addClass 'drop-target-is-after'
      @placeholderEl.insertAfter(el)

  onDrop: (event) =>
    unless event.originalEvent.dataTransfer.getData('atom-event') is 'true'
      event.preventDefault()
      event.stopPropagation()
      return

    @find(".is-dragging").removeClass 'is-dragging'
    @removeDropTargetClasses()

    event.stopPropagation()

    dataTransfer  = event.originalEvent.dataTransfer
    fromIndex     = parseInt(dataTransfer.getData('sortable-index'))
    fromPaneIndex = parseInt(dataTransfer.getData('from-pane-index'))
    fromPane      = @paneContainer.paneAtIndex(fromPaneIndex)
    toIndex       = @getDropTargetIndex(event)
    toPane        = $(event.target).closest('.pane').view()
    draggedTab    = fromPane.find(".tab-bar .sortable:eq(#{fromIndex})").view()
    item          = draggedTab.item

    if toPane is fromPane
      toIndex-- if fromIndex < toIndex
      toPane.moveItem(item, toIndex)
    else
      fromPane.moveItemToPane(item, toPane, toIndex--)
    toPane.showItem(item)
    toPane.focus()

  removeDropTargetClasses: ->
    rootView.find('.tab-bar .is-drop-target').removeClass 'is-drop-target'
    rootView.find('.tab-bar .drop-target-is-after').removeClass 'drop-target-is-after'

  getDropTargetIndex: (event) ->
    target = $(event.target)
    li = target.parents('li')
    target = li if li.length
    return unless target.is('.tab-bar') or target.parents('.tab-bar').length

    return if target.is('.placeholder')

    sortables = @find('.sortable')
    el = target.closest('.sortable')
    el = sortables.last() if el.length == 0

    console.log el.find('.title').text()

    return unless el

    elementCenter = el.offset().left + el.width() / 2

    if event.originalEvent.pageX < elementCenter
      sortables.index(el)
    else if el.next('.sortable').length > 0
      sortables.index(el.next('.sortable'))
    else
      sortables.index(el) + 1

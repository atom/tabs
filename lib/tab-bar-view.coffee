BrowserWindow = null # Defer require until actually used
RendererIpc = require 'ipc'

{$, View} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'
TabView = require './tab-view'

module.exports =
class TabBarView extends View
  @content: ->
    @ul tabindex: -1, class: "list-inline tab-bar inset-panel"

  initialize: (@pane) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add @element,
      'tabs:close-tab': => @closeTab()
      'tabs:close-other-tabs': => @closeOtherTabs()
      'tabs:close-tabs-to-right': => @closeTabsToRight()
      'tabs:close-saved-tabs': => @closeSavedTabs()
      'tabs:close-all-tabs': => @closeAllTabs()
      'tabs:split-up': => @splitTab('splitUp')
      'tabs:split-down': => @splitTab('splitDown')
      'tabs:split-left': => @splitTab('splitLeft')
      'tabs:split-right': => @splitTab('splitRight')

    @on 'dragstart', '.sortable', @onDragStart
    @on 'dragend', '.sortable', @onDragEnd
    @on 'dragleave', @onDragLeave
    @on 'dragover', @onDragOver
    @on 'drop', @onDrop

    @paneContainer = @pane.getContainer()
    @addTabForItem(item) for item in @pane.getItems()

    @subscriptions.add @pane.onDidDestroy =>
      @unsubscribe()

    @subscriptions.add @pane.onDidAddItem ({item, index}) =>
      @addTabForItem(item, index)

    @subscriptions.add @pane.onDidMoveItem ({item, newIndex}) =>
      @moveItemTabToIndex(item, newIndex)

    @subscriptions.add @pane.onDidRemoveItem ({item}) =>
      @removeTabForItem(item)

    @subscriptions.add @pane.onDidChangeActiveItem =>
      @updateActiveTab()

    @subscriptions.add atom.config.observe 'tabs.tabScrolling', => @updateTabScrolling()
    @subscriptions.add atom.config.observe 'tabs.tabScrollingThreshold', => @updateTabScrollingThreshold()
    @subscriptions.add atom.config.observe 'tabs.alwaysShowTabBar', => @updateTabBarVisibility()

    @updateActiveTab()

    @on 'mousedown', '.tab', ({target, which, ctrlKey}) =>
      tab = $(target).closest('.tab')[0]
      if which is 3 or (which is 1 and ctrlKey is true)
        @find('.right-clicked').removeClass('right-clicked')
        tab.classList.add('right-clicked')
        false
      else if which is 1 and not target.classList.contains('close-icon')
        @pane.activateItem(tab.item)
        @pane.activate()
        true
      else if which is 2
        @pane.destroyItem(tab.item)
        false

    @on 'dblclick', ({target}) =>
      if target is @element
        atom.commands.dispatch(@element, 'application:new-file')
        false
        
    @on 'dblclick', '.tab', ({target}) =>
      atom.commands.dispatch(@element, 'core:save')
      false

    @on 'click', '.tab .close-icon', ({target}) =>
      tab = $(target).closest('.tab')[0]
      @pane.destroyItem(tab.item)
      false

    RendererIpc.on('tab:dropped', @onDropOnOtherWindow)

  unsubscribe: ->
    RendererIpc.removeListener('tab:dropped', @onDropOnOtherWindow)
    @subscriptions.dispose()

  addTabForItem: (item, index) ->
    tabView = new TabView()
    tabView.initialize(item)
    @insertTabAtIndex(tabView, index)

  moveItemTabToIndex: (item, index) ->
    if tab = @tabForItem(item)
      tab.remove()
      @insertTabAtIndex(tab, index)

  insertTabAtIndex: (tab, index) ->
    followingTab = @tabAtIndex(index) if index?
    if followingTab
      @element.insertBefore(tab, followingTab)
    else
      @element.appendChild(tab)
    tab.updateTitle()
    @updateTabBarVisibility()

  removeTabForItem: (item) ->
    @tabForItem(item)?.destroy()
    tab.updateTitle() for tab in @getTabs()
    @updateTabBarVisibility()

  updateTabBarVisibility: ->
    if !atom.config.get('tabs.alwaysShowTabBar') and not @shouldAllowDrag()
      @element.classList.add('hidden')
    else
      @element.classList.remove('hidden')

  getTabs: ->
    @children('.tab').toArray()

  tabAtIndex: (index) ->
    @children(".tab:eq(#{index})")[0]

  tabForItem: (item) ->
    _.detect @getTabs(), (tab) -> tab.item is item

  setActiveTab: (tabView) ->
    if tabView? and not tabView.classList.contains('active')
      @element.querySelector('.tab.active')?.classList.remove('active')
      tabView.classList.add('active')

  updateActiveTab: ->
    @setActiveTab(@tabForItem(@pane.getActiveItem()))

  closeTab: (tab) ->
    tab ?= @children('.right-clicked')[0]
    @pane.destroyItem(tab.item)

  splitTab: (fn) ->
    if item = @children('.right-clicked')[0]?.item
      if copiedItem = @copyItem(item)
        @pane[fn](items: [copiedItem])

  copyItem: (item) ->
    item.copy?() ? atom.deserializers.deserialize(item.serialize())

  closeOtherTabs: ->
    tabs = @getTabs()
    active = @children('.right-clicked')[0]
    return unless active?
    @closeTab tab for tab in tabs when tab isnt active

  closeTabsToRight: ->
    tabs = @getTabs()
    active = @children('.right-clicked')[0]
    index = tabs.indexOf(active)
    return if index is -1
    @closeTab tab for tab, i in tabs when i > index

  closeSavedTabs: ->
    for tab in @getTabs()
      @closeTab(tab) unless tab.item.isModified?()

  closeAllTabs: ->
    @closeTab(tab) for tab in @getTabs()

  getProcessId: ->
    @processId ?= atom.getCurrentWindow().getProcessId()

  getRoutingId: ->
    @routingId ?= atom.getCurrentWindow().getRoutingId()

  shouldAllowDrag: ->
    (@paneContainer.getPanes().length > 1) or (@pane.getItems().length > 1)

  onDragStart: (event) =>
    event.originalEvent.dataTransfer.setData 'atom-event', 'true'

    element = $(event.target).closest('.sortable')
    element.addClass 'is-dragging'
    element[0].destroyTooltip()

    event.originalEvent.dataTransfer.setData 'sortable-index', element.index()

    paneIndex = @paneContainer.getPanes().indexOf(@pane)
    event.originalEvent.dataTransfer.setData 'from-pane-index', paneIndex
    event.originalEvent.dataTransfer.setData 'from-pane-id', @pane.id
    event.originalEvent.dataTransfer.setData 'from-process-id', @getProcessId()
    event.originalEvent.dataTransfer.setData 'from-routing-id', @getRoutingId()

    item = @pane.getItems()[element.index()]
    return unless item?

    if typeof item.getURI is 'function'
      itemURI = item.getURI() ? ''
    else if typeof item.getPath is 'function'
      itemURI = item.getPath() ? ''
    else if typeof item.getUri is 'function'
      itemURI = item.getUri() ? ''

    if itemURI?
      event.originalEvent.dataTransfer.setData 'text/plain', itemURI

      if process.platform is 'darwin' # see #69
        itemURI = "file://#{itemURI}" unless @uriHasProtocol(itemURI)
        event.originalEvent.dataTransfer.setData 'text/uri-list', itemURI

      if item.isModified?() and item.getText?
        event.originalEvent.dataTransfer.setData 'has-unsaved-changes', 'true'
        event.originalEvent.dataTransfer.setData 'modified-text', item.getText()

  uriHasProtocol: (uri) ->
    try
      require('url').parse(uri).protocol?
    catch error
      false

  onDragLeave: (event) =>
    @removePlaceholder()

  onDragEnd: (event) =>
    @clearDropTarget()

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
      element = sortableObjects.eq(newDropTargetIndex).addClass 'is-drop-target'
      @getPlaceholder().insertBefore(element)
    else
      element = sortableObjects.eq(newDropTargetIndex - 1).addClass 'drop-target-is-after'
      @getPlaceholder().insertAfter(element)

  onDropOnOtherWindow: (fromPaneId, fromItemIndex) =>
    if @pane.id is fromPaneId
      if itemToRemove = @pane.getItems()[fromItemIndex]
        @pane.destroyItem(itemToRemove)

    @clearDropTarget()

  clearDropTarget: ->
    element = @find(".is-dragging")
    element.removeClass 'is-dragging'
    element[0]?.updateTooltip()
    @removeDropTargetClasses()
    @removePlaceholder()

  onDrop: (event) =>
    event.preventDefault()
    {dataTransfer} = event.originalEvent

    return unless dataTransfer.getData('atom-event') is 'true'

    fromProcessId = parseInt(dataTransfer.getData('from-process-id'))
    fromRoutingId = parseInt(dataTransfer.getData('from-routing-id'))
    fromPaneId    = parseInt(dataTransfer.getData('from-pane-id'))
    fromIndex     = parseInt(dataTransfer.getData('sortable-index'))
    fromPaneIndex = parseInt(dataTransfer.getData('from-pane-index'))

    hasUnsavedChanges = dataTransfer.getData('has-unsaved-changes') is 'true'
    modifiedText = dataTransfer.getData('modified-text')

    toIndex = @getDropTargetIndex(event)
    toPane = @pane

    @clearDropTarget()

    if fromProcessId is @getProcessId()
      fromPane = @paneContainer.getPanes()[fromPaneIndex]
      item = fromPane.getItems()[fromIndex]
      @moveItemBetweenPanes(fromPane, fromIndex, toPane, toIndex, item) if item?
    else
      droppedURI = dataTransfer.getData('text/plain')
      atom.workspace.open(droppedURI).then (item) =>
        # Move the item from the pane it was opened on to the target pane
        # where it was dropped onto
        activePane = atom.workspace.getActivePane()
        activeItemIndex = activePane.getItems().indexOf(item)
        @moveItemBetweenPanes(activePane, activeItemIndex, toPane, toIndex, item)
        item.setText?(modifiedText) if hasUnsavedChanges

        if not isNaN(fromProcessId) and not isNaN(fromRoutingId)
          # Let the window where the drag started know that the tab was dropped
          browserWindow = @browserWindowForProcessIdAndRoutingId(fromProcessId, fromRoutingId)
          browserWindow?.webContents.send('tab:dropped', fromPaneId, fromIndex)

      atom.focus()

  onMouseWheel: ({originalEvent}) =>
    @wheelDelta ?= 0
    @wheelDelta += originalEvent.wheelDelta

    if @wheelDelta <= -@tabScrollingThreshold
      @wheelDelta = 0
      @pane.activateNextItem()
    else if @wheelDelta >= @tabScrollingThreshold
      @wheelDelta = 0
      @pane.activatePreviousItem()

  updateTabScrollingThreshold: ->
    @tabScrollingThreshold = atom.config.get('tabs.tabScrollingThreshold')

  updateTabScrolling: ->
    @tabScrolling = atom.config.get('tabs.tabScrolling')
    @tabScrollingThreshold = atom.config.get('tabs.tabScrollingThreshold')
    if @tabScrolling
      @on 'wheel', @onMouseWheel
    else
      @off 'wheel'

  browserWindowForProcessIdAndRoutingId: (processId, routingId) ->
    BrowserWindow ?= require('remote').require('browser-window')
    for browserWindow in BrowserWindow.getAllWindows()
      if browserWindow.getProcessId() is processId and browserWindow.getRoutingId() is routingId
        return browserWindow

    null

  moveItemBetweenPanes: (fromPane, fromIndex, toPane, toIndex, item) ->
    if toPane is fromPane
      toIndex-- if fromIndex < toIndex
      toPane.moveItem(item, toIndex)
    else
      fromPane.moveItemToPane(item, toPane, toIndex--)
    toPane.activateItem(item)
    toPane.activate()

  removeDropTargetClasses: ->
    workspaceElement = $(atom.views.getView(atom.workspace))
    workspaceElement.find('.tab-bar .is-drop-target').removeClass 'is-drop-target'
    workspaceElement.find('.tab-bar .drop-target-is-after').removeClass 'drop-target-is-after'

  getDropTargetIndex: (event) ->
    target = $(event.target)
    tabBar = @getTabBar(event.target)

    return if @isPlaceholder(target)

    sortables = tabBar.find('.sortable')
    element = target.closest('.sortable')
    element = sortables.last() if element.length == 0

    return 0 unless element.length

    elementCenter = element.offset().left + element.width() / 2

    if event.originalEvent.pageX < elementCenter
      sortables.index(element)
    else if element.next('.sortable').length > 0
      sortables.index(element.next('.sortable'))
    else
      sortables.index(element) + 1

  getPlaceholder: ->
    @placeholderEl ?= $('<li/>', class: 'placeholder')

  removePlaceholder: ->
    @placeholderEl?.remove()
    @placeholderEl = null

  isPlaceholder: (element) ->
    element.is('.placeholder')

  getTabBar: (target) ->
    target = $(target)
    if target.is('.tab-bar') then target else target.parents('.tab-bar')

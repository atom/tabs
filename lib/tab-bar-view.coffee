BrowserWindow = null # Defer require until actually used
RendererIpc = require 'ipc'

{matches, contains, closest, indexOf} = require './html-helpers'
{$, View} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'
TabView = require './tab-view'

module.exports =
class TabBarView extends View
  @content: ->
    @ul tabindex: -1, class: "list-inline tab-bar inset-panel"

  initialize: (@pane, state={}) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add atom.views.getView(@pane),
      'tabs:keep-preview-tab': => @clearPreviewTabs()
      'tabs:close-tab': => @closeTab(@getActiveTab())
      'tabs:close-other-tabs': => @closeOtherTabs(@getActiveTab())
      'tabs:close-tabs-to-right': => @closeTabsToRight(@getActiveTab())
      'tabs:close-saved-tabs': => @closeSavedTabs()
      'tabs:close-all-tabs': => @closeAllTabs()

    addElementCommands = (commands) =>
      commandsWithPropagationStopped = {}
      Object.keys(commands).forEach (name) ->
        commandsWithPropagationStopped[name] = (event) ->
          event.stopPropagation()
          commands[name]()

      @subscriptions.add(atom.commands.add(@element, commandsWithPropagationStopped))

    addElementCommands
      'tabs:close-tab': => @closeTab()
      'tabs:close-other-tabs': => @closeOtherTabs()
      'tabs:close-tabs-to-right': => @closeTabsToRight()
      'tabs:close-saved-tabs': => @closeSavedTabs()
      'tabs:close-all-tabs': => @closeAllTabs()
      'tabs:split-up': => @splitTab('splitUp')
      'tabs:split-down': => @splitTab('splitDown')
      'tabs:split-left': => @splitTab('splitLeft')
      'tabs:split-right': => @splitTab('splitRight')

    @element.addEventListener "dragstart", @onDragStart
    @element.addEventListener "dragend", @onDragEnd
    @element.addEventListener "dragleave", @onDragLeave
    @element.addEventListener "dragover", @onDragOver
    @element.addEventListener "drop", @onDrop

    @paneContainer = @pane.getContainer()
    @addTabForItem(item) for item in @pane.getItems()
    @setInitialPreviewTab(state.previewTabURI)

    @subscriptions.add @pane.onDidDestroy =>
      @unsubscribe()

    @subscriptions.add @pane.onDidAddItem ({item, index}) =>
      @addTabForItem(item, index)

    @subscriptions.add @pane.onDidMoveItem ({item, newIndex}) =>
      @moveItemTabToIndex(item, newIndex)

    @subscriptions.add @pane.onDidRemoveItem ({item}) =>
      @removeTabForItem(item)

    @subscriptions.add @pane.onDidChangeActiveItem (item) =>
      @destroyPreviousPreviewTab()
      @updateActiveTab()

    @subscriptions.add atom.config.observe 'tabs.tabScrolling', => @updateTabScrolling()
    @subscriptions.add atom.config.observe 'tabs.tabScrollingThreshold', => @updateTabScrollingThreshold()
    @subscriptions.add atom.config.observe 'tabs.alwaysShowTabBar', => @updateTabBarVisibility()

    @handleTreeViewEvents()

    @updateActiveTab()

    @element.addEventListener "mousedown", @onMouseDown
    @element.addEventListener "dblclick", @onDoubleClick
    @element.addEventListener "click", @onClick

    RendererIpc.on('tab:dropped', @onDropOnOtherWindow)

  unsubscribe: ->
    RendererIpc.removeListener('tab:dropped', @onDropOnOtherWindow)
    @subscriptions.dispose()

  handleTreeViewEvents: ->
    treeViewSelector = '.tree-view .entry.file'
    clearPreviewTabForFile = ({target}) =>
      return unless @pane.isFocused()
      return unless matches(target, treeViewSelector)

      target = target.querySelector('[data-path]') unless target.dataset.path

      if itemPath = target.dataset.path
        @tabForItem(@pane.itemForURI(itemPath))?.clearPreview()

    document.body.addEventListener('dblclick', clearPreviewTabForFile)
    @subscriptions.add dispose: ->
      document.body.removeEventListener('dblclick', clearPreviewTabForFile)

  setInitialPreviewTab: (previewTabURI) ->
    for tab in @getTabs() when tab.isPreviewTab
      tab.clearPreview() if tab.item.getURI() isnt previewTabURI
    return

  getPreviewTabURI: ->
    for tab in @getTabs() when tab.isPreviewTab
      return tab.item.getURI()
    return

  clearPreviewTabs: ->
    tab.clearPreview() for tab in @getTabs()
    return

  storePreviewTabToDestroy: ->
    for tab in @getTabs() when tab.isPreviewTab
      @previewTabToDestroy = tab
    return

  destroyPreviousPreviewTab: ->
    if @previewTabToDestroy?.isPreviewTab
      @pane.destroyItem(@previewTabToDestroy.item)
    @previewTabToDestroy = null

  addTabForItem: (item, index) ->
    tabView = new TabView()
    tabView.initialize(item)
    tabView.clearPreview() if @isItemMovingBetweenPanes
    @storePreviewTabToDestroy() if tabView.isPreviewTab
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
    if not atom.config.get('tabs.alwaysShowTabBar') and not @shouldAllowDrag()
      @element.classList.add('hidden')
    else
      @element.classList.remove('hidden')

  getTabs: ->
    tab for tab in @element.querySelectorAll(".tab")

  tabAtIndex: (index) ->
    @element.querySelectorAll(".tab")[index]

  tabForItem: (item) ->
    _.detect @getTabs(), (tab) -> tab.item is item

  setActiveTab: (tabView) ->
    if tabView? and not tabView.classList.contains('active')
      @element.querySelector('.tab.active')?.classList.remove('active')
      tabView.classList.add('active')

  getActiveTab: ->
    @tabForItem(@pane.getActiveItem())

  updateActiveTab: ->
    @setActiveTab(@tabForItem(@pane.getActiveItem()))

  closeTab: (tab) ->
    tab ?= @element.querySelector('.right-clicked')
    @pane.destroyItem(tab.item) if tab?

  splitTab: (fn) ->
    if item = @element.querySelector('.right-clicked')?.item
      if copiedItem = @copyItem(item)
        @pane[fn](items: [copiedItem])

  copyItem: (item) ->
    item.copy?() ? atom.deserializers.deserialize(item.serialize())

  closeOtherTabs: (active) ->
    tabs = @getTabs()
    active ?= @element.querySelector('.right-clicked')
    return unless active?
    @closeTab tab for tab in tabs when tab isnt active

  closeTabsToRight: (active) ->
    tabs = @getTabs()
    active ?= @element.querySelector('.right-clicked')
    index = tabs.indexOf(active)
    return if index is -1
    @closeTab tab for tab, i in tabs when i > index

  closeSavedTabs: ->
    for tab in @getTabs()
      @closeTab(tab) unless tab.item.isModified?()

  closeAllTabs: ->
    @closeTab(tab) for tab in @getTabs()

  getWindowId: ->
    @windowId ?= atom.getCurrentWindow().id

  shouldAllowDrag: ->
    (@paneContainer.getPanes().length > 1) or (@pane.getItems().length > 1)

  onDragStart: (event) =>
    return unless matches(event.target, '.sortable')

    event.originalEvent.dataTransfer.setData 'atom-event', 'true'

    element = closest(event.target, '.sortable')
    element.classList.add('is-dragging')
    element.destroyTooltip()

    event.originalEvent.dataTransfer.setData 'sortable-index', indexOf(element)

    paneIndex = @paneContainer.getPanes().indexOf(@pane)
    event.originalEvent.dataTransfer.setData 'from-pane-index', paneIndex
    event.originalEvent.dataTransfer.setData 'from-pane-id', @pane.id
    event.originalEvent.dataTransfer.setData 'from-window-id', @getWindowId()

    item = @pane.getItems()[indexOf(element)]
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
    return unless matches(event.target, '.sortable')

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
    element = @element.querySelector(".is-dragging")
    element?.classList.remove('is-dragging')
    element?.updateTooltip()
    @removeDropTargetClasses()
    @removePlaceholder()

  onDrop: (event) =>
    event.preventDefault()
    {dataTransfer} = event.originalEvent

    return unless dataTransfer.getData('atom-event') is 'true'

    fromWindowId  = parseInt(dataTransfer.getData('from-window-id'))
    fromPaneId    = parseInt(dataTransfer.getData('from-pane-id'))
    fromIndex     = parseInt(dataTransfer.getData('sortable-index'))
    fromPaneIndex = parseInt(dataTransfer.getData('from-pane-index'))

    hasUnsavedChanges = dataTransfer.getData('has-unsaved-changes') is 'true'
    modifiedText = dataTransfer.getData('modified-text')

    toIndex = @getDropTargetIndex(event)
    toPane = @pane

    @clearDropTarget()

    if fromWindowId is @getWindowId()
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

        if not isNaN(fromWindowId)
          # Let the window where the drag started know that the tab was dropped
          browserWindow = @browserWindowForId(fromWindowId)
          browserWindow?.webContents.send('tab:dropped', fromPaneId, fromIndex)

      atom.focus()

  onMouseWheel: ({originalEvent}) =>
    return if originalEvent.shiftKey

    @wheelDelta ?= 0
    @wheelDelta += originalEvent.wheelDelta

    if @wheelDelta <= -@tabScrollingThreshold
      @wheelDelta = 0
      @pane.activateNextItem()
    else if @wheelDelta >= @tabScrollingThreshold
      @wheelDelta = 0
      @pane.activatePreviousItem()

  onMouseDown: ({target, which, ctrlKey, preventDefault}) =>
    return unless matches(target, ".tab")

    tab = closest(target, '.tab')
    if which is 3 or (which is 1 and ctrlKey is true)
      @element.querySelector('.right-clicked')?.classList.remove('right-clicked')
      tab.classList.add('right-clicked')
      preventDefault()
    else if which is 1 and not target.classList.contains('close-icon')
      @pane.activateItem(tab.item)
      setImmediate => @pane.activate()
    else if which is 2
      @pane.destroyItem(tab.item)
      preventDefault()

  onDoubleClick: ({target, preventDefault}) =>
    if target is @element
      atom.commands.dispatch(@element, 'application:new-file')
      preventDefault()

  onClick: ({target}) =>
    return unless matches(target, ".tab .close-icon")

    tab = closest(target, '.tab')
    @pane.destroyItem(tab.item)
    false

  updateTabScrollingThreshold: ->
    @tabScrollingThreshold = atom.config.get('tabs.tabScrollingThreshold')

  updateTabScrolling: ->
    @tabScrolling = atom.config.get('tabs.tabScrolling')
    @tabScrollingThreshold = atom.config.get('tabs.tabScrollingThreshold')
    if @tabScrolling
      @on 'wheel', @onMouseWheel
    else
      @off 'wheel'

  browserWindowForId: (id) ->
    BrowserWindow ?= require('remote').require('browser-window')
    BrowserWindow.fromId id

  moveItemBetweenPanes: (fromPane, fromIndex, toPane, toIndex, item) ->
    try
      if toPane is fromPane
        toIndex-- if fromIndex < toIndex
        toPane.moveItem(item, toIndex)
      else
        @isItemMovingBetweenPanes = true
        fromPane.moveItemToPane(item, toPane, toIndex--)
      toPane.activateItem(item)
      toPane.activate()
    finally
      @isItemMovingBetweenPanes = false

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
    element = sortables.last() if element.length is 0

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

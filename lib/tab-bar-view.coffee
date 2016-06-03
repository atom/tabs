BrowserWindow = null # Defer require until actually used
{ipcRenderer} = require 'electron'

{matches, closest, indexOf} = require './html-helpers'
{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'
TabView = require './tab-view'

class TabBarView extends HTMLElement
  createdCallback: ->
    @classList.add("list-inline")
    @classList.add("tab-bar")
    @classList.add("inset-panel")
    @setAttribute("tabindex", -1)

  initialize: (@pane) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add atom.views.getView(@pane),
      'tabs:keep-pending-tab': => @terminatePendingStates()
      'tabs:close-tab': => @closeTab(@getActiveTab())
      'tabs:close-other-tabs': => @closeOtherTabs(@getActiveTab())
      'tabs:close-tabs-to-right': => @closeTabsToRight(@getActiveTab())
      'tabs:close-tabs-to-left': => @closeTabsToLeft(@getActiveTab())
      'tabs:close-saved-tabs': => @closeSavedTabs()
      'tabs:close-all-tabs': (event) =>
        event.stopPropagation()
        @closeAllTabs()
      'tabs:open-in-new-window': => @openInNewWindow()

    addElementCommands = (commands) =>
      commandsWithPropagationStopped = {}
      Object.keys(commands).forEach (name) ->
        commandsWithPropagationStopped[name] = (event) ->
          event.stopPropagation()
          commands[name]()

      @subscriptions.add(atom.commands.add(this, commandsWithPropagationStopped))

    addElementCommands
      'tabs:close-tab': => @closeTab()
      'tabs:close-other-tabs': => @closeOtherTabs()
      'tabs:close-tabs-to-right': => @closeTabsToRight()
      'tabs:close-tabs-to-left': => @closeTabsToLeft()
      'tabs:close-saved-tabs': => @closeSavedTabs()
      'tabs:close-all-tabs': => @closeAllTabs()
      'tabs:split-up': => @splitTab('splitUp')
      'tabs:split-down': => @splitTab('splitDown')
      'tabs:split-left': => @splitTab('splitLeft')
      'tabs:split-right': => @splitTab('splitRight')

    @addEventListener "dragstart", @onDragStart
    @addEventListener "dragend", @onDragEnd
    @addEventListener "dragleave", @onDragLeave
    @addEventListener "dragover", @onDragOver
    @addEventListener "drop", @onDrop

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

    @subscriptions.add @pane.onDidChangeActiveItem (item) =>
      @updateActiveTab()

    @subscriptions.add atom.config.observe 'tabs.tabScrolling', @updateTabScrolling.bind(this)
    @subscriptions.add atom.config.observe 'tabs.tabScrollingThreshold', => @updateTabScrollingThreshold()
    @subscriptions.add atom.config.observe 'tabs.alwaysShowTabBar', => @updateTabBarVisibility()

    @updateActiveTab()

    @addEventListener "mousedown", @onMouseDown
    @addEventListener "dblclick", @onDoubleClick
    @addEventListener "click", @onClick

    @onDropOnOtherWindow = @onDropOnOtherWindow.bind(this)
    ipcRenderer.on('tab:dropped',  @onDropOnOtherWindow)

  unsubscribe: ->
    ipcRenderer.removeListener('tab:dropped', @onDropOnOtherWindow)
    @subscriptions.dispose()

  terminatePendingStates: ->
    tab.terminatePendingState?() for tab in @getTabs()
    return

  addTabForItem: (item, index) ->
    tabView = new TabView()
    tabView.initialize(item, @pane)
    tabView.terminatePendingState() if @isItemMovingBetweenPanes
    @insertTabAtIndex(tabView, index)
    if atom.config.get('tabs.addNewTabsAtEnd')
      @pane.moveItem(item, @pane.getItems().length - 1) unless @isItemMovingBetweenPanes

  moveItemTabToIndex: (item, index) ->
    if tab = @tabForItem(item)
      tab.remove()
      @insertTabAtIndex(tab, index)

  insertTabAtIndex: (tab, index) ->
    followingTab = @tabAtIndex(index) if index?
    if followingTab
      @insertBefore(tab, followingTab)
    else
      @appendChild(tab)
    tab.updateTitle()
    @updateTabBarVisibility()

  removeTabForItem: (item) ->
    @tabForItem(item)?.destroy()
    tab.updateTitle() for tab in @getTabs()
    @updateTabBarVisibility()

  updateTabBarVisibility: ->
    if not atom.config.get('tabs.alwaysShowTabBar') and not @shouldAllowDrag()
      @classList.add('hidden')
    else
      @classList.remove('hidden')

  getTabs: ->
    tab for tab in @querySelectorAll(".tab")

  tabAtIndex: (index) ->
    @querySelectorAll(".tab")[index]

  tabForItem: (item) ->
    _.detect @getTabs(), (tab) -> tab.item is item

  setActiveTab: (tabView) ->
    if tabView? and not tabView.classList.contains('active')
      @querySelector('.tab.active')?.classList.remove('active')
      tabView.classList.add('active')

  getActiveTab: ->
    @tabForItem(@pane.getActiveItem())

  updateActiveTab: ->
    @setActiveTab(@tabForItem(@pane.getActiveItem()))

  closeTab: (tab) ->
    tab ?= @querySelector('.right-clicked')
    @pane.destroyItem(tab.item) if tab?

  openInNewWindow: (tab) ->
    tab ?= @querySelector('.right-clicked')
    item = tab?.item
    return unless item?
    if typeof item.getURI is 'function'
      itemURI = item.getURI()
    else if typeof item.getPath is 'function'
      itemURI = item.getPath()
    else if typeof item.getUri is 'function'
      itemURI = item.getUri()
    return unless itemURI?
    @closeTab(tab)
    pathsToOpen = [atom.project.getPaths(), itemURI].reduce ((a, b) -> a.concat(b)), []
    atom.open({pathsToOpen: pathsToOpen, newWindow: true, devMode: atom.devMode, safeMode: atom.safeMode})

  splitTab: (fn) ->
    if item = @querySelector('.right-clicked')?.item
      if copiedItem = @copyItem(item)
        @pane[fn](items: [copiedItem])

  copyItem: (item) ->
    item.copy?() ? atom.deserializers.deserialize(item.serialize())

  closeOtherTabs: (active) ->
    tabs = @getTabs()
    active ?= @querySelector('.right-clicked')
    return unless active?
    @closeTab tab for tab in tabs when tab isnt active

  closeTabsToRight: (active) ->
    tabs = @getTabs()
    active ?= @querySelector('.right-clicked')
    index = tabs.indexOf(active)
    return if index is -1
    @closeTab tab for tab, i in tabs when i > index

  closeTabsToLeft: (active) ->
    tabs = @getTabs()
    active ?= @querySelector('.right-clicked')
    index = tabs.indexOf(active)
    return if index is -1
    @closeTab tab for tab, i in tabs when i < index

  closeSavedTabs: ->
    for tab in @getTabs()
      @closeTab(tab) unless tab.item.isModified?()

  closeAllTabs: ->
    @closeTab(tab) for tab in @getTabs()

  getWindowId: ->
    @windowId ?= atom.getCurrentWindow().id

  shouldAllowDrag: ->
    (@paneContainer.getPanes().length > 1) or (@pane.getItems().length > 1)

  onDragStart: (event) ->
    return unless matches(event.target, '.sortable')

    event.dataTransfer.setData 'atom-event', 'true'

    element = closest(event.target, '.sortable')
    element.classList.add('is-dragging')
    element.destroyTooltip()

    event.dataTransfer.setData 'sortable-index', indexOf(element)

    paneIndex = @paneContainer.getPanes().indexOf(@pane)
    event.dataTransfer.setData 'from-pane-index', paneIndex
    event.dataTransfer.setData 'from-pane-id', @pane.id
    event.dataTransfer.setData 'from-window-id', @getWindowId()

    item = @pane.getItems()[indexOf(element)]
    return unless item?

    if typeof item.getURI is 'function'
      itemURI = item.getURI() ? ''
    else if typeof item.getPath is 'function'
      itemURI = item.getPath() ? ''
    else if typeof item.getUri is 'function'
      itemURI = item.getUri() ? ''

    if itemURI?
      event.dataTransfer.setData 'text/plain', itemURI

      if process.platform is 'darwin' # see #69
        itemURI = "file://#{itemURI}" unless @uriHasProtocol(itemURI)
        event.dataTransfer.setData 'text/uri-list', itemURI

      if item.isModified?() and item.getText?
        event.dataTransfer.setData 'has-unsaved-changes', 'true'
        event.dataTransfer.setData 'modified-text', item.getText()

  uriHasProtocol: (uri) ->
    try
      require('url').parse(uri).protocol?
    catch error
      false

  onDragLeave: (event) ->
    @removePlaceholder()

  onDragEnd: (event) ->
    return unless matches(event.target, '.sortable')

    @clearDropTarget()

  onDragOver: (event) ->
    unless event.dataTransfer.getData('atom-event') is 'true'
      event.preventDefault()
      event.stopPropagation()
      return

    event.preventDefault()
    newDropTargetIndex = @getDropTargetIndex(event)
    return unless newDropTargetIndex?

    @removeDropTargetClasses()

    tabBar = @getTabBar(event.target)
    sortableObjects = tabBar.querySelectorAll(".sortable")
    placeholder = @getPlaceholder()
    return unless placeholder?

    if newDropTargetIndex < sortableObjects.length
      element = sortableObjects[newDropTargetIndex]
      element.classList.add 'is-drop-target'
      element.parentElement.insertBefore(placeholder, element)
    else
      if element = sortableObjects[newDropTargetIndex - 1]
        element.classList.add 'drop-target-is-after'
        if sibling = element.nextSibling
          element.parentElement.insertBefore(placeholder, sibling)
        else
          element.parentElement.appendChild(placeholder)

  onDropOnOtherWindow: (fromPaneId, fromItemIndex) ->
    if @pane.id is fromPaneId
      if itemToRemove = @pane.getItems()[fromItemIndex]
        @pane.destroyItem(itemToRemove)

    @clearDropTarget()

  clearDropTarget: ->
    element = @querySelector(".is-dragging")
    element?.classList.remove('is-dragging')
    element?.updateTooltip()
    @removeDropTargetClasses()
    @removePlaceholder()

  onDrop: (event) ->
    event.preventDefault()

    return unless event.dataTransfer.getData('atom-event') is 'true'

    fromWindowId  = parseInt(event.dataTransfer.getData('from-window-id'))
    fromPaneId    = parseInt(event.dataTransfer.getData('from-pane-id'))
    fromIndex     = parseInt(event.dataTransfer.getData('sortable-index'))
    fromPaneIndex = parseInt(event.dataTransfer.getData('from-pane-index'))

    hasUnsavedChanges = event.dataTransfer.getData('has-unsaved-changes') is 'true'
    modifiedText = event.dataTransfer.getData('modified-text')

    toIndex = @getDropTargetIndex(event)
    toPane = @pane

    @clearDropTarget()

    if fromWindowId is @getWindowId()
      fromPane = @paneContainer.getPanes()[fromPaneIndex]
      item = fromPane.getItems()[fromIndex]
      @moveItemBetweenPanes(fromPane, fromIndex, toPane, toIndex, item) if item?
    else
      droppedURI = event.dataTransfer.getData('text/plain')
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

  onMouseWheel: (event) ->
    return if event.shiftKey

    @wheelDelta ?= 0
    @wheelDelta += event.wheelDeltaY

    if @wheelDelta <= -@tabScrollingThreshold
      @wheelDelta = 0
      @pane.activateNextItem()
    else if @wheelDelta >= @tabScrollingThreshold
      @wheelDelta = 0
      @pane.activatePreviousItem()

  onMouseDown: (event) ->
    return unless matches(event.target, ".tab")

    tab = closest(event.target, '.tab')
    if event.which is 3 or (event.which is 1 and event.ctrlKey is true)
      @querySelector('.right-clicked')?.classList.remove('right-clicked')
      tab.classList.add('right-clicked')
      event.preventDefault()
    else if event.which is 1 and not event.target.classList.contains('close-icon')
      @pane.activateItem(tab.item)
      setImmediate => @pane.activate() unless @pane.isDestroyed()
    else if event.which is 2
      @pane.destroyItem(tab.item)
      event.preventDefault()

  onDoubleClick: (event) ->
    if tab = closest(event.target, '.tab')
      tab.item.terminatePendingState?()

    else if event.target is this
      atom.commands.dispatch(this, 'application:new-file')
      event.preventDefault()

  onClick: (event) ->
    return unless matches(event.target, ".tab .close-icon")

    tab = closest(event.target, '.tab')
    @pane.destroyItem(tab.item)
    false

  updateTabScrollingThreshold: ->
    @tabScrollingThreshold = atom.config.get('tabs.tabScrollingThreshold')

  updateTabScrolling: (value) ->
    if value is 'platform'
      @tabScrolling = (process.platform is 'linux')
    else
      @tabScrolling = value
    @tabScrollingThreshold = atom.config.get('tabs.tabScrollingThreshold')

    if @tabScrolling
      @addEventListener 'mousewheel', @onMouseWheel
    else
      @removeEventListener 'mousewheel', @onMouseWheel

  browserWindowForId: (id) ->
    BrowserWindow ?= require('electron').remote.BrowserWindow

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
    workspaceElement = atom.views.getView(atom.workspace)
    for dropTarget in workspaceElement.querySelectorAll('.tab-bar .is-drop-target')
      dropTarget.classList.remove('is-drop-target')

    for dropTarget in workspaceElement.querySelectorAll('.tab-bar .drop-target-is-after')
      dropTarget.classList.remove('drop-target-is-after')

  getDropTargetIndex: (event) ->
    target = event.target
    tabBar = @getTabBar(target)

    return if @isPlaceholder(target)

    sortables = tabBar.querySelectorAll(".sortable")
    element = closest(target, '.sortable')
    element ?= sortables[sortables.length - 1]

    return 0 unless element?

    {left, width} = element.getBoundingClientRect()
    elementCenter = left + width / 2
    elementIndex = indexOf(element, sortables)

    if event.pageX < elementCenter
      elementIndex
    else
      elementIndex + 1

  getPlaceholder: ->
    return @placeholderEl if @placeholderEl?

    @placeholderEl = document.createElement("li")
    @placeholderEl.classList.add("placeholder")
    @placeholderEl

  removePlaceholder: ->
    @placeholderEl?.remove()
    @placeholderEl = null

  isPlaceholder: (element) ->
    element.classList.contains('placeholder')

  getTabBar: (target) ->
    if target.classList.contains('tab-bar')
      target
    else
      closest(target, '.tab-bar')

module.exports = document.registerElement("atom-tabs", prototype: TabBarView.prototype, extends: "ul")

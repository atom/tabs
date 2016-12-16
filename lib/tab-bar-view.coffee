BrowserWindow = null # Defer require until actually used
{ipcRenderer} = require 'electron'

{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'
TabView = require './tab-view'

module.exports =
class TabBarView
  constructor: (@pane) ->
    @element = document.createElement('ul')
    @element.classList.add("list-inline")
    @element.classList.add("tab-bar")
    @element.classList.add("inset-panel")
    @element.setAttribute('is', 'atom-tabs')
    @element.setAttribute("tabindex", -1)

    @tabs = []
    @tabsByElement = new WeakMap
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

      @subscriptions.add(atom.commands.add(@element, commandsWithPropagationStopped))

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

    @element.addEventListener "mouseenter", @onMouseEnter.bind(this)
    @element.addEventListener "mouseleave", @onMouseLeave.bind(this)
    @element.addEventListener "dragstart", @onDragStart.bind(this)
    @element.addEventListener "dragend", @onDragEnd.bind(this)
    @element.addEventListener "dragleave", @onDragLeave.bind(this)
    @element.addEventListener "dragover", @onDragOver.bind(this)
    @element.addEventListener "drop", @onDrop.bind(this)

    @paneContainer = @pane.getContainer()
    @addTabForItem(item) for item in @pane.getItems()

    @subscriptions.add @pane.onDidDestroy =>
      @destroy()

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

    @element.addEventListener "mousedown", @onMouseDown.bind(this)
    @element.addEventListener "dblclick", @onDoubleClick.bind(this)

    @onDropOnOtherWindow = @onDropOnOtherWindow.bind(this)
    ipcRenderer.on('tab:dropped', @onDropOnOtherWindow)

  destroy: ->
    ipcRenderer.removeListener('tab:dropped', @onDropOnOtherWindow)
    @subscriptions.dispose()
    @element.remove()

  terminatePendingStates: ->
    tab.terminatePendingState?() for tab in @getTabs()
    return

  addTabForItem: (item, index) ->
    tabView = new TabView({
      item,
      @pane,
      @tabs,
      didClickCloseIcon: =>
        @closeTab(tabView)
        return
    })
    tabView.terminatePendingState() if @isItemMovingBetweenPanes
    @tabsByElement.set(tabView.element, tabView)
    @insertTabAtIndex(tabView, index)
    if atom.config.get('tabs.addNewTabsAtEnd')
      @pane.moveItem(item, @pane.getItems().length - 1) unless @isItemMovingBetweenPanes

  moveItemTabToIndex: (item, index) ->
    tabIndex = @tabs.findIndex((t) -> t.item is item)
    if tabIndex isnt -1
      tab = @tabs[tabIndex]
      tab.element.remove()
      @tabs.splice(tabIndex, 1)
      @insertTabAtIndex(tab, index)

  insertTabAtIndex: (tab, index) ->
    followingTab = @tabs[index] if index?
    if followingTab
      @element.insertBefore(tab.element, followingTab.element)
      @tabs.splice(index, 0, tab)
    else
      @element.appendChild(tab.element)
      @tabs.push(tab)

    tab.updateTitle()
    @updateTabBarVisibility()

  removeTabForItem: (item) ->
    tabIndex = @tabs.findIndex((t) -> t.item is item)
    if tabIndex isnt -1
      tab = @tabs[tabIndex]
      @tabs.splice(tabIndex, 1)
      @tabsByElement.delete(tab)
      tab.destroy()
    tab.updateTitle() for tab in @getTabs()
    @updateTabBarVisibility()

  updateTabBarVisibility: ->
    if not atom.config.get('tabs.alwaysShowTabBar') and not @shouldAllowDrag()
      @element.classList.add('hidden')
    else
      @element.classList.remove('hidden')

  getTabs: ->
    @tabs.slice()

  tabAtIndex: (index) ->
    @tabs[index]

  tabForItem: (item) ->
    @tabs.find((t) -> t.item is item)

  setActiveTab: (tabView) ->
    if tabView? and tabView isnt @activeTab
      @activeTab?.element.classList.remove('active')
      @activeTab = tabView
      @activeTab.element.classList.add('active')
      @activeTab.element.scrollIntoView(false)

  getActiveTab: ->
    @tabForItem(@pane.getActiveItem())

  updateActiveTab: ->
    @setActiveTab(@tabForItem(@pane.getActiveItem()))

  closeTab: (tab) ->
    tab ?= @rightClickedTab
    @pane.destroyItem(tab.item) if tab?

  openInNewWindow: (tab) ->
    tab ?= @rightClickedTab
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
    if item = @rightClickedTab?.item
      if copiedItem = @copyItem(item)
        @pane[fn](items: [copiedItem])

  copyItem: (item) ->
    item.copy?() ? atom.deserializers.deserialize(item.serialize())

  closeOtherTabs: (active) ->
    tabs = @getTabs()
    active ?= @rightClickedTab
    return unless active?
    @closeTab tab for tab in tabs when tab isnt active

  closeTabsToRight: (active) ->
    tabs = @getTabs()
    active ?= @rightClickedTab
    index = tabs.indexOf(active)
    return if index is -1
    @closeTab tab for tab, i in tabs when i > index

  closeTabsToLeft: (active) ->
    tabs = @getTabs()
    active ?= @rightClickedTab
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
    @draggedTab = @tabForElement(event.target)
    return unless @draggedTab

    event.dataTransfer.setData 'atom-event', 'true'

    @draggedTab.element.classList.add('is-dragging')
    @draggedTab.destroyTooltip()

    tabIndex = @tabs.indexOf(@draggedTab)
    event.dataTransfer.setData 'sortable-index', tabIndex

    paneIndex = @paneContainer.getPanes().indexOf(@pane)
    event.dataTransfer.setData 'from-pane-index', paneIndex
    event.dataTransfer.setData 'from-pane-id', @pane.id
    event.dataTransfer.setData 'from-window-id', @getWindowId()

    item = @pane.getItems()[@tabs.indexOf(@draggedTab)]
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
    return unless @tabForElement(event.target)

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

    tabs = @getTabs()
    placeholder = @getPlaceholder()
    return unless placeholder?

    if newDropTargetIndex < tabs.length
      tab = tabs[newDropTargetIndex]
      tab.element.classList.add 'is-drop-target'
      tab.element.parentElement.insertBefore(placeholder, tab.element)
    else
      if tab = tabs[newDropTargetIndex - 1]
        tab.element.classList.add 'drop-target-is-after'
        if sibling = tab.element.nextSibling
          tab.element.parentElement.insertBefore(placeholder, sibling)
        else
          tab.element.parentElement.appendChild(placeholder)

  onDropOnOtherWindow: (fromPaneId, fromItemIndex) ->
    if @pane.id is fromPaneId
      if itemToRemove = @pane.getItems()[fromItemIndex]
        @pane.destroyItem(itemToRemove)

    @clearDropTarget()

  clearDropTarget: ->
    @draggedTab?.element.classList.remove('is-dragging')
    @draggedTab?.updateTooltip()
    @draggedTab = null
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
      if fromPane?.id isnt fromPaneId
        # If dragging from a different pane container, we have to be more
        # exhaustive in our search.
        fromPane = Array.from document.querySelectorAll('atom-pane')
          .map (paneEl) -> paneEl.model
          .find (pane) -> pane.id is fromPaneId
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
    tab = @tabForElement(event.target)
    return unless tab

    if event.which is 3 or (event.which is 1 and event.ctrlKey is true)
      @rightClickedTab?.element.classList.remove('right-clicked')
      @rightClickedTab = tab
      @rightClickedTab.element.classList.add('right-clicked')
      event.preventDefault()
    else if event.which is 1 and not event.target.classList.contains('close-icon')
      @pane.activateItem(tab.item)
      setImmediate => @pane.activate() unless @pane.isDestroyed()
    else if event.which is 2
      @pane.destroyItem(tab.item)
      event.preventDefault()

  onDoubleClick: (event) ->
    if tab = @tabForElement(event.target)
      tab.item.terminatePendingState?()
    else if event.target is @element
      atom.commands.dispatch(@element, 'application:new-file')
      event.preventDefault()

  updateTabScrollingThreshold: ->
    @tabScrollingThreshold = atom.config.get('tabs.tabScrollingThreshold')

  updateTabScrolling: (value) ->
    if value is 'platform'
      @tabScrolling = (process.platform is 'linux')
    else
      @tabScrolling = value
    @tabScrollingThreshold = atom.config.get('tabs.tabScrollingThreshold')

    if @tabScrolling
      @element.addEventListener 'mousewheel', @onMouseWheel.bind(this)
    else
      @element.removeEventListener 'mousewheel', @onMouseWheel.bind(this)

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

    return if @isPlaceholder(target)

    tabs = @getTabs()
    tab = @tabForElement(target)
    tab ?= tabs[tabs.length - 1]

    return 0 unless tab?

    {left, width} = tab.element.getBoundingClientRect()
    elementCenter = left + width / 2
    elementIndex = tabs.indexOf(tab)

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

  onMouseEnter: ->
    for tab in @getTabs()
      {width} = tab.element.getBoundingClientRect()
      tab.element.style.maxWidth = width.toFixed(2) + 'px'
    return

  onMouseLeave: ->
    tab.element.style.maxWidth = '' for tab in @getTabs()
    return

  tabForElement: (element) ->
    currentElement = element
    while currentElement?
      if tab = @tabsByElement.get(currentElement)
        return tab
      else
        currentElement = currentElement.parentElement

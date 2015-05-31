path = require 'path'
{$} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'event-kit'

module.exports =
class TabView extends HTMLElement
  initialize: (@item) ->
    @path = @item.getPath?()

    @subscriptions = new CompositeDisposable()

    @classList.add('tab', 'sortable')

    @itemTitle = document.createElement('div')
    @itemTitle.classList.add('title')
    @appendChild(@itemTitle)

    closeIcon = document.createElement('div')
    closeIcon.classList.add('close-icon')
    @appendChild(closeIcon)

    @handleEvents()
    @updateDataAttributes()
    @updateTitle()
    @updateIcon()
    @updateModifiedStatus()
    @setupTooltip()

    if @path
      repo = @repoForPath(@path)
      @subscribeToRepo(repo)
      @updateStatus(repo)

  handleEvents: ->
    titleChangedHandler = =>
      @updateDataAttributes()
      @updateTitle()
      @updateTooltip()

    if typeof @item.onDidChangeTitle is 'function'
      @titleSubscription = @item.onDidChangeTitle(titleChangedHandler)
    else if typeof @item.on is 'function'
      #TODO Remove once old events are no longer supported
      @item.on('title-changed', titleChangedHandler)
      @titleSubscription = dispose: =>
        @item.off?('title-changed', titleChangedHandler)

    iconChangedHandler = =>
      @updateIcon()

    if typeof @item.onDidChangeIcon is 'function'
      @iconSubscription = @item.onDidChangeIcon? =>
        @updateIcon()
    else if typeof @item.on is 'function'
      #TODO Remove once old events are no longer supported
      @item.on('icon-changed', iconChangedHandler)
      @iconSubscription = dispose: =>
        @item.off?('icon-changed', iconChangedHandler)

    modifiedHandler = =>
      @updateModifiedStatus()

    if typeof @item.onDidChangeModified is 'function'
      @modifiedSubscription = @item.onDidChangeModified(modifiedHandler)
    else if typeof @item.on is 'function'
      #TODO Remove once old events are no longer supported
      @item.on('modified-status-changed', modifiedHandler)
      @modifiedSubscription = dispose: =>
        @item.off?('modified-status-changed', modifiedHandler)

    @configSubscription = atom.config.observe 'tabs.showIcons', =>
      @updateIconVisibility()

  setupTooltip: ->
    # Defer creating the tooltip until the tab is moused over
    onMouseEnter = =>
      @mouseEnterSubscription.dispose()
      @hasBeenMousedOver = true
      @updateTooltip()

      # Trigger again so the tooltip shows
      @dispatchEvent(new CustomEvent('mouseenter', bubbles: true))

    @mouseEnterSubscription = dispose: =>
      @removeEventListener('mouseenter', onMouseEnter)
      @mouseEnterSubscription = null

    @addEventListener('mouseenter', onMouseEnter)

  updateTooltip: ->
    return unless @hasBeenMousedOver

    @destroyTooltip()

    if @path
      @tooltip = atom.tooltips.add this,
        title: @path
        html: false
        delay:
          show: 1000
          hide: 100
        placement: 'bottom'

  destroyTooltip: ->
    return unless @hasBeenMousedOver
    @tooltip?.dispose()

  destroy: ->
    @titleSubscription?.dispose()
    @modifiedSubscription?.dispose()
    @iconSubscription?.dispose()
    @mouseEnterSubscription?.dispose()
    @configSubscription?.dispose()
    @subscriptions?.dispose()
    @destroyTooltip()
    @remove()

  updateDataAttributes: ->
    if @path
      @itemTitle.dataset.name = path.basename(@path)
      @itemTitle.dataset.path = @path
    else
      delete @itemTitle.dataset.name
      delete @itemTitle.dataset.path

    if itemClass = @item.constructor?.name
      @dataset.type = itemClass
    else
      delete @dataset.type

  updateTitle: ({updateSiblings, useLongTitle}={}) ->
    return if @updatingTitle
    @updatingTitle = true

    if updateSiblings is false
      title = @item.getTitle()
      title = @item.getLongTitle?() ? title if useLongTitle
      @itemTitle.textContent = title
    else
      title = @item.getTitle()
      useLongTitle = false
      for tab in @getTabs() when tab isnt this
        if tab.item.getTitle() is title
          tab.updateTitle(updateSiblings: false, useLongTitle: true)
          useLongTitle = true
      title = @item.getLongTitle?() ? title if useLongTitle

      @itemTitle.textContent = title

    @updatingTitle = false

  updateIcon: ->
    if @iconName
      @itemTitle.classList.remove('icon', "icon-#{@iconName}")

    if @iconName = @item.getIconName?()
      @itemTitle.classList.add('icon', "icon-#{@iconName}")

  getTabs: ->
    @parentElement?.querySelectorAll('.tab') ? []

  updateIconVisibility: ->
    if atom.config.get 'tabs.showIcons'
      @itemTitle.classList.remove('hide-icon')
    else
      @itemTitle.classList.add('hide-icon')

  updateModifiedStatus: ->
    if @item.isModified?()
      @classList.add('modified') unless @isModified
      @isModified = true
    else
      @classList.remove('modified') if @isModified
      @isModified = false

  # Subscribe to the project' repo for changes to the Git status of the file
  # on this tab.
  subscribeToRepo: (repo) ->
    return unless repo?

    @subscriptions.add repo.onDidChangeStatus (event) =>
      @updateStatus(repo) if @path is event.path
    @subscriptions.add repo.onDidChangeStatuses =>
      @updateStatus(repo)

  # Update the status property of this tab using the repo.
  updateStatus: (repo) ->
    return unless repo?

    newStatus = null
    if repo.isPathIgnored(@path)
      newStatus = 'ignored'
    else
      status = repo.getCachedPathStatus(@path)
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    if newStatus isnt @status
      @status = newStatus
      @itemTitle.classList.remove('status-ignored', 'status-modified',  'status-added')
      @itemTitle.classList.add("status-#{@status}") if @status

  repoForPath: (goalPath) ->
    for projectPath, i in atom.project.getPaths()
      if goalPath is projectPath or goalPath.indexOf(projectPath + path.sep) is 0
        return atom.project.getRepositories()[i]
    null

module.exports = document.registerElement('tabs-tab', prototype: TabView.prototype, extends: 'li')

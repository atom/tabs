path = require 'path'
{$} = require 'atom-space-pen-views'

module.exports =
class TabView extends HTMLElement
  initialize: (@item) ->
    @isPreviewTab = atom.config.get('tabs.usePreviewTabs') and @item.getPath?

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

    if @isPreviewTab
      @itemTitle.classList.add('temp')
      @classList.add('preview-tab')
      @addEventListener 'dblclick', => @clearPreview()

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

    if itemPath = @item.getPath?()
      @tooltip = atom.tooltips.add this,
        title: itemPath
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
    @destroyTooltip()
    @remove()

  updateDataAttributes: ->
    if itemPath = @item.getPath?()
      @itemTitle.dataset.name = path.basename(itemPath)
      @itemTitle.dataset.path = itemPath
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

  clearPreview: ->
    @isPreviewTab = false
    @itemTitle.classList.remove('temp')
    @classList.remove('preview-tab')

  updateIconVisibility: ->
    if atom.config.get 'tabs.showIcons'
      @itemTitle.classList.remove('hide-icon')
    else
      @itemTitle.classList.add('hide-icon')

  updateModifiedStatus: ->
    if @item.isModified?()
      @clearPreview()
      @classList.add('modified') unless @isModified
      @isModified = true
    else
      @classList.remove('modified') if @isModified
      @isModified = false

module.exports = document.registerElement('tabs-tab', prototype: TabView.prototype, extends: 'li')

path = require 'path'
{$} = require 'atom'

module.exports =
class TabView extends HTMLElement
  initialize: (@item) ->
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

  handleEvents: ->
    @titleSubscription = @item.onDidChangeTitle? =>
      @updateDataAttributes()
      @updateTitle()
      @updateTooltip()

    @iconSubscription = @item.onDidChangeIcon? =>
      @updateIcon()

    @modifiedSubscription = @item.onDidChangeModified? =>
      @updateModifiedStatus()

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

    $(this).destroyTooltip()

    if itemPath = @item.getPath?()
      $(this).setTooltip
        title: itemPath
        html: false
        delay:
          show: 2000
          hide: 100
        placement: 'bottom'

  destroy: ->
    @titleSubscription?.dispose()
    @modifiedSubscription?.dispose()
    @iconSubscription?.dispose()
    @mouseEnterSubscription?.dispose()
    @configSubscription?.off() # Not a Disposable yet

    $(this).destroyTooltip() if @hasBeenMousedOver
    @remove()

  updateDataAttributes: ->
    if itemPath = @item.getPath?()
      @itemTitle.dataset.name = path.basename(itemPath)
      @itemTitle.dataset.path = itemPath

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

module.exports = document.registerElement('tabs-tab', prototype: TabView.prototype, extends: 'li')
